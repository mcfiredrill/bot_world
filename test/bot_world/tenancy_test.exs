defmodule BotWorld.TenancyTest do
  use BotWorld.DataCase, async: true

  alias BotWorld.{Command, Commands, MediaGroupCommand, MediaGroups, Repo, Triggers}

  setup do
    %{owner: register_user(), other: register_user()}
  end

  test "commands are listed and fetched only for their owner", %{owner: owner, other: other} do
    owner_command = command_fixture(owner, "owner")
    other_command = command_fixture(other, "other")

    assert Enum.map(Commands.list_commands(owner), & &1.id) == [owner_command.id]
    assert Enum.map(Commands.list_commands(other), & &1.id) == [other_command.id]

    assert_raise Ecto.NoResultsError, fn ->
      Commands.get_command!(owner, other_command.id)
    end
  end

  test "media groups reject another user's command", %{owner: owner, other: other} do
    other_command = command_fixture(other, "other")

    assert {:error, changeset} =
             MediaGroups.create_media_group(owner, %{
               "name" => "Invalid",
               "command_ids" => [other_command.id]
             })

    assert "contains an invalid command" in errors_on(changeset).commands
  end

  test "triggers reject another user's media group", %{owner: owner, other: other} do
    other_command = command_fixture(other, "other")
    other_group = group_fixture(other, other_command, "Other group")

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
    owner_command = command_fixture(owner, "owner")
    other_command = command_fixture(other, "other")
    other_group = group_fixture(other, other_command, "Other group")

    assert {:error, changeset} =
             %MediaGroupCommand{}
             |> MediaGroupCommand.changeset(%{
               user_id: owner.id,
               media_group_id: other_group.id,
               command_id: owner_command.id
             })
             |> Repo.insert()

    assert "does not exist" in errors_on(changeset).media_group_id
  end

  test "media group names are unique per user, not globally", %{owner: owner, other: other} do
    owner_command = command_fixture(owner, "owner")
    other_command = command_fixture(other, "other")

    assert {:ok, _} = MediaGroups.create_media_group(owner, group_attrs("Shared", owner_command))
    assert {:ok, _} = MediaGroups.create_media_group(other, group_attrs("Shared", other_command))

    assert {:error, changeset} =
             MediaGroups.create_media_group(owner, group_attrs("Shared", owner_command))

    assert "has already been taken" in errors_on(changeset).name
  end

  test "command creation requires the user's S3 namespace", %{owner: owner, other: other} do
    assert {:error, changeset} =
             Commands.create_command(owner, %{
               "name" => "wrong",
               "s3_key" => "users/#{other.id}/sfx/wrong.mp3"
             })

    assert "must belong to the authenticated user" in errors_on(changeset).s3_key

    assert {:ok, command} =
             Commands.create_command(owner, %{
               "name" => "right",
               "s3_key" => "users/#{owner.id}/sfx/right.mp3"
             })

    assert command.user_id == owner.id
  end

  test "event dispatch selects commands only from the specified tenant", %{
    owner: owner,
    other: other
  } do
    other_command = command_fixture(other, "other")
    other_group = group_fixture(other, other_command, "Other group")

    assert {:ok, _} =
             Triggers.create_trigger(other, %{
               "name" => "Follow",
               "type" => "twitch_follow",
               "media_group_id" => other_group.id
             })

    Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())

    assert :ok = Commands.dispatch_event(owner, "channel.follow", %{})
    refute_receive {:play_command, _}

    assert :ok = Commands.dispatch_event(other, "channel.follow", %{})
    assert_receive {:play_command, %{name: "other"}}
  end

  defp command_fixture(user, name) do
    %Command{user_id: user.id}
    |> Command.changeset(%{
      name: name,
      s3_key: "users/#{user.id}/sfx/#{name}.mp3",
      media_type: "audio"
    })
    |> Repo.insert!()
  end

  defp group_fixture(user, command, name) do
    {:ok, group} = MediaGroups.create_media_group(user, group_attrs(name, command))
    group
  end

  defp group_attrs(name, command) do
    %{"name" => name, "command_ids" => [command.id]}
  end
end
