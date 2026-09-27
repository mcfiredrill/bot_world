defmodule BotWorldWeb.UserSessionAPIController do
  use BotWorldWeb, :controller

  alias BotWorldWeb.UserAuth

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user_session()
    |> send_resp(:no_content, "")
  end
end
