defmodule BotWorldWeb.TriggersController do
  use BotWorldWeb, :controller
  alias BotWorld.{Commands, MediaGroup, Repo, Trigger}
  import Ecto.Query

  def index(conn, _params) do
    triggers = Repo.all(from t in Trigger, preload: [media_group: :commands])
    render(conn, :index, triggers: triggers)
  end

  def new(conn, _params) do
    changeset = Trigger.changeset(%Trigger{}, %{})
    media_groups = media_groups()

    render(conn, :new,
      changeset: changeset,
      media_groups: media_groups,
      trigger_types: Trigger.trigger_types()
    )
  end

  def create(conn, %{"trigger" => trigger_params}) do
    changeset = Trigger.changeset(%Trigger{}, trigger_params)

    case Repo.insert(changeset) do
      {:ok, _trigger} ->
        conn
        |> put_flash(:info, "Trigger created successfully.")
        |> redirect(to: ~p"/triggers")

      {:error, changeset} ->
        media_groups = media_groups()

        render(conn, :new,
          changeset: changeset,
          media_groups: media_groups,
          trigger_types: Trigger.trigger_types()
        )
    end
  end

  def show(conn, %{"id" => id}) do
    trigger = Repo.get!(Trigger, id) |> Repo.preload(media_group: :commands)
    render(conn, :show, trigger: trigger)
  end

  def edit(conn, %{"id" => id}) do
    trigger = Repo.get!(Trigger, id)
    changeset = Trigger.changeset(trigger, %{})
    media_groups = media_groups()

    render(conn, :edit,
      trigger: trigger,
      changeset: changeset,
      media_groups: media_groups,
      trigger_types: Trigger.trigger_types()
    )
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
        media_groups = media_groups()

        render(conn, :edit,
          trigger: trigger,
          changeset: changeset,
          media_groups: media_groups,
          trigger_types: Trigger.trigger_types()
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    trigger = Repo.get!(Trigger, id)

    case Repo.delete(trigger) do
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
        Commands.dispatch_event("channel.cheer", %{"bits" => amount})

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

  defp media_groups do
    Repo.all(from g in MediaGroup, order_by: g.name)
  end
end
