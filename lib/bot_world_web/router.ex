defmodule BotWorldWeb.Router do
  use BotWorldWeb, :router

  import BotWorldWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BotWorldWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :browser_auth do
    plug :accepts, ["html", "json"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BotWorldWeb.Layouts, :root}
    plug BotWorldWeb.Plugs.ProtectFromForgeryForHtml
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_session do
    plug :fetch_session
    plug :fetch_current_user
  end

  scope "/", BotWorldWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  ## Authentication routes

  scope "/", BotWorldWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
  end

  scope "/", BotWorldWeb do
    pipe_through [:browser_auth, :redirect_if_user_is_authenticated]

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", BotWorldWeb do
    pipe_through [:browser_auth, :require_authenticated_user]

    get "/commands", CommandsController, :index
  end

  scope "/", BotWorldWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/commands/:command", CommandsController, :show
    post "/commands", CommandsController, :create

    resources "/triggers", TriggersController
  end

  scope "/", BotWorldWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
  end

  # Other scopes may use custom stacks.
  scope "/api", BotWorldWeb do
    pipe_through :api

    get "/commands", CommandsController, :index
  end

  scope "/api", BotWorldWeb do
    pipe_through [:api, :api_session, :redirect_if_user_is_authenticated_api]

    post "/users/register", UserRegistrationAPIController, :create
    post "/users/log_in", UserSessionAPIController, :create
  end

  scope "/api", BotWorldWeb do
    pipe_through [:api, :api_session]

    delete "/users/log_out", UserSessionAPIController, :delete
  end

  scope "/api", BotWorldWeb do
    pipe_through [:api, :api_session, :require_authenticated_api_user]

    resources "/triggers", TriggersAPIController, except: [:new, :edit]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:bot_world, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BotWorldWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
