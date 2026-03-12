defmodule LearnElixirWeb.Presence do
  @moduledoc "Presence tracker for AI brains that also rebroadcasts agent changes to LiveViews."

  use Phoenix.Presence,
    otp_app: :learn_elixir,
    pubsub_server: LearnElixir.PubSub

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_metas(topic, diff, presences, state) do
    Phoenix.PubSub.local_broadcast(
      LearnElixir.PubSub,
      LearnElixir.AI.agents_events_topic(),
      {:presence_sync, topic, diff, presences}
    )

    {:ok, state}
  end
end
