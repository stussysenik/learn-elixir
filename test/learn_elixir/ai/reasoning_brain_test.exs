defmodule LearnElixir.AI.ReasoningBrainTest do
  use ExUnit.Case, async: false

  alias LearnElixir.AI

  test "streams a verified answer into the shared room" do
    room_id = unique_room()
    Phoenix.PubSub.subscribe(LearnElixir.PubSub, AI.room_topic(room_id))
    {:ok, _pid} = AI.ensure_brain(room_id)

    on_exit(fn -> cleanup_room(room_id) end)

    assert %{status: %{phase: "idle"}} = AI.snapshot(room_id)
    assert {:ok, _assistant_id} = AI.submit_problem(room_id, "12 * (8 - 3)", "tester-1")

    assert_receive {:brain_event, {:message_upsert, %{role: "user", content: "12 * (8 - 3)"}}}
    assert_receive {:brain_event, {:status, %{phase: "thinking"}}}

    assert_receive {:brain_event, {:message_upsert, %{role: "assistant", state: "streaming"}}},
                   1_500

    assert_receive {:brain_event, {:status, %{phase: "ready"}}}, 4_000

    snapshot = AI.snapshot(room_id)
    assistant = Enum.find(snapshot.messages, &(&1.role == "assistant"))

    assert assistant.answer == "60"
    assert assistant.formula == "12 * (8 - 3)"
    assert assistant.verification.status == :verified
    assert snapshot.thinking? == false
  end

  test "the dynamic supervisor restarts a crashed brain" do
    room_id = unique_room()
    Phoenix.PubSub.subscribe(LearnElixir.PubSub, AI.room_topic(room_id))
    {:ok, pid} = AI.ensure_brain(room_id)

    on_exit(fn -> cleanup_room(room_id) end)

    assert_receive {:brain_event, {:agent_booted, %{room_id: ^room_id}}}

    ref = Process.monitor(pid)
    Process.exit(pid, :kill)

    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}
    assert_receive {:brain_event, {:agent_booted, %{room_id: ^room_id}}}, 2_000

    {:ok, restarted_pid} = AI.ensure_brain(room_id)

    refute restarted_pid == pid
    assert %{status: %{phase: "idle"}} = AI.snapshot(room_id)
  end

  defp unique_room do
    "room-" <> Integer.to_string(System.unique_integer([:positive]))
  end

  defp cleanup_room(room_id) do
    case Registry.lookup(LearnElixir.AI.Registry, room_id) do
      [{pid, _value}] ->
        DynamicSupervisor.terminate_child(LearnElixir.AI.Supervisor, pid)

      [] ->
        :ok
    end
  end
end
