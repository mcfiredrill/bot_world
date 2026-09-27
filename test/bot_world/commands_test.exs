defmodule BotWorld.CommandsTest do
  use BotWorld.DataCase, async: false

  alias BotWorld.{Command, Commands, MediaGroup, Trigger}

  setup do
    %{user: register_user()}
  end

  defp insert_command(user, attrs) do
    {trigger_attrs, attrs} = Map.pop(attrs, "triggers", [])
    command = %Command{user_id: user.id} |> Command.changeset(attrs) |> Repo.insert!()

    if trigger_attrs != [] do
      group =
        %MediaGroup{name: "#{command.name} group", user_id: user.id}
        |> Repo.preload(:commands)
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_assoc(:commands, [command])
        |> Repo.insert!()

      Enum.each(trigger_attrs, fn attrs ->
        %Trigger{user_id: user.id}
        |> Trigger.changeset(Map.put(attrs, "media_group_id", group.id))
        |> Repo.insert!()
      end)
    end

    command
  end

  describe "trigger_type_for_eventsub_type/1" do
    test "maps known Twitch EventSub types to trigger types" do
      assert Commands.trigger_type_for_eventsub_type("channel.follow") == "twitch_follow"
      assert Commands.trigger_type_for_eventsub_type("channel.subscribe") == "twitch_subscribe"
      assert Commands.trigger_type_for_eventsub_type("channel.cheer") == "twitch_bits"

      assert Commands.trigger_type_for_eventsub_type(
               "channel.channel_points_custom_reward_redemption.add"
             ) == "twitch_point_redeem"
    end

    test "returns nil for unknown types" do
      assert Commands.trigger_type_for_eventsub_type("channel.raid") == nil
    end
  end

  describe "random_command_for_trigger_type/1" do
    test "returns a command whose trigger matches the given type", %{user: user} do
      command =
        insert_command(user, %{
          "name" => "airhorn",
          "s3_key" => "sfx/airhorn.mp3",
          "media_type" => "audio",
          "triggers" => [%{"name" => "Follow", "type" => "twitch_follow"}]
        })

      assert {:ok, matched} = Commands.random_command_for_trigger_type(user, "twitch_follow")
      assert matched.id == command.id
    end

    test "returns an error when no command matches", %{user: user} do
      assert {:error, :no_command} = Commands.random_command_for_trigger_type(user, "twitch_bits")
    end

    test "randomly selects among all clips in the trigger's media group", %{user: user} do
      first = insert_command(user, %{"name" => "first", "s3_key" => "sfx/first.mp3"})
      second = insert_command(user, %{"name" => "second", "s3_key" => "sfx/second.mp3"})

      group =
        %MediaGroup{name: "Random group", user_id: user.id}
        |> Repo.preload(:commands)
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_assoc(:commands, [first, second])
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
          {:ok, command} = Commands.random_command_for_trigger_type(user, "twitch_follow")
          command.id
        end

      assert selected_ids == MapSet.new([first.id, second.id])
    end
  end

  describe "dispatch_event/2" do
    test "broadcasts a play_command message when a command matches", %{user: user} do
      insert_command(user, %{
        "name" => "airhorn",
        "s3_key" => "sfx/airhorn.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "Follow", "type" => "twitch_follow"}]
      })

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())

      assert :ok = Commands.dispatch_event(user, "channel.follow", %{})

      assert_receive {:play_command, %{media_type: "audio", name: "airhorn", url: url}}
      assert url =~ "sfx/airhorn.mp3"
    end

    test "does nothing when no command matches the trigger type", %{user: user} do
      Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())

      assert :ok = Commands.dispatch_event(user, "channel.cheer", %{})

      refute_receive {:play_command, _}
    end

    test "does nothing for an unmapped eventsub type", %{user: user} do
      Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())

      assert :ok = Commands.dispatch_event(user, "channel.raid", %{})

      refute_receive {:play_command, _}
    end

    test "matches a twitch_point_redeem trigger by reward name (case-insensitive)", %{user: user} do
      insert_command(user, %{
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

      insert_command(user, %{
        "name" => "confetti",
        "s3_key" => "sfx/confetti.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "Any redeem", "type" => "twitch_point_redeem"}]
      })

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())

      assert :ok =
               Commands.dispatch_event(
                 user,
                 "channel.channel_points_custom_reward_redemption.add",
                 %{
                   "reward" => %{"title" => "hydrate"}
                 }
               )

      assert_receive {:play_command, %{name: "hydrate"}}
    end

    test "falls back to a catch-all twitch_point_redeem trigger when no reward name matches", %{
      user: user
    } do
      insert_command(user, %{
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

      insert_command(user, %{
        "name" => "confetti",
        "s3_key" => "sfx/confetti.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "Any redeem", "type" => "twitch_point_redeem"}]
      })

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())

      assert :ok =
               Commands.dispatch_event(
                 user,
                 "channel.channel_points_custom_reward_redemption.add",
                 %{
                   "reward" => %{"title" => "Confetti Cannon"}
                 }
               )

      assert_receive {:play_command, %{name: "confetti"}}
    end

    test "matches a twitch_bits trigger by exact bits amount", %{user: user} do
      insert_command(user, %{
        "name" => "hundred-bits",
        "s3_key" => "sfx/hundred-bits.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "100 bits", "type" => "twitch_bits", "bits_amount" => "100"}]
      })

      insert_command(user, %{
        "name" => "any-bits",
        "s3_key" => "sfx/any-bits.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "Any bits", "type" => "twitch_bits"}]
      })

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())

      assert :ok = Commands.dispatch_event(user, "channel.cheer", %{"bits" => 100})

      assert_receive {:play_command, %{name: "hundred-bits"}}
    end

    test "falls back to a catch-all twitch_bits trigger when the exact amount doesn't match", %{
      user: user
    } do
      insert_command(user, %{
        "name" => "hundred-bits",
        "s3_key" => "sfx/hundred-bits.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "100 bits", "type" => "twitch_bits", "bits_amount" => "100"}]
      })

      insert_command(user, %{
        "name" => "any-bits",
        "s3_key" => "sfx/any-bits.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "Any bits", "type" => "twitch_bits"}]
      })

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())

      assert :ok = Commands.dispatch_event(user, "channel.cheer", %{"bits" => 250})

      assert_receive {:play_command, %{name: "any-bits"}}
    end

    test "does nothing when bits amount doesn't match and there is no catch-all trigger", %{
      user: user
    } do
      insert_command(user, %{
        "name" => "hundred-bits",
        "s3_key" => "sfx/hundred-bits.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "100 bits", "type" => "twitch_bits", "bits_amount" => "100"}]
      })

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())

      assert :ok = Commands.dispatch_event(user, "channel.cheer", %{"bits" => 250})

      refute_receive {:play_command, _}
    end
  end
end
