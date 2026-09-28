defmodule BotWorld.Repo.Migrations.RenameMediaGroupCommandsToItems do
  use Ecto.Migration

  def up do
    rename table(:media_group_commands), to: table(:media_group_items)
    rename table(:media_group_items), :command_id, to: :media_item_id

    rename_index(:commands_user_id_index, :media_items_user_id_index)
    rename_index(:commands_id_user_id_index, :media_items_id_user_id_index)
    rename_index(:media_group_commands_user_id_index, :media_group_items_user_id_index)

    rename_index(
      :media_group_commands_media_group_id_command_id_index,
      :media_group_items_media_group_id_media_item_id_index
    )

    rename_index(:media_group_commands_command_id_index, :media_group_items_media_item_id_index)

    rename_constraint(
      :media_group_items,
      :media_group_commands_group_tenant_fkey,
      :media_group_items_group_tenant_fkey
    )

    rename_constraint(
      :media_group_items,
      :media_group_commands_command_tenant_fkey,
      :media_group_items_media_item_tenant_fkey
    )
  end

  def down do
    rename_constraint(
      :media_group_items,
      :media_group_items_media_item_tenant_fkey,
      :media_group_commands_command_tenant_fkey
    )

    rename_constraint(
      :media_group_items,
      :media_group_items_group_tenant_fkey,
      :media_group_commands_group_tenant_fkey
    )

    rename_index(:media_group_items_media_item_id_index, :media_group_commands_command_id_index)

    rename_index(
      :media_group_items_media_group_id_media_item_id_index,
      :media_group_commands_media_group_id_command_id_index
    )

    rename_index(:media_group_items_user_id_index, :media_group_commands_user_id_index)
    rename_index(:media_items_id_user_id_index, :commands_id_user_id_index)
    rename_index(:media_items_user_id_index, :commands_user_id_index)

    rename table(:media_group_items), :media_item_id, to: :command_id
    rename table(:media_group_items), to: table(:media_group_commands)
  end

  defp rename_index(old_name, new_name) do
    execute("ALTER INDEX #{old_name} RENAME TO #{new_name}")
  end

  defp rename_constraint(table, old_name, new_name) do
    execute("ALTER TABLE #{table} RENAME CONSTRAINT #{old_name} TO #{new_name}")
  end
end
