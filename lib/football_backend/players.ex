defmodule FootballBackend.Players do
  @moduledoc """
  The Players context.
  """

  import Ecto.Query, warn: false
  alias FootballBackend.{Repo, Teams.Team}
  alias FootballBackend.Players.Player
  alias FootballBackend.Football.{PlayerSeasonStat, ProviderMappings}

  def list_players do
    Repo.all(Player)
  end

  def top_scorers(league_id, season) do
    providers = ["api_football", "football_data"]

    provider =
      Enum.find(providers, fn source ->
        Repo.one(
          from stat in PlayerSeasonStat,
            where: stat.provider == ^source and stat.league_id == ^league_id and stat.season == ^season,
            select: count(stat.id)
        ) > 0
      end)

    rows =
      if provider do
        Repo.all(
          from stat in PlayerSeasonStat,
            join: player in assoc(stat, :player),
            join: team in assoc(stat, :team),
            where: stat.provider == ^provider and stat.league_id == ^league_id and stat.season == ^season,
            order_by: [desc: stat.goals, desc_nulls_last: stat.assists, asc: player.name],
            select: %{
              player_id: player.id,
              name: player.name,
              position: player.position,
              jersey_number: player.jersey_number,
              team: %{id: team.id, name: team.name, logo: team.logo},
              appearances: stat.appearances,
              lineups: stat.lineups,
              minutes: stat.minutes,
              goals: stat.goals,
              assists: stat.assists,
              penalties: stat.penalties,
              shots: stat.shots,
              shots_on_target: stat.shots_on_target,
              clean_sheets: stat.clean_sheets,
              passes: stat.passes,
              key_passes: stat.key_passes,
              yellow_cards: stat.yellow_cards,
              red_cards: stat.red_cards,
              rating: stat.rating,
              fetched_at: stat.fetched_at
            }
        )
      else
        []
      end

    %{source: provider, league_id: league_id, season: season, data: rows}
  end

  def import_provider_season_stats(provider, league_id, season, rows) do
    fetched_at = DateTime.utc_now() |> DateTime.truncate(:second)

    result =
      Enum.reduce_while(rows, :ok, fn row, :ok ->
        team_data = row.team

        with team_external_id when is_integer(team_external_id) <- team_data.external_id,
             player_external_id when is_integer(player_external_id) <- row.external_id,
             {:ok, team} <- provider_team(provider, team_external_id, team_data),
             {:ok, player} <- ProviderMappings.upsert_player(provider, player_external_id, Map.merge(row.player, %{team_id: team.id})) do
          attrs = Map.merge(row.statistics, %{
            provider: provider,
            league_id: league_id,
            season: season,
            player_id: player.id,
            team_id: team.id,
            provider_data: row.provider_data,
            fetched_at: fetched_at
          })

          case Repo.insert(PlayerSeasonStat.changeset(%PlayerSeasonStat{}, attrs),
                 on_conflict: {:replace, Map.keys(attrs) -- [:provider, :league_id, :season, :player_id, :team_id] ++ [:updated_at]},
                 conflict_target: [:provider, :league_id, :season, :player_id, :team_id]) do
            {:ok, _stat} -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        else
          _ -> {:halt, {:error, {:invalid_provider_scorer, provider, row}}}
        end
      end)

    case result do
      :ok ->
        Repo.delete_all(
          from stat in PlayerSeasonStat,
            where: stat.provider == ^provider and stat.league_id == ^league_id and stat.season == ^season,
            where: stat.fetched_at < ^fetched_at
        )

        :ok

      error -> error
    end
  rescue
    error -> {:error, {:provider_scorer_persistence, Exception.message(error)}}
  end

  defp provider_team(provider, external_id, team_data) do
    case ProviderMappings.get_team_id(provider, external_id) do
      nil ->
        ProviderMappings.upsert_team(provider, external_id, %{
          name: team_data.name,
          country: team_data[:country] || "Unknown",
          logo: team_data[:logo]
        })

      team_id ->
        case Repo.get(Team, team_id) do
          %Team{} = team -> {:ok, team}
          nil -> {:error, {:provider_team_not_found, provider, external_id}}
        end
    end
  end

  def get_player!(id), do: Repo.get!(Player, id)

  def create_player(attrs \\ %{}) do
    %Player{}
    |> Player.changeset(attrs)
    |> Repo.insert()
  end

  def update_player(%Player{} = player, attrs) do
    player
    |> Player.changeset(attrs)
    |> Repo.update()
  end

  def delete_player(%Player{} = player) do
    Repo.delete(player)
  end

  def change_player(%Player{} = player, attrs \\ %{}) do
    Player.changeset(player, attrs)
  end
end
