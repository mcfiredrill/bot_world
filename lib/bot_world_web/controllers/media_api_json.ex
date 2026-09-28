defmodule BotWorldWeb.MediaAPIJSON do
  alias BotWorld.S3

  def show(%{media_item: media_item}) do
    %{media_item: media_item_data(media_item)}
  end

  def presign(%{upload: upload}) do
    %{upload: upload}
  end

  defp media_item_data(media_item) do
    %{
      id: media_item.id,
      name: media_item.name,
      aliases: media_item.aliases,
      s3_key: media_item.s3_key,
      url: S3.public_url(media_item.s3_key),
      media_type: media_item.media_type,
      inserted_at: media_item.inserted_at,
      updated_at: media_item.updated_at
    }
  end
end
