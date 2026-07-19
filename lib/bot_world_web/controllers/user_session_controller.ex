defmodule BotWorldWeb.UserSessionController do
  use BotWorldWeb, :controller

  alias BotWorld.Accounts
  alias BotWorldWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, error_message: nil)
  end

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      case get_format(conn) do
        "json" ->
          token = UserAuth.generate_user_api_token(user)

          conn
          |> put_view(json: BotWorldWeb.UserSessionAPIJSON)
          |> put_status(:created)
          |> render(:show, user: user, token: token)

        _ ->
          conn
          |> put_flash(:info, "Welcome back!")
          |> UserAuth.log_in_user(user, user_params)
      end
    else
      invalid_credentials_response(conn)
    end
  end

  def create(conn, _params) do
    if get_format(conn) == "json" do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{errors: %{detail: "Expected user email and password."}})
    else
      render(conn, :new, error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end

  defp invalid_credentials_response(conn) do
    if get_format(conn) == "json" do
      conn
      |> put_status(:unauthorized)
      |> json(%{errors: %{detail: "Invalid email or password"}})
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      render(conn, :new, error_message: "Invalid email or password")
    end
  end
end
