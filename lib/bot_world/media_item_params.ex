defmodule BotWorld.MediaItemParams do
  @allowed_fields ~w(name aliases media_type s3_key)

  def normalize(media_item_params) do
    media_item_params
    |> Map.take(@allowed_fields)
    |> normalize_aliases()
  end

  def put_s3_key(media_item_params, s3_key) do
    media_item_params
    |> normalize()
    |> Map.put("s3_key", s3_key)
  end

  def build_s3_key(user_id, media_type, filename) do
    prefix = if media_type == "video", do: "video", else: "sfx"
    "users/#{user_id}/#{prefix}/#{UUID.uuid4()}_#{Path.basename(filename)}"
  end

  defp normalize_aliases(%{"aliases" => aliases} = params) when is_binary(aliases) do
    normalized_aliases =
      aliases
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    Map.put(params, "aliases", normalized_aliases)
  end

  defp normalize_aliases(params), do: params
end
