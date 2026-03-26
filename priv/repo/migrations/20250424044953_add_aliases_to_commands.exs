defmodule BotWorld.Repo.Migrations.AddAliasesToCommands do
  use Ecto.Migration

  def change do
    alter table(:commands) do
      add :aliases, {:array, :string}, null: false, default: []
    end
  end
end
