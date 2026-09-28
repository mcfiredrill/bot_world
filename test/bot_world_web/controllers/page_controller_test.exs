defmodule BotWorldWeb.PageControllerTest do
  use BotWorldWeb.ConnCase

  setup :register_and_log_in_user

  test "GET / renders the media_items index", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)

    assert body =~ "Create Media Item"
    assert body =~ "Uploaded Media"
  end
end
