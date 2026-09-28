defmodule BotWorldWeb.MediaGroupsController do
  use BotWorldWeb, :controller

  alias BotWorld.{MediaGroup, MediaGroups}

  def index(conn, _params) do
    render(conn, :index, media_groups: MediaGroups.list_media_groups(conn.assigns.current_user))
  end

  def new(conn, _params) do
    media_group = %MediaGroup{user_id: conn.assigns.current_user.id, media_items: []}
    render_form(conn, :new, media_group, MediaGroups.change_media_group(media_group))
  end

  def create(conn, %{"media_group" => params}) do
    case MediaGroups.create_media_group(conn.assigns.current_user, params) do
      {:ok, media_group} ->
        conn
        |> put_flash(:info, "Media group created successfully.")
        |> redirect(to: ~p"/groups/#{media_group}")

      {:error, changeset} ->
        render_form(
          conn,
          :new,
          %MediaGroup{user_id: conn.assigns.current_user.id, media_items: []},
          changeset
        )
    end
  end

  def show(conn, %{"id" => id}) do
    render(conn, :show, media_group: MediaGroups.get_media_group!(conn.assigns.current_user, id))
  end

  def edit(conn, %{"id" => id}) do
    media_group = MediaGroups.get_media_group!(conn.assigns.current_user, id)
    render_form(conn, :edit, media_group, MediaGroups.change_media_group(media_group))
  end

  def update(conn, %{"id" => id, "media_group" => params}) do
    media_group = MediaGroups.get_media_group!(conn.assigns.current_user, id)

    case MediaGroups.update_media_group(conn.assigns.current_user, media_group, params) do
      {:ok, media_group} ->
        conn
        |> put_flash(:info, "Media group updated successfully.")
        |> redirect(to: ~p"/groups/#{media_group}")

      {:error, changeset} ->
        render_form(conn, :edit, media_group, changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    media_group = MediaGroups.get_media_group!(conn.assigns.current_user, id)

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
    selected_media_item_ids =
      changeset
      |> Ecto.Changeset.get_field(:media_items, media_group.media_items)
      |> Enum.map(& &1.id)

    render(conn, template,
      media_group: media_group,
      changeset: changeset,
      media_items: BotWorld.Media.list_media_items(conn.assigns.current_user),
      selected_media_item_ids: selected_media_item_ids
    )
  end
end
