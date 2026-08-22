defmodule BotWorld.Repo.Migrations.CreateMediaGroups do
  use Ecto.Migration

  def up do
    create table(:media_groups) do
      add :name, :string, null: false
      add :legacy_command_id, references(:commands, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:media_groups, [:name])

    create table(:media_group_commands) do
      add :media_group_id, references(:media_groups, on_delete: :delete_all), null: false
      add :command_id, references(:commands, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:media_group_commands, [:media_group_id, :command_id])
    create index(:media_group_commands, [:command_id])

    alter table(:triggers) do
      add :media_group_id, references(:media_groups, on_delete: :restrict)
    end

    create index(:triggers, [:media_group_id])
    flush()

    execute("""
    INSERT INTO media_groups (name, legacy_command_id, inserted_at, updated_at)
    SELECT 'Migrated: ' || commands.name || ' (' || commands.id || ')', commands.id, NOW(), NOW()
    FROM commands
    WHERE EXISTS (SELECT 1 FROM triggers WHERE triggers.command_id = commands.id)
    """)

    execute("""
    INSERT INTO media_group_commands (media_group_id, command_id, inserted_at, updated_at)
    SELECT id, legacy_command_id, NOW(), NOW()
    FROM media_groups
    WHERE legacy_command_id IS NOT NULL
    """)

    execute("""
    UPDATE triggers
    SET media_group_id = media_groups.id
    FROM media_groups
    WHERE media_groups.legacy_command_id = triggers.command_id
    """)

    alter table(:triggers) do
      modify :media_group_id, :bigint, null: false
      remove :command_id
    end

    alter table(:media_groups) do
      remove :legacy_command_id
    end
  end

  def down do
    alter table(:triggers) do
      add :command_id, references(:commands, on_delete: :delete_all)
    end

    flush()

    execute("""
    UPDATE triggers
    SET command_id = memberships.command_id
    FROM (
      SELECT DISTINCT ON (media_group_id) media_group_id, command_id
      FROM media_group_commands
      ORDER BY media_group_id, id
    ) AS memberships
    WHERE memberships.media_group_id = triggers.media_group_id
    """)

    alter table(:triggers) do
      modify :command_id, :bigint, null: false
      remove :media_group_id
    end

    drop table(:media_group_commands)
    drop table(:media_groups)
  end
end
