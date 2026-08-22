defmodule BotWorld.MediaGroups do
  import Ecto.Query, warn: false

  alias BotWorld.{Command, MediaGroup, Repo}

  def list_media_groups do
    MediaGroup
    |> order_by([g], asc: g.name)
    |> preload([:commands, :triggers])
    |> Repo.all()
  end

  def get_media_group!(id),
    do: MediaGroup |> Repo.get!(id) |> Repo.preload([:commands, :triggers])

  def change_media_group(%MediaGroup{} = media_group, attrs \\ %{}) do
    MediaGroup.changeset(media_group, attrs)
  end

  def create_media_group(attrs) do
    %MediaGroup{}
    |> Repo.preload(:commands)
    |> save_media_group(attrs)
  end

  def update_media_group(%MediaGroup{} = media_group, attrs) do
    media_group
    |> Repo.preload(:commands)
    |> save_media_group(attrs)
  end

  def delete_media_group(%MediaGroup{} = media_group) do
    media_group
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(:triggers,
      message: "cannot be deleted while triggers use this group"
    )
    |> Repo.delete()
  end

  defp save_media_group(media_group, attrs) do
    command_ids = Map.get(attrs, "command_ids", Map.get(attrs, :command_ids, []))
    command_ids = command_ids |> Enum.reject(&(&1 in [nil, ""])) |> Enum.map(&parse_id/1)
    commands = Repo.all(from c in Command, where: c.id in ^command_ids)

    media_group
    |> MediaGroup.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:commands, commands)
    |> validate_has_commands(commands)
    |> Repo.insert_or_update()
  end

  defp validate_has_commands(changeset, []),
    do: Ecto.Changeset.add_error(changeset, :commands, "select at least one media clip")

  defp validate_has_commands(changeset, _commands), do: changeset

  defp parse_id(id) when is_integer(id), do: id
  defp parse_id(id) when is_binary(id), do: String.to_integer(id)
end
