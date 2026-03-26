defmodule BotWorldWeb.TriggersController do
  use BotWorldWeb, :controller
  alias BotWorld.{Trigger, Command, Repo}
  import Ecto.Query

  def index(conn, _params) do
    triggers = Repo.all(from t in Trigger, preload: [:command])
    render(conn, :index, triggers: triggers)
  end

  def new(conn, _params) do
    changeset = Trigger.changeset(%Trigger{}, %{})
    commands = Repo.all(Command)
    render(conn, :new, changeset: changeset, commands: commands, trigger_types: Trigger.trigger_types())
  end

  def create(conn, %{"trigger" => trigger_params}) do
    changeset = Trigger.changeset(%Trigger{}, trigger_params)

    case Repo.insert(changeset) do
      {:ok, _trigger} ->
        conn
        |> put_flash(:info, "Trigger created successfully.")
        |> redirect(to: ~p"/triggers")

      {:error, changeset} ->
        commands = Repo.all(Command)
        render(conn, :new, changeset: changeset, commands: commands, trigger_types: Trigger.trigger_types())
    end
  end

  def show(conn, %{"id" => id}) do
    trigger = Repo.get!(Trigger, id) |> Repo.preload(:command)
    render(conn, :show, trigger: trigger)
  end

  def edit(conn, %{"id" => id}) do
    trigger = Repo.get!(Trigger, id)
    changeset = Trigger.changeset(trigger, %{})
    commands = Repo.all(Command)
    render(conn, :edit, trigger: trigger, changeset: changeset, commands: commands, trigger_types: Trigger.trigger_types())
  end

  def update(conn, %{"id" => id, "trigger" => trigger_params}) do
    trigger = Repo.get!(Trigger, id)
    changeset = Trigger.changeset(trigger, trigger_params)

    case Repo.update(changeset) do
      {:ok, trigger} ->
        conn
        |> put_flash(:info, "Trigger updated successfully.")
        |> redirect(to: ~p"/triggers/#{trigger}")

      {:error, changeset} ->
        commands = Repo.all(Command)
        render(conn, :edit, trigger: trigger, changeset: changeset, commands: commands, trigger_types: Trigger.trigger_types())
    end
  end

  def delete(conn, %{"id" => id}) do
    trigger = Repo.get!(Trigger, id)
    {:ok, _trigger} = Repo.delete(trigger)

    conn
    |> put_flash(:info, "Trigger deleted successfully.")
    |> redirect(to: ~p"/triggers")
  end
end
