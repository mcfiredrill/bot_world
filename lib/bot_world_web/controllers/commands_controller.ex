defmodule BotWorldWeb.CommandsController do
  use BotWorldWeb, :controller
  alias BotWorld.{Command, Repo, Trigger}
  alias BotWorldWeb.TriggersHTML

  def index(conn, _params) do
    render_index(conn, command_form_changeset())
  end

  def show(conn, %{"command" => command}) do
    render(conn, :show, command: command)
  end

  def create(conn, %{"command" => command_params}) do
    case command_params["media_file"] do
      %Plug.Upload{filename: filename, path: temp_path, content_type: content_type} ->
        media_type = command_params["media_type"] || "audio"
        prefix = if media_type == "video", do: "video", else: "sfx"
        s3_key = "#{prefix}/#{UUID.uuid4()}_#{filename}"

        case BotWorld.S3.upload_file(temp_path, s3_key, content_type) do
          {:ok, %{body: %{key: returned_key}}} ->
            attrs = command_attrs(command_params, returned_key)
            changeset = Command.changeset(command_for_insert(attrs), attrs)

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
    params = normalize_command_params(command_params)
    trigger_count = max(length(Map.get(params, "triggers", [])), 1)
    command = %Command{triggers: List.duplicate(%Trigger{}, trigger_count)}

    Command.changeset(command, params)
  end

  defp command_for_insert(attrs) do
    %Command{triggers: List.duplicate(%Trigger{}, length(Map.get(attrs, "triggers", [])))}
  end

  defp command_attrs(command_params, s3_key) do
    command_params
    |> normalize_command_params()
    |> Map.put("s3_key", s3_key)
  end

  defp normalize_command_params(command_params) do
    command_params
    |> Map.take(["name", "aliases", "media_type", "triggers"])
    |> normalize_aliases()
    |> normalize_triggers()
  end

  defp normalize_aliases(%{"aliases" => aliases} = params) when is_binary(aliases) do
    normalized_aliases =
      aliases
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    Map.put(params, "aliases", normalized_aliases)
  end

  defp normalize_aliases(params), do: params

  defp normalize_triggers(%{"triggers" => triggers} = params) when is_map(triggers) do
    normalized_triggers =
      triggers
      |> Enum.sort_by(fn {index, _attrs} -> String.to_integer(index) end)
      |> Enum.map(fn {_index, attrs} -> attrs end)
      |> Enum.reject(&blank_trigger?/1)

    Map.put(params, "triggers", normalized_triggers)
  end

  defp normalize_triggers(params), do: params

  defp blank_trigger?(attrs) do
    Enum.all?([attrs["name"], attrs["type"]], &blank_value?/1)
  end

  defp blank_value?(value), do: value in [nil, ""]

  defp trigger_form_count(changeset) do
    changeset
    |> Ecto.Changeset.get_field(:triggers, [])
    |> length()
    |> max(1)
  end
end
