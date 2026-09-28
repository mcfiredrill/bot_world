defmodule BotWorldWeb.MediaControllerTest do
  use BotWorldWeb.ConnCase, async: true

  alias BotWorld.{MediaItem, MediaGroup, Repo, Trigger}
  alias BotWorld.Twitch.Credential

  setup :register_and_log_in_user

  defp json_api_conn(conn) do
    put_req_header(conn, "accept", "application/vnd.api+json")
  end

  defp media_item_with_redeem_fixture(user) do
    media_item =
      %MediaItem{user_id: user.id}
      |> MediaItem.changeset(%{
        "name" => "hydrate-sound",
        "s3_key" => "sfx/hydrate.mp3",
        "media_type" => "audio"
      })
      |> Repo.insert!()

    group =
      %MediaGroup{name: "Hydration sounds", user_id: user.id}
      |> Repo.preload(:media_items)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:media_items, [media_item])
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

    {media_item, group, trigger}
  end

  test "GET /media renders the media item form and group navigation", %{conn: conn} do
    conn = get(conn, ~p"/media")
    body = html_response(conn, 200)
    overlay_token = Application.get_env(:bot_world, :overlay)[:token]

    assert body =~ "Media File"
    assert body =~ "Groups"
    assert body =~ ~s(href="/overlay/#{overlay_token}")
  end

  test "GET /media shows the current user's Twitch handle in the navbar", %{
    conn: conn,
    user: user
  } do
    %Credential{}
    |> Credential.changeset(%{
      user_id: user.id,
      twitch_user_id: "123456",
      twitch_login: "streamer",
      access_token: "access-token",
      refresh_token: "refresh-token",
      scopes: [],
      expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
    })
    |> Repo.insert!()

    body = conn |> get(~p"/media") |> html_response(200)

    assert body =~ "@streamer"
  end

  test "GET /media shows trigger matching details in the media table", %{
    conn: conn,
    user: user
  } do
    {_media_item, _group, _trigger} = media_item_with_redeem_fixture(user)

    body = conn |> get(~p"/media") |> html_response(200)

    assert body =~ "Hydrate redeem"
    assert body =~ "Twitch Point Redeem"
    assert body =~ "Reward: Hydrate"
  end

  test "GET /media renders type-appropriate media previews", %{conn: conn, user: user} do
    audio_item =
      %MediaItem{user_id: user.id}
      |> MediaItem.changeset(%{
        name: "airhorn",
        s3_key: "users/#{user.id}/audio/airhorn.mp3",
        media_type: "audio"
      })
      |> Repo.insert!()

    video_item =
      %MediaItem{user_id: user.id}
      |> MediaItem.changeset(%{
        name: "celebration",
        s3_key: "users/#{user.id}/video/celebration.mp4",
        media_type: "video"
      })
      |> Repo.insert!()

    body = conn |> get(~p"/media") |> html_response(200)

    assert body =~ ~s(<audio id="media-preview-#{audio_item.id}")
    assert body =~ ~s(<video id="media-preview-#{video_item.id}")
    assert body =~ BotWorld.S3.public_url(audio_item.s3_key)
    assert body =~ BotWorld.S3.public_url(video_item.s3_key)
  end

  test "GET /media/:media_item links to the editor for a linked redeem trigger", %{
    conn: conn,
    user: user
  } do
    {media_item, _group, trigger} = media_item_with_redeem_fixture(user)
    body = conn |> get(~p"/media/#{media_item}") |> html_response(200)

    assert body =~ "Reward: Hydrate"
    assert body =~ ~s(href="/triggers/#{trigger.id}/edit")
    assert body =~ "Edit trigger"
  end

  test "GET /media/:media_item does not expose another user's media item", %{
    conn: conn
  } do
    other_user = register_user()

    other_media_item =
      %MediaItem{user_id: other_user.id}
      |> MediaItem.changeset(%{
        "name" => "private",
        "s3_key" => "users/#{other_user.id}/sfx/private.mp3",
        "media_type" => "audio"
      })
      |> Repo.insert!()

    assert_error_sent :not_found, fn ->
      get(conn, ~p"/media/#{other_media_item}")
    end
  end

  test "DELETE /media/:media_item deletes an ungrouped media item", %{
    conn: conn,
    user: user
  } do
    {:ok, media_item} =
      %MediaItem{user_id: user.id}
      |> MediaItem.changeset(%{
        "name" => "hydrate-sound",
        "s3_key" => "sfx/hydrate.mp3",
        "media_type" => "audio"
      })
      |> Repo.insert()

    conn = delete(conn, ~p"/media/#{media_item}")

    assert redirected_to(conn) == ~p"/media"
    assert Repo.get(MediaItem, media_item.id) == nil
  end

  test "DELETE /media/:media_item refuses to delete a directly targeted item", %{
    conn: conn,
    user: user
  } do
    media_item =
      %MediaItem{user_id: user.id}
      |> MediaItem.changeset(%{name: "direct", s3_key: "sfx/direct.mp3"})
      |> Repo.insert!()

    %Trigger{user_id: user.id}
    |> Trigger.changeset(%{
      name: "Direct follow",
      type: "twitch_follow",
      media_item_id: media_item.id
    })
    |> Repo.insert!()

    conn = delete(conn, ~p"/media/#{media_item}")

    assert redirected_to(conn) == ~p"/media/#{media_item}"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "direct triggers"
    assert Repo.get!(MediaItem, media_item.id)
  end

  test "GET /media returns JSON for a JSON:API accept header", %{conn: conn, user: user} do
    {:ok, media_item} =
      %MediaItem{user_id: user.id}
      |> MediaItem.changeset(%{
        "name" => "airhorn",
        "s3_key" => "sfx/airhorn.mp3",
        "media_type" => "audio"
      })
      |> Repo.insert()

    conn =
      conn
      |> json_api_conn()
      |> get(~p"/media")

    assert %{
             "data" => [
               %{
                 "id" => id,
                 "type" => "media_item",
                 "attributes" => %{
                   "name" => "airhorn",
                   "s3-key" => "sfx/airhorn.mp3",
                   "media-type" => "audio"
                 }
               }
             ]
           } = json_response(conn, 200)

    assert id == Integer.to_string(media_item.id)
  end

  test "GET /media returns JSON unauthorized for a JSON:API request when logged out" do
    conn =
      build_conn()
      |> json_api_conn()
      |> get(~p"/media")

    assert %{"errors" => [%{"detail" => "Authentication required."}]} = json_response(conn, 401)
  end
end
