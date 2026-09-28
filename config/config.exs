import Config

config :football_backend,
  ecto_repos: [FootballBackend.Repo],
  generators: [timestamp_type: :utc_datetime]

config :football_backend, FootballBackendWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: FootballBackendWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: FootballBackend.PubSub

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :football_backend, FootballBackend.Football,
  api_key: System.get_env("API_SPORT_FOOTBALL_API_KEY"),
  league_id: 39,
  season_override: nil,
  sync_interval_ms: 6 * 60 * 60 * 1_000,
  enabled: true

import_config "#{config_env()}.exs"
