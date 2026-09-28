defmodule BotWorldWeb.MediaAPIControllerTest do
  use BotWorldWeb.ConnCase, async: true

  alias BotWorld.{MediaItem, Repo}

  defp json_conn(conn) do
    put_req_header(conn, "accept", "application/json")
  end

  describe "authentication" do
    test "requires an authenticated user to list media_items", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> get(~p"/api/media")

      assert %{"errors" => %{"detail" => "Authentication required."}} =
               json_response(conn, :unauthorized)
    end

    test "requires an authenticated user to create media_items", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/media", %{
          media_item: %{name: "airhorn", s3_key: "sfx/airhorn.mp3", media_type: "audio"}
        })

      assert %{"errors" => %{"detail" => "Authentication required."}} =
               json_response(conn, :unauthorized)
    end

    test "requires an authenticated user to presign uploads", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/media/presign", %{
          upload: %{filename: "airhorn.mp3", content_type: "audio/mpeg"}
        })

      assert %{"errors" => %{"detail" => "Authentication required."}} =
               json_response(conn, :unauthorized)
    end
  end

  describe "POST /api/media" do
    setup %{conn: conn} do
      user = register_user()
      %{conn: authenticate_api_user(conn, user), user: user}
    end

    test "creates a media_item from JSON", %{conn: conn, user: user} do
      s3_key = "users/#{user.id}/sfx/airhorn.mp3"

      conn =
        conn
        |> json_conn()
        |> post(~p"/api/media", %{
          media_item: %{
            name: "airhorn",
            aliases: ["horn", "loud"],
            s3_key: s3_key,
            media_type: "audio"
          }
        })

      assert %{
               "media_item" => %{
                 "id" => id,
                 "name" => "airhorn",
                 "aliases" => ["horn", "loud"],
                 "s3_key" => ^s3_key,
                 "media_type" => "audio"
               }
             } = json_response(conn, :created)

      media_item = Repo.get!(MediaItem, id)
      assert media_item.name == "airhorn"
    end

    test "returns validation errors as JSON", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/media", %{media_item: %{}})

      assert %{"errors" => %{"name" => [_], "s3_key" => [_]}} =
               json_response(conn, :unprocessable_entity)
    end
  end

  describe "POST /api/media/presign" do
    setup %{conn: conn} do
      user = register_user()
      %{conn: authenticate_api_user(conn, user), user: user}
    end

    test "returns presigned upload details for video uploads", %{conn: conn, user: user} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/media/presign", %{
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
                 "headers" => %{
                   "content-type" => "video/mp4",
                   "x-amz-acl" => "public-read"
                 },
                 "media_type" => "video",
                 "expires_in" => 3600
               }
             } = json_response(conn, :ok)

      assert String.starts_with?(key, "users/#{user.id}/video/")
      assert String.contains?(key, "_celebration.mp4")
      assert String.starts_with?(url, "http://localhost:9000/bot-world/#{key}?")
      assert String.contains?(url, "X-Amz-Algorithm=")
    end

    test "validates required upload params", %{conn: conn} do
      conn =
        conn
        |> json_conn()
        |> post(~p"/api/media/presign", %{upload: %{media_type: "audio"}})

      assert %{"errors" => %{"filename" => [_], "content_type" => [_]}} =
               json_response(conn, :unprocessable_entity)
    end
  end
end
