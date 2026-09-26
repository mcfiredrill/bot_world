defmodule BotWorldWeb.TriggersController do
  use BotWorldWeb, :controller
  alias BotWorld.{Commands, Trigger, Triggers}

  def index(conn, _params) do
    triggers = Triggers.list_triggers(conn.assigns.current_user)
    render(conn, :index, triggers: triggers)
  end

  def new(conn, _params) do
    changeset = Triggers.change_trigger(%Trigger{user_id: conn.assigns.current_user.id})
    media_groups = media_groups(conn)

    render(conn, :new,
      changeset: changeset,
      media_groups: media_groups,
      trigger_types: Trigger.trigger_types()
    )
  end

  def create(conn, %{"trigger" => trigger_params}) do
    case Triggers.create_trigger(conn.assigns.current_user, trigger_params) do
      {:ok, _trigger} ->
        conn
        |> put_flash(:info, "Trigger created successfully.")
        |> redirect(to: ~p"/triggers")

      {:error, changeset} ->
        media_groups = media_groups(conn)

        render(conn, :new,
          changeset: changeset,
          media_groups: media_groups,
          trigger_types: Trigger.trigger_types()
        )
    end
  end

  def show(conn, %{"id" => id}) do
    trigger = Triggers.get_trigger!(conn.assigns.current_user, id, media_group: :commands)
    render(conn, :show, trigger: trigger)
  end

  def edit(conn, %{"id" => id}) do
    trigger = Triggers.get_trigger!(conn.assigns.current_user, id)
    changeset = Triggers.change_trigger(trigger)
    media_groups = media_groups(conn)

    render(conn, :edit,
      trigger: trigger,
      changeset: changeset,
      media_groups: media_groups,
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
        media_groups = media_groups(conn)

        render(conn, :edit,
          trigger: trigger,
          changeset: changeset,
          media_groups: media_groups,
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
        Commands.dispatch_event(conn.assigns.current_user, "channel.cheer", %{"bits" => amount})

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

  defp media_groups(conn), do: Triggers.list_media_groups(conn.assigns.current_user)
end
