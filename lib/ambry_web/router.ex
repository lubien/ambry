defmodule AmbryWeb.Router do
  @moduledoc false

  use AmbryWeb, :router

  import AmbrySchema.PlugHelpers
  import AmbryWeb.UserAuth

  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {AmbryWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug AmbryWeb.Plugs.FirstTimeSetup
  end

  pipeline :uploads do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_current_user
    plug :fetch_api_user
    plug :require_any_authenticated_user

    # Serve static user uploads
    plug Plug.Static,
      at: "/uploads",
      from: {Ambry.Paths, :uploads_folder_disk_path, []},
      gzip: false,
      only: ~w(media)
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_api_user
  end

  pipeline :gql do
    plug :accepts, ["json", "graphql"]
    plug :fetch_api_user
    plug :put_absinthe_context
  end

  pipeline :admin do
    plug :put_root_layout, {AmbryWeb.LayoutView, "admin_root.html"}
  end

  scope "/uploads", AmbryWeb do
    pipe_through :uploads

    get "/*path", FallbackController, :index
  end

  scope "/", AmbryWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :user,
      on_mount: [
        {AmbryWeb.UserLiveAuth, :ensure_mounted_current_user},
        AmbryWeb.NavHooks,
        AmbryWeb.PlayerStateHooks
      ] do
      live "/", NowPlayingLive.Index, :index
      live "/library", LibraryLive.Home, :home
      live "/people/:id", PersonLive.Show, :show
      live "/series/:id", SeriesLive.Show, :show
      live "/books/:id", BookLive.Show, :show
      live "/search/:query", SearchLive.Results, :results
    end
  end

  scope "/admin", AmbryWeb.Admin, as: :admin do
    pipe_through [:browser, :require_authenticated_user, :require_admin, :admin]

    live_session :admin,
      on_mount: [
        {AmbryWeb.UserLiveAuth, :ensure_mounted_current_user},
        {AmbryWeb.Admin.Auth, :ensure_mounted_admin_user},
        AmbryWeb.Admin.NavHooks
      ] do
      live "/", HomeLive.Index, :index

      live "/people", PersonLive.Index, :index
      live "/people/new", PersonLive.Index, :new
      live "/people/:id/edit", PersonLive.Index, :edit

      live "/books", BookLive.Index, :index
      live "/books/new", BookLive.Index, :new
      live "/books/:id/edit", BookLive.Index, :edit

      live "/series", SeriesLive.Index, :index
      live "/series/new", SeriesLive.Index, :new
      live "/series/:id/edit", SeriesLive.Index, :edit

      live "/media", MediaLive.Index, :index
      live "/media/new", MediaLive.Index, :new
      live "/media/:id/edit", MediaLive.Index, :edit
      live "/media/:id/chapters", MediaLive.Index, :chapters

      live "/users", UserLive.Index, :index

      live "/audit", AuditLive.Index, :index
    end

    live_dashboard "/dashboard", metrics: AmbryWeb.Telemetry
  end

  scope "/api", AmbryWeb.API, as: :api do
    pipe_through [:api]

    post "/log_in", SessionController, :create
  end

  scope "/api", AmbryWeb.API, as: :api do
    pipe_through [:api, :require_authenticated_api_user]

    delete "/log_out", SessionController, :delete

    resources "/books", BookController, only: [:index, :show]
    resources "/people", PersonController, only: [:show]
    resources "/series", SeriesController, only: [:show]
    resources "/player_states", PlayerStateController, only: [:index, :show, :update]
    resources "/bookmarks", BookmarkController, only: [:create, :update, :delete]
    get "/bookmarks/:media_id", BookmarkController, :index
  end

  scope "/gql" do
    pipe_through [:gql]

    forward "/", Absinthe.Plug.GraphiQL, schema: AmbrySchema, interface: :playground
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
      forward "/voyager", AmbryWeb.Plugs.Voyager
    end
  end

  ## Authentication routes

  scope "/", AmbryWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", AmbryWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
  end

  scope "/", AmbryWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update
  end

  scope "/first_time_setup", AmbryWeb.FirstTimeSetup, as: :first_time_setup do
    pipe_through :browser

    live "/", SetupLive.Index, :index
  end
end
