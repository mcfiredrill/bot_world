defmodule BotWorld.Twitch.HelixTest do
  use ExUnit.Case, async: true

  alias BotWorld.Twitch.Helix

  @config %{client_id: "client123", oauth_token: "token123", broadcaster_id: "42"}

  test "event_specs/0 lists the four supported EventSub subscriptions" do
    specs = Helix.event_specs()

    assert Enum.map(specs, fn {type, version, _fun} -> {type, version} end) == [
             {"channel.follow", "2"},
             {"channel.subscribe", "1"},
             {"channel.cheer", "1"},
             {"channel.channel_points_custom_reward_redemption.add", "1"}
           ]

    assert [{_, _, follow_condition_fun} | _] = specs
    assert follow_condition_fun.(@config) == %{broadcaster_user_id: "42", moderator_user_id: "42"}
  end

  test "create_subscription/6 posts the expected request to Helix" do
    request_fun = fn %Finch.Request{} = request ->
      assert request.method == "POST"
      assert request.scheme == :https
      assert request.host == "api.twitch.tv"
      assert request.path == "/helix/eventsub/subscriptions"

      assert {"authorization", "Bearer token123"} in request.headers
      assert {"client-id", "client123"} in request.headers

      assert Jason.decode!(request.body) == %{
               "type" => "channel.follow",
               "version" => "2",
               "condition" => %{"broadcaster_user_id" => "42"},
               "transport" => %{"method" => "websocket", "session_id" => "session-abc"}
             }

      {:ok, %Finch.Response{status: 202, body: ~s({"data":[]})}}
    end

    assert {:ok, %{"data" => []}} =
             Helix.create_subscription(
               "channel.follow",
               "2",
               %{broadcaster_user_id: "42"},
               "session-abc",
               @config,
               request_fun
             )
  end

  test "create_subscription/6 returns an error for non-2xx responses" do
    request_fun = fn _request -> {:ok, %Finch.Response{status: 401, body: "unauthorized"}} end

    assert {:error, {401, "unauthorized"}} =
             Helix.create_subscription(
               "channel.follow",
               "2",
               %{broadcaster_user_id: "42"},
               "session-abc",
               @config,
               request_fun
             )
  end
end
