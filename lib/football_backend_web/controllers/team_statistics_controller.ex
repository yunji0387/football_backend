defmodule FootballBackendWeb.TeamStatisticsController do
  use FootballBackendWeb, :controller

  def show(conn, %{"id" => id} = params) do
    with {team_id, ""} when team_id > 0 <- Integer.parse(id) do
      league_id = parse_positive_integer(params["league_id"], FootballBackend.Football.configured_league_id())
      season = parse_positive_integer(params["season"], FootballBackend.Football.current_season())

      case FootballBackend.Football.team_statistics(team_id, league_id, season) do
        nil -> conn |> put_status(:not_found) |> json(%{error: "Team statistics are not available for this team and season"})
        statistics -> json(conn, %{data: statistics, league_id: league_id, season: season})
      end
    else
      _ -> conn |> put_status(:bad_request) |> json(%{error: "Invalid team id"})
    end
  end

  defp parse_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> integer
      _ -> default
    end
  end

  defp parse_positive_integer(_, default), do: default
end
