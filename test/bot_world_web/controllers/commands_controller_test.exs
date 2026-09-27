defmodule BotWorldWeb.CommandsControllerTest do
  use BotWorldWeb.ConnCase, async: true

  alias BotWorld.{Command, MediaGroup, Repo, Trigger}

  setup :register_and_log_in_user

  defp json_api_conn(conn) do
    put_req_header(conn, "accept", "application/vnd.api+json")
  end

  defp command_with_redeem_fixture(user) do
    command =
      %Command{user_id: user.id}
      |> Command.changeset(%{
        "name" => "hydrate-sound",
        "s3_key" => "sfx/hydrate.mp3",
        "media_type" => "audio"
      })
      |> Repo.insert!()

    group =
      %MediaGroup{name: "Hydration sounds", user_id: user.id}
      |> Repo.preload(:commands)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:commands, [command])
      |> Repo.insert!()

    trigger =
      %Trigger{user_id: user.id}
      |> Trigger.changeset(%{
        "name" => "Hydrate redeem",
        "type" => "twitch_point_redeem",
        "reward_name" => "Hydrate",
        "media_group_id" => group.id
      })
      |> Repo.insert!()

    {command, group, trigger}
  end

  test "GET /commands renders the media command form and group navigation", %{conn: conn} do
    conn = get(conn, ~p"/commands")
    body = html_response(conn, 200)

    assert body =~ "Media File"
    assert body =~ "Groups"
  end

  test "GET /commands shows trigger matching details in the commands table", %{
    conn: conn,
    user: user
  } do
    {_command, _group, _trigger} = command_with_redeem_fixture(user)

    body = conn |> get(~p"/commands") |> html_response(200)

    assert body =~ "Hydrate redeem"
    assert body =~ "Twitch Point Redeem"
    assert body =~ "Reward: Hydrate"
  end

  test "GET /commands/:command links to the editor for a linked redeem trigger", %{
    conn: conn,
    user: user
  } do
    {command, _group, trigger} = command_with_redeem_fixture(user)
    body = conn |> get(~p"/commands/#{command}") |> html_response(200)

    assert body =~ "Reward: Hydrate"
    assert body =~ ~s(href="/triggers/#{trigger.id}/edit")
    assert body =~ "Edit trigger"
  end

  test "GET /commands/:command does not expose another user's command", %{
    conn: conn
  } do
    other_user = register_user()

    other_command =
      %Command{user_id: other_user.id}
      |> Command.changeset(%{
        "name" => "private",
        "s3_key" => "users/#{other_user.id}/sfx/private.mp3",
        "media_type" => "audio"
      })
      |> Repo.insert!()

    assert_error_sent :not_found, fn ->
      get(conn, ~p"/commands/#{other_command}")
    end
  end

  test "DELETE /commands/:command deletes an ungrouped command", %{conn: conn, user: user} do
    {:ok, command} =
      %Command{user_id: user.id}
      |> Command.changeset(%{
        "name" => "hydrate-sound",
        "s3_key" => "sfx/hydrate.mp3",
        "media_type" => "audio"
      })
      |> Repo.insert()

    conn = delete(conn, ~p"/commands/#{command}")

    assert redirected_to(conn) == ~p"/commands"
    assert Repo.get(Command, command.id) == nil
  end

  test "GET /commands returns JSON for a JSON:API accept header", %{conn: conn, user: user} do
    {:ok, command} =
      %Command{user_id: user.id}
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
