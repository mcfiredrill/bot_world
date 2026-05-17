defmodule BotWorldWeb.TriggersAPIController do
  use BotWorldWeb, :controller

  alias BotWorld.{Repo, Trigger}
  alias BotWorldWeb.ChangesetJSON
  import Ecto.Query

  def index(conn, _params) do
    triggers = Repo.all(from t in Trigger, preload: [:command])
    render(conn, :index, triggers: triggers)
  end

  def create(conn, %{"trigger" => trigger_params}) do
    case %Trigger{}
         |> Trigger.changeset(trigger_params)
         |> Repo.insert() do
      {:ok, trigger} ->
        trigger = Repo.preload(trigger, :command)

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
    changeset = Trigger.changeset(%Trigger{}, %{})

    conn
    |> put_status(:unprocessable_entity)
    |> json(ChangesetJSON.errors(changeset))
  end

  def show(conn, %{"id" => id}) do
    trigger = Repo.get!(Trigger, id) |> Repo.preload(:command)
    render(conn, :show, trigger: trigger)
  end

  def update(conn, %{"id" => id, "trigger" => trigger_params}) do
    trigger = Repo.get!(Trigger, id)

    case trigger
         |> Trigger.changeset(trigger_params)
         |> Repo.update() do
      {:ok, trigger} ->
        render(conn, :show, trigger: Repo.preload(trigger, :command))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(ChangesetJSON.errors(changeset))
    end
  end

  def update(conn, %{"id" => id}) do
    changeset =
      Trigger
      |> Repo.get!(id)
      |> Trigger.changeset(%{})

    conn
    |> put_status(:unprocessable_entity)
    |> json(ChangesetJSON.errors(changeset))
  end

  def delete(conn, %{"id" => id}) do
    Trigger
    |> Repo.get!(id)
    |> Repo.delete!()

    send_resp(conn, :no_content, "")
  end
end
