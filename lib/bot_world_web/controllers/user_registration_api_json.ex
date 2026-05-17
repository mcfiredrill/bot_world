defmodule BotWorldWeb.UserRegistrationAPIJSON do
  def show(%{user: user}) do
    %{user: BotWorldWeb.UserJSON.data(user)}
  end
end
