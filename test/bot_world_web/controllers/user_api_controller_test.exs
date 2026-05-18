defmodule BotWorldWeb.UserAPIControllerTest do
  use BotWorldWeb.ConnCase, async: true

  alias BotWorld.Accounts
  alias BotWorldWeb.UserJWT

  defp json_conn(conn) do
    put_req_header(conn, "accept", "application/json")
  end

  defp json_request_conn(conn) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
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
               },
               "token" => token
             } = json_response(conn, :created)

      assert user_id
      assert {:ok, session_token} = UserJWT.verify(token)
      assert Accounts.get_user_by_session_token(session_token)
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
    test "returns a JWT and user JSON", %{conn: conn} do
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
               },
               "token" => token
             } = json_response(conn, :created)

      assert user_id == user.id
      assert email == user.email
      assert {:ok, session_token} = UserJWT.verify(token)
      assert Accounts.get_user_by_session_token(session_token)
      assert get_session(conn, :user_token) == nil
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

  describe "POST /users/log_in" do
    test "accepts JSON without a CSRF token and returns a JWT", %{conn: conn} do
      user = register_user(%{email: "root-login@example.com"})

      conn =
        conn
        |> json_request_conn()
        |> post(~p"/users/log_in", %{user: %{email: user.email, password: "hello world 123!"}})

      assert %{
               "user" => %{"id" => user_id, "email" => email},
               "token" => token
             } = json_response(conn, :created)

      assert user_id == user.id
      assert email == user.email
      assert {:ok, session_token} = UserJWT.verify(token)
      assert Accounts.get_user_by_session_token(session_token)
    end
  end

  describe "DELETE /api/users/log_out" do
    test "clears the current bearer token session", %{conn: conn} do
      user = register_user(%{email: "logout@example.com"})
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
