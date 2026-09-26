defmodule BotWorld.MediaGroup do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_groups" do
    field :name, :string
    belongs_to :user, BotWorld.Accounts.User

    many_to_many :commands, BotWorld.Command,
      join_through: BotWorld.MediaGroupCommand,
      join_defaults: :set_join_user,
      on_replace: :delete

    has_many :triggers, BotWorld.Trigger

    timestamps(type: :utc_datetime)
  end

  def changeset(media_group, attrs) do
    media_group
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name, name: :media_groups_user_id_name_index)
  end

  def set_join_user(join, media_group), do: %{join | user_id: media_group.user_id}
end
