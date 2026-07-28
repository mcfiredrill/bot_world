defmodule BotWorld.Repo.Migrations.AddRewardMatchFieldsToTriggers do
  use Ecto.Migration

  def change do
    alter table(:triggers) do
      add :reward_name, :string
      add :bits_amount, :integer
    end
  end
end
