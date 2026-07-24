defmodule BotWorld.Twitch.ClientSupervisor do
  @moduledoc """
  Dynamic supervisor for `BotWorld.Twitch.EventSubClient`, so the client can
  be started/restarted on demand once a broadcaster's Twitch account is
  connected, rather than only at application boot.
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
