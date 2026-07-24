defmodule BotWorld.Twitch.EventSubClient do
  @moduledoc """
  Maintains the Twitch EventSub WebSocket connection, creates subscriptions
  on session_welcome, and dispatches notifications to `BotWorld.Commands`.
  """

  use WebSockex
  require Logger
  alias BotWorld.Commands
  alias BotWorld.Twitch.Helix

  @eventsub_url "wss://eventsub.wss.twitch.tv/ws"

  def start_link(_opts \\ []) do
    case BotWorld.Twitch.event_sub_config() do
      {:ok, config} ->
        WebSockex.start_link(@eventsub_url, __MODULE__, %{session_id: nil, config: config}, name: __MODULE__)

      {:error, reason} ->
        Logger.warning("Not starting Twitch EventSub client: #{inspect(reason)}")
        :ignore
    end
  end

  @impl WebSockex
  def handle_frame({:text, msg}, state) do
    msg
    |> Jason.decode!()
    |> handle_message(state)
  end

  def handle_frame(_frame, state), do: {:ok, state}

  @impl WebSockex
  def handle_disconnect(%{reason: reason}, state) do
    Logger.warning("Twitch EventSub disconnected (#{inspect(reason)}), reconnecting")
    {:reconnect, state}
  end

  defp handle_message(
         %{
           "metadata" => %{"message_type" => "session_welcome"},
           "payload" => %{"session" => %{"id" => session_id}}
         },
         state
       ) do
    Logger.info("Twitch EventSub session established: #{session_id}")
    subscribe_all(session_id, state.config)
    {:ok, %{state | session_id: session_id}}
  end

  defp handle_message(%{"metadata" => %{"message_type" => "session_keepalive"}}, state) do
    {:ok, state}
  end

  defp handle_message(%{"metadata" => %{"message_type" => "session_reconnect"}}, state) do
    Logger.warning("Twitch EventSub requested reconnect; closing so the supervisor restarts fresh")
    {:close, state}
  end

  defp handle_message(
         %{
           "metadata" => %{"message_type" => "notification", "subscription_type" => subscription_type},
           "payload" => %{"event" => event}
         },
         state
       ) do
    Commands.dispatch_event(subscription_type, event)
    {:ok, state}
  end

  defp handle_message(%{"metadata" => %{"message_type" => "revocation"}} = json, state) do
    Logger.warning("Twitch EventSub subscription revoked: #{inspect(json)}")
    {:ok, state}
  end

  defp handle_message(json, state) do
    Logger.debug("Unhandled Twitch EventSub message: #{inspect(json)}")
    {:ok, state}
  end

  defp subscribe_all(session_id, config) do
    Enum.each(Helix.event_specs(), fn {event_type, version, condition_fun} ->
      Helix.create_subscription(event_type, version, condition_fun.(config), session_id, config)
    end)
  end
end
