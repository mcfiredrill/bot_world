defmodule BotWorldWeb.UserSessionController do
  use BotWorldWeb, :controller

  alias BotWorldWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new)
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
