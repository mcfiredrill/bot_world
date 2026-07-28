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
      triggers: Enum.map(Map.get(command, :triggers, []), &trigger_data/1),
      inserted_at: command.inserted_at,
      updated_at: command.updated_at
    }
  end

  defp trigger_data(trigger) do
    %{
      id: trigger.id,
      name: trigger.name,
      type: trigger.type,
      reward_name: trigger.reward_name,
      bits_amount: trigger.bits_amount,
      command_id: trigger.command_id,
      inserted_at: trigger.inserted_at,
      updated_at: trigger.updated_at
    }
  end
end
