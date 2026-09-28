defmodule BotWorld.MediaItemTest do
  use ExUnit.Case, async: true

  alias BotWorld.MediaItem

  test "uses the media_items table while media_item-facing names remain compatible" do
    assert MediaItem.__schema__(:source) == "media_items"
  end

  test "casts playable media fields" do
    changeset =
      MediaItem.changeset(%MediaItem{}, %{
        "name" => "airhorn",
        "s3_key" => "sfx/airhorn.mp3",
        "media_type" => "audio"
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :media_type) == "audio"
  end

  test "validates the media type" do
    changeset =
      MediaItem.changeset(%MediaItem{}, %{
        "name" => "airhorn",
        "s3_key" => "sfx/airhorn.mp3",
        "media_type" => "image"
      })

    refute changeset.valid?
    assert {"is invalid", _opts} = changeset.errors[:media_type]
  end
end
