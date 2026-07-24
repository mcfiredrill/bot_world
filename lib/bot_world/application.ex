defmodule BotWorld.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BotWorldWeb.Telemetry,
      BotWorld.Repo,
      {DNSCluster, query: Application.get_env(:bot_world, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BotWorld.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: BotWorld.Finch},
      # Start a worker by calling: BotWorld.Worker.start_link(arg)
      # {BotWorld.Worker, arg},
      BotWorld.Twitch.ClientSupervisor,
      # Start to serve requests, typically the last entry
      BotWorldWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BotWorld.Supervisor]
    result = Supervisor.start_link(children, opts)

    BotWorld.Twitch.maybe_connect_event_sub()

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BotWorldWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
