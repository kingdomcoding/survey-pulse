defmodule SurveyPulseWeb.Router do
  use SurveyPulseWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SurveyPulseWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SurveyPulseWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/surveys/new", SurveyFormLive, :new
    get "/surveys/:id/export", ExportController, :export
    live "/surveys/:id", SurveyLive, :show
  end

  scope "/api", SurveyPulseWeb.Api do
    pipe_through :api

    post "/ingest", IngestController, :create
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:survey_pulse, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SurveyPulseWeb.Telemetry
    end
  end
end
