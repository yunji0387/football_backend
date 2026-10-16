defmodule FootballBackendWeb.RoundController do
  use FootballBackendWeb, :controller

  def index(conn, params) do
    league_id = parse_positive_integer(params["league_id"], FootballBackend.Football.configured_league_id())
    season = parse_positive_integer(params["season"], FootballBackend.Football.current_season())
    rounds = FootballBackend.Football.rounds(league_id, season)
    if rounds == [], do: FootballBackend.Football.SyncWorker.request_sync(league_id, season)
    json(conn, %{data: rounds, league_id: league_id, season: season})
  end

  defp parse_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> integer
      _ -> default
    end
  end

  defp parse_positive_integer(_, default), do: default
end
