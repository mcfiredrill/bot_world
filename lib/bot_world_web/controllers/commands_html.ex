defmodule BotWorldWeb.CommandsHTML do
  use BotWorldWeb, :html

  alias BotWorldWeb.TriggersHTML

  embed_templates "commands_html/*"

  defp your_s3_host do
    "localhost:9000/bot-world"
  end

  defp trigger_type(trigger), do: TriggersHTML.format_trigger_type(trigger.type)
  defp trigger_match(trigger), do: TriggersHTML.format_trigger_match(trigger)
end
