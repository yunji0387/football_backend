defmodule FootballBackend.Football.SyncRuns do
  import Ecto.Query
  alias FootballBackend.Repo
  alias FootballBackend.Football.SyncRun
  alias FootballBackend.Football.{PlayerSeasonStat, TeamSeasonStat, Standing, ApiSnapshot}
  alias FootballBackend.Matches.Match
  alias FootballBackend.Teams.Team

  @resource "player_season_stats"

  def start_or_resume(provider, league_id, season) do
    case Repo.one(
           from run in SyncRun,
             where:
               run.provider == ^provider and run.resource == ^@resource and
                 run.league_id == ^league_id and run.season == ^season and
                 run.status in ["running", "failed"],
             order_by: [desc: run.inserted_at],
             limit: 1
         ) do
      %SyncRun{status: "running"} = run ->
        {:ok, run}

      %SyncRun{status: "failed"} = run ->
        run
        |> SyncRun.changeset(%{status: "running", error: nil, completed_at: nil})
        |> Repo.update()

      nil ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        %SyncRun{}
        |> SyncRun.changeset(%{
          provider: provider,
          resource: @resource,
          league_id: league_id,
          season: season,
          status: "running",
          started_at: now
        })
        |> Repo.insert()
    end
  end

  def get!(id), do: Repo.get!(SyncRun, id)

  def checkpoint(%SyncRun{} = run, page, total_pages, fetched, saved) do
    run
    |> SyncRun.changeset(%{
      current_page: page,
      total_pages: total_pages,
      records_fetched: run.records_fetched + fetched,
      records_saved: run.records_saved + saved
    })
    |> Repo.update()
  end

  def complete(%SyncRun{} = run) do
    run
    |> SyncRun.changeset(%{
      status: "completed",
      completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end

  def fail(%SyncRun{} = run, reason) do
    run
    |> SyncRun.changeset(%{
      status: "failed",
      error: reason |> inspect() |> String.slice(0, 500),
      completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end

  def latest(provider, league_id, season) do
    Repo.one(
      from run in SyncRun,
        where:
          run.provider == ^provider and run.resource == ^@resource and
            run.league_id == ^league_id and run.season == ^season,
        order_by: [desc: run.inserted_at],
        limit: 1
    )
  end

  def coverage(league_id, season) do
    players =
      Repo.all(
        from stat in PlayerSeasonStat,
          where: stat.league_id == ^league_id and stat.season == ^season,
          group_by: stat.provider,
          select: %{
            provider: stat.provider,
            rows: count(stat.id),
            distinct_players: count(stat.player_id, :distinct)
          }
      )

    teams =
      Repo.all(
        from stat in TeamSeasonStat,
          where: stat.league_id == ^league_id and stat.season == ^season,
          group_by: stat.provider,
          select: %{provider: stat.provider, rows: count(stat.id)}
      )

    run = latest("api_football", league_id, season)

    distinct_players =
      Repo.one(
        from stat in PlayerSeasonStat,
          where: stat.league_id == ^league_id and stat.season == ^season,
          select: count(stat.player_id, :distinct)
      )

    %{
      league_id: league_id,
      season: season,
      canonical_teams_total: Repo.aggregate(Team, :count, :id),
      matches_in_scope:
        Repo.aggregate(
          from(match in Match, where: match.league_id == ^league_id and match.season == ^season),
          :count,
          :id
        ),
      standings_in_scope:
        Repo.aggregate(
          from(standing in Standing,
            where: standing.league_id == ^league_id and standing.season == ^season
          ),
          :count,
          :id
        ),
      snapshots_in_scope:
        Repo.aggregate(
          from(snapshot in ApiSnapshot,
            where: snapshot.league_id == ^league_id and snapshot.season == ^season
          ),
          :count,
          :id
        ),
      player_season_stats: %{
        table_total_rows: Repo.aggregate(PlayerSeasonStat, :count, :id),
        scope_rows: Enum.sum(Enum.map(players, & &1.rows)),
        scope_distinct_players: distinct_players,
        providers: players
      },
      team_season_stats: %{
        table_total_rows: Repo.aggregate(TeamSeasonStat, :count, :id),
        scope_rows: Enum.sum(Enum.map(teams, & &1.rows)),
        providers: teams
      },
      player_sync: serialize_run(run)
    }
  end

  defp serialize_run(nil), do: nil

  defp serialize_run(run) do
    Map.take(run, [
      :provider,
      :resource,
      :status,
      :current_page,
      :total_pages,
      :records_fetched,
      :records_saved,
      :error,
      :started_at,
      :completed_at,
      :updated_at
    ])
  end
end
