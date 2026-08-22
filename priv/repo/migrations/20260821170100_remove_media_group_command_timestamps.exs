defmodule BotWorld.Repo.Migrations.RemoveMediaGroupCommandTimestamps do
  use Ecto.Migration

  def change do
    alter table(:media_group_commands) do
      remove :inserted_at, :utc_datetime
      remove :updated_at, :utc_datetime
    end
  end
end
