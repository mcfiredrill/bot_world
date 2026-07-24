defmodule BotWorld.Repo.Migrations.CreateTwitchCredentials do
  use Ecto.Migration

  def change do
    create table(:twitch_credentials) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :twitch_user_id, :string, null: false
      add :twitch_login, :string, null: false
      add :access_token, :string, null: false
      add :refresh_token, :string, null: false
      add :scopes, {:array, :string}, null: false, default: []
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:twitch_credentials, [:user_id])
    create unique_index(:twitch_credentials, [:twitch_user_id])
  end
end
