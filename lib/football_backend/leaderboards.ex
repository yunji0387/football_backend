defmodule FootballBackend.Leaderboards do
  import Ecto.Query

  alias FootballBackend.Repo
  alias FootballBackend.Football.{PlayerSeasonStat, TeamSeasonStat}

  @providers ["api_football", "football_data"]

  def players(league_id, season, metric, limit) do
    provider = preferred_provider(PlayerSeasonStat, league_id, season)

    rows =
      if provider do
        Repo.all(
          from stat in PlayerSeasonStat,
            join: player in assoc(stat, :player),
            join: team in assoc(stat, :team),
            where: stat.provider == ^provider and stat.league_id == ^league_id and stat.season == ^season,
            where: not is_nil(field(stat, ^metric)),
            order_by: [desc: field(stat, ^metric), asc: player.name, asc: team.name],
            limit: ^limit,
            select: %{
              player_id: player.id,
              name: player.name,
              position: player.position,
              team: %{id: team.id, name: team.name, logo: team.logo},
              value: field(stat, ^metric),
              appearances: stat.appearances,
              minutes: stat.minutes
            }
        )
      else
        []
      end

    %{source: provider, league_id: league_id, season: season, metric: metric, data: rank(rows)}
  end

  def teams(league_id, season, metric, limit) do
    provider = preferred_provider(TeamSeasonStat, league_id, season)

    rows =
      if provider do
        Repo.all(
          from stat in TeamSeasonStat,
            join: team in assoc(stat, :team),
            where: stat.provider == ^provider and stat.league_id == ^league_id and stat.season == ^season,
            where: not is_nil(field(stat, ^metric)),
            order_by: [desc: field(stat, ^metric), asc: team.name],
            limit: ^limit,
            select: %{
              team_id: team.id,
              name: team.name,
              logo: team.logo,
              value: field(stat, ^metric),
              played: stat.played,
              wins: stat.wins,
              draws: stat.draws,
              losses: stat.losses
            }
        )
      else
        []
      end

    %{source: provider, league_id: league_id, season: season, metric: metric, data: rank(rows)}
  end

  defp preferred_provider(schema, league_id, season) do
    Enum.find(@providers, fn provider ->
      Repo.one(from stat in schema,
        where: stat.provider == ^provider and stat.league_id == ^league_id and stat.season == ^season,
        select: count(stat.id)) > 0
    end)
  end

  defp rank(rows) do
    rows
    |> Enum.with_index(1)
    |> Enum.map(fn {row, place} -> Map.put(row, :rank, place) end)
  end
end
