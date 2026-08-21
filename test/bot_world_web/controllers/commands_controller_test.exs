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

  test "GET /commands shows trigger matching details in the commands table", %{conn: conn} do
    {:ok, _command} =
      %Command{}
      |> Command.changeset(%{
        "name" => "hydrate-sound",
        "s3_key" => "sfx/hydrate.mp3",
        "media_type" => "audio",
        "triggers" => [
          %{
            "name" => "Hydrate redeem",
            "type" => "twitch_point_redeem",
            "reward_name" => "Hydrate"
          }
        ]
      })
      |> Repo.insert()

    body = conn |> get(~p"/commands") |> html_response(200)

    assert body =~ "Hydrate redeem"
    assert body =~ "Twitch Point Redeem"
    assert body =~ "Reward: Hydrate"
  end

  test "GET /commands/:command links to the editor for a linked redeem trigger", %{conn: conn} do
    {:ok, command} =
      %Command{}
      |> Command.changeset(%{
        "name" => "hydrate-sound",
        "s3_key" => "sfx/hydrate.mp3",
        "media_type" => "audio",
        "triggers" => [
          %{
            "name" => "Hydrate redeem",
            "type" => "twitch_point_redeem",
            "reward_name" => "Hydrate"
          }
        ]
      })
      |> Repo.insert()

    trigger = command |> Repo.preload(:triggers) |> Map.fetch!(:triggers) |> List.first()
    body = conn |> get(~p"/commands/#{command}") |> html_response(200)

    assert body =~ "Reward: Hydrate"
    assert body =~ ~s(href="/triggers/#{trigger.id}/edit")
    assert body =~ "Edit trigger"
  end

  test "DELETE /commands/:command deletes the command and its linked triggers", %{conn: conn} do
    {:ok, command} =
      %Command{}
      |> Command.changeset(%{
        "name" => "hydrate-sound",
        "s3_key" => "sfx/hydrate.mp3",
        "media_type" => "audio",
        "triggers" => [
          %{
            "name" => "Hydrate redeem",
            "type" => "twitch_point_redeem",
            "reward_name" => "Hydrate"
          }
        ]
      })
      |> Repo.insert()

    trigger_id = command |> Repo.preload(:triggers) |> Map.fetch!(:triggers) |> List.first() |> Map.fetch!(:id)

    conn = delete(conn, ~p"/commands/#{command}")

    assert redirected_to(conn) == ~p"/commands"
    assert Repo.get(Command, command.id) == nil
    assert Repo.get(BotWorld.Trigger, trigger_id) == nil
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
                 "type" => "command",
                 "attributes" => %{
                   "name" => "airhorn",
                   "s3-key" => "sfx/airhorn.mp3",
                   "media-type" => "audio"
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
