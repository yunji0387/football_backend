defmodule FootballBackendWeb.LeaderboardController do
  use FootballBackendWeb, :controller

  alias FootballBackend.Leaderboards

  @player_metrics ~w(goals assists clean_sheets passes key_passes)
  @team_metrics ~w(played wins draws losses goals_for goals_against clean_sheets passes key_passes)
  @max_limit 100

  def players(conn, params), do: index(conn, params, :players, @player_metrics)
  def teams(conn, params), do: index(conn, params, :teams, @team_metrics)

  defp index(conn, params, board, metrics) do
    with {:ok, metric} <- parse_metric(params["metric"], metrics),
         {:ok, league_id} <-
           parse_positive_integer(
             params["league_id"],
             FootballBackend.Football.configured_league_id()
           ),
         {:ok, season} <-
           parse_positive_integer(params["season"], FootballBackend.Football.current_season()),
         {:ok, limit} <- parse_limit(params["limit"]) do
      result =
        case board do
          :players -> Leaderboards.players(league_id, season, String.to_atom(metric), limit)
          :teams -> Leaderboards.teams(league_id, season, String.to_atom(metric), limit)
        end

      if is_nil(result.source),
        do: FootballBackend.Football.SyncWorker.request_sync(league_id, season)

      json(conn, result)
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "metric, league_id, season, or limit is invalid"})
    end
  end

  defp parse_metric(value, metrics) when is_binary(value) do
    if value in metrics, do: {:ok, value}, else: :error
  end

  defp parse_metric(_, _metrics), do: :error

  defp parse_positive_integer(nil, default), do: {:ok, default}

  defp parse_positive_integer(value, _default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> {:ok, integer}
      _ -> :error
    end
  end

  defp parse_positive_integer(_, _default), do: :error

  defp parse_limit(nil), do: {:ok, 20}

  defp parse_limit(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 and integer <= @max_limit -> {:ok, integer}
      _ -> :error
    end
  end

  defp parse_limit(_), do: :error
end
