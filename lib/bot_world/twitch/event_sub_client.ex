defmodule BotWorld.Twitch.EventSubClient do
  @moduledoc """
  Maintains the Twitch EventSub WebSocket connection, creates subscriptions
  on session_welcome, and dispatches notifications to `BotWorld.Media`.
  """

  use WebSockex
  require Logger
  alias BotWorld.Media
  alias BotWorld.Twitch.Helix

  @eventsub_url "wss://eventsub.wss.twitch.tv/ws"

  def child_spec(opts) do
    user_id = Keyword.fetch!(opts, :user_id)

    %{
      id: {__MODULE__, user_id},
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent
    }
  end

  def start_link(opts) do
    user_id = Keyword.fetch!(opts, :user_id)

    case BotWorld.Twitch.event_sub_config(user_id) do
      {:ok, config} ->
        WebSockex.start_link(
          @eventsub_url,
          __MODULE__,
          %{session_id: nil, config: config, reconnect_attempts: 0},
          name: via(user_id),
          handle_initial_conn_failure: true
        )

      {:error, reason} ->
        Logger.warning(
          "Not starting Twitch EventSub client for user #{user_id}: #{inspect(reason)}"
        )

        :ignore
    end
  end

  def via(user_id) do
    {:via, Registry, {BotWorld.Twitch.ClientRegistry, user_id}}
  end

  def whereis(user_id) do
    case Registry.lookup(BotWorld.Twitch.ClientRegistry, user_id) do
      [{pid, _value}] -> pid
      [] -> nil
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
    attempts = Map.get(state, :reconnect_attempts, 0)
    delay = reconnect_delay(attempts, reason)

    Logger.warning(
      "Twitch EventSub disconnected (#{inspect(reason)}), reconnecting in #{delay}ms"
    )

    Process.sleep(delay)
    {:reconnect, Map.put(state, :reconnect_attempts, attempts + 1)}
  end

  @doc false
  def reconnect_delay(attempts, reason) do
    base = if match?(%WebSockex.RequestError{code: 429}, reason), do: 30_000, else: 1_000
    min(base * Integer.pow(2, min(attempts, 6)), 60_000)
  end

  defp handle_message(
         %{
           "metadata" => %{"message_type" => "session_welcome"},
           "payload" => %{"session" => %{"id" => session_id}}
         },
         state
       ) do
    Logger.info("Twitch EventSub session established: #{session_id}")
    request_fun = Map.get(state, :request_fun, &default_request/1)

    with {:ok, config} <- BotWorld.Twitch.event_sub_config(state.config.user_id, request_fun),
         {:ok, config} <- subscribe_all(session_id, config, request_fun) do
      {:ok, %{state | session_id: session_id, config: config, reconnect_attempts: 0}}
    else
      {:error, reason} ->
        Logger.warning("Twitch EventSub subscriptions unavailable: #{inspect(reason)}")
        {:close, Map.put(state, :reconnect_attempts, 6)}
    end
  end

  defp handle_message(%{"metadata" => %{"message_type" => "session_keepalive"}}, state) do
    {:ok, state}
  end

  defp handle_message(%{"metadata" => %{"message_type" => "session_reconnect"}}, state) do
    Logger.warning(
      "Twitch EventSub requested reconnect; closing so the supervisor restarts fresh"
    )

    {:close, state}
  end

  defp handle_message(
         %{
           "metadata" => %{
             "message_type" => "notification",
             "subscription_type" => subscription_type
           },
           "payload" => %{"event" => event}
         },
         state
       ) do
    Logger.info("Twitch EventSub notification: #{subscription_type} #{inspect(event)}")
    Media.dispatch_event(state.config.user_id, subscription_type, event)
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

  defp subscribe_all(session_id, config, request_fun) do
    Enum.reduce_while(Helix.event_specs(), {:ok, config, false}, fn
      {event_type, version, condition_fun}, {:ok, config, refreshed?} ->
        result =
          Helix.create_subscription(
            event_type,
            version,
            condition_fun.(config),
            session_id,
            config,
            request_fun
          )

        case result do
          {:error, {401, _body}} when not refreshed? ->
            credential = BotWorld.Twitch.get_credential(config.user_id)

            with {:ok, token} <- BotWorld.Twitch.refresh_access_token(credential, request_fun),
                 config = %{config | oauth_token: token},
                 {:ok, _} <-
                   Helix.create_subscription(
                     event_type,
                     version,
                     condition_fun.(config),
                     session_id,
                     config,
                     request_fun
                   ) do
              {:cont, {:ok, config, true}}
            else
              error -> {:halt, error}
            end

          {:error, {401, _body}} ->
            {:halt, result}

          {:ok, _} ->
            {:cont, {:ok, config, refreshed?}}

          {:error, _} ->
            # A missing scope for one event should not prevent the others.
            {:cont, {:ok, config, refreshed?}}
        end
    end)
    |> case do
      {:ok, config, _} -> {:ok, config}
      error -> error
    end
  end

  defp default_request(request), do: Finch.request(request, BotWorld.Finch)
end
