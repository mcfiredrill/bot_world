defmodule BotWorldWeb.TriggersAPIControllerTest do
  use BotWorldWeb.ConnCase, async: true

  alias BotWorld.{Command, MediaGroup, Repo, Trigger}

  defp json_conn(conn) do
    put_req_header(conn, "accept", "application/json")
  end

  defp command_fixture(user) do
    {:ok, command} =
      %Command{user_id: user.id}
      |> Command.changeset(%{
        name: "applause",
        s3_key: "sfx/applause.mp3",
        media_type: "audio"
      })
      |> Repo.insert()

    command
  end

  defp trigger_fixture(user, command) do
    group = group_fixture(user, command)

    {:ok, trigger} =
      %Trigger{user_id: user.id}
      |> Trigger.changeset(%{
        name: "Bits trigger",
        type: "twitch_bits",
        media_group_id: group.id
      })
      |> Repo.insert()

    Repo.preload(trigger, media_group: :commands)
  end

  defp group_fixture(user, command) do
    %MediaGroup{name: "#{command.name} group", user_id: user.id}
    |> Repo.preload(:commands)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:commands, [command])
    |> Repo.insert!()
  end

  describe "authentication" do
    test "requires an authenticated user", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> get(~p"/api/triggers")

      assert %{"errors" => %{"detail" => "Authentication required."}} =
               json_response(conn, :unauthorized)
    end
  end

  describe "GET /api/triggers" do
    setup %{conn: conn} do
      user = register_user()
      %{conn: authenticate_api_user(conn, user), user: user}
    end

    test "lists triggers and shows nested media group data", %{conn: conn, user: user} do
      command = command_fixture(user)
      trigger = trigger_fixture(user, command)

      conn =
        conn
        |> json_conn()
        |> get(~p"/api/triggers")

      assert %{
               "triggers" => [
                 %{
                   "id" => id,
                   "name" => "Bits trigger",
                   "type" => "twitch_bits",
                   "media_group_id" => group_id,
                   "media_group" => %{
                     "id" => nested_group_id,
                     "commands" => [%{"id" => nested_command_id, "name" => "applause"}]
                   }
                 }
               ]
             } = json_response(conn, :ok)

      assert id == trigger.id
      assert group_id == trigger.media_group_id
      assert nested_group_id == trigger.media_group_id
      assert nested_command_id == command.id
    end
  end

  describe "trigger lifecycle" do
    setup %{conn: conn} do
      user = register_user()
      %{conn: authenticate_api_user(conn, user), user: user}
    end

    test "creates, shows, updates, and deletes triggers", %{conn: conn, user: user} do
      command = command_fixture(user)
      group = group_fixture(user, command)

      create_conn =
        conn
        |> json_conn()
        |> post(~p"/api/triggers", %{
          trigger: %{
            name: "Follow trigger",
            type: "twitch_follow",
            media_group_id: group.id
          }
        })

      assert %{
               "trigger" => %{
                 "id" => trigger_id,
                 "name" => "Follow trigger",
                 "type" => "twitch_follow",
                 "media_group_id" => group_id
               }
             } = json_response(create_conn, :created)

      assert group_id == group.id
      assert get_resp_header(create_conn, "location") == ["/api/triggers/#{trigger_id}"]

      [authorization] = get_req_header(create_conn, "authorization")

      show_conn =
        build_conn()
        |> json_conn()
        |> put_req_header("authorization", authorization)
        |> get(~p"/api/triggers/#{trigger_id}")

      assert %{"trigger" => %{"id" => ^trigger_id, "media_group" => %{"id" => ^group_id}}} =
               json_response(show_conn, :ok)

      update_conn =
        build_conn()
        |> json_conn()
        |> put_req_header("authorization", authorization)
        |> put(~p"/api/triggers/#{trigger_id}", %{
          trigger: %{name: "Updated follow trigger", type: "twitch_subscribe"}
        })

      assert %{
               "trigger" => %{
                 "id" => ^trigger_id,
                 "name" => "Updated follow trigger",
                 "type" => "twitch_subscribe"
               }
             } = json_response(update_conn, :ok)

      delete_conn =
        build_conn()
        |> json_conn()
        |> put_req_header("authorization", authorization)
        |> delete(~p"/api/triggers/#{trigger_id}")

      assert response(delete_conn, :no_content)
      assert_raise Ecto.NoResultsError, fn -> Repo.get!(Trigger, trigger_id) end
    end

    test "returns validation errors as JSON", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/triggers", %{trigger: %{}})

      assert %{
               "errors" => %{
                 "name" => [_ | _],
                 "type" => [_ | _],
                 "media_group_id" => [_ | _]
               }
             } = json_response(conn, :unprocessable_entity)
    end

    test "does not expose another user's trigger", %{conn: conn} do
      other_user = register_user()
      command = command_fixture(other_user)
      trigger = trigger_fixture(other_user, command)

      assert_error_sent :not_found, fn ->
        conn
        |> json_conn()
        |> get(~p"/api/triggers/#{trigger.id}")
      end
    end
  end
end
