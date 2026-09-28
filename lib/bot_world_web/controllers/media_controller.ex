defmodule BotWorldWeb.MediaController do
  use BotWorldWeb, :controller
  alias BotWorld.{Media, MediaItem, MediaItemParams, Repo}
  alias BotWorld.Twitch

  def index(conn, _params) do
    render_index(conn, media_item_form_changeset(conn.assigns.current_user))
  end

  def show(conn, %{"media_item" => id}) do
    media_item =
      Media.get_media_item!(conn.assigns.current_user, id, media_groups: :triggers)

    render(conn, :show, media_item: media_item)
  end

  def create(conn, %{"media_item" => media_item_params}) do
    case media_item_params["media_file"] do
      %Plug.Upload{filename: filename, path: temp_path, content_type: content_type} ->
        user = conn.assigns.current_user

        s3_key =
          MediaItemParams.build_s3_key(
            user.id,
            media_item_params["media_type"] || "audio",
            filename
          )

        case BotWorld.S3.upload_file(temp_path, s3_key, content_type) do
          {:ok, %{body: %{key: returned_key}}} ->
            attrs = MediaItemParams.put_s3_key(media_item_params, returned_key)

            case Media.create_media_item(user, attrs) do
              {:ok, _media_item} ->
                conn
                |> put_flash(:info, "Media item created successfully.")
                |> redirect(to: ~p"/media")

              {:error, changeset} ->
                render_index(conn, changeset)
            end

          {:error, reason} ->
            conn
            |> put_flash(:error, "Failed to upload file: #{inspect(reason)}")
            |> render_index(media_item_form_changeset(user, media_item_params))
        end

      _ ->
        changeset =
          media_item_form_changeset(conn.assigns.current_user, media_item_params)
          |> Ecto.Changeset.add_error(:media_file, "can't be blank")

        render_index(conn, changeset)
    end
  end

  def delete(conn, %{"media_item" => id}) do
    media_item =
      Media.get_media_item!(conn.assigns.current_user, id,
        media_groups: [:media_items, :triggers]
      )

    if Enum.any?(media_item.media_groups, &(length(&1.media_items) == 1 and &1.triggers != [])) do
      conn
      |> put_flash(
        :error,
        "Remove this clip's triggers or add another clip to its groups before deleting it."
      )
      |> redirect(to: ~p"/media/#{media_item}")
    else
      delete_media_item(conn, media_item)
    end
  end

  defp delete_media_item(conn, media_item) do
    case Repo.delete(media_item) do
      {:ok, _media_item} ->
        conn
        |> put_flash(:info, "Media item deleted successfully.")
        |> redirect(to: ~p"/media")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to delete media item.")
        |> redirect(to: ~p"/media/#{media_item}")
    end
  end

  defp render_index(conn, changeset) do
    render(conn, :index,
      changeset: changeset,
      media_items: Media.list_media_items(conn.assigns.current_user),
      twitch_credential: Twitch.get_credential(conn.assigns.current_user),
      overlay_token: overlay_token()
    )
  end

  defp overlay_token, do: Application.get_env(:bot_world, :overlay, [])[:token]

  defp media_item_form_changeset(user, media_item_params \\ %{}) do
    params = MediaItemParams.normalize(media_item_params)
    Media.change_media_item(%MediaItem{user_id: user.id}, params)
  end
end
