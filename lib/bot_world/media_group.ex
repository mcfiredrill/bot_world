defmodule BotWorld.MediaGroup do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_groups" do
    field :name, :string

    many_to_many :commands, BotWorld.Command,
      join_through: "media_group_commands",
      on_replace: :delete

    has_many :triggers, BotWorld.Trigger

    timestamps(type: :utc_datetime)
  end

  def changeset(media_group, attrs) do
    media_group
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
