defmodule BotWorldWeb.CommandsController do
  use BotWorldWeb, :controller
  alias BotWorld.{Command, Repo}

  def index(conn, _params) do
    changeset = Command.changeset(%Command{}, %{})
    commands  = Repo.all(Command)
    render(conn, :index, changeset: changeset, commands: commands)
  end

  def show(conn, %{"command" => command}) do
    render(conn, :show, command: command)
  end

  def create(conn, %{"command" => command_params}) do
    # extract file upload from the params (supports both audio and video)
    %Plug.Upload{filename: filename, path: temp_path, content_type: content_type} =
      command_params["media_file"]

    media_type = command_params["media_type"] || "audio"
    prefix = if media_type == "video", do: "video", else: "sfx"

    # generate a unique S3 key
    s3_key = "#{prefix}/#{UUID.uuid4()}_#{filename}"

    # upload the file to S3
    case BotWorld.S3.upload_file(temp_path, s3_key, content_type) do
      {:ok, %{body: %{key: returned_key}}} ->
        # save the command with the s3_key
        changeset = Command.changeset(%Command{}, %{
          "name" => command_params["name"],
          "s3_key" => returned_key,
          "media_type" => media_type
        })

        case Repo.insert(changeset) do
          {:ok, _command} ->
            conn
            |> put_flash(:info, "Command created successfully.")
            |> redirect(to: ~p"/commands")

          {:error, changeset} ->
            render(conn, :index, changeset: changeset, commands: Repo.all(Command))
        end

      {:error, reason} ->
        changeset = Command.changeset(%Command{}, command_params)

        conn
        |> put_flash(:error, "Failed to upload file: #{inspect(reason)}")
        |> render(:index, changeset: changeset, commands: Repo.all(Command))
    end
  end
end
