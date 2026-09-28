defmodule BotWorld.MediaGroupItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "media_group_items" do
    belongs_to :user, BotWorld.Accounts.User
    belongs_to :media_group, BotWorld.MediaGroup
    belongs_to :media_item, BotWorld.MediaItem
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :media_group_id, :media_item_id])
    |> validate_required([:user_id, :media_group_id, :media_item_id])
    |> foreign_key_constraint(:media_group_id, name: :media_group_items_group_tenant_fkey)
    |> foreign_key_constraint(:media_item_id, name: :media_group_items_media_item_tenant_fkey)
    |> unique_constraint([:media_group_id, :media_item_id])
  end
end
