defmodule BotWorldWeb.CommandsController do
  use BotWorldWeb, :controller
  alias BotWorld.{Command, CommandParams, Repo, Trigger}
  alias BotWorldWeb.TriggersHTML

  def index(conn, _params) do
    render_index(conn, command_form_changeset())
  end

  def show(conn, %{"command" => id}) do
    command =
      Command
      |> Repo.get!(id)
      |> Repo.preload(:triggers)

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

  defp render_index(conn, changeset) do
    render(conn, :index,
      changeset: changeset,
      commands: Repo.all(Command),
      trigger_type_options: trigger_type_options(),
      trigger_form_count: trigger_form_count(changeset)
    )
  end

  defp trigger_type_options do
    Enum.map(Trigger.trigger_types(), fn type ->
      {TriggersHTML.format_trigger_type(type), type}
    end)
  end

  defp command_form_changeset(command_params \\ %{}) do
    params = CommandParams.normalize(command_params)
    trigger_count = max(length(Map.get(params, "triggers", [])), 1)
    command = %Command{triggers: Enum.map(1..trigger_count, fn _ -> %Trigger{} end)}

    Command.changeset(command, params)
  end

  defp trigger_form_count(changeset) do
    changeset
    |> Ecto.Changeset.get_field(:triggers, [])
    |> length()
    |> max(1)
  end
end
