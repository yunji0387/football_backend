defmodule FootballBackendWeb.Router do
  use FootballBackendWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", FootballBackendWeb do
    pipe_through :api

    get "/health", HealthController, :index
    get "/standings", StandingController, :index

    resources "/teams", TeamController, except: [:new, :edit]
    resources "/players", PlayerController, except: [:new, :edit]
    resources "/matches", MatchController, except: [:new, :edit]
  end
end
