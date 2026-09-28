defmodule BotWorld.Triggers do
  import Ecto.Query, warn: false

  alias BotWorld.Accounts.User
  alias BotWorld.{MediaGroup, MediaItem, Repo, Trigger}

  def list_triggers(%User{id: user_id}) do
    Trigger
    |> where([t], t.user_id == ^user_id)
    |> order_by([t], asc: t.name)
    |> preload([:media_item, media_group: :media_items])
    |> Repo.all()
  end

  def get_trigger!(%User{id: user_id}, id, preloads \\ []) do
    Trigger
    |> Repo.get_by!(id: id, user_id: user_id)
    |> Repo.preload(preloads)
  end

  def change_trigger(%Trigger{} = trigger, attrs \\ %{}), do: Trigger.changeset(trigger, attrs)

  def create_trigger(%User{id: user_id}, attrs) do
    %Trigger{user_id: user_id}
    |> Trigger.changeset(attrs)
    |> validate_target_owner(user_id)
    |> Repo.insert()
  end

  def update_trigger(%User{id: user_id}, %Trigger{user_id: user_id} = trigger, attrs) do
    trigger
    |> Trigger.changeset(attrs)
    |> validate_target_owner(user_id)
    |> Repo.update()
  end

  def delete_trigger(%User{} = user, id) do
    user
    |> get_trigger!(id)
    |> Repo.delete()
  end

  def list_media_groups(%User{id: user_id}) do
    Repo.all(from g in MediaGroup, where: g.user_id == ^user_id, order_by: g.name)
  end

  def list_media_items(%User{id: user_id}) do
    Repo.all(from m in MediaItem, where: m.user_id == ^user_id, order_by: m.name)
  end

  defp validate_target_owner(changeset, user_id) do
    changeset
    |> validate_owner(:media_group_id, MediaGroup, user_id)
    |> validate_owner(:media_item_id, MediaItem, user_id)
  end

  defp validate_owner(changeset, field, schema, user_id) do
    case Ecto.Changeset.get_field(changeset, field) do
      nil ->
        changeset

      id ->
        if Repo.exists?(
             from record in schema, where: record.id == ^id and record.user_id == ^user_id
           ),
           do: changeset,
           else: Ecto.Changeset.add_error(changeset, field, "is invalid")
    end
  end
end
