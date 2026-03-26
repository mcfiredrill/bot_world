defmodule BotWorldWeb.CommandsHTML do
  use BotWorldWeb, :html

  embed_templates "commands_html/*"

  defp your_s3_host do
    "localhost:9000/bot-world"
  end
end
