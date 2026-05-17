defmodule BotWorld.CommandTest do
  use ExUnit.Case, async: true

  alias BotWorld.Command

  test "casts nested triggers when creating a command" do
    changeset =
      Command.changeset(%Command{}, %{
        "name" => "airhorn",
        "s3_key" => "sfx/airhorn.mp3",
        "media_type" => "audio",
        "triggers" => [
          %{"name" => "Follow trigger", "type" => "twitch_follow"},
          %{"name" => "Chat trigger", "type" => "chat_command"}
        ]
      })

    assert changeset.valid?
    assert length(changeset.changes.triggers) == 2
  end

  test "propagates nested trigger validation errors" do
    changeset =
      Command.changeset(%Command{}, %{
        "name" => "airhorn",
        "s3_key" => "sfx/airhorn.mp3",
        "media_type" => "audio",
        "triggers" => [%{"name" => "", "type" => "twitch_follow"}]
      })

    refute changeset.valid?
    assert [%Ecto.Changeset{} = trigger_changeset] = changeset.changes.triggers
    assert {"can't be blank", _opts} = trigger_changeset.errors[:name]
  end
end
