defmodule LearnElixirWeb.MathLabLive do
  @moduledoc "Collaborative LiveView surface for supervised math reasoning agents."

  use LearnElixirWeb, :live_view

  alias LearnElixir.AI

  @impl true
  def mount(_params, _session, socket) do
    room_id = AI.default_room()
    viewer_id = "observer-" <> Integer.to_string(System.unique_integer([:positive]))
    snapshot = AI.snapshot(room_id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(LearnElixir.PubSub, AI.room_topic(room_id))
      Phoenix.PubSub.subscribe(LearnElixir.PubSub, AI.agents_events_topic())
    end

    latest_result = latest_assistant(snapshot.messages)

    socket =
      socket
      |> assign(:page_title, "Reasoning Brain Lab")
      |> assign(:room_id, room_id)
      |> assign(:viewer_id, viewer_id)
      |> assign(:agents, AI.list_agents())
      |> assign(:message_count, length(snapshot.messages))
      |> assign(:message_ids, MapSet.new(Enum.map(snapshot.messages, & &1.id)))
      |> assign(:busy?, snapshot.thinking?)
      |> assign(:current_status, snapshot.status)
      |> assign(:latest_result, latest_result)
      |> assign_form("")
      |> stream_configure(:messages, dom_id: &"message-#{&1.id}")
      |> stream(:messages, snapshot.messages, reset: true)

    {:ok, socket}
  end

  @impl true
  def handle_event("solve", %{"prompt" => %{"problem" => problem}}, socket) do
    case AI.submit_problem(socket.assigns.room_id, problem, socket.assigns.viewer_id) do
      {:ok, _assistant_id} ->
        {:noreply,
         socket
         |> assign_form("")
         |> assign(:busy?, true)}

      {:error, :empty} ->
        {:noreply,
         put_flash(socket, :error, "Add a math problem before sending it to the brain.")}

      {:error, :busy} ->
        {:noreply,
         put_flash(
           socket,
           :info,
           "The shared agent is already thinking. Wait for the current answer to finish streaming."
         )}
    end
  end

  def handle_event("use_example", %{"problem" => problem}, socket) do
    {:noreply, assign_form(socket, problem)}
  end

  @impl true
  def handle_info({:brain_event, {:message_upsert, message}}, socket) do
    new_message? = not MapSet.member?(socket.assigns.message_ids, message.id)

    socket =
      socket
      |> assign(:message_ids, MapSet.put(socket.assigns.message_ids, message.id))
      |> assign(:message_count, socket.assigns.message_count + if(new_message?, do: 1, else: 0))
      |> assign(:latest_result, latest_result(socket.assigns.latest_result, message))
      |> stream_insert(:messages, message, at: -1)

    {:noreply, socket}
  end

  def handle_info({:brain_event, {:status, status}}, socket) do
    {:noreply,
     socket
     |> assign(:busy?, status.phase in ["thinking", "streaming"])
     |> assign(:current_status, status)
     |> assign(:agents, AI.list_agents())}
  end

  def handle_info({:brain_event, {:agent_booted, _meta}}, socket) do
    {:noreply, assign(socket, :agents, AI.list_agents())}
  end

  def handle_info({:presence_sync, _topic, _diff, _presences}, socket) do
    {:noreply, assign(socket, :agents, AI.list_agents())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={%{}}>
      <section class="grid gap-[var(--sp-md)] xl:grid-cols-[minmax(0,1.55fr)_minmax(21rem,0.85fr)]">
        <div class="space-y-[var(--sp-md)]">
          <section class="panel-surface hero-surface overflow-hidden">
            <div class="grid gap-[var(--sp-md)] lg:grid-cols-[minmax(0,1.1fr)_minmax(18rem,0.9fr)]">
              <div class="space-y-[var(--sp-sm)]">
                <div class="flex flex-wrap items-center gap-3">
                  <span class="eyebrow">Shared AI Control Room</span>
                  <span class="status-pill">{status_label(@current_status.phase)}</span>
                </div>

                <div class="space-y-3">
                  <h1 class="headline">
                    Supervised math agents, streaming in real time, without a database.
                  </h1>
                  <p class="deck max-w-2xl">
                    This room runs one GenServer-backed reasoning brain under a DynamicSupervisor, tracks its live status with Presence, structures output through Instructor when configured, and verifies every result with Nx before the explanation finishes typing.
                  </p>
                </div>

                <div class="flex flex-wrap gap-3 text-sm text-[var(--color-muted)]">
                  <span class="badge-chip">Room: {@room_id}</span>
                  <span class="badge-chip">Viewer: {@viewer_id}</span>
                  <span class="badge-chip">Transcript: {@message_count} items</span>
                </div>

                <.form for={@form} id="brain-form" class="space-y-[var(--sp-sm)]" phx-submit="solve">
                  <.input
                    field={@form[:problem]}
                    type="textarea"
                    label="Give the room a problem"
                    placeholder="Try: ((14 + 6) * 3) / 5"
                    class="input-shell min-h-40 w-full rounded-[28px] border border-[color:rgba(17,49,42,0.16)] bg-white/85 px-5 py-4 text-base leading-7 text-[var(--color-ink)] shadow-[inset_0_1px_0_rgba(255,255,255,0.85)] outline-none transition duration-200 placeholder:text-[var(--color-muted)] focus:border-[var(--color-accent-strong)] focus:ring-0"
                  />

                  <div class="flex flex-wrap items-center gap-3">
                    <button
                      id="solve-button"
                      type="submit"
                      class="accent-button"
                      disabled={@busy?}
                    >
                      {if @busy?, do: "Brain Streaming", else: "Dispatch Problem"}
                    </button>

                    <button
                      type="button"
                      phx-click="use_example"
                      phx-value-problem="12 * (8 - 3)"
                      class="ghost-button"
                    >
                      Quick Multiply
                    </button>

                    <button
                      type="button"
                      phx-click="use_example"
                      phx-value-problem="(18 divided by 6) + 4"
                      class="ghost-button"
                    >
                      Divided + Add
                    </button>
                  </div>
                </.form>
              </div>

              <div class="stacked-metrics">
                <article class="metric-card">
                  <p class="metric-label">Live Agent Status</p>
                  <p class="metric-value">{@current_status.detail}</p>
                  <p class="metric-caption">
                    Presence and PubSub keep every open browser aligned on the same state.
                  </p>
                </article>

                <article class="metric-card metric-card-accent">
                  <p class="metric-label">Latest Verified Answer</p>
                  <%= if @latest_result do %>
                    <p class="metric-value">{@latest_result.answer || "Pending"}</p>
                    <p class="metric-caption">
                      Formula: {@latest_result.formula || "Awaiting output"}
                    </p>
                  <% else %>
                    <p class="metric-value">Waiting</p>
                    <p class="metric-caption">Submit a prompt to start the first shared stream.</p>
                  <% end %>
                </article>

                <article class="metric-card">
                  <p class="metric-label">Thinking Agents</p>
                  <p class="metric-value">{thinking_count(@agents)}</p>
                  <p class="metric-caption">
                    Presence snapshots are rebuilt every time agent metadata changes.
                  </p>
                </article>
              </div>
            </div>
          </section>

          <section class="panel-surface">
            <div class="mb-[var(--sp-sm)] flex items-center justify-between gap-4">
              <div>
                <p class="eyebrow">Room Transcript</p>
                <h2 class="section-title">Token stream</h2>
              </div>
              <span class="badge-chip">LiveView streams + `stream_insert/4`</span>
            </div>

            <div id="messages" phx-update="stream" class="space-y-[var(--sp-sm)]">
              <div id="messages-empty" class="empty-transcript hidden only:block">
                The shared room is quiet. Dispatch a problem and the reasoning brain will publish every step here.
              </div>

              <article
                :for={{dom_id, message} <- @streams.messages}
                id={dom_id}
                class={[
                  "message-shell transition duration-300",
                  if(message.role == "assistant", do: "assistant-shell", else: "user-shell")
                ]}
              >
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <div class="flex items-center gap-3">
                    <span class="message-role">{role_label(message.role)}</span>
                    <span class="badge-chip badge-chip-soft">{message.state}</span>
                    <%= if message.provider do %>
                      <span class="badge-chip badge-chip-soft">{message.provider}</span>
                    <% end %>
                  </div>

                  <%= if message.answer do %>
                    <span class="answer-tag">{message.answer}</span>
                  <% end %>
                </div>

                <p class="message-body whitespace-pre-wrap">{message.content}</p>

                <%= if message.formula do %>
                  <div class="formula-shell">
                    <p class="formula-label">Verified Formula</p>
                    <code>{message.formula}</code>
                  </div>
                <% end %>

                <%= if message.steps != [] do %>
                  <ol class="step-grid">
                    <li :for={step <- message.steps} class="step-card">
                      <p class="step-index">Step {step.position}</p>
                      <h3>{step.title}</h3>
                      <p>{step.detail}</p>
                    </li>
                  </ol>
                <% end %>

                <%= if message.verification do %>
                  <div class={verification_classes(message.verification.status)}>
                    {verification_text(message.verification)}
                  </div>
                <% end %>

                <%= if message.warning do %>
                  <p class="warning-note">{message.warning}</p>
                <% end %>
              </article>
            </div>
          </section>
        </div>

        <aside class="space-y-[var(--sp-md)]">
          <section class="panel-surface">
            <div class="mb-[var(--sp-sm)] flex items-center justify-between gap-4">
              <div>
                <p class="eyebrow">Presence</p>
                <h2 class="section-title">Thinking roster</h2>
              </div>
              <span class="badge-chip">{length(@agents)} tracked</span>
            </div>

            <div class="space-y-3">
              <article :for={agent <- @agents} class="agent-row">
                <div>
                  <p class="agent-name">{agent.label}</p>
                  <p class="agent-problem">{agent.last_problem}</p>
                </div>
                <span class={agent_status_classes(agent.status)}>
                  {String.capitalize(agent.status)}
                </span>
              </article>
            </div>
          </section>

          <section class="panel-surface">
            <div class="mb-[var(--sp-sm)] flex items-center justify-between gap-4">
              <div>
                <p class="eyebrow">Architecture</p>
                <h2 class="section-title">Why this stays responsive</h2>
              </div>

              <button
                type="button"
                class="ghost-button"
                phx-click={
                  JS.toggle(
                    to: "#constitution-panel",
                    in:
                      {"transition ease-out duration-300", "opacity-0 translate-y-2",
                       "opacity-100 translate-y-0"},
                    out:
                      {"transition ease-in duration-200", "opacity-100 translate-y-0",
                       "opacity-0 translate-y-2"}
                  )
                }
              >
                Toggle Blueprint
              </button>
            </div>

            <div id="constitution-panel" class="space-y-3">
              <article class="architecture-card">
                <h3>GenServer Brain</h3>
                <p>
                  Conversation context lives inside the supervised process, so each room stays stateful without Ecto or an external store.
                </p>
              </article>
              <article class="architecture-card">
                <h3>DynamicSupervisor</h3>
                <p>
                  Every brain is restartable. If a room process crashes, the supervisor boots a fresh process under the same registry key.
                </p>
              </article>
              <article class="architecture-card">
                <h3>Instructor + Nx</h3>
                <p>
                  Structured plans come from Instructor when configured, then Nx recomputes the same formula before the UI treats the answer as trustworthy.
                </p>
              </article>
            </div>
          </section>

          <section class="panel-surface">
            <p class="eyebrow">Design Constitution</p>
            <h2 class="section-title">12pt / Golden Ratio tokens</h2>
            <p class="deck">
              Every panel and control in this screen uses the prompt’s 12pt rhythm, layered shadows, logical spacing, and a 60/30/10 color split instead of the Phoenix starter theme.
            </p>
          </section>
        </aside>
      </section>
    </Layouts.app>
    """
  end

  defp assign_form(socket, problem) do
    assign(socket, :form, to_form(%{"problem" => problem}, as: :prompt))
  end

  defp latest_result(_current, %{role: "assistant", answer: answer} = message)
       when not is_nil(answer),
       do: message

  defp latest_result(current, _message), do: current

  defp latest_assistant(messages) do
    messages
    |> Enum.reverse()
    |> Enum.find(&(&1.role == "assistant" and not is_nil(&1.answer)))
  end

  defp thinking_count(agents) do
    Enum.count(agents, &(&1.status == "thinking"))
  end

  defp status_label("thinking"), do: "Thinking"
  defp status_label("streaming"), do: "Streaming"
  defp status_label("ready"), do: "Ready"
  defp status_label("error"), do: "Recovery"
  defp status_label(_phase), do: "Idle"

  defp role_label("assistant"), do: "Reasoning Brain"
  defp role_label(_role), do: "Room Input"

  defp verification_text(%{status: :verified, expected: expected}) do
    "Nx confirmed the answer at #{format_number(expected)}."
  end

  defp verification_text(%{status: :mismatch, expected: expected, given: given}) do
    "Nx found a mismatch: expected #{format_number(expected)}, received #{format_number(given)}."
  end

  defp verification_text(_verification) do
    "Verification data is unavailable for this message."
  end

  defp verification_classes(:verified), do: "verification-shell verification-shell-ok"
  defp verification_classes(:mismatch), do: "verification-shell verification-shell-warn"
  defp verification_classes(_status), do: "verification-shell"

  defp agent_status_classes("thinking"), do: "status-pill status-pill-hot"
  defp agent_status_classes(_status), do: "status-pill status-pill-calm"

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
