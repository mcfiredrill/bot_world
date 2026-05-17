defmodule BotWorldWeb.UserAPIControllerTest do
  use BotWorldWeb.ConnCase, async: true

  alias BotWorld.Accounts

  defp json_conn(conn) do
    put_req_header(conn, "accept", "application/json")
  end

  describe "POST /api/users/register" do
    test "registers a user and returns JSON", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/users/register", %{
          user: %{email: "register@example.com", password: "hello world 123!"}
        })

      assert %{
               "user" => %{
                 "id" => user_id,
                 "email" => "register@example.com"
               }
             } = json_response(conn, :created)

      assert user_id
      assert get_session(conn, :user_token)
    end

    test "returns validation errors as JSON", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/users/register", %{user: %{email: "bad", password: "short"}})

      assert %{
               "errors" => %{
                 "email" => [_ | _],
                 "password" => [_ | _]
               }
             } = json_response(conn, :unprocessable_entity)
    end
  end

  describe "POST /api/users/log_in" do
    test "creates a session and returns JSON", %{conn: conn} do
      user = register_user(%{email: "login@example.com"})

      conn =
        conn
        |> json_conn()
        |> post(~p"/api/users/log_in", %{
          user: %{email: user.email, password: "hello world 123!"}
        })

      assert %{
               "user" => %{
                 "id" => user_id,
                 "email" => email
               }
             } = json_response(conn, :created)

      assert user_id == user.id
      assert email == user.email
      assert get_session(conn, :user_token)
    end

    test "returns JSON for invalid credentials", %{conn: conn} do
      user = register_user(%{email: "invalid-login@example.com"})

      conn =
        conn
        |> json_conn()
        |> post(~p"/api/users/log_in", %{
          user: %{email: user.email, password: "not the right password"}
        })

      assert %{"errors" => %{"detail" => "Invalid email or password"}} =
               json_response(conn, :unauthorized)
    end
  end

  describe "DELETE /api/users/log_out" do
    test "clears the current session", %{conn: conn} do
      user = register_user(%{email: "logout@example.com"})
      user_token = Accounts.generate_user_session_token(user)

      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_token, user_token)
        |> json_conn()
        |> delete(~p"/api/users/log_out")

      assert response(conn, :no_content)
      assert get_session(conn, :user_token) == nil
      assert Accounts.get_user_by_session_token(user_token) == nil
    end
  end
end
