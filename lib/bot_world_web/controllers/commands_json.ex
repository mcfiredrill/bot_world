defmodule BotWorldWeb.CommandsJSON do
  def index(%{commands: commands}) do
    %{commands: Enum.map(commands, &command/1)}
  end

  def command(command) do
    %{
      id: command.id,
      name: command.name,
      s3_key: command.s3_key,
      url: s3_url_for(command.s3_key),
      inserted_at: command.inserted_at,
      updated_at: command.updated_at
    }
  end

  defp s3_url_for(key) do
    # customize this if needed
    "http://localhost:9000/bot-world/#{key}"
  end
end
