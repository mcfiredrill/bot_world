defmodule BotWorld.CommandParams do
  @allowed_fields ~w(name aliases media_type s3_key triggers)

  def normalize(command_params) do
    command_params
    |> Map.take(@allowed_fields)
    |> normalize_aliases()
    |> normalize_triggers()
  end

  def put_s3_key(command_params, s3_key) do
    command_params
    |> normalize()
    |> Map.put("s3_key", s3_key)
  end

  def build_s3_key(media_type, filename) do
    prefix = if media_type == "video", do: "video", else: "sfx"
    "#{prefix}/#{UUID.uuid4()}_#{Path.basename(filename)}"
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

  defp normalize_triggers(%{"triggers" => triggers} = params) when is_map(triggers) do
    normalized_triggers =
      triggers
      |> Enum.sort_by(fn {index, _attrs} -> String.to_integer(index) end)
      |> Enum.map(fn {_index, attrs} -> attrs end)
      |> Enum.reject(&blank_trigger?/1)

    Map.put(params, "triggers", normalized_triggers)
  end

  defp normalize_triggers(params), do: params

  defp blank_trigger?(attrs) do
    Enum.all?([attrs["name"], attrs["type"]], &blank_value?/1)
  end

  defp blank_value?(value), do: value in [nil, ""]
end
