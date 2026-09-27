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
