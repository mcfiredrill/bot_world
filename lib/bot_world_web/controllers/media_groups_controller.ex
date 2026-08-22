defmodule BotWorldWeb.MediaGroupsController do
  use BotWorldWeb, :controller

  alias BotWorld.{Command, MediaGroup, MediaGroups, Repo}

  def index(conn, _params) do
    render(conn, :index, media_groups: MediaGroups.list_media_groups())
  end

  def new(conn, _params) do
    media_group = %MediaGroup{commands: []}
    render_form(conn, :new, media_group, MediaGroups.change_media_group(media_group))
  end

  def create(conn, %{"media_group" => params}) do
    case MediaGroups.create_media_group(params) do
      {:ok, media_group} ->
        conn
        |> put_flash(:info, "Media group created successfully.")
        |> redirect(to: ~p"/groups/#{media_group}")

      {:error, changeset} ->
        render_form(conn, :new, %MediaGroup{commands: []}, changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    render(conn, :show, media_group: MediaGroups.get_media_group!(id))
  end

  def edit(conn, %{"id" => id}) do
    media_group = MediaGroups.get_media_group!(id)
    render_form(conn, :edit, media_group, MediaGroups.change_media_group(media_group))
  end

  def update(conn, %{"id" => id, "media_group" => params}) do
    media_group = MediaGroups.get_media_group!(id)

    case MediaGroups.update_media_group(media_group, params) do
      {:ok, media_group} ->
        conn
        |> put_flash(:info, "Media group updated successfully.")
        |> redirect(to: ~p"/groups/#{media_group}")

      {:error, changeset} ->
        render_form(conn, :edit, media_group, changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    media_group = MediaGroups.get_media_group!(id)

    case MediaGroups.delete_media_group(media_group) do
      {:ok, _media_group} ->
        conn
        |> put_flash(:info, "Media group deleted successfully.")
        |> redirect(to: ~p"/groups")

      {:error, changeset} ->
        message = changeset.errors |> Keyword.get(:triggers) |> elem(0)

        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/groups/#{media_group}")
    end
  end

  defp render_form(conn, template, media_group, changeset) do
    selected_command_ids =
      changeset
      |> Ecto.Changeset.get_field(:commands, media_group.commands)
      |> Enum.map(& &1.id)

    render(conn, template,
      media_group: media_group,
      changeset: changeset,
      commands: Repo.all(Command),
      selected_command_ids: selected_command_ids
    )
  end
end
