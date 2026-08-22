defmodule BotWorldWeb.TriggersAPIJSON do
  alias BotWorldWeb.CommandsJSON

  def index(%{triggers: triggers}) do
    %{triggers: Enum.map(triggers, &trigger_data/1)}
  end

  def show(%{trigger: trigger}) do
    %{trigger: trigger_data(trigger)}
  end

  defp trigger_data(trigger) do
    %{
      id: trigger.id,
      name: trigger.name,
      type: trigger.type,
      reward_name: trigger.reward_name,
      bits_amount: trigger.bits_amount,
      media_group_id: trigger.media_group_id,
      media_group: media_group_data(trigger),
      inserted_at: trigger.inserted_at,
      updated_at: trigger.updated_at
    }
  end

  defp media_group_data(%{media_group: %_{} = media_group}) do
    %{
      id: media_group.id,
      name: media_group.name,
      commands: Enum.map(media_group.commands, &CommandsJSON.command/1)
    }
  end

  defp media_group_data(_trigger), do: nil
end
