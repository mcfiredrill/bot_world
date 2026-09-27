defmodule BotWorldWeb.TwitchAuthController do
  use BotWorldWeb, :controller

  alias BotWorld.Twitch
  alias BotWorldWeb.UserAuth

  def new(conn, _params) do
    state = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    conn
    |> put_session(:twitch_oauth_state, state)
    |> redirect(external: Twitch.authorize_url(state))
  end

  def callback(conn, params) do
    expected_state = get_session(conn, :twitch_oauth_state)
    conn = delete_session(conn, :twitch_oauth_state)

    if valid_state?(expected_state, params["state"]) do
      finish_callback(conn, params)
    else
      conn
      |> put_flash(:error, "Twitch authorization failed (state mismatch).")
      |> redirect(to: ~p"/users/log_in")
    end
  end

  defp finish_callback(conn, %{"code" => code}) do
    case Twitch.authenticate(code) do
      {:ok, %{user: user}} ->
        Twitch.connect_event_sub(user)
        UserAuth.log_in_user(conn, user)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Could not sign in with Twitch. Please try again.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  defp finish_callback(conn, %{"error_description" => description}) do
    conn
    |> put_flash(:error, "Twitch authorization failed: #{description}")
    |> redirect(to: ~p"/users/log_in")
  end

  defp finish_callback(conn, _params) do
    conn
    |> put_flash(:error, "Twitch authorization failed.")
    |> redirect(to: ~p"/users/log_in")
  end

  defp valid_state?(expected_state, returned_state)
       when is_binary(expected_state) and is_binary(returned_state) and
              byte_size(expected_state) == byte_size(returned_state) do
    Plug.Crypto.secure_compare(expected_state, returned_state)
  end

  defp valid_state?(_expected_state, _returned_state), do: false
end
