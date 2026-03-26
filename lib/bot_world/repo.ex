defmodule BotWorld.Repo do
  use Ecto.Repo,
    otp_app: :bot_world,
    adapter: Ecto.Adapters.Postgres
end
