defmodule BotWorldWeb.UserRegistrationController do
  use BotWorldWeb, :controller

  def new(conn, _params) do
    redirect(conn, to: ~p"/users/log_in")
  end
end
