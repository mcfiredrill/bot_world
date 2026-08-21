defmodule BotWorldWeb.PageControllerTest do
  use BotWorldWeb.ConnCase

  setup :register_and_log_in_user

  test "GET / renders the commands index", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)

    assert body =~ "Create Command"
    assert body =~ "Uploaded Commands"
  end
end
