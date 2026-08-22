defmodule BotWorldWeb.CommandsAPIController do
  use BotWorldWeb, :controller

  import Ecto.Changeset

  alias BotWorld.{Command, CommandParams, Repo, S3}
  alias BotWorldWeb.ChangesetJSON

  def create(conn, %{"command" => command_params}) do
    attrs = CommandParams.normalize(command_params)

    case %Command{}
         |> Command.changeset(attrs)
         |> Repo.insert() do
      {:ok, command} ->
        conn
        |> put_status(:created)
        |> render(:show, command: command)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(ChangesetJSON.errors(changeset))
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(ChangesetJSON.errors(Command.changeset(%Command{}, %{})))
  end

  def presign(conn, %{"upload" => upload_params}) do
    changeset = upload_changeset(upload_params)

    if changeset.valid? do
      %{filename: filename, content_type: content_type, media_type: media_type} =
        apply_changes(changeset)

      s3_key = CommandParams.build_s3_key(media_type, filename)

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
