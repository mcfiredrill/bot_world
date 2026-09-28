defmodule BotWorld.Repo.Migrations.RenameCommandsToMediaItems do
  use Ecto.Migration

  def change do
    rename table(:commands), to: table(:media_items)
  end
end
