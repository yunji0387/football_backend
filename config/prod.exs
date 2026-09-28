import Config

config :football_backend, FootballBackendWeb.Endpoint, cache_static_manifest: nil

config :logger, level: :info

config :phoenix, :plug_init_mode, :runtime
