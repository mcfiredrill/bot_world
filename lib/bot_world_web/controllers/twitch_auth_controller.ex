defmodule BotWorldWeb.TwitchAuthController do
  use BotWorldWeb, :controller

  alias BotWorld.Twitch

  def new(conn, _params) do
    state = Base.url_encode64(:crypto.strong_rand_bytes(24))

    conn
    |> put_session(:twitch_oauth_state, state)
    |> redirect(external: Twitch.authorize_url(state))
  end

  def callback(conn, %{"state" => state, "code" => code}) do
    expected_state = get_session(conn, :twitch_oauth_state)
    conn = delete_session(conn, :twitch_oauth_state)

    if is_binary(expected_state) and state == expected_state do
      case Twitch.connect(conn.assigns.current_user, code) do
        {:ok, credential} ->
          Twitch.connect_event_sub()

          conn
          |> put_flash(:info, "Connected Twitch account @#{credential.twitch_login}.")
          |> redirect(to: ~p"/commands")

        {:error, _reason} ->
          conn
          |> put_flash(:error, "Could not connect your Twitch account. Please try again.")
          |> redirect(to: ~p"/commands")
      end
    else
      conn
      |> put_flash(:error, "Twitch authorization failed (state mismatch).")
      |> redirect(to: ~p"/commands")
    end
  end

  def callback(conn, %{"error_description" => description}) do
    conn
    |> put_flash(:error, "Twitch authorization failed: #{description}")
    |> redirect(to: ~p"/commands")
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Twitch authorization failed.")
    |> redirect(to: ~p"/commands")
  end
end
