defmodule BotWorldWeb.MediaJSON do
  alias BotWorld.S3

  def index(%{media_items: media_items}) do
    %{data: Enum.map(media_items, &resource_object/1)}
  end

  def media_item(media_item) do
    %{
      id: media_item.id,
      name: media_item.name,
      s3_key: media_item.s3_key,
      url: S3.public_url(media_item.s3_key),
      inserted_at: media_item.inserted_at,
      updated_at: media_item.updated_at
    }
  end

  defp resource_object(media_item) do
    %{
      id: to_string(media_item.id),
      type: "media_item",
      attributes: %{
        name: media_item.name,
        aliases: media_item.aliases,
        "s3-key": media_item.s3_key,
        url: S3.public_url(media_item.s3_key),
        "media-type": media_item.media_type,
        "inserted-at": media_item.inserted_at,
        "updated-at": media_item.updated_at
      }
    }
  end
end
