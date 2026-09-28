defmodule BotWorldWeb.TriggersAPIJSON do
  alias BotWorldWeb.MediaJSON

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
      target_type: target_type(trigger),
      media_group_id: trigger.media_group_id,
      media_item_id: trigger.media_item_id,
      media_group: media_group_data(trigger),
      media_item: media_item_data(trigger),
      inserted_at: trigger.inserted_at,
      updated_at: trigger.updated_at
    }
  end

  defp media_group_data(%{media_group: %_{} = media_group}) do
    %{
      id: media_group.id,
      name: media_group.name,
      media_items: Enum.map(media_group.media_items, &MediaJSON.media_item/1)
    }
  end

  defp media_group_data(_trigger), do: nil

  defp media_item_data(%{media_item: %_{} = media_item}), do: MediaJSON.media_item(media_item)
  defp media_item_data(_trigger), do: nil

  defp target_type(%{media_item_id: id}) when not is_nil(id), do: "media_item"
  defp target_type(_trigger), do: "media_group"
end
