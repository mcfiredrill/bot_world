defmodule BotWorldWeb.CommandsController do
  use BotWorldWeb, :controller
  alias BotWorld.{Command, CommandParams, Repo}

  def index(conn, _params) do
    render_index(conn, command_form_changeset())
  end

  def show(conn, %{"command" => id}) do
    command =
      Command
      |> Repo.get!(id)
      |> Repo.preload(media_groups: :triggers)

    render(conn, :show, command: command)
  end

  def create(conn, %{"command" => command_params}) do
    case command_params["media_file"] do
      %Plug.Upload{filename: filename, path: temp_path, content_type: content_type} ->
        s3_key = CommandParams.build_s3_key(command_params["media_type"] || "audio", filename)

        case BotWorld.S3.upload_file(temp_path, s3_key, content_type) do
          {:ok, %{body: %{key: returned_key}}} ->
            attrs = CommandParams.put_s3_key(command_params, returned_key)
            changeset = Command.changeset(%Command{}, attrs)

            case Repo.insert(changeset) do
              {:ok, _command} ->
                conn
                |> put_flash(:info, "Command created successfully.")
                |> redirect(to: ~p"/commands")

              {:error, changeset} ->
                render_index(conn, changeset)
            end

          {:error, reason} ->
            conn
            |> put_flash(:error, "Failed to upload file: #{inspect(reason)}")
            |> render_index(command_form_changeset(command_params))
        end

      _ ->
        changeset =
          command_form_changeset(command_params)
          |> Ecto.Changeset.add_error(:media_file, "can't be blank")

        render_index(conn, changeset)
    end
  end

  def delete(conn, %{"command" => id}) do
    command = Command |> Repo.get!(id) |> Repo.preload(media_groups: [:commands, :triggers])

    if Enum.any?(command.media_groups, &(length(&1.commands) == 1 and &1.triggers != [])) do
      conn
      |> put_flash(
        :error,
        "Remove this clip's triggers or add another clip to its groups before deleting it."
      )
      |> redirect(to: ~p"/commands/#{command}")
    else
      delete_command(conn, command)
    end
  end

  defp delete_command(conn, command) do
    case Repo.delete(command) do
      {:ok, _command} ->
        conn
        |> put_flash(:info, "Command deleted successfully.")
        |> redirect(to: ~p"/commands")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to delete command.")
        |> redirect(to: ~p"/commands/#{command}")
    end
  end

  defp render_index(conn, changeset) do
    render(conn, :index,
      changeset: changeset,
      commands: Command |> Repo.all() |> Repo.preload(media_groups: :triggers),
      overlay_token: overlay_token()
    )
  end

  defp overlay_token, do: Application.get_env(:bot_world, :overlay, [])[:token]

  defp command_form_changeset(command_params \\ %{}) do
    params = CommandParams.normalize(command_params)
    Command.changeset(%Command{}, params)
  end
end
