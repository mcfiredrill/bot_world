defmodule BotWorldWeb.MediaGroupsControllerTest do
  use BotWorldWeb.ConnCase, async: true

  alias BotWorld.{MediaItem, MediaGroup, Repo}

  setup :register_and_log_in_user

  defp media_item_fixture(user, name) do
    %MediaItem{user_id: user.id}
    |> MediaItem.changeset(%{name: name, s3_key: "sfx/#{name}.mp3", media_type: "audio"})
    |> Repo.insert!()
  end

  test "creates and edits a media group with selected clips", %{conn: conn, user: user} do
    first = media_item_fixture(user, "first")
    second = media_item_fixture(user, "second")

    create_conn =
      post(conn, ~p"/groups", %{
        media_group: %{name: "Celebrations", media_item_ids: [first.id, second.id]}
      })

    [group] = Repo.all(MediaGroup)
    assert redirected_to(create_conn) == ~p"/groups/#{group}"

    group = Repo.preload(group, :media_items)
    assert MapSet.new(group.media_items, & &1.id) == MapSet.new([first.id, second.id])

    update_conn =
      put(recycle(create_conn), ~p"/groups/#{group}", %{
        media_group: %{name: "Big Celebrations", media_item_ids: [second.id]}
      })

    assert redirected_to(update_conn) == ~p"/groups/#{group}"
    updated = group |> Repo.reload!() |> Repo.preload(:media_items)
    assert updated.name == "Big Celebrations"
    assert Enum.map(updated.media_items, & &1.id) == [second.id]
  end

  test "renders group controls", %{conn: conn, user: user} do
    media_item_fixture(user, "airhorn")
    body = conn |> get(~p"/groups/new") |> html_response(:ok)

    assert body =~ "New Media Group"
    assert body =~ "airhorn"
    assert body =~ ~s(name="media_group[media_item_ids][]")
  end
end
