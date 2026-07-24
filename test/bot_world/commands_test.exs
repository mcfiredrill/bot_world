defmodule BotWorld.CommandsTest do
  use BotWorld.DataCase, async: false

  alias BotWorld.{Command, Commands}

  defp insert_command(attrs) do
    %Command{}
    |> Command.changeset(attrs)
    |> Repo.insert!()
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
    test "returns a command whose trigger matches the given type" do
      command =
        insert_command(%{
          "name" => "airhorn",
          "s3_key" => "sfx/airhorn.mp3",
          "media_type" => "audio",
          "triggers" => [%{"name" => "Follow", "type" => "twitch_follow"}]
        })

      assert {:ok, matched} = Commands.random_command_for_trigger_type("twitch_follow")
      assert matched.id == command.id
    end

    test "returns an error when no command matches" do
      assert {:error, :no_command} = Commands.random_command_for_trigger_type("twitch_bits")
    end
  end

  describe "dispatch_event/2" do
    test "broadcasts a play_command message when a command matches" do
      insert_command(%{
        "name" => "airhorn",
        "s3_key" => "sfx/airhorn.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "Follow", "type" => "twitch_follow"}]
      })

      Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())

      assert :ok = Commands.dispatch_event("channel.follow", %{})

      assert_receive {:play_command, %{media_type: "audio", name: "airhorn", url: url}}
      assert url =~ "sfx/airhorn.mp3"
    end

    test "does nothing when no command matches the trigger type" do
      Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())

      assert :ok = Commands.dispatch_event("channel.cheer", %{})

      refute_receive {:play_command, _}
    end

    test "does nothing for an unmapped eventsub type" do
      Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())

      assert :ok = Commands.dispatch_event("channel.raid", %{})

      refute_receive {:play_command, _}
    end
  end
end
