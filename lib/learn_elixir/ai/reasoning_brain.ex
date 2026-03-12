defmodule LearnElixir.AI.ReasoningBrain do
  @moduledoc "A supervised GenServer that owns conversation context for a shared math session."

  use GenServer

  alias LearnElixir.AI
  alias LearnElixir.AI.StructuredSolver
  alias LearnElixir.Math.Plan
  alias LearnElixirWeb.Presence

  @chunk_delay 18
  @message_limit 24
  @conversation_limit 12

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: via(room_id))
  end

  @doc false
  def child_spec(room_id) do
    %{
      id: {__MODULE__, room_id},
      start: {__MODULE__, :start_link, [room_id]},
      restart: :permanent
    }
  end

  @impl true
  def init(room_id) do
    state = %{
      room_id: room_id,
      conversation: [],
      messages: [],
      thinking?: false,
      current_task: nil,
      current_stream: nil,
      status: status("idle", "Ready for a shared math problem")
    }

    {:ok, state, {:continue, :boot}}
  end

  @impl true
  def handle_continue(:boot, state) do
    {:ok, _meta} =
      Presence.track(self(), AI.agents_presence_topic(), state.room_id, presence_meta(state))

    broadcast_room(state, {:agent_booted, %{room_id: state.room_id, status: state.status}})
    broadcast_room(state, {:status, state.status})
    {:noreply, state}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply,
     %{
       room_id: state.room_id,
       messages: state.messages,
       thinking?: state.thinking?,
       status: state.status
     }, state}
  end

  @impl true
  def handle_call({:submit_problem, problem, viewer_id}, _from, state) do
    trimmed_problem = String.trim(problem)

    cond do
      trimmed_problem == "" ->
        {:reply, {:error, :empty}, state}

      state.thinking? ->
        {:reply, {:error, :busy}, state}

      true ->
        user_message =
          new_message("user", %{
            content: trimmed_problem,
            author: viewer_id,
            state: "done"
          })

        assistant_message =
          new_message("assistant", %{
            content: "",
            state: "pending"
          })

        task =
          Task.Supervisor.async_nolink(LearnElixir.TaskSupervisor, fn ->
            StructuredSolver.solve(trimmed_problem, state.conversation)
          end)

        new_status = status("thinking", "Structuring and checking the problem")

        new_state =
          state
          |> put_message(user_message)
          |> put_message(assistant_message)
          |> Map.put(:thinking?, true)
          |> Map.put(:current_task, %{
            ref: task.ref,
            assistant_id: assistant_message.id,
            viewer_id: viewer_id,
            prompt: trimmed_problem
          })
          |> Map.put(
            :conversation,
            trim_conversation(state.conversation ++ [%{role: "user", content: trimmed_problem}])
          )
          |> Map.put(:status, new_status)
          |> sync_presence()

        broadcast_room(new_state, {:message_upsert, user_message})
        broadcast_room(new_state, {:message_upsert, assistant_message})
        broadcast_room(new_state, {:status, new_status})

        {:reply, {:ok, assistant_message.id}, new_state}
    end
  end

  @impl true
  def handle_info({ref, {:ok, result}}, %{current_task: %{ref: ref} = task} = state) do
    Process.demonitor(ref, [:flush])

    case result do
      %{plan: %Plan{} = plan, provider: provider, verification: verification, warning: warning} ->
        message =
          state.messages
          |> find_message(task.assistant_id)
          |> Map.merge(%{
            provider: provider_label(provider),
            confidence: plan.confidence,
            formula: plan.normalized_expression,
            answer: Plan.format_answer(plan),
            verification: verification,
            warning: warning,
            steps: plan.steps,
            state: "streaming"
          })

        streaming_state =
          state
          |> Map.put(:current_task, nil)
          |> Map.put(:current_stream, %{
            assistant_id: task.assistant_id,
            content: "",
            chunks: build_chunks(plan, provider, verification, warning)
          })
          |> Map.put(:status, status("streaming", "Streaming a verified explanation"))
          |> put_message(message)
          |> sync_presence()

        broadcast_room(streaming_state, {:message_upsert, message})
        broadcast_room(streaming_state, {:status, streaming_state.status})
        send(self(), :emit_next_chunk)
        {:noreply, streaming_state}

      _ ->
        error_state =
          finalize_error(
            state,
            task.assistant_id,
            "The reasoning task returned an unexpected shape. Try a simpler arithmetic prompt."
          )

        {:noreply, error_state}
    end
  end

  def handle_info(
        {ref, {:error, reason}},
        %{current_task: %{ref: ref, assistant_id: assistant_id}} = state
      ) do
    Process.demonitor(ref, [:flush])
    {:noreply, finalize_error(state, assistant_id, error_to_string(reason))}
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{current_task: %{ref: ref, assistant_id: assistant_id}} = state
      ) do
    {:noreply,
     finalize_error(state, assistant_id, "The structured solver crashed: #{inspect(reason)}")}
  end

  def handle_info(:emit_next_chunk, %{current_stream: %{chunks: [chunk | rest]} = stream} = state) do
    updated_content = stream.content <> chunk
    last_chunk? = rest == []

    message =
      state.messages
      |> find_message(stream.assistant_id)
      |> Map.put(:content, updated_content)
      |> Map.put(:state, if(last_chunk?, do: "done", else: "streaming"))

    new_state =
      state
      |> put_message(message)
      |> Map.put(:current_stream, %{stream | chunks: rest, content: updated_content})

    broadcast_room(new_state, {:message_upsert, message})

    if last_chunk? do
      finished_state =
        new_state
        |> Map.put(:current_stream, nil)
        |> Map.put(:thinking?, false)
        |> Map.put(
          :conversation,
          trim_conversation(
            new_state.conversation ++ [%{role: "assistant", content: updated_content}]
          )
        )
        |> Map.put(:status, status("ready", "Verified answer delivered to the room"))
        |> sync_presence()

      broadcast_room(finished_state, {:status, finished_state.status})
      {:noreply, finished_state}
    else
      Process.send_after(self(), :emit_next_chunk, @chunk_delay)
      {:noreply, new_state}
    end
  end

  def handle_info(:emit_next_chunk, state), do: {:noreply, state}

  defp finalize_error(state, assistant_id, reason) do
    message =
      state.messages
      |> find_message(assistant_id)
      |> Map.merge(%{
        content: reason,
        state: "done",
        provider: "local recovery",
        verification: %{status: :unverified, expected: nil, given: nil, delta: nil},
        warning: nil,
        steps: []
      })

    new_state =
      state
      |> Map.put(:thinking?, false)
      |> Map.put(:current_task, nil)
      |> Map.put(:current_stream, nil)
      |> Map.put(:status, status("error", reason))
      |> Map.put(
        :conversation,
        trim_conversation(state.conversation ++ [%{role: "assistant", content: reason}])
      )
      |> put_message(message)
      |> sync_presence()

    broadcast_room(new_state, {:message_upsert, message})
    broadcast_room(new_state, {:status, new_state.status})
    new_state
  end

  defp via(room_id), do: {:via, Registry, {LearnElixir.AI.Registry, room_id}}

  defp sync_presence(state) do
    _result =
      Presence.update(
        self(),
        AI.agents_presence_topic(),
        state.room_id,
        presence_meta(state)
      )

    state
  end

  defp presence_meta(state) do
    %{
      label: "Brain / #{humanize_room(state.room_id)}",
      status: if(state.thinking?, do: "thinking", else: "idle"),
      phase: state.status.phase,
      last_problem: last_user_problem(state.conversation),
      updated_at: System.system_time(:millisecond)
    }
  end

  defp broadcast_room(state, event) do
    Phoenix.PubSub.broadcast(
      LearnElixir.PubSub,
      AI.room_topic(state.room_id),
      {:brain_event, event}
    )
  end

  defp status(phase, detail) do
    %{phase: phase, detail: detail, updated_at: System.system_time(:millisecond)}
  end

  defp put_message(state, message) do
    updated_messages =
      case Enum.find_index(state.messages, &(&1.id == message.id)) do
        nil ->
          (state.messages ++ [message])
          |> Enum.take(-@message_limit)

        index ->
          List.replace_at(state.messages, index, message)
      end

    %{state | messages: updated_messages}
  end

  defp find_message(messages, message_id) do
    Enum.find(messages, &(&1.id == message_id)) ||
      new_message("assistant", %{id: message_id, content: "", state: "pending"})
  end

  defp new_message(role, attrs) do
    %{
      id: Map.get(attrs, :id, build_id(role)),
      role: role,
      content: Map.get(attrs, :content, ""),
      author: Map.get(attrs, :author, role),
      state: Map.get(attrs, :state, "done"),
      provider: Map.get(attrs, :provider),
      confidence: Map.get(attrs, :confidence),
      formula: Map.get(attrs, :formula),
      answer: Map.get(attrs, :answer),
      verification: Map.get(attrs, :verification),
      warning: Map.get(attrs, :warning),
      steps: Map.get(attrs, :steps, []),
      inserted_at: System.system_time(:millisecond)
    }
  end

  defp build_chunks(plan, provider, verification, warning) do
    verification_line =
      case verification.status do
        :verified -> "Nx verification: confirmed #{format_number(verification.expected)}."
        :mismatch -> "Nx verification: expected #{format_number(verification.expected)} instead."
        _ -> "Nx verification: unavailable."
      end

    warning_line =
      if warning do
        "\nRecovery note: #{warning}\n"
      else
        ""
      end

    content =
      [
        "Structured source: #{provider_label(provider)}\n",
        "Formula: #{plan.normalized_expression}\n\n",
        Enum.map_join(plan.steps, "\n", fn step ->
          "#{step.position}. #{step.title}: #{step.detail}"
        end),
        "\n\nAnswer: #{Plan.format_answer(plan)}\n",
        verification_line,
        warning_line
      ]
      |> IO.iodata_to_binary()

    content
    |> String.split(~r/(\s+)/, include_captures: true, trim: true)
    |> Enum.chunk_every(4)
    |> Enum.map(&Enum.join/1)
  end

  defp provider_label(:instructor) do
    Application.get_env(:learn_elixir, :llm_provider_label, "Instructor")
  end

  defp provider_label(:fallback), do: "Local deterministic solver"
  defp provider_label(other), do: to_string(other)

  defp format_last_problem(nil), do: "Awaiting a shared math prompt"
  defp format_last_problem(%{role: "user", content: content}), do: content
  defp format_last_problem(%{content: content}), do: content

  defp last_user_problem(conversation) do
    conversation
    |> Enum.reverse()
    |> Enum.find_value("Awaiting a shared math prompt", fn
      %{role: "user", content: content} -> content
      other -> format_last_problem(other)
    end)
  end

  defp trim_conversation(conversation), do: Enum.take(conversation, -@conversation_limit)

  defp humanize_room(room_id) do
    room_id
    |> String.replace("-", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp error_to_string(reason) when is_binary(reason), do: reason
  defp error_to_string(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp error_to_string(reason), do: inspect(reason)

  defp build_id(role), do: "#{role}-#{System.unique_integer([:positive])}"

  defp format_number(nil), do: "unknown"

  defp format_number(number) do
    rounded = Float.round(number * 1.0, 6)

    if rounded == trunc(rounded) do
      Integer.to_string(trunc(rounded))
    else
      :erlang.float_to_binary(rounded, decimals: 6)
      |> String.trim_trailing("0")
      |> String.trim_trailing(".")
    end
  end
end
