defmodule BotWorld.Command do
  use Ecto.Schema
  import Ecto.Changeset

  schema "commands" do
    field :name, :string
    field :aliases, {:array, :string}, default: []
    field :s3_key, :string
    field :media_type, :string, default: "audio"
    many_to_many :media_groups, BotWorld.MediaGroup, join_through: "media_group_commands"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(command, attrs) do
    command
    |> cast(attrs, [:name, :aliases, :s3_key, :media_type])
    |> validate_required([:name, :s3_key])
    |> validate_inclusion(:media_type, ["audio", "video"])
  end
end
