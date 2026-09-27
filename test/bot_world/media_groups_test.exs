defmodule BotWorld.MediaGroupsTest do
  use BotWorld.DataCase, async: true

  alias BotWorld.{Command, MediaGroups}

  setup do
    %{user: register_user()}
  end

  defp command_fixture(user, name) do
    %Command{user_id: user.id}
    |> Command.changeset(%{name: name, s3_key: "sfx/#{name}.mp3", media_type: "audio"})
    |> Repo.insert!()
  end

  test "creates a reusable group with multiple media clips", %{user: user} do
    first = command_fixture(user, "first")
    second = command_fixture(user, "second")

    assert {:ok, group} =
             MediaGroups.create_media_group(user, %{
               "name" => "Celebrations",
               "command_ids" => [to_string(first.id), to_string(second.id)]
             })

    group = MediaGroups.get_media_group!(user, group.id)
    assert MapSet.new(group.commands, & &1.id) == MapSet.new([first.id, second.id])
  end

  test "requires at least one media clip", %{user: user} do
    assert {:error, changeset} =
             MediaGroups.create_media_group(user, %{"name" => "Empty", "command_ids" => []})

    assert {"select at least one media clip", _} = changeset.errors[:commands]
  end
end
