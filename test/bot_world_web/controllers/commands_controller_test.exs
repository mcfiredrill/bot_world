defmodule BotWorldWeb.CommandsControllerTest do
  use BotWorldWeb.ConnCase, async: true

  alias BotWorld.{Command, Repo}

  setup :register_and_log_in_user

  defp json_api_conn(conn) do
    put_req_header(conn, "accept", "application/vnd.api+json")
  end

  test "GET /commands renders trigger inputs on the command form", %{conn: conn} do
    conn = get(conn, ~p"/commands")
    body = html_response(conn, 200)

    assert body =~ "Add Trigger"
    assert body =~ "Trigger Type"
    assert body =~ ~s(name="command[triggers][0][name]")
    assert body =~ ~s(name="command[triggers][0][type]")
  end

  test "GET /commands returns JSON for a JSON:API accept header", %{conn: conn} do
    {:ok, command} =
      %Command{}
      |> Command.changeset(%{
        "name" => "airhorn",
        "s3_key" => "sfx/airhorn.mp3",
        "media_type" => "audio"
      })
      |> Repo.insert()

    conn =
      conn
      |> json_api_conn()
      |> get(~p"/commands")

    assert %{
             "data" => [
               %{
                 "id" => id,
                 "type" => "commands",
                 "attributes" => %{
                   "name" => "airhorn",
                   "s3_key" => "sfx/airhorn.mp3",
                   "media_type" => "audio"
                 }
               }
             ]
           } = json_response(conn, 200)

    assert id == Integer.to_string(command.id)
  end

  test "GET /commands returns JSON unauthorized for a JSON:API request when logged out" do
    conn =
      build_conn()
      |> json_api_conn()
      |> get(~p"/commands")

    assert %{"errors" => [%{"detail" => "Authentication required."}]} = json_response(conn, 401)
  end
end
