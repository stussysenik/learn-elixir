defmodule LearnElixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LearnElixirWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:learn_elixir, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LearnElixir.PubSub},
      LearnElixirWeb.Presence,
      {Registry, keys: :unique, name: LearnElixir.AI.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: LearnElixir.AI.Supervisor},
      {Task.Supervisor, name: LearnElixir.TaskSupervisor},
      # Start a worker by calling: LearnElixir.Worker.start_link(arg)
      # {LearnElixir.Worker, arg},
      # Start to serve requests, typically the last entry
      LearnElixirWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LearnElixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LearnElixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
