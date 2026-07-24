defmodule BotWorld.Twitch.Helix do
  @moduledoc """
  Twitch Helix API calls needed to drive EventSub over WebSocket.
  """

  require Logger

  @subscriptions_url "https://api.twitch.tv/helix/eventsub/subscriptions"
  @users_url "https://api.twitch.tv/helix/users"

  @doc """
  The EventSub subscriptions to create once a session is established, as
  `{event_type, version, condition_fun}` where `condition_fun` builds the
  Helix `condition` map from the Twitch config.
  """
  def event_specs do
    [
      {"channel.follow", "2",
       fn cfg -> %{broadcaster_user_id: cfg.broadcaster_id, moderator_user_id: cfg.broadcaster_id} end},
      {"channel.subscribe", "1", fn cfg -> %{broadcaster_user_id: cfg.broadcaster_id} end},
      {"channel.cheer", "1", fn cfg -> %{broadcaster_user_id: cfg.broadcaster_id} end},
      {"channel.channel_points_custom_reward_redemption.add", "1",
       fn cfg -> %{broadcaster_user_id: cfg.broadcaster_id} end}
    ]
  end

  def create_subscription(event_type, version, condition, session_id, config, request_fun \\ &default_request/1) do
    body =
      Jason.encode!(%{
        type: event_type,
        version: version,
        condition: condition,
        transport: %{method: "websocket", session_id: session_id}
      })

    headers = [
      {"authorization", "Bearer #{config.oauth_token}"},
      {"client-id", config.client_id},
      {"content-type", "application/json"}
    ]

    :post
    |> Finch.build(@subscriptions_url, headers, body)
    |> request_fun.()
    |> handle_response(event_type)
  end

  defp handle_response({:ok, %Finch.Response{status: status, body: body}}, _event_type)
       when status in 200..299 do
    {:ok, Jason.decode!(body)}
  end

  defp handle_response({:ok, %Finch.Response{status: status, body: body}}, event_type) do
    Logger.warning("Twitch Helix subscription failed (#{status}) for #{event_type}: #{body}")
    {:error, {status, body}}
  end

  defp handle_response({:error, reason}, event_type) do
    Logger.warning("Twitch Helix subscription request error for #{event_type}: #{inspect(reason)}")
    {:error, reason}
  end

  @doc """
  Fetches the Twitch user the given access token belongs to.
  """
  def get_current_user(access_token, client_id, request_fun \\ &default_request/1) do
    headers = [
      {"authorization", "Bearer #{access_token}"},
      {"client-id", client_id}
    ]

    :get
    |> Finch.build(@users_url, headers)
    |> request_fun.()
    |> handle_users_response()
  end

  defp handle_users_response({:ok, %Finch.Response{status: 200, body: body}}) do
    case Jason.decode!(body) do
      %{"data" => [user | _]} -> {:ok, user}
      _ -> {:error, :no_user}
    end
  end

  defp handle_users_response({:ok, %Finch.Response{status: status, body: body}}) do
    Logger.warning("Twitch Helix get users failed (#{status}): #{body}")
    {:error, {status, body}}
  end

  defp handle_users_response({:error, reason}) do
    Logger.warning("Twitch Helix get users request error: #{inspect(reason)}")
    {:error, reason}
  end

  defp default_request(request), do: Finch.request(request, BotWorld.Finch)
end
