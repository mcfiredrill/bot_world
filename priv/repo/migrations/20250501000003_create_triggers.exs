defmodule BotWorld.Repo.Migrations.CreateTriggers do
  use Ecto.Migration

  def change do
    create table(:triggers) do
      add :name, :string, null: false
      add :type, :string, null: false
      add :command_id, references(:commands, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:triggers, [:command_id])
    create index(:triggers, [:type])
  end
end
