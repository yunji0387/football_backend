import Config

season_override =
  case System.get_env("FOOTBALL_SEASON") do
    nil ->
      nil

    value ->
      case Integer.parse(value) do
        {season, ""} when season > 0 -> season
        _ -> nil
      end
  end

config :football_backend, FootballBackend.Football,
  api_key: System.get_env("API_SPORT_FOOTBALL_API_KEY"),
  football_data_token: System.get_env("FOOTBALL_DATA_TOKEN"),
  telegram_bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
  telegram_chat_id: System.get_env("TELEGRAM_CHAT_ID"),
  football_competition: System.get_env("FOOTBALL_COMPETITION", "PL"),
  season_override: season_override

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :football_backend, FootballBackend.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: [:inet6]

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :football_backend, FootballBackendWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base
end
