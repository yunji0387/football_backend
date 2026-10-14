defmodule FootballBackend.Football.FootballData do
  @moduledoc "Fallback sync adapter for football-data.org's v4 API."
  alias FootballBackend.Repo
  alias FootballBackend.Football.Standing
  alias FootballBackend.Football.ProviderMappings

  @base_url ~c"https://api.football-data.org/v4"
  @min_interval_ms 6_100

  def sync do
    config = Application.get_env(:football_backend, FootballBackend.Football, [])
    token = Keyword.get(config, :football_data_token)
    competition = Keyword.get(config, :football_competition, "PL")
    league_id = FootballBackend.Football.configured_league_id()
    season = FootballBackend.Football.current_season()

    with token when is_binary(token) and token != "" <- token,
         {:ok, matches} <- get("competitions/#{competition}/matches?season=#{season}", token),
         {:ok, standings} <- get("competitions/#{competition}/standings?season=#{season}", token),
         :ok <- save_matches(matches, standings, league_id, season),
         :ok <- save_standings(standings, league_id, season) do
      :ok
    else
      nil -> {:error, :football_data_token_not_configured}
      "" -> {:error, :football_data_token_not_configured}
      {:error, _} = error -> error
    end
  end

  defp get(path, token) do
    url = @base_url ++ ~c"/" ++ String.to_charlist(path)
    headers = [{~c"X-Auth-Token", String.to_charlist(token)}]

    case rate_limited_request(url, headers) do
      {:ok, {{_, 200, _}, _, body}} -> Jason.decode(body)
      {:ok, {{_, status, _}, _, body}} -> {:error, {:football_data_http_status, status, body}}
      {:error, reason} -> {:error, {:football_data_http_error, reason}}
    end
  end

  defp rate_limited_request(url, headers) do
    lock = {{__MODULE__, :api_request}, self()}

    :global.trans(lock, fn ->
      last_key = {__MODULE__, :last_request_at}
      now = System.monotonic_time(:millisecond)

      case :persistent_term.get(last_key, nil) do
        nil -> :ok
        last -> Process.sleep(max(@min_interval_ms - (now - last), 0))
      end

      response = :httpc.request(:get, {url, headers}, [timeout: 20_000, connect_timeout: 10_000], [body_format: :binary])
      :persistent_term.put(last_key, System.monotonic_time(:millisecond))
      response
    end)
  end

  defp save_matches(%{"matches" => matches}, standings, league_id, season) do
    team_rows =
      Enum.flat_map(matches, &[&1["homeTeam"], &1["awayTeam"]]) ++
        Enum.flat_map(standings["standings"] || [], &Enum.map(&1["table"] || [], fn row -> row["team"] end))

    with {:ok, teams} <- upsert_teams(team_rows),
         :ok <- upsert_matches(matches, teams, league_id, season) do
      :ok
    end
  rescue
    error -> {:error, {:football_data_match_persistence, Exception.message(error)}}
  end

  defp save_matches(_, _, _, _), do: {:error, :football_data_invalid_matches_response}

  defp upsert_teams(team_rows) do
    team_rows
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1["id"])
    |> Enum.reduce_while({:ok, %{}}, fn team_data, {:ok, team_ids} ->
      attrs = %{
        name: team_data["name"], country: get_in(team_data, ["area", "name"]) || "Unknown",
        logo: team_data["crest"]
      }

      case ProviderMappings.upsert_team("football_data", team_data["id"], attrs) do
        {:ok, team} -> {:cont, {:ok, Map.put(team_ids, team_data["id"], team.id)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp upsert_matches(matches, teams, league_id, season) do
    Enum.reduce_while(matches, :ok, fn row, :ok ->
      home = row["homeTeam"] || %{}
      away = row["awayTeam"] || %{}
      score = get_in(row, ["score", "fullTime"]) || %{}

      with home_id when not is_nil(home_id) <- teams[home["id"]],
           away_id when not is_nil(away_id) <- teams[away["id"]],
           {:ok, played_at, _} <- DateTime.from_iso8601(row["utcDate"]) do
        attrs = %{
          league_id: league_id, season: season, home_team_id: home_id, away_team_id: away_id,
          played_at: played_at, home_score: score["home"] || 0, away_score: score["away"] || 0,
          status: normalize_status(row["status"]), elapsed: nil,
          round: if(row["matchday"], do: "Matchday #{row["matchday"]}", else: row["stage"])
        }

        case ProviderMappings.upsert_match("football_data", row["id"], attrs) do
          {:ok, _match} -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      else
        _ -> {:cont, :ok}
      end
    end)
  end

  defp save_standings(%{"standings" => tables}, league_id, season) do
    tables
    |> Enum.find(&(&1["type"] == "TOTAL"))
    |> case do
      nil -> :ok
      table ->
        Enum.each(table["table"] || [], fn row ->
          team_id = ProviderMappings.get_team_id("football_data", get_in(row, ["team", "id"]))
          if team_id do
            attrs = %{league_id: league_id, season: season, team_id: team_id, rank: row["position"],
              points: row["points"], goals_diff: row["goalDifference"], played: row["playedGames"],
              win: row["won"], draw: row["draw"], lose: row["lost"], goals_for: row["goalsFor"],
              goals_against: row["goalsAgainst"], form: row["form"]}
            Repo.insert!(Standing.changeset(%Standing{}, attrs), on_conflict: {:replace, Map.keys(attrs) -- [:league_id, :season, :team_id] ++ [:updated_at]}, conflict_target: [:league_id, :season, :team_id])
          end
        end)
        :ok
    end
  rescue
    error -> {:error, {:football_data_standings_persistence, Exception.message(error)}}
  end

  defp save_standings(_, _, _), do: {:error, :football_data_invalid_standings_response}

  defp normalize_status("FINISHED"), do: "FT"
  defp normalize_status("IN_PLAY"), do: "LIVE"
  defp normalize_status("PAUSED"), do: "HT"
  defp normalize_status("SUSPENDED"), do: "SUSP"
  defp normalize_status("POSTPONED"), do: "PST"
  defp normalize_status("CANCELLED"), do: "CANC"
  defp normalize_status("AWARDED"), do: "AWD"
  defp normalize_status(status), do: status
end
