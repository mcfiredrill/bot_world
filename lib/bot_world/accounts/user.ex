defmodule BotWorld.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    has_many :media_items, BotWorld.MediaItem
    has_many :media_groups, BotWorld.MediaGroup
    has_many :triggers, BotWorld.Trigger
    has_one :twitch_credential, BotWorld.Twitch.Credential

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a user changeset for an account whose identity is supplied by Twitch.

  The associated Twitch credential is created in the same transaction by the
  Twitch context, so this local tenant record does not need an email or
  password.
  """
  def twitch_registration_changeset(user) do
    change(user)
  end
end
