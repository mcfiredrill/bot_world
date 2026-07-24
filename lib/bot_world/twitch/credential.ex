defmodule BotWorld.Twitch.Credential do
  use Ecto.Schema
  import Ecto.Changeset

  schema "twitch_credentials" do
    field :twitch_user_id, :string
    field :twitch_login, :string
    field :access_token, :string, redact: true
    field :refresh_token, :string, redact: true
    field :scopes, {:array, :string}, default: []
    field :expires_at, :utc_datetime

    belongs_to :user, BotWorld.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [
      :user_id,
      :twitch_user_id,
      :twitch_login,
      :access_token,
      :refresh_token,
      :scopes,
      :expires_at
    ])
    |> validate_required([
      :user_id,
      :twitch_user_id,
      :twitch_login,
      :access_token,
      :refresh_token,
      :scopes,
      :expires_at
    ])
    |> unique_constraint(:user_id)
    |> unique_constraint(:twitch_user_id)
  end
end
