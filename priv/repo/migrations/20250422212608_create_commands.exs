defmodule BotWorld.Repo.Migrations.CreateCommands do
  use Ecto.Migration

  def change do
    create table(:commands) do
      add :name, :string
      add :s3_key, :string

      timestamps(type: :utc_datetime)
    end
  end
end
