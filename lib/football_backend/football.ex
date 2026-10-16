defmodule FootballBackend.Football do
  @moduledoc "Syncs league-wide football data from API-Football into the local database."
  import Ecto.Query
  require Logger

  alias FootballBackend.{Repo, Teams.Team}
  alias FootballBackend.Football.Standing
  alias FootballBackend.Football.ProviderMappings
  alias FootballBackend.Football.ApiSnapshot
  alias FootballBackend.Football.TeamSeasonStat
  alias FootballBackend.Matches.Match

  @base_url ~c"https://v3.football.api-sports.io"
  @api_min_interval_ms 6_100
  @season_cache_seconds 86_400
  @live_cache_seconds 900
  @max_detail_fixtures_per_sync 3
  @api_football_league_ids %{"PL" => 39}

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

  def rounds(league_id \\ configured_league_id(), season \\ current_season()) do
    case Repo.get_by(ApiSnapshot, endpoint: "fixtures/rounds", league_id: league_id, season: season, resource_id: "all") do
      nil -> []
      snapshot -> snapshot.payload["data"] || []
    end
  end

  def team_statistics(team_id, league_id \\ configured_league_id(), season \\ current_season()) do
    case Repo.get(Team, team_id) do
      nil -> nil
      team ->
        case ProviderMappings.team_external_id(team.id, "api_football") do
          nil -> nil
          external_id ->
            case Repo.get_by(ApiSnapshot, endpoint: "teams/statistics", league_id: league_id, season: season, resource_id: to_string(external_id)) do
              nil -> nil
              snapshot -> List.first(snapshot.payload["data"] || [])
            end
        end
    end
  end

  def fixture_details(match_id) do
    case Repo.get(Match, match_id) do
      nil -> nil
      match ->
        case ProviderMappings.match_external_id(match.id, "api_football") do
          nil -> nil
          external_id ->
            details =
              ["fixtures/events", "fixtures/lineups", "fixtures/statistics"]
              |> Enum.map(fn endpoint ->
                snapshot = Repo.get_by(ApiSnapshot, endpoint: endpoint, league_id: match.league_id, season: match.season, resource_id: to_string(external_id))
                {String.replace_prefix(endpoint, "fixtures/", ""), if(snapshot, do: snapshot.payload["data"], else: nil)}
              end)
              |> Map.new()

            Map.merge(%{api_football_id: external_id, status: match.status}, details)
        end
    end
  end

  def sync do
    case sync_primary() do
      :ok -> :ok
      {:error, primary_reason} ->
        Logger.warning("Primary API-Football sync failed; trying football-data.org backup: #{inspect(primary_reason)}")

        case FootballBackend.Football.FootballData.sync() do
          :ok ->
            Logger.info("football-data.org backup sync completed")
            :ok

          {:error, backup_reason} ->
            {:error, {:all_providers_failed, %{api_football: primary_reason, football_data: backup_reason}}}
        end
    end
  end

  defp sync_primary do
    with key when is_binary(key) and key != "" <- api_key(),
         league_id <- configured_league_id(),
         season <- current_season(),
         {:ok, teams} <- fetch_all("teams", league: league_id, season: season),
         :ok <- save_teams(teams),
         :ok <- sync_rounds(league_id, season),
         :ok <- sync_team_statistics(teams, league_id, season),
         {:ok, fixtures} <- fetch_all("fixtures", league: league_id, season: season),
         :ok <- save_fixtures(fixtures, league_id, season),
         :ok <- sync_fixture_details(fixtures, league_id, season),
         {:ok, tables} <- fetch_all("standings", league: league_id, season: season),
         :ok <- save_standings(tables, league_id, season) do
      case sync_player_season_stats(league_id, season) do
        :ok -> Logger.info("API-Football player season statistics synced")
        {:error, reason} -> Logger.warning("API-Football player season statistics unavailable: #{inspect(reason)}")
      end
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
    competition = Application.get_env(:football_backend, __MODULE__, []) |> Keyword.get(:football_competition, "PL")
    Map.fetch!(@api_football_league_ids, competition)
  end

  defp sync_player_season_stats(league_id, season) do
    if fresh_snapshot?("players", league_id, season, "all", @season_cache_seconds) do
      :ok
    else
      case fetch_all("players", league: league_id, season: season) do
        {:ok, rows} ->
          players =
            Enum.flat_map(rows, fn row ->
              player = row["player"] || %{}

              Enum.map(row["statistics"] || [], fn statistics ->
                team = statistics["team"] || %{}
                games = statistics["games"] || %{}
                goals = statistics["goals"] || %{}
                shots = statistics["shots"] || %{}
                passes = statistics["passes"] || %{}
                cards = statistics["cards"] || %{}

                %{
                  external_id: player["id"],
                  player: %{name: player["name"], position: games["position"], jersey_number: player["number"]},
                  team: %{external_id: team["id"], name: team["name"], logo: team["logo"], country: "England"},
                  statistics: %{
                    appearances: games["appearences"] || games["appearances"],
                    lineups: games["lineups"], minutes: games["minutes"], goals: goals["total"] || 0,
                    assists: goals["assists"], penalties: goals["penalty"], shots: shots["total"],
                    shots_on_target: shots["on"], clean_sheets: nil, passes: passes["total"],
                    key_passes: passes["key"], yellow_cards: cards["yellow"], red_cards: cards["red"],
                    rating: games["rating"], player_profile: player,
                    league_data: statistics["league"], team_data: team, games_data: games,
                    substitutes_data: statistics["substitutes"], shots_data: statistics["shots"],
                    goals_data: statistics["goals"], passes_data: passes,
                    tackles_data: statistics["tackles"], duels_data: statistics["duels"],
                    dribbles_data: statistics["dribbles"], fouls_data: statistics["fouls"],
                    cards_data: cards, penalty_data: statistics["penalty"],
                    offsides: statistics["offsides"]
                  },
                  provider_data: %{player: player, statistics: statistics}
                }
              end)
            end)
            |> Enum.filter(&is_integer(&1.external_id))

          case if(players == [], do: {:error, :empty_player_season_response}, else: FootballBackend.Players.import_provider_season_stats("api_football", league_id, season, players)) do
            :ok -> save_snapshot("players", league_id, season, "all", %{count: length(players)})
            {:error, reason} -> {:error, {:player_season_stats_persistence, reason}}
          end

        {:error, reason} -> {:error, {:player_season_stats_fetch, reason}}
      end
    end
  end

  defp api_key, do: Application.get_env(:football_backend, __MODULE__, []) |> Keyword.get(:api_key)

  defp sync_rounds(league_id, season) do
    if fresh_snapshot?("fixtures/rounds", league_id, season, "all", @season_cache_seconds) do
      :ok
    else
      with {:ok, rows} <- fetch_all("fixtures/rounds", league: league_id, season: season) do
        save_snapshot("fixtures/rounds", league_id, season, "all", rows)
      end
    end
  end

  defp sync_team_statistics(teams, league_id, season) do
    teams
    |> Enum.map(&get_in(&1, ["team", "id"]))
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce_while(:ok, fn team_id, :ok ->
      resource_id = to_string(team_id)

      result =
        if fresh_snapshot?("teams/statistics", league_id, season, resource_id, @season_cache_seconds) do
          case Repo.get_by(ApiSnapshot, endpoint: "teams/statistics", league_id: league_id,
                 season: season, resource_id: resource_id) do
            nil -> :ok
            snapshot -> persist_team_season_stats(team_id, league_id, season, List.first(snapshot.payload["data"] || []))
          end
        else
          case fetch_all("teams/statistics", league: league_id, season: season, team: team_id) do
            {:ok, rows} ->
              with :ok <- save_snapshot("teams/statistics", league_id, season, resource_id, rows),
                   :ok <- persist_team_season_stats(team_id, league_id, season, List.first(rows)) do
                :ok
              end

            error -> error
          end
        end

      case result do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp persist_team_season_stats(external_team_id, league_id, season, data) when is_map(data) do
    case ProviderMappings.get_team_id("api_football", external_team_id) do
      nil -> :ok
      team_id ->
        fixtures = data["fixtures"] || %{}
        wins = fixtures["wins"] || %{}
        draws = fixtures["draws"] || %{}
        loses = fixtures["loses"] || %{}
        goals = data["goals"] || %{}
        goals_for = goals["for"] || %{}
        goals_against = goals["against"] || %{}
        clean_sheets = data["clean_sheet"] || %{}
        existing = Repo.get_by(TeamSeasonStat, provider: "api_football", league_id: league_id,
          season: season, team_id: team_id)
        fetched_at = DateTime.utc_now() |> DateTime.truncate(:second)
        attrs = %{
          team_id: team_id, provider: "api_football", league_id: league_id, season: season,
          played: get_in(fixtures, ["played", "total"]),
          wins: wins["total"], draws: draws["total"], losses: loses["total"],
          goals_for: goals_for["total"], goals_against: goals_against["total"],
          clean_sheets: clean_sheets["total"], passes: existing && existing.passes,
          key_passes: existing && existing.key_passes,
          league_data: data["league"], team_data: data["team"],
          fixtures_data: fixtures, goals_data: goals, biggest_data: data["biggest"],
          clean_sheet_data: clean_sheets, failed_to_score_data: data["failed_to_score"],
          penalty_data: data["penalty"], lineups_data: %{data: data["lineups"]},
          cards_data: data["cards"], form: data["form"],
          provider_data: data, fetched_at: fetched_at
        }

        case Repo.insert(TeamSeasonStat.changeset(%TeamSeasonStat{}, attrs),
               on_conflict: {:replace, Map.keys(attrs) -- [:provider, :league_id, :season, :team_id] ++ [:updated_at]},
               conflict_target: [:provider, :league_id, :season, :team_id]) do
          {:ok, _stat} -> :ok
          {:error, reason} -> {:error, {:team_season_stats_persistence, reason}}
        end
    end
  end

  defp persist_team_season_stats(_external_team_id, _league_id, _season, _data), do: :ok

  defp sync_fixture_details(fixtures, league_id, season) do
    now = DateTime.utc_now()

    fixtures
    |> Enum.filter(fn row -> detail_candidate?(row, now) and fixture_details_needed?(row, league_id, season, now) end)
    |> Enum.sort_by(&detail_priority(&1, now))
    |> Enum.take(@max_detail_fixtures_per_sync)
    |> Enum.reduce_while(:ok, fn row, :ok ->
      fixture = row["fixture"]
      status = get_in(fixture, ["status", "short"])
      api_id = fixture["id"]
      resource_id = to_string(api_id)
      completed? = status in ["FT", "AET", "PEN"]
      live? = status in ["1H", "HT", "2H", "ET", "BT", "P", "LIVE"]

      endpoints = fixture_detail_endpoints(status)

      Enum.reduce_while(endpoints, :ok, fn endpoint, :ok ->
        should_refresh? = fixture_endpoint_needs_refresh?(endpoint, league_id, season, resource_id, live?, completed?, now)

        if should_refresh? do
          case fetch_all(endpoint, fixture: api_id) do
            {:ok, data} ->
              case save_snapshot(endpoint, league_id, season, resource_id, data) do
                :ok -> {:cont, :ok}
                error -> {:halt, error}
              end

            error -> {:halt, error}
          end
        else
          {:cont, :ok}
        end
      end)
      |> case do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp fixture_detail_endpoints(status) do
    (if status in ["FT", "AET", "PEN"] or status in ["1H", "HT", "2H", "ET", "BT", "P", "LIVE"],
      do: ["fixtures/events", "fixtures/statistics"], else: []) ++ ["fixtures/lineups"]
  end

  defp fixture_details_needed?(%{"fixture" => fixture}, league_id, season, now) do
    status = get_in(fixture, ["status", "short"])
    completed? = status in ["FT", "AET", "PEN"]
    live? = status in ["1H", "HT", "2H", "ET", "BT", "P", "LIVE"]
    resource_id = to_string(fixture["id"])

    Enum.any?(fixture_detail_endpoints(status), fn endpoint ->
      fixture_endpoint_needs_refresh?(endpoint, league_id, season, resource_id, live?, completed?, now)
    end)
  end

  defp fixture_endpoint_needs_refresh?(endpoint, league_id, season, resource_id, live?, completed?, now) do
    case Repo.get_by(ApiSnapshot, endpoint: endpoint, league_id: league_id, season: season, resource_id: resource_id) do
      nil -> true
      snapshot when endpoint == "fixtures/lineups" ->
        empty? = snapshot.payload["data"] in [nil, []]
        empty? and DateTime.diff(now, snapshot.updated_at, :second) >= @season_cache_seconds
      _snapshot when completed? -> false
      snapshot when live? -> DateTime.diff(now, snapshot.updated_at, :second) >= @live_cache_seconds
      snapshot -> DateTime.diff(now, snapshot.updated_at, :second) >= @season_cache_seconds
    end
  end

  defp detail_candidate?(%{"fixture" => fixture}, now) do
    status = get_in(fixture, ["status", "short"])
    {:ok, kickoff, _offset} = DateTime.from_iso8601(fixture["date"])
    age_seconds = DateTime.diff(now, kickoff, :second)
    live? = status in ["1H", "HT", "2H", "ET", "BT", "P", "LIVE"]
    completed_recently? = status in ["FT", "AET", "PEN"] and age_seconds >= 0 and age_seconds <= 36 * 60 * 60
    lineup_window? = age_seconds >= -2 * 60 * 60 and age_seconds <= 4 * 60 * 60
    live? or completed_recently? or lineup_window?
  rescue
    _ -> false
  end

  defp detail_priority(%{"fixture" => fixture}, now) do
    status = get_in(fixture, ["status", "short"])
    {:ok, kickoff, _offset} = DateTime.from_iso8601(fixture["date"])
    cond do
      status in ["1H", "HT", "2H", "ET", "BT", "P", "LIVE"] -> {0, -DateTime.to_unix(kickoff)}
      DateTime.diff(now, kickoff, :second) < 0 -> {1, DateTime.to_unix(kickoff)}
      true -> {2, -DateTime.to_unix(kickoff)}
    end
  rescue
    _ -> {3, 0}
  end

  defp fresh_snapshot?(endpoint, league_id, season, resource_id, max_age_seconds) do
    case Repo.get_by(ApiSnapshot, endpoint: endpoint, league_id: league_id, season: season, resource_id: resource_id) do
      nil -> false
      snapshot -> DateTime.diff(DateTime.utc_now(), snapshot.updated_at, :second) < max_age_seconds
    end
  end

  defp save_snapshot(endpoint, league_id, season, resource_id, data) do
    attrs = %{endpoint: endpoint, league_id: league_id, season: season,
      resource_id: resource_id, payload: %{data: data}}

    Repo.insert!(ApiSnapshot.changeset(%ApiSnapshot{}, attrs),
      on_conflict: {:replace, [:payload, :updated_at]},
      conflict_target: [:endpoint, :league_id, :season, :resource_id]
    )

    :ok
  rescue
    error -> {:error, {:snapshot_persistence, Exception.message(error)}}
  end

  defp fetch_all(endpoint, params, page \\ 1, acc \\ []) do
    query_params = Map.new(params)
    query_params = if page > 1, do: Map.put(query_params, :page, page), else: query_params
    query = URI.encode_query(query_params)
    url = @base_url ++ ~c"/" ++ String.to_charlist(endpoint <> "?" <> query)
    headers = [{~c"x-apisports-key", String.to_charlist(api_key())}]

    case rate_limited_request(url, headers) do
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

                  # API-Football's teams/statistics endpoint returns one
                  # statistics object in `response`, while most endpoints
                  # return a list. Normalize it to a one-element list so the
                  # snapshot and controller can use the same representation.
                  response when endpoint == "teams/statistics" and is_map(response) ->
                    {:ok, acc ++ [response]}

                  other -> {:error, {:invalid_response, other}}
                end
            end

          {:error, reason} -> {:error, {:invalid_json, reason}}
        end

      {:ok, {{_, status, _}, _headers, body}} -> {:error, {:http_status, status, body}}
      {:error, reason} -> {:error, {:http_error, reason}}
    end
  end

  defp rate_limited_request(url, headers) do
    lock = {{__MODULE__, :api_request}, self()}

    :global.trans(lock, fn ->
      last_request_key = {__MODULE__, :last_request_at}
      now = System.monotonic_time(:millisecond)

      case :persistent_term.get(last_request_key, nil) do
        nil -> :ok
        last -> Process.sleep(max(@api_min_interval_ms - (now - last), 0))
      end

      response = :httpc.request(:get, {url, headers}, [timeout: 20_000, connect_timeout: 10_000], [body_format: :binary])
      :persistent_term.put(last_request_key, System.monotonic_time(:millisecond))
      response
    end)
  end

  defp save_teams(rows) do
    Enum.reduce_while(rows, :ok, fn %{"team" => team}, :ok ->
      attrs = %{name: team["name"], country: team["country"] || "England",
        founded_year: team["founded"], logo: team["logo"]}

      case ProviderMappings.upsert_team("api_football", team["id"], attrs) do
        {:ok, _team} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      :ok -> :ok
      error -> error
    end
  rescue
    error -> {:error, {:team_persistence, Exception.message(error)}}
  end

  defp save_fixtures(rows, league_id, season) do
    Enum.reduce_while(rows, :ok, fn %{"fixture" => fixture, "teams" => teams, "goals" => goals}, :ok ->
      with home_id when not is_nil(home_id) <- ProviderMappings.get_team_id("api_football", teams["home"]["id"]),
           away_id when not is_nil(away_id) <- ProviderMappings.get_team_id("api_football", teams["away"]["id"]),
           {:ok, played_at, _} <- DateTime.from_iso8601(fixture["date"]) do
        attrs = %{league_id: league_id, season: season,
          home_team_id: home_id, away_team_id: away_id, played_at: played_at,
          home_score: goals["home"], away_score: goals["away"],
          status: fixture["status"]["short"], elapsed: fixture["status"]["elapsed"], round: fixture["round"]}

        case ProviderMappings.upsert_match("api_football", fixture["id"], attrs) do
          {:ok, _match} -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      else
        _ -> {:cont, :ok}
      end
    end)
  rescue
    error -> {:error, {:fixture_persistence, Exception.message(error)}}
  end

  defp save_standings(rows, league_id, season) do
    rows
    |> Enum.flat_map(fn row -> get_in(row, ["league", "standings"]) || [] end)
    |> Enum.each(fn table ->
      Enum.each(table, fn row ->
        team_id = ProviderMappings.get_team_id("api_football", row["team"]["id"])

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
