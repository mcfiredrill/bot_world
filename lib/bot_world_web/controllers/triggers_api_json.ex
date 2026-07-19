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
      command_id: trigger.command_id,
      command: command_data(trigger),
      inserted_at: trigger.inserted_at,
      updated_at: trigger.updated_at
    }
  end

  defp command_data(%{command: %_{} = command}), do: CommandsJSON.command(command)
  defp command_data(_trigger), do: nil
end
