defmodule BotWorld.TriggerTest do
  use BotWorld.DataCase, async: true

  alias BotWorld.{MediaGroup, MediaItem, Triggers}

  setup do
    user = register_user()

    media_item =
      %MediaItem{user_id: user.id}
      |> MediaItem.changeset(%{name: "airhorn", s3_key: "users/#{user.id}/sfx/airhorn.mp3"})
      |> Repo.insert!()

    media_group =
      %MediaGroup{user_id: user.id}
      |> MediaGroup.changeset(%{name: "sounds"})
      |> Repo.insert!()

    %{user: user, media_item: media_item, media_group: media_group}
  end

  test "requires exactly one target", %{user: user, media_item: item, media_group: group} do
    base = %{name: "Follow", type: "twitch_follow"}

    assert {:error, changeset} = Triggers.create_trigger(user, base)
    assert "must select exactly one target" in errors_on(changeset).target_type

    assert {:ok, trigger} =
             Triggers.create_trigger(user, Map.put(base, :media_group_id, group.id))

    assert trigger.media_group_id == group.id
    assert trigger.media_item_id == nil

    both = Map.merge(base, %{media_group_id: group.id, media_item_id: item.id})
    assert {:error, changeset} = Triggers.create_trigger(user, both)
    assert "must select exactly one target" in errors_on(changeset).target_type
  end

  test "switching target type clears the previous target", %{
    user: user,
    media_item: item,
    media_group: group
  } do
    {:ok, trigger} =
      Triggers.create_trigger(user, %{
        name: "Follow",
        type: "twitch_follow",
        media_group_id: group.id
      })

    assert {:ok, updated} =
             Triggers.update_trigger(user, trigger, %{
               target_type: "media_item",
               media_item_id: item.id
             })

    assert updated.media_group_id == nil
    assert updated.media_item_id == item.id
  end

  test "rejects another user's direct media item", %{user: user} do
    other = register_user()

    other_item =
      %MediaItem{user_id: other.id}
      |> MediaItem.changeset(%{name: "private", s3_key: "users/#{other.id}/sfx/private.mp3"})
      |> Repo.insert!()

    assert {:error, changeset} =
             Triggers.create_trigger(user, %{
               name: "Follow",
               type: "twitch_follow",
               media_item_id: other_item.id
             })

    assert "is invalid" in errors_on(changeset).media_item_id
  end
end
