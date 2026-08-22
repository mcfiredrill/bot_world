defmodule BotWorld.CommandTest do
  use ExUnit.Case, async: true

  alias BotWorld.Command

  test "casts playable media fields" do
    changeset =
      Command.changeset(%Command{}, %{
        "name" => "airhorn",
        "s3_key" => "sfx/airhorn.mp3",
        "media_type" => "audio"
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :media_type) == "audio"
  end

  test "validates the media type" do
    changeset =
      Command.changeset(%Command{}, %{
        "name" => "airhorn",
        "s3_key" => "sfx/airhorn.mp3",
        "media_type" => "image"
      })

    refute changeset.valid?
    assert {"is invalid", _opts} = changeset.errors[:media_type]
  end
end
