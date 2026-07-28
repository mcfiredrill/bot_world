defmodule BotWorld.Trigger do
  use Ecto.Schema
  import Ecto.Changeset

  schema "triggers" do
    field :name, :string
    field :type, :string
    field :reward_name, :string
    field :bits_amount, :integer
    belongs_to :command, BotWorld.Command

    timestamps(type: :utc_datetime)
  end

  @trigger_types ~w(twitch_point_redeem twitch_bits twitch_follow twitch_subscribe chat_command)

  def trigger_types, do: @trigger_types

  @doc false
  def changeset(trigger, attrs) do
    trigger
    |> cast(attrs, [:name, :type, :reward_name, :bits_amount, :command_id])
    |> validate_trigger_fields()
    |> validate_required([:command_id])
    |> foreign_key_constraint(:command_id)
  end

  def command_changeset(trigger, attrs) do
    trigger
    |> cast(attrs, [:name, :type, :reward_name, :bits_amount])
    |> validate_trigger_fields()
  end

  defp validate_trigger_fields(changeset) do
    changeset
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, @trigger_types)
    |> validate_number(:bits_amount, greater_than_or_equal_to: 0)
  end
end
