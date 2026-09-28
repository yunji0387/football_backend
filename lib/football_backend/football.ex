defmodule FootballBackend.Football do
  @moduledoc "Syncs league-wide football data from API-Football into the local database."
  import Ecto.Query
  require Logger

  alias FootballBackend.{Repo, Teams.Team}
  alias FootballBackend.Football.Standing
  alias FootballBackend.Matches.Match

  @base_url ~c"https://v3.football.api-sports.io"

  def current_season(date \\ Date.utc_today()) do
    case Keyword.get(Application.get_env(:football_backend, __MODULE__, []), :season_override) do
      season when is_integer(season) -> season
      _ -> if date.month >= 8, do: date.year, else: date.year - 1
    end
  end

  def standings(league_id \\ configured_league_id(), season \\ current_season()) do
    Repo.all(
      from s in Standing,
        join: t in assoc(s, :team),
        where: s.league_id == ^league_id and s.season == ^season,
        order_by: s.rank,
        select: %{rank: s.rank, team: t.name, logo: t.logo, played: s.played,
          win: s.win, draw: s.draw, lose: s.lose, goals_for: s.goals_for,
          goals_against: s.goals_against, goals_diff: s.goals_diff,
          points: s.points, form: s.form}
    )
  end

  def sync do
    with key when is_binary(key) and key != "" <- api_key(),
         league_id <- configured_league_id(),
         season <- current_season(),
         {:ok, teams} <- fetch_all("teams", league: league_id, season: season),
         :ok <- save_teams(teams),
         {:ok, fixtures} <- fetch_all("fixtures", league: league_id, season: season),
         :ok <- save_fixtures(fixtures, league_id, season),
         {:ok, tables} <- fetch_all("standings", league: league_id, season: season),
         :ok <- save_standings(tables, league_id, season) do
      Logger.info("API-Football sync completed for league #{league_id}, season #{season}")
      :ok
    else
      nil -> {:error, :api_key_not_configured}
      "" -> {:error, :api_key_not_configured}
      {:error, reason} = error ->
        Logger.warning("API-Football sync failed: #{inspect(reason)}")
        error
    end
  end

  def configured_league_id do
    Application.get_env(:football_backend, __MODULE__, []) |> Keyword.get(:league_id, 39)
  end

  defp api_key, do: Application.get_env(:football_backend, __MODULE__, []) |> Keyword.get(:api_key)

  defp fetch_all(endpoint, params, page \\ 1, acc \\ []) do
    query_params = Map.new(params)
    query_params = if page > 1, do: Map.put(query_params, :page, page), else: query_params
    query = URI.encode_query(query_params)
    url = @base_url ++ ~c"/" ++ String.to_charlist(endpoint <> "?" <> query)
    headers = [{~c"x-apisports-key", String.to_charlist(api_key())}]

    case :httpc.request(:get, {url, headers}, [timeout: 20_000, connect_timeout: 10_000], [body_format: :binary]) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        case Jason.decode(body) do
          {:ok, decoded} ->
            case Map.get(decoded, "errors", []) do
              errors when errors not in [nil, [], %{}, ""] -> {:error, {:api_errors, errors}}
              _ ->
                case Map.get(decoded, "response") do
                  rows when is_list(rows) ->
                    paging = Map.get(decoded, "paging", %{})
                    accumulated = acc ++ rows
                    if page < Map.get(paging, "total", 1), do: fetch_all(endpoint, params, page + 1, accumulated), else: {:ok, accumulated}

                  other -> {:error, {:invalid_response, other}}
                end
            end

          {:error, reason} -> {:error, {:invalid_json, reason}}
        end

      {:ok, {{_, status, _}, _headers, body}} -> {:error, {:http_status, status, body}}
      {:error, reason} -> {:error, {:http_error, reason}}
    end
  end

  defp save_teams(rows) do
    Enum.each(rows, fn %{"team" => team} ->
      attrs = %{api_football_id: team["id"], name: team["name"], country: team["country"] || "England",
        founded_year: team["founded"], logo: team["logo"]}
      existing = Repo.get_by(Team, api_football_id: attrs.api_football_id) || Repo.get_by(Team, name: attrs.name)

      case existing do
        nil -> Repo.insert!(Team.changeset(%Team{}, attrs))
        team -> Repo.update!(Team.changeset(team, attrs))
      end
    end)
    :ok
  rescue
    error -> {:error, {:team_persistence, Exception.message(error)}}
  end

  defp save_fixtures(rows, league_id, season) do
    team_ids = Repo.all(from t in Team, where: not is_nil(t.api_football_id), select: {t.api_football_id, t.id}) |> Map.new()

    Enum.each(rows, fn %{"fixture" => fixture, "teams" => teams, "goals" => goals} ->
      with home_id when not is_nil(home_id) <- Map.get(team_ids, teams["home"]["id"]),
           away_id when not is_nil(away_id) <- Map.get(team_ids, teams["away"]["id"]),
           {:ok, played_at, _} <- DateTime.from_iso8601(fixture["date"]) do
        attrs = %{api_football_id: fixture["id"], league_id: league_id, season: season,
          home_team_id: home_id, away_team_id: away_id, played_at: played_at,
          home_score: goals["home"] || 0, away_score: goals["away"] || 0,
          status: fixture["status"]["short"], elapsed: fixture["status"]["elapsed"], round: fixture["round"]}
        Repo.insert!(Match.changeset(%Match{}, attrs), on_conflict: {:replace, [:home_team_id, :away_team_id, :played_at, :home_score, :away_score, :status, :elapsed, :round, :updated_at]}, conflict_target: :api_football_id)
      else
        _ -> :ok
      end
    end)
    :ok
  rescue
    error -> {:error, {:fixture_persistence, Exception.message(error)}}
  end

  defp save_standings(rows, league_id, season) do
    rows
    |> Enum.flat_map(fn row -> get_in(row, ["league", "standings"]) || [] end)
    |> Enum.each(fn table ->
      Enum.each(table, fn row ->
        team_id = Repo.get_by(Team, api_football_id: row["team"]["id"]) |> case do
          nil -> nil
          team -> team.id
        end

        if team_id do
          stats = row["all"] || %{}
          goals = stats["goals"] || %{}
          attrs = %{league_id: league_id, season: season, team_id: team_id, rank: row["rank"],
            points: row["points"], goals_diff: row["goalsDiff"], played: stats["played"],
            win: stats["win"], draw: stats["draw"], lose: stats["lose"],
            goals_for: goals["for"], goals_against: goals["against"], form: row["form"]}
          Repo.insert!(Standing.changeset(%Standing{}, attrs), on_conflict: {:replace, Map.keys(attrs) -- [:league_id, :season, :team_id] ++ [:updated_at]}, conflict_target: [:league_id, :season, :team_id])
        end
      end)
    end)
    :ok
  rescue
    error -> {:error, {:standings_persistence, Exception.message(error)}}
  end
end
