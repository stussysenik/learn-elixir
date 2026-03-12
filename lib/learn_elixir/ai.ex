defmodule LearnElixir.AI do
  @moduledoc "Public API for supervised reasoning brains and agent presence."

  alias LearnElixir.AI.ReasoningBrain
  alias LearnElixirWeb.Presence

  @default_room "arithmetic-atrium"

  def default_room, do: @default_room

  def room_topic(room_id), do: "learn_elixir:room:" <> room_id
  def agents_presence_topic, do: "learn_elixir:agents"
  def agents_events_topic, do: "learn_elixir:agents:events"

  def ensure_brain(room_id \\ @default_room) do
    case Registry.lookup(LearnElixir.AI.Registry, room_id) do
      [{pid, _value}] ->
        {:ok, pid}

      [] ->
        case DynamicSupervisor.start_child(LearnElixir.AI.Supervisor, {ReasoningBrain, room_id}) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          other -> other
        end
    end
  end

  def snapshot(room_id \\ @default_room) do
    with {:ok, pid} <- ensure_brain(room_id) do
      GenServer.call(pid, :snapshot)
    end
  end

  def submit_problem(room_id, problem, viewer_id) do
    with {:ok, pid} <- ensure_brain(room_id) do
      GenServer.call(pid, {:submit_problem, problem, viewer_id}, 30_000)
    end
  end

  def list_agents do
    Presence.list(agents_presence_topic())
    |> Enum.map(fn {room_id, %{metas: metas}} ->
      meta = List.last(metas) || %{}

      %{
        room_id: room_id,
        label: meta[:label] || humanize_room(room_id),
        status: meta[:status] || "idle",
        phase: meta[:phase] || "idle",
        last_problem: meta[:last_problem] || "Awaiting a shared math prompt",
        updated_at: meta[:updated_at] || 0
      }
    end)
    |> Enum.sort_by(fn agent ->
      {agent.status != "thinking", -agent.updated_at}
    end)
  end

  defp humanize_room(room_id) do
    room_id
    |> String.replace("-", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
