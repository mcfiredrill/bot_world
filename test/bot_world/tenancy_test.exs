defmodule BotWorld.TenancyTest do
  # These tests subscribe to the shared overlay PubSub topic, so running them
  # alongside other dispatch tests can leak unrelated playback messages into
  # this process.
  use BotWorld.DataCase, async: false

  alias BotWorld.{MediaItem, Media, MediaGroupItem, MediaGroups, Repo, Triggers}

  setup do
    %{owner: register_user(), other: register_user()}
  end

  test "media_items are listed and fetched only for their owner", %{owner: owner, other: other} do
    owner_media_item = media_item_fixture(owner, "owner")
    other_media_item = media_item_fixture(other, "other")

    assert Enum.map(Media.list_media_items(owner), & &1.id) == [owner_media_item.id]
    assert Enum.map(Media.list_media_items(other), & &1.id) == [other_media_item.id]

    assert_raise Ecto.NoResultsError, fn ->
      Media.get_media_item!(owner, other_media_item.id)
    end
  end

  test "media groups reject another user's media_item", %{owner: owner, other: other} do
    other_media_item = media_item_fixture(other, "other")

    assert {:error, changeset} =
             MediaGroups.create_media_group(owner, %{
               "name" => "Invalid",
               "media_item_ids" => [other_media_item.id]
             })

    assert "contains an invalid media item" in errors_on(changeset).media_items
  end

  test "triggers reject another user's media group", %{owner: owner, other: other} do
    other_media_item = media_item_fixture(other, "other")
    other_group = group_fixture(other, other_media_item, "Other group")

    assert {:error, changeset} =
             Triggers.create_trigger(owner, %{
               "name" => "Invalid",
               "type" => "twitch_follow",
               "media_group_id" => other_group.id
             })

    assert "is invalid" in errors_on(changeset).media_group_id
  end

  test "the database rejects a cross-tenant media group membership", %{
    owner: owner,
    other: other
  } do
    owner_media_item = media_item_fixture(owner, "owner")
    other_media_item = media_item_fixture(other, "other")
    other_group = group_fixture(other, other_media_item, "Other group")

    assert {:error, changeset} =
             %MediaGroupItem{}
             |> MediaGroupItem.changeset(%{
               user_id: owner.id,
               media_group_id: other_group.id,
               media_item_id: owner_media_item.id
             })
             |> Repo.insert()

    assert "does not exist" in errors_on(changeset).media_group_id
  end

  test "media group names are unique per user, not globally", %{owner: owner, other: other} do
    owner_media_item = media_item_fixture(owner, "owner")
    other_media_item = media_item_fixture(other, "other")

    assert {:ok, _} =
             MediaGroups.create_media_group(owner, group_attrs("Shared", owner_media_item))

    assert {:ok, _} =
             MediaGroups.create_media_group(other, group_attrs("Shared", other_media_item))

    assert {:error, changeset} =
             MediaGroups.create_media_group(owner, group_attrs("Shared", owner_media_item))

    assert "has already been taken" in errors_on(changeset).name
  end

  test "media_item creation requires the user's S3 namespace", %{owner: owner, other: other} do
    assert {:error, changeset} =
             Media.create_media_item(owner, %{
               "name" => "wrong",
               "s3_key" => "users/#{other.id}/sfx/wrong.mp3"
             })

    assert "must belong to the authenticated user" in errors_on(changeset).s3_key

    assert {:ok, media_item} =
             Media.create_media_item(owner, %{
               "name" => "right",
               "s3_key" => "users/#{owner.id}/sfx/right.mp3"
             })

    assert media_item.user_id == owner.id
  end

  test "event dispatch selects media_items only from the specified tenant", %{
    owner: owner,
    other: other
  } do
    other_media_item = media_item_fixture(other, "other")
    other_group = group_fixture(other, other_media_item, "Other group")

    assert {:ok, _} =
             Triggers.create_trigger(other, %{
               "name" => "Follow",
               "type" => "twitch_follow",
               "media_group_id" => other_group.id
             })

    Phoenix.PubSub.subscribe(BotWorld.PubSub, Media.overlay_topic())

    assert :ok = Media.dispatch_event(owner, "channel.follow", %{})
    refute_receive {:play_media_item, _}

    assert :ok = Media.dispatch_event(other, "channel.follow", %{})
    assert_receive {:play_media_item, %{name: "other"}}
  end

  defp media_item_fixture(user, name) do
    %MediaItem{user_id: user.id}
    |> MediaItem.changeset(%{
      name: name,
      s3_key: "users/#{user.id}/sfx/#{name}.mp3",
      media_type: "audio"
    })
    |> Repo.insert!()
  end

  defp group_fixture(user, media_item, name) do
    {:ok, group} = MediaGroups.create_media_group(user, group_attrs(name, media_item))
    group
  end

  defp group_attrs(name, media_item) do
    %{"name" => name, "media_item_ids" => [media_item.id]}
  end
end
