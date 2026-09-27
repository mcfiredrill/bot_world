defmodule BotWorldWeb.UserAPIControllerTest do
  use BotWorldWeb.ConnCase, async: true

  alias BotWorld.Accounts
  alias BotWorldWeb.UserJWT

  defp json_conn(conn) do
    put_req_header(conn, "accept", "application/json")
  end

  describe "DELETE /api/users/log_out" do
    test "clears the current bearer token session", %{conn: conn} do
      user = register_user()
      jwt = BotWorldWeb.UserAuth.generate_user_api_token(user)
      {:ok, session_token} = UserJWT.verify(jwt)

      conn =
        conn
        |> json_conn()
        |> put_req_header("authorization", "Bearer #{jwt}")
        |> delete(~p"/api/users/log_out")

      assert response(conn, :no_content)
      assert get_session(conn, :user_token) == nil
      assert Accounts.get_user_by_session_token(session_token) == nil
    end
  end
end
