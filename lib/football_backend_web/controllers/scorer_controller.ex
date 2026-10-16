defmodule FootballBackendWeb.ScorerController do
  use FootballBackendWeb, :controller

  alias FootballBackend.Players

  def index(conn, params) do
    with {:ok, league_id} <-
           parse_positive_integer(
             params["league_id"],
             FootballBackend.Football.configured_league_id()
           ),
         {:ok, season} <-
           parse_positive_integer(params["season"], FootballBackend.Football.current_season()) do
      result = Players.top_scorers(league_id, season)

      if is_nil(result.source),
        do: FootballBackend.Football.SyncWorker.request_sync(league_id, season)

      json(conn, result)
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "league_id and season must be positive integers"})
    end
  end

  defp parse_positive_integer(nil, default), do: {:ok, default}

  defp parse_positive_integer(value, _default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> {:ok, integer}
      _ -> :error
    end
  end

  defp parse_positive_integer(_, _default), do: :error
end
