defmodule BotWorld.MediaGroupCommand do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "media_group_commands" do
    belongs_to :user, BotWorld.Accounts.User
    belongs_to :media_group, BotWorld.MediaGroup
    belongs_to :command, BotWorld.Command
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :media_group_id, :command_id])
    |> validate_required([:user_id, :media_group_id, :command_id])
    |> foreign_key_constraint(:media_group_id, name: :media_group_commands_group_tenant_fkey)
    |> foreign_key_constraint(:command_id, name: :media_group_commands_command_tenant_fkey)
    |> unique_constraint([:media_group_id, :command_id])
  end
end
