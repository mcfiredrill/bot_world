defmodule BotWorld.Repo.Migrations.AddMediaTypeToCommands do
  use Ecto.Migration

  def change do
    alter table(:commands) do
      add :media_type, :string, default: "audio"
    end
  end
end
