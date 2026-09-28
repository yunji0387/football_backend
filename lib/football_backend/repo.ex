defmodule FootballBackend.Repo do
  use Ecto.Repo,
    otp_app: :football_backend,
    adapter: Ecto.Adapters.Postgres
end
