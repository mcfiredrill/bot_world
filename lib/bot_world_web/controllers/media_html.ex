defmodule BotWorldWeb.MediaHTML do
  use BotWorldWeb, :html

  alias BotWorldWeb.TriggersHTML

  embed_templates "media_html/*"

  defp trigger_type(trigger), do: TriggersHTML.format_trigger_type(trigger.type)
  defp trigger_match(trigger), do: TriggersHTML.format_trigger_match(trigger)
end
