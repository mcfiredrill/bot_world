defmodule BotWorld.MediaTest do
  use BotWorld.DataCase, async: false

  alias BotWorld.{MediaItem, Media, MediaGroup, Trigger}

  setup do
    %{user: register_user()}
  end

  defp insert_media_item(user, attrs) do
    {trigger_attrs, attrs} = Map.pop(attrs, "triggers", [])
    media_item = %MediaItem{user_id: user.id} |> MediaItem.changeset(attrs) |> Repo.insert!()

    if trigger_attrs != [] do
      group =
        %MediaGroup{name: "#{media_item.name} group", user_id: user.id}
        |> Repo.preload(:media_items)
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_assoc(:media_items, [media_item])
        |> Repo.insert!()

      Enum.each(trigger_attrs, fn attrs ->
        %Trigger{user_id: user.id}
        |> Trigger.changeset(Map.put(attrs, "media_group_id", group.id))
        |> Repo.insert!()
      end)
    end

    media_item
  end

  describe "trigger_type_for_eventsub_type/1" do
    test "maps known Twitch EventSub types to trigger types" do
      assert Media.trigger_type_for_eventsub_type("channel.follow") == "twitch_follow"
      assert Media.trigger_type_for_eventsub_type("channel.subscribe") == "twitch_subscribe"
      assert Media.trigger_type_for_eventsub_type("channel.cheer") == "twitch_bits"

      assert Media.trigger_type_for_eventsub_type(
               "channel.channel_points_custom_reward_redemption.add"
             ) == "twitch_point_redeem"
    end

    test "returns nil for unknown types" do
      assert Media.trigger_type_for_eventsub_type("channel.raid") == nil
    end
  end

  describe "random_media_item_for_trigger_type/1" do
    test "returns a media_item whose trigger matches the given type", %{user: user} do
      media_item =
        insert_media_item(user, %{
          "name" => "airhorn",
          "s3_key" => "sfx/airhorn.mp3",
          "media_type" => "audio",
          "triggers" => [%{"name" => "Follow", "type" => "twitch_follow"}]
        })

      assert {:ok, matched} = Media.random_media_item_for_trigger_type(user, "twitch_follow")
      assert matched.id == media_item.id
    end

    test "returns an error when no media item matches", %{user: user} do
      assert {:error, :no_media_item} =
               Media.random_media_item_for_trigger_type(user, "twitch_bits")
    end

    test "randomly selects among all clips in the trigger's media group", %{user: user} do
      first = insert_media_item(user, %{"name" => "first", "s3_key" => "sfx/first.mp3"})
      second = insert_media_item(user, %{"name" => "second", "s3_key" => "sfx/second.mp3"})

      group =
        %MediaGroup{name: "Random group", user_id: user.id}
        |> Repo.preload(:media_items)
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_assoc(:media_items, [first, second])
        |> Repo.insert!()

      %Trigger{user_id: user.id}
      |> Trigger.changeset(%{
        "name" => "Follow",
        "type" => "twitch_follow",
        "media_group_id" => group.id
      })
      |> Repo.insert!()

      selected_ids =
        for _ <- 1..40, into: MapSet.new() do
          {:ok, media_item} = Media.random_media_item_for_trigger_type(user, "twitch_follow")
          media_item.id
        end

      assert selected_ids == MapSet.new([first.id, second.id])
    end
  end

  describe "dispatch_event/2" do
    test "plays a directly targeted media item", %{user: user} do
      media_item =
        insert_media_item(user, %{
          "name" => "direct",
          "s3_key" => "sfx/direct.mp3",
          "media_type" => "audio"
        })

      %Trigger{user_id: user.id}
      |> Trigger.changeset(%{
        "name" => "Direct follow",
        "type" => "twitch_follow",
        "media_item_id" => media_item.id
      })
      |> Repo.insert!()

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Media.overlay_topic())

      assert :ok = Media.dispatch_event(user, "channel.follow", %{})
      assert_receive {:play_media_item, %{name: "direct"}}
    end

    test "broadcasts a play_media_item message when a media_item matches", %{user: user} do
      insert_media_item(user, %{
        "name" => "airhorn",
        "s3_key" => "sfx/airhorn.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "Follow", "type" => "twitch_follow"}]
      })

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Media.overlay_topic())

      assert :ok = Media.dispatch_event(user, "channel.follow", %{})

      assert_receive {:play_media_item, %{media_type: "audio", name: "airhorn", url: url}}
      assert url =~ "sfx/airhorn.mp3"
    end

    test "does nothing when no media item matches the trigger type", %{user: user} do
      Phoenix.PubSub.subscribe(BotWorld.PubSub, Media.overlay_topic())

      assert :ok = Media.dispatch_event(user, "channel.cheer", %{})

      refute_receive {:play_media_item, _}
    end

    test "does nothing for an unmapped eventsub type", %{user: user} do
      Phoenix.PubSub.subscribe(BotWorld.PubSub, Media.overlay_topic())

      assert :ok = Media.dispatch_event(user, "channel.raid", %{})

      refute_receive {:play_media_item, _}
    end

    test "matches a twitch_point_redeem trigger by reward name (case-insensitive)", %{user: user} do
      insert_media_item(user, %{
        "name" => "hydrate",
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

      insert_media_item(user, %{
        "name" => "confetti",
        "s3_key" => "sfx/confetti.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "Any redeem", "type" => "twitch_point_redeem"}]
      })

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Media.overlay_topic())

      assert :ok =
               Media.dispatch_event(
                 user,
                 "channel.channel_points_custom_reward_redemption.add",
                 %{
                   "reward" => %{"title" => "hydrate"}
                 }
               )

      assert_receive {:play_media_item, %{name: "hydrate"}}
    end

    test "falls back to a catch-all twitch_point_redeem trigger when no reward name matches", %{
      user: user
    } do
      insert_media_item(user, %{
        "name" => "hydrate",
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

      insert_media_item(user, %{
        "name" => "confetti",
        "s3_key" => "sfx/confetti.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "Any redeem", "type" => "twitch_point_redeem"}]
      })

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Media.overlay_topic())

      assert :ok =
               Media.dispatch_event(
                 user,
                 "channel.channel_points_custom_reward_redemption.add",
                 %{
                   "reward" => %{"title" => "Confetti Cannon"}
                 }
               )

      assert_receive {:play_media_item, %{name: "confetti"}}
    end

    test "matches a twitch_bits trigger by exact bits amount", %{user: user} do
      insert_media_item(user, %{
        "name" => "hundred-bits",
        "s3_key" => "sfx/hundred-bits.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "100 bits", "type" => "twitch_bits", "bits_amount" => "100"}]
      })

      insert_media_item(user, %{
        "name" => "any-bits",
        "s3_key" => "sfx/any-bits.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "Any bits", "type" => "twitch_bits"}]
      })

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Media.overlay_topic())

      assert :ok = Media.dispatch_event(user, "channel.cheer", %{"bits" => 100})

      assert_receive {:play_media_item, %{name: "hundred-bits"}}
    end

    test "falls back to a catch-all twitch_bits trigger when the exact amount doesn't match", %{
      user: user
    } do
      insert_media_item(user, %{
        "name" => "hundred-bits",
        "s3_key" => "sfx/hundred-bits.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "100 bits", "type" => "twitch_bits", "bits_amount" => "100"}]
      })

      insert_media_item(user, %{
        "name" => "any-bits",
        "s3_key" => "sfx/any-bits.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "Any bits", "type" => "twitch_bits"}]
      })

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Media.overlay_topic())

      assert :ok = Media.dispatch_event(user, "channel.cheer", %{"bits" => 250})

      assert_receive {:play_media_item, %{name: "any-bits"}}
    end

    test "does nothing when bits amount doesn't match and there is no catch-all trigger", %{
      user: user
    } do
      insert_media_item(user, %{
        "name" => "hundred-bits",
        "s3_key" => "sfx/hundred-bits.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "100 bits", "type" => "twitch_bits", "bits_amount" => "100"}]
      })

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Media.overlay_topic())

      assert :ok = Media.dispatch_event(user, "channel.cheer", %{"bits" => 250})

      refute_receive {:play_media_item, _}
    end
  end
end
