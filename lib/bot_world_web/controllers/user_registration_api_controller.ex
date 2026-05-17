defmodule BotWorldWeb.UserRegistrationAPIController do
  use BotWorldWeb, :controller

  alias BotWorld.Accounts
  alias BotWorld.Accounts.User
  alias BotWorldWeb.{ChangesetJSON, UserAuth}

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> UserAuth.log_in_user_session(user)
        |> put_status(:created)
        |> render(:show, user: user)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(ChangesetJSON.errors(changeset))
    end
  end

  def create(conn, _params) do
    changeset = Accounts.change_user_registration(%User{}, %{})

    conn
    |> put_status(:unprocessable_entity)
    |> json(ChangesetJSON.errors(changeset))
  end
end
