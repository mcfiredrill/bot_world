defmodule BotWorld.Twitch.ClientSupervisor do
  @moduledoc """
  Dynamic supervisor for the per-user `BotWorld.Twitch.EventSubClient`
  processes. Each connected Twitch identity has an independently restartable
  WebSocket connection.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
