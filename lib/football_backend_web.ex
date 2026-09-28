defmodule FootballBackendWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such as controllers and views.
  """

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:json],
        layouts: []

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def json do
    quote do
      import Phoenix.Controller, only: [json: 2]
    end
  end

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: FootballBackendWeb.Endpoint,
        router: FootballBackendWeb.Router,
        statics: FootballBackendWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/router/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  def static_paths, do: ~w()
end
