defmodule BotWorld.Repo.Migrations.AddTenantOwnership do
  use Ecto.Migration

  def up do
    alter table(:commands) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end

    alter table(:media_groups) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end

    alter table(:triggers) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end

    alter table(:media_group_commands) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end

    drop_if_exists unique_index(:media_groups, [:name])

    create index(:commands, [:user_id])
    create index(:media_groups, [:user_id])
    create index(:triggers, [:user_id])
    create index(:media_group_commands, [:user_id])
    create unique_index(:media_groups, [:user_id, :name])

    # PostgreSQL requires a unique key matching the columns targeted by a
    # composite foreign key. These also make tenant-scoped joins efficient.
    create unique_index(:commands, [:id, :user_id])
    create unique_index(:media_groups, [:id, :user_id])

    execute("""
    ALTER TABLE triggers
    ADD CONSTRAINT triggers_media_group_tenant_fkey
    FOREIGN KEY (media_group_id, user_id)
    REFERENCES media_groups (id, user_id)
    ON DELETE RESTRICT
    """)

    execute("""
    ALTER TABLE media_group_commands
    ADD CONSTRAINT media_group_commands_group_tenant_fkey
    FOREIGN KEY (media_group_id, user_id)
    REFERENCES media_groups (id, user_id)
    ON DELETE CASCADE
    """)

    execute("""
    ALTER TABLE media_group_commands
    ADD CONSTRAINT media_group_commands_command_tenant_fkey
    FOREIGN KEY (command_id, user_id)
    REFERENCES commands (id, user_id)
    ON DELETE CASCADE
    """)
  end

  def down do
    execute(
      "ALTER TABLE media_group_commands DROP CONSTRAINT media_group_commands_command_tenant_fkey"
    )

    execute(
      "ALTER TABLE media_group_commands DROP CONSTRAINT media_group_commands_group_tenant_fkey"
    )

    execute("ALTER TABLE triggers DROP CONSTRAINT triggers_media_group_tenant_fkey")

    drop_if_exists unique_index(:media_groups, [:user_id, :name])
    drop_if_exists unique_index(:media_groups, [:id, :user_id])
    drop_if_exists unique_index(:commands, [:id, :user_id])

    alter table(:media_group_commands) do
      remove :user_id
    end

    alter table(:triggers) do
      remove :user_id
    end

    alter table(:media_groups) do
      remove :user_id
    end

    alter table(:commands) do
      remove :user_id
    end

    create unique_index(:media_groups, [:name])
  end
end
