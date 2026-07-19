defmodule BotWorldWeb.UserSessionAPIController do
  use BotWorldWeb, :controller

  alias BotWorld.Accounts
  alias BotWorldWeb.UserAuth

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      token = UserAuth.generate_user_api_token(user)

      conn
      |> put_status(:created)
      |> render(:show, user: user, token: token)
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{errors: %{detail: "Invalid email or password"}})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{detail: "Expected user email and password."}})
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user_session()
    |> send_resp(:no_content, "")
  end
end
