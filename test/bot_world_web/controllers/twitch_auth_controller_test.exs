defmodule BotWorldWeb.TwitchAuthControllerTest do
  use BotWorldWeb.ConnCase, async: false

  alias BotWorld.Accounts
  alias BotWorld.Repo
  alias BotWorld.Twitch.Credential

  setup do
    previous_twitch_config = Application.get_env(:bot_world, :twitch)
    previous_request_fun = Application.get_env(:bot_world, :twitch_request_fun)

    Application.put_env(:bot_world, :twitch,
      client_id: "client-id",
      client_secret: "client-secret",
      redirect_uri: "https://example.test/auth/twitch/callback"
    )

    on_exit(fn ->
      Application.put_env(:bot_world, :twitch, previous_twitch_config)

      if previous_request_fun do
        Application.put_env(:bot_world, :twitch_request_fun, previous_request_fun)
      else
        Application.delete_env(:bot_world, :twitch_request_fun)
      end
    end)
  end

  test "GET /auth/twitch is public and stores a fresh OAuth state", %{conn: conn} do
    conn = get(conn, ~p"/auth/twitch")

    redirect_uri = redirected_to(conn)
    query = redirect_uri |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

    assert String.starts_with?(redirect_uri, "https://id.twitch.tv/oauth2/authorize?")
    assert query["client_id"] == "client-id"
    assert query["state"] == get_session(conn, :twitch_oauth_state)
    assert byte_size(query["state"]) >= 43
  end

  test "callback creates the Twitch user, logs them in, and preserves return_to", %{conn: conn} do
    Application.put_env(:bot_world, :twitch_request_fun, &successful_twitch_request/1)

    conn =
      conn
      |> init_test_session(%{
        twitch_oauth_state: "expected-state",
        user_return_to: "/triggers/new"
      })
      |> get(~p"/auth/twitch/callback?state=expected-state&code=oauth-code")

    assert redirected_to(conn) == "/triggers/new"
    assert get_session(conn, :twitch_oauth_state) == nil

    user = Accounts.get_user_by_session_token(get_session(conn, :user_token))
    assert user
    assert Repo.get_by!(Credential, twitch_user_id: "42").user_id == user.id
  end

  test "callback consumes state and rejects a mismatch without calling Twitch", %{conn: conn} do
    Application.put_env(:bot_world, :twitch_request_fun, fn _request ->
      flunk("Twitch must not be called when OAuth state does not match")
    end)

    conn =
      conn
      |> init_test_session(%{twitch_oauth_state: "expected-state"})
      |> get(~p"/auth/twitch/callback?state=wrong-state&code=oauth-code")

    assert redirected_to(conn) == ~p"/users/log_in"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "state mismatch"
    assert get_session(conn, :twitch_oauth_state) == nil
    assert get_session(conn, :user_token) == nil
  end

  test "denied authorization requires valid state and consumes it", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{twitch_oauth_state: "expected-state"})
      |> get(
        ~p"/auth/twitch/callback?state=expected-state&error=access_denied&error_description=The+user+denied+access"
      )

    assert redirected_to(conn) == ~p"/users/log_in"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "The user denied access"
    assert get_session(conn, :twitch_oauth_state) == nil
    assert get_session(conn, :user_token) == nil
  end

  defp successful_twitch_request(request) do
    case request.path do
      "/oauth2/token" ->
        body =
          Jason.encode!(%{
            access_token: "access-token",
            refresh_token: "refresh-token",
            scope: ["bits:read"],
            expires_in: 3600
          })

        {:ok, %Finch.Response{status: 200, body: body}}

      "/helix/users" ->
        body = Jason.encode!(%{data: [%{id: "42", login: "streamer"}]})
        {:ok, %Finch.Response{status: 200, body: body}}
    end
  end
end
