defmodule Sturdy.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SturdyWeb.Telemetry,
      Sturdy.Repo,
      {DNSCluster, query: Application.get_env(:sturdy, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Sturdy.PubSub},
      # Start a worker by calling: Sturdy.Worker.start_link(arg)
      # {Sturdy.Worker, arg},
      # Start to serve requests, typically the last entry
      SturdyWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sturdy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SturdyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
