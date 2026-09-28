defmodule BotWorld.Trigger do
  use Ecto.Schema
  import Ecto.Changeset

  schema "triggers" do
    field :name, :string
    field :type, :string
    field :reward_name, :string
    field :bits_amount, :integer
    field :target_type, :string, virtual: true
    belongs_to :user, BotWorld.Accounts.User
    belongs_to :media_group, BotWorld.MediaGroup
    belongs_to :media_item, BotWorld.MediaItem

    timestamps(type: :utc_datetime)
  end

  @trigger_types ~w(twitch_point_redeem twitch_bits twitch_follow twitch_subscribe chat_command)

  def trigger_types, do: @trigger_types

  @doc false
  def changeset(trigger, attrs) do
    trigger
    |> cast(attrs, [
      :name,
      :type,
      :reward_name,
      :bits_amount,
      :target_type,
      :media_group_id,
      :media_item_id
    ])
    |> normalize_target()
    |> validate_trigger_fields()
    |> validate_target()
    |> foreign_key_constraint(:media_group_id)
    |> foreign_key_constraint(:media_group_id, name: :triggers_media_group_tenant_fkey)
    |> foreign_key_constraint(:media_item_id)
    |> foreign_key_constraint(:media_item_id, name: :triggers_media_item_tenant_fkey)
    |> check_constraint(:target_type, name: :triggers_exactly_one_target)
  end

  defp validate_trigger_fields(changeset) do
    changeset
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, @trigger_types)
    |> validate_number(:bits_amount, greater_than_or_equal_to: 0)
  end

  defp normalize_target(changeset) do
    target_type =
      get_change(changeset, :target_type) ||
        infer_target_type(
          get_field(changeset, :media_group_id),
          get_field(changeset, :media_item_id)
        )

    case target_type do
      "media_group" ->
        changeset
        |> put_change(:target_type, "media_group")
        |> put_change(:media_item_id, nil)

      "media_item" ->
        changeset
        |> put_change(:target_type, "media_item")
        |> put_change(:media_group_id, nil)

      _other ->
        changeset
    end
  end

  defp validate_target(changeset) do
    group_id = get_field(changeset, :media_group_id)
    item_id = get_field(changeset, :media_item_id)

    changeset
    |> validate_inclusion(:target_type, ["media_group", "media_item"])
    |> case do
      changeset when not is_nil(group_id) and is_nil(item_id) -> changeset
      changeset when is_nil(group_id) and not is_nil(item_id) -> changeset
      changeset -> add_error(changeset, :target_type, "must select exactly one target")
    end
  end

  defp infer_target_type(group_id, nil) when not is_nil(group_id), do: "media_group"
  defp infer_target_type(nil, item_id) when not is_nil(item_id), do: "media_item"
  defp infer_target_type(_group_id, _item_id), do: nil
end
