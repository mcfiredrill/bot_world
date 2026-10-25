defmodule BotWorldWeb.TriggersController do
  use BotWorldWeb, :controller
  alias BotWorld.{Media, Trigger, Triggers}

  def index(conn, params) do
    sort = if params["sort"] in ~w(name type matches target), do: params["sort"], else: "name"
    direction = if params["direction"] == "desc", do: :desc, else: :asc

    triggers =
      conn.assigns.current_user
      |> Triggers.list_triggers()
      |> Enum.sort_by(&{trigger_sort_value(&1, sort), String.downcase(&1.name), &1.id}, direction)

    render(conn, :index, triggers: triggers, sort: sort, direction: direction)
  end

  def new(conn, _params) do
    changeset = Triggers.change_trigger(%Trigger{user_id: conn.assigns.current_user.id})

    render(conn, :new,
      changeset: changeset,
      media_groups: media_groups(conn),
      media_items: media_items(conn),
      trigger_types: Trigger.trigger_types()
    )
  end

  def bits_rewards(conn, _params) do
    rewards =
      conn.assigns.current_user
      |> Triggers.list_triggers()
      |> Enum.filter(&(&1.type == "twitch_bits"))
      |> Enum.sort_by(&{is_nil(&1.bits_amount), &1.bits_amount, &1.name})

    rewards_text =
      Enum.map_join(rewards, "\n", fn reward ->
        amount =
          if is_nil(reward.bits_amount),
            do: "Other Bits amounts",
            else: "#{reward.bits_amount} Bits"

        "- #{amount}: #{reward.name}"
      end)

    render(conn, :bits_rewards, rewards: rewards, rewards_text: rewards_text)
  end

  def create(conn, %{"trigger" => trigger_params}) do
    case Triggers.create_trigger(conn.assigns.current_user, trigger_params) do
      {:ok, _trigger} ->
        conn
        |> put_flash(:info, "Trigger created successfully.")
        |> redirect(to: ~p"/triggers")

      {:error, changeset} ->
        render(conn, :new,
          changeset: changeset,
          media_groups: media_groups(conn),
          media_items: media_items(conn),
          trigger_types: Trigger.trigger_types()
        )
    end
  end

  def show(conn, %{"id" => id}) do
    trigger = Triggers.get_trigger!(conn.assigns.current_user, id, trigger_preloads())
    render(conn, :show, trigger: trigger)
  end

  def edit(conn, %{"id" => id}) do
    trigger = Triggers.get_trigger!(conn.assigns.current_user, id)
    changeset = Triggers.change_trigger(trigger)

    render(conn, :edit,
      trigger: trigger,
      changeset: changeset,
      media_groups: media_groups(conn),
      media_items: media_items(conn),
      trigger_types: Trigger.trigger_types()
    )
  end

  def update(conn, %{"id" => id, "trigger" => trigger_params}) do
    trigger = Triggers.get_trigger!(conn.assigns.current_user, id)

    case Triggers.update_trigger(conn.assigns.current_user, trigger, trigger_params) do
      {:ok, trigger} ->
        conn
        |> put_flash(:info, "Trigger updated successfully.")
        |> redirect(to: ~p"/triggers/#{trigger}")

      {:error, changeset} ->
        render(conn, :edit,
          trigger: trigger,
          changeset: changeset,
          media_groups: media_groups(conn),
          media_items: media_items(conn),
          trigger_types: Trigger.trigger_types()
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    case Triggers.delete_trigger(conn.assigns.current_user, id) do
      {:ok, _trigger} ->
        conn
        |> put_flash(:info, "Trigger deleted successfully.")
        |> redirect(to: ~p"/triggers")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to delete trigger.")
        |> redirect(to: ~p"/triggers")
    end
  end

  def test_bits(conn, %{"test_bits" => %{"bits" => bits}}) do
    case Integer.parse(to_string(bits)) do
      {amount, ""} when amount >= 0 ->
        Media.dispatch_event(conn.assigns.current_user, "channel.cheer", %{"bits" => amount})

        conn
        |> put_flash(:info, "Simulated a #{amount}-bit cheer.")
        |> redirect(to: ~p"/triggers")

      _invalid ->
        invalid_bits(conn)
    end
  end

  def test_bits(conn, _params), do: invalid_bits(conn)

  defp invalid_bits(conn) do
    conn
    |> put_flash(:error, "Bits must be a non-negative whole number.")
    |> redirect(to: ~p"/triggers")
  end

  defp trigger_sort_value(trigger, "name"), do: String.downcase(trigger.name)
  defp trigger_sort_value(trigger, "type"), do: trigger.type

  defp trigger_sort_value(%{type: "twitch_bits"} = trigger, "matches"),
    do: {"bits", is_nil(trigger.bits_amount), trigger.bits_amount}

  defp trigger_sort_value(trigger, "matches"),
    do: {"text", String.downcase(BotWorldWeb.TriggersHTML.format_trigger_match(trigger))}

  defp trigger_sort_value(trigger, "target") do
    if trigger.media_item,
      do: {"media item", String.downcase(trigger.media_item.name)},
      else: {"group", String.downcase(trigger.media_group.name)}
  end

  defp media_groups(conn), do: Triggers.list_media_groups(conn.assigns.current_user)
  defp media_items(conn), do: Triggers.list_media_items(conn.assigns.current_user)
  defp trigger_preloads, do: [:media_item, media_group: :media_items]
end
