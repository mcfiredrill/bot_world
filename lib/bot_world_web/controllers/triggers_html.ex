defmodule BotWorldWeb.TriggersHTML do
  use BotWorldWeb, :html

  embed_templates "triggers_html/*"

  @doc """
  Formats trigger type for display.
  """
  def format_trigger_type(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
