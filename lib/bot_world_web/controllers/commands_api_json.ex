defmodule BotWorldWeb.CommandsAPIJSON do
  alias BotWorld.S3

  def show(%{command: command}) do
    %{command: command_data(command)}
  end

  def presign(%{upload: upload}) do
    %{upload: upload}
  end

  defp command_data(command) do
    %{
      id: command.id,
      name: command.name,
      aliases: command.aliases,
      s3_key: command.s3_key,
      url: S3.public_url(command.s3_key),
      media_type: command.media_type,
      inserted_at: command.inserted_at,
      updated_at: command.updated_at
    }
  end
end
