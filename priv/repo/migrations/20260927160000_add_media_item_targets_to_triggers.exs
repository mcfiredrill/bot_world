defmodule BotWorld.Repo.Migrations.AddMediaItemTargetsToTriggers do
  use Ecto.Migration

  def up do
    alter table(:triggers) do
      modify :media_group_id, :bigint, null: true
      add :media_item_id, references(:media_items, on_delete: :restrict)
    end

    create index(:triggers, [:media_item_id])

    execute("""
    ALTER TABLE triggers
    ADD CONSTRAINT triggers_media_item_tenant_fkey
    FOREIGN KEY (media_item_id, user_id)
    REFERENCES media_items (id, user_id)
    ON DELETE RESTRICT
    """)

    create constraint(:triggers, :triggers_exactly_one_target,
             check: "num_nonnulls(media_group_id, media_item_id) = 1"
           )
  end

  def down do
    drop constraint(:triggers, :triggers_exactly_one_target)
    execute("ALTER TABLE triggers DROP CONSTRAINT triggers_media_item_tenant_fkey")
    drop index(:triggers, [:media_item_id])

    alter table(:triggers) do
      remove :media_item_id
      modify :media_group_id, :bigint, null: false
    end
  end
end
