defmodule FootballBackendWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :football_backend

  @session_options [
    store: :cookie,
    key: "_football_backend_key",
    signing_salt: "f00tba11",
    same_site: "Lax"
  ]

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  plug CORSPlug

  plug FootballBackendWeb.Router
end
