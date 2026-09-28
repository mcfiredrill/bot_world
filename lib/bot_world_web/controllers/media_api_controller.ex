defmodule BotWorldWeb.MediaAPIController do
  use BotWorldWeb, :controller

  import Ecto.Changeset

  alias BotWorld.{MediaItem, MediaItemParams, Media, S3}
  alias BotWorldWeb.ChangesetJSON

  def create(conn, %{"media_item" => media_item_params}) do
    attrs = MediaItemParams.normalize(media_item_params)

    case Media.create_media_item(conn.assigns.current_user, attrs) do
      {:ok, media_item} ->
        conn
        |> put_status(:created)
        |> render(:show, media_item: media_item)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(ChangesetJSON.errors(changeset))
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(
      ChangesetJSON.errors(
        Media.change_media_item(%MediaItem{user_id: conn.assigns.current_user.id}, %{})
      )
    )
  end

  def presign(conn, %{"upload" => upload_params}) do
    changeset = upload_changeset(upload_params)

    if changeset.valid? do
      %{filename: filename, content_type: content_type, media_type: media_type} =
        apply_changes(changeset)

      s3_key = MediaItemParams.build_s3_key(conn.assigns.current_user.id, media_type, filename)

      case S3.presign_upload(s3_key, content_type) do
        {:ok, upload} ->
          render(conn, :presign, upload: Map.put(upload, :media_type, media_type))

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: %{detail: to_string(reason)}})
      end
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(ChangesetJSON.errors(changeset))
    end
  end

  def presign(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(ChangesetJSON.errors(upload_changeset(%{})))
  end

  defp upload_changeset(params) do
    {%{}, %{filename: :string, content_type: :string, media_type: :string}}
    |> cast(params, [:filename, :content_type, :media_type])
    |> validate_required([:filename, :content_type])
    |> put_default_media_type()
    |> validate_inclusion(:media_type, ["audio", "video"])
  end

  defp put_default_media_type(changeset) do
    case get_field(changeset, :media_type) do
      nil -> put_change(changeset, :media_type, "audio")
      "" -> put_change(changeset, :media_type, "audio")
      _media_type -> changeset
    end
  end
end
