defmodule BotWorld.Repo.Migrations.RemovePasswordAuthentication do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :email, :citext
      remove :hashed_password, :string
      remove :confirmed_at, :utc_datetime
    end
  end
end
