defmodule BotWorldWeb.CommandsAPIControllerTest do
  use BotWorldWeb.ConnCase, async: true

  alias BotWorld.{Command, Repo}

  defp json_conn(conn) do
    put_req_header(conn, "accept", "application/json")
  end

  describe "authentication" do
    test "requires an authenticated user to create commands", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/commands", %{
          command: %{name: "airhorn", s3_key: "sfx/airhorn.mp3", media_type: "audio"}
        })

      assert %{"errors" => %{"detail" => "Authentication required."}} =
               json_response(conn, :unauthorized)
    end

    test "requires an authenticated user to presign uploads", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/commands/presign", %{
          upload: %{filename: "airhorn.mp3", content_type: "audio/mpeg"}
        })

      assert %{"errors" => %{"detail" => "Authentication required."}} =
               json_response(conn, :unauthorized)
    end
  end

  describe "POST /api/commands" do
    setup %{conn: conn} do
      user = register_user()
      %{conn: authenticate_api_user(conn, user), user: user}
    end

    test "creates a command from JSON", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/commands", %{
          command: %{
            name: "airhorn",
            aliases: ["horn", "loud"],
            s3_key: "sfx/airhorn.mp3",
            media_type: "audio"
          }
        })

      assert %{
               "command" => %{
                 "id" => id,
                 "name" => "airhorn",
                 "aliases" => ["horn", "loud"],
                 "s3_key" => "sfx/airhorn.mp3",
                 "media_type" => "audio"
               }
             } = json_response(conn, :created)

      command = Repo.get!(Command, id)
      assert command.name == "airhorn"
    end

    test "returns validation errors as JSON", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/commands", %{command: %{}})

      assert %{"errors" => %{"name" => [_], "s3_key" => [_]}} =
               json_response(conn, :unprocessable_entity)
    end
  end

  describe "POST /api/commands/presign" do
    setup %{conn: conn} do
      user = register_user()
      %{conn: authenticate_api_user(conn, user), user: user}
    end

    test "returns presigned upload details for video uploads", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/commands/presign", %{
          upload: %{
            filename: "celebration.mp4",
            content_type: "video/mp4",
            media_type: "video"
          }
        })

      assert %{
               "upload" => %{
                 "key" => key,
                 "method" => "PUT",
                 "url" => url,
                 "headers" => %{"content-type" => "video/mp4"},
                 "media_type" => "video",
                 "expires_in" => 3600
               }
             } = json_response(conn, :ok)

      assert String.starts_with?(key, "video/")
      assert String.contains?(key, "_celebration.mp4")
      assert String.starts_with?(url, "http://localhost:9000/bot-world/#{key}?")
      assert String.contains?(url, "X-Amz-Algorithm=")
    end

    test "validates required upload params", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/commands/presign", %{upload: %{media_type: "audio"}})

      assert %{"errors" => %{"filename" => [_], "content_type" => [_]}} =
               json_response(conn, :unprocessable_entity)
    end
  end
end
