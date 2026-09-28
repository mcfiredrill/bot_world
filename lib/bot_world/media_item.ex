defmodule BotWorld.MediaItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_items" do
    field :name, :string
    field :aliases, {:array, :string}, default: []
    field :s3_key, :string
    field :media_type, :string, default: "audio"
    belongs_to :user, BotWorld.Accounts.User

    many_to_many :media_groups, BotWorld.MediaGroup,
      join_through: BotWorld.MediaGroupItem,
      join_defaults: :set_join_user

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(media_item, attrs) do
    media_item
    |> cast(attrs, [:name, :aliases, :s3_key, :media_type])
    |> validate_required([:name, :s3_key])
    |> validate_inclusion(:media_type, ["audio", "video"])
  end

  def set_join_user(join, media_item), do: %{join | user_id: media_item.user_id}
end
