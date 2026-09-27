defmodule BotWorld.Repo.Migrations.AllowTwitchOnlyUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :email, :citext, null: true, from: {:citext, null: false}
      modify :hashed_password, :string, null: true, from: {:string, null: false}
    end
  end
end
