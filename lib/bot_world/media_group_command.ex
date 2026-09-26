defmodule BotWorld.MediaGroupCommand do
  use Ecto.Schema

  @primary_key false
  schema "media_group_commands" do
    belongs_to :user, BotWorld.Accounts.User
    belongs_to :media_group, BotWorld.MediaGroup
    belongs_to :command, BotWorld.Command
  end
end
