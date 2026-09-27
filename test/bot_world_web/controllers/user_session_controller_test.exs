defmodule BotWorldWeb.UserSessionControllerTest do
  use BotWorldWeb.ConnCase, async: true

  test "GET /users/log_in offers Twitch as the only authentication method", %{conn: conn} do
    conn = get(conn, ~p"/users/log_in")
    response = html_response(conn, 200)

    assert response =~ "Continue with Twitch"
    assert response =~ ~p"/auth/twitch"
    refute response =~ "type=\"password\""
    refute response =~ "type=\"email\""
  end

  test "GET /users/register redirects to the shared Twitch login", %{conn: conn} do
    conn = get(conn, ~p"/users/register")
    assert redirected_to(conn) == ~p"/users/log_in"
  end

  test "legacy password endpoints no longer exist", %{conn: conn} do
    assert response(
             post(conn, "/users/log_in", %{
               user: %{email: "old@example.com", password: "password"}
             }),
             404
           )

    assert response(
             post(conn, "/api/users/log_in", %{
               user: %{email: "old@example.com", password: "password"}
             }),
             404
           )

    assert response(
             post(conn, "/api/users/register", %{
               user: %{email: "old@example.com", password: "password"}
             }),
             404
           )
  end
end
