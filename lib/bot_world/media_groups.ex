defmodule BotWorld.MediaGroups do
  import Ecto.Query, warn: false

  alias BotWorld.Accounts.User
  alias BotWorld.{MediaGroup, MediaItem, Repo}

  def list_media_groups(%User{id: user_id}) do
    MediaGroup
    |> where([g], g.user_id == ^user_id)
    |> order_by([g], asc: g.name)
    |> preload([:media_items, :triggers])
    |> Repo.all()
  end

  def get_media_group!(%User{id: user_id}, id) do
    MediaGroup
    |> Repo.get_by!(id: id, user_id: user_id)
    |> Repo.preload([:media_items, :triggers])
  end

  def change_media_group(%MediaGroup{} = media_group, attrs \\ %{}) do
    MediaGroup.changeset(media_group, attrs)
  end

  def create_media_group(%User{id: user_id}, attrs) do
    %MediaGroup{user_id: user_id}
    |> Repo.preload(:media_items)
    |> save_media_group(attrs, user_id)
  end

  def update_media_group(%User{id: user_id}, %MediaGroup{user_id: user_id} = media_group, attrs) do
    media_group
    |> Repo.preload(:media_items)
    |> save_media_group(attrs, user_id)
  end

  def delete_media_group(%MediaGroup{} = media_group) do
    media_group
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(:triggers,
      message: "cannot be deleted while triggers use this group"
    )
    |> Repo.delete()
  end

  defp save_media_group(media_group, attrs, user_id) do
    media_item_ids = Map.get(attrs, "media_item_ids", Map.get(attrs, :media_item_ids, []))
    media_item_ids = media_item_ids |> Enum.reject(&(&1 in [nil, ""])) |> Enum.map(&parse_id/1)

    media_items =
      Repo.all(from c in MediaItem, where: c.user_id == ^user_id and c.id in ^media_item_ids)

    media_group
    |> MediaGroup.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:media_items, media_items)
    |> validate_all_media_items_selected(media_item_ids, media_items)
    |> validate_has_media_items(media_items)
    |> Repo.insert_or_update()
  end

  defp validate_has_media_items(changeset, []),
    do: Ecto.Changeset.add_error(changeset, :media_items, "select at least one media clip")

  defp validate_has_media_items(changeset, _media_items), do: changeset

  defp validate_all_media_items_selected(changeset, media_item_ids, media_items) do
    if length(media_item_ids) == length(media_items),
      do: changeset,
      else: Ecto.Changeset.add_error(changeset, :media_items, "contains an invalid media item")
  end

  defp parse_id(id) when is_integer(id), do: id
  defp parse_id(id) when is_binary(id), do: String.to_integer(id)
end
