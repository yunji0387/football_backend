defmodule FootballBackendWeb.MatchJSON do
  alias FootballBackend.Matches.Match

  def index(%{matches: matches}) do
    %{data: for(match <- matches, do: data(match))}
  end

  def show(%{match: match}) do
    %{data: data(match)}
  end

  defp data(%Match{} = match) do
    %{
      id: match.id,
      home_team_id: match.home_team_id,
      away_team_id: match.away_team_id,
      home_score: match.home_score,
      away_score: match.away_score,
      played_at: match.played_at,
      api_football_id: match.api_football_id,
      league_id: match.league_id,
      season: match.season,
      status: match.status,
      elapsed: match.elapsed,
      round: match.round
    }
  end
end
