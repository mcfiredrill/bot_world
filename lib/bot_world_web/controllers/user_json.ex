defmodule BotWorldWeb.UserJSON do
  def data(user) do
    %{
      id: user.id,
      email: user.email,
      confirmed_at: user.confirmed_at,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end
end
