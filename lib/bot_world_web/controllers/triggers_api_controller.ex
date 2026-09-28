defmodule BotWorldWeb.TriggersAPIController do
  use BotWorldWeb, :controller

  alias BotWorld.{Trigger, Triggers}
  alias BotWorldWeb.ChangesetJSON

  def index(conn, _params) do
    triggers = Triggers.list_triggers(conn.assigns.current_user)
    render(conn, :index, triggers: triggers)
  end

  def create(conn, %{"trigger" => trigger_params}) do
    case Triggers.create_trigger(conn.assigns.current_user, trigger_params) do
      {:ok, trigger} ->
        trigger = BotWorld.Repo.preload(trigger, trigger_preloads())

        conn
        |> put_status(:created)
        |> put_resp_header("location", ~p"/api/triggers/#{trigger.id}")
        |> render(:show, trigger: trigger)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(ChangesetJSON.errors(changeset))
    end
  end

  def create(conn, _params) do
    changeset = Triggers.change_trigger(%Trigger{user_id: conn.assigns.current_user.id})

    conn
    |> put_status(:unprocessable_entity)
    |> json(ChangesetJSON.errors(changeset))
  end

  def show(conn, %{"id" => id}) do
    trigger = Triggers.get_trigger!(conn.assigns.current_user, id, trigger_preloads())
    render(conn, :show, trigger: trigger)
  end

  def update(conn, %{"id" => id, "trigger" => trigger_params}) do
    trigger = Triggers.get_trigger!(conn.assigns.current_user, id)

    case trigger
         |> then(&Triggers.update_trigger(conn.assigns.current_user, &1, trigger_params)) do
      {:ok, trigger} ->
        render(conn, :show, trigger: BotWorld.Repo.preload(trigger, trigger_preloads()))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(ChangesetJSON.errors(changeset))
    end
  end

  def update(conn, %{"id" => id}) do
    changeset =
      conn.assigns.current_user
      |> Triggers.get_trigger!(id)
      |> Triggers.change_trigger(%{})

    conn
    |> put_status(:unprocessable_entity)
    |> json(ChangesetJSON.errors(changeset))
  end

  def delete(conn, %{"id" => id}) do
    {:ok, _trigger} = Triggers.delete_trigger(conn.assigns.current_user, id)

    send_resp(conn, :no_content, "")
  end

  defp trigger_preloads, do: [:media_item, media_group: :media_items]
end
