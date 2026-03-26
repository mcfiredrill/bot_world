defmodule BotWorld.Trigger do
  use Ecto.Schema
  import Ecto.Changeset

  schema "triggers" do
    field :name, :string
    field :type, :string
    belongs_to :command, BotWorld.Command

    timestamps(type: :utc_datetime)
  end

  @trigger_types ~w(twitch_point_redeem twitch_bits twitch_follow twitch_subscribe)

  def trigger_types, do: @trigger_types

  @doc false
  def changeset(trigger, attrs) do
    trigger
    |> cast(attrs, [:name, :type, :command_id])
    |> validate_required([:name, :type, :command_id])
    |> validate_inclusion(:type, @trigger_types)
    |> foreign_key_constraint(:command_id)
  end
end
