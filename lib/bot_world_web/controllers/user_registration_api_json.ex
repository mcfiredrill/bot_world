defmodule BotWorldWeb.UserRegistrationAPIJSON do
  def show(%{user: user, token: token}) do
    %{user: BotWorldWeb.UserJSON.data(user), token: token}
  end
end
