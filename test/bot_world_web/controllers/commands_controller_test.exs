defmodule BotWorldWeb.CommandsControllerTest do
  use BotWorldWeb.ConnCase, async: true

  setup :register_and_log_in_user

  test "GET /commands renders trigger inputs on the command form", %{conn: conn} do
    conn = get(conn, ~p"/commands")
    body = html_response(conn, 200)

    assert body =~ "Add Trigger"
    assert body =~ "Trigger Type"
    assert body =~ ~s(name="command[triggers][0][name]")
    assert body =~ ~s(name="command[triggers][0][type]")
  end
end
