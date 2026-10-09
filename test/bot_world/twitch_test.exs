defmodule BotWorld.TwitchTest do
  use BotWorld.DataCase, async: false

  alias BotWorld.Accounts.User
  alias BotWorld.Repo
  alias BotWorld.Twitch
  alias BotWorld.Twitch.Credential
  alias BotWorld.Twitch.EventSubClient

  setup do
    previous_config = Application.get_env(:bot_world, :twitch)

    Application.put_env(:bot_world, :twitch,
      client_id: "client-id",
      client_secret: "client-secret",
      redirect_uri: "https://example.test/auth/twitch/callback"
    )

    on_exit(fn -> Application.put_env(:bot_world, :twitch, previous_config) end)
  end

  test "authenticate/2 atomically creates a passwordless user and credential" do
    request_fun = twitch_request_fun("42", "streamer")

    assert {:ok, %{user: user, credential: credential}} =
             Twitch.authenticate("authorization-code", request_fun)

    assert credential.user_id == user.id
    assert credential.twitch_user_id == "42"
    assert credential.twitch_login == "streamer"
    assert credential.access_token == "access-token"
    assert credential.refresh_token == "refresh-token"
    assert credential.scopes == ["bits:read"]
    assert Repo.aggregate(User, :count) == 1
    assert Repo.aggregate(Credential, :count) == 1
  end

  test "authenticate/2 reuses the user identified by twitch_user_id and updates the credential" do
    assert {:ok, %{user: original_user}} =
             Twitch.authenticate("first-code", twitch_request_fun("42", "old_login"))

    assert {:ok, %{user: returned_user, credential: credential}} =
             Twitch.authenticate(
               "second-code",
               twitch_request_fun("42", "new_login", "new-access-token")
             )

    assert returned_user.id == original_user.id
    assert credential.user_id == original_user.id
    assert credential.twitch_login == "new_login"
    assert credential.access_token == "new-access-token"
    assert Repo.aggregate(User, :count) == 1
    assert Repo.aggregate(Credential, :count) == 1
  end

  test "authenticate/2 does not persist anything when Twitch user lookup fails" do
    request_fun = fn request ->
      case request.path do
        "/oauth2/token" -> token_response()
        "/helix/users" -> {:ok, %Finch.Response{status: 401, body: "unauthorized"}}
      end
    end

    assert {:error, {401, "unauthorized"}} =
             Twitch.authenticate("authorization-code", request_fun)

    assert Repo.aggregate(User, :count) == 0
    assert Repo.aggregate(Credential, :count) == 0
  end

  test "credentials and EventSub configs are resolved independently by user" do
    assert {:ok, %{user: first_user}} =
             Twitch.authenticate("first-code", twitch_request_fun("42", "first_streamer"))

    assert {:ok, %{user: second_user}} =
             Twitch.authenticate("second-code", twitch_request_fun("84", "second_streamer"))

    assert Twitch.get_credential(first_user).twitch_user_id == "42"
    assert Twitch.get_credential(second_user.id).twitch_user_id == "84"
    assert Enum.map(Twitch.list_credentials(), & &1.user_id) == [first_user.id, second_user.id]

    assert {:ok, first_config} = Twitch.event_sub_config(first_user)
    assert {:ok, second_config} = Twitch.event_sub_config(second_user)

    assert first_config.user_id == first_user.id
    assert first_config.broadcaster_id == "42"
    assert second_config.user_id == second_user.id
    assert second_config.broadcaster_id == "84"
  end

  test "EventSub clients have a unique child and registry identity per user" do
    first_spec = EventSubClient.child_spec(user_id: 1)
    second_spec = EventSubClient.child_spec(user_id: 2)

    assert first_spec.id == {EventSubClient, 1}
    assert second_spec.id == {EventSubClient, 2}
    assert first_spec.start != second_spec.start

    assert EventSubClient.via(1) ==
             {:via, Registry, {BotWorld.Twitch.ClientRegistry, 1}}

    assert EventSubClient.via(2) ==
             {:via, Registry, {BotWorld.Twitch.ClientRegistry, 2}}
  end

  test "EventSub reloads credentials on welcome and refreshes once after a 401" do
    assert {:ok, %{user: user}} =
             Twitch.authenticate("first-code", twitch_request_fun("42", "streamer"))

    request_fun = fn request ->
      case request.path do
        "/oauth2/token" ->
          assert URI.decode_query(request.body)["grant_type"] == "refresh_token"
          send(self(), :refreshed)
          token_response("fresh-token")

        "/helix/eventsub/subscriptions" ->
          cond do
            {"authorization", "Bearer access-token"} in request.headers ->
              {:ok, %Finch.Response{status: 401, body: "invalid token"}}

            {"authorization", "Bearer fresh-token"} in request.headers ->
              send(self(), {:subscribed, Jason.decode!(request.body)["type"]})
              {:ok, %Finch.Response{status: 202, body: ~s({"data":[]})}}
          end
      end
    end

    state = %{
      config: %{user_id: user.id, oauth_token: "stale-in-memory-token"},
      session_id: nil,
      reconnect_attempts: 4,
      request_fun: request_fun
    }

    assert {:ok, new_state} = EventSubClient.handle_frame(welcome_frame(), state)
    assert new_state.config.oauth_token == "fresh-token"
    assert new_state.reconnect_attempts == 0
    assert Twitch.get_credential(user).access_token == "fresh-token"
    assert_received :refreshed
    refute_received :refreshed

    for {type, _, _} <- BotWorld.Twitch.Helix.event_specs() do
      assert_received {:subscribed, ^type}
    end
  end

  test "EventSub stops subscribing when the refreshed token is still rejected" do
    assert {:ok, %{user: user}} =
             Twitch.authenticate("first-code", twitch_request_fun("42", "streamer"))

    request_fun = fn request ->
      case request.path do
        "/oauth2/token" ->
          send(self(), :refreshed)
          token_response("fresh-token")

        "/helix/eventsub/subscriptions" ->
          send(self(), :subscription_attempt)
          {:ok, %Finch.Response{status: 401, body: "invalid token"}}
      end
    end

    state = %{
      config: %{user_id: user.id},
      session_id: nil,
      reconnect_attempts: 0,
      request_fun: request_fun
    }

    assert {:close, new_state} = EventSubClient.handle_frame(welcome_frame(), state)
    assert new_state.reconnect_attempts == 6
    assert_received :refreshed
    refute_received :refreshed
    assert_received :subscription_attempt
    assert_received :subscription_attempt
    refute_received :subscription_attempt
  end

  test "reconnect delays grow, are capped, and give rate limiting a cooldown" do
    assert EventSubClient.reconnect_delay(0, :closed) == 1_000
    assert EventSubClient.reconnect_delay(3, :closed) == 8_000
    assert EventSubClient.reconnect_delay(100, :closed) == 60_000
    rate_limit = %WebSockex.RequestError{code: 429, message: "Too Many Requests"}
    assert EventSubClient.reconnect_delay(0, rate_limit) == 30_000
    assert EventSubClient.reconnect_delay(1, rate_limit) == 60_000
  end

  defp welcome_frame do
    {:text,
     Jason.encode!(%{
       metadata: %{message_type: "session_welcome"},
       payload: %{session: %{id: "new-session"}}
     })}
  end

  defp twitch_request_fun(twitch_user_id, twitch_login, access_token \\ "access-token") do
    fn request ->
      case request.path do
        "/oauth2/token" ->
          assert request.method == "POST"

          assert URI.decode_query(request.body)["code"] in [
                   "authorization-code",
                   "first-code",
                   "second-code"
                 ]

          token_response(access_token)

        "/helix/users" ->
          assert request.method == "GET"
          assert {"authorization", "Bearer #{access_token}"} in request.headers

          body = Jason.encode!(%{data: [%{id: twitch_user_id, login: twitch_login}]})
          {:ok, %Finch.Response{status: 200, body: body}}
      end
    end
  end

  defp token_response(access_token \\ "access-token") do
    body =
      Jason.encode!(%{
        access_token: access_token,
        refresh_token: "refresh-token",
        scope: ["bits:read"],
        expires_in: 3600
      })

    {:ok, %Finch.Response{status: 200, body: body}}
  end
end
