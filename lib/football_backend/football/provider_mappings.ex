defmodule FootballBackend.Football.ProviderMappings do
  @moduledoc "Maps provider-specific IDs and names to canonical local teams, matches, and players."
  import Ecto.Query

  alias FootballBackend.{Repo, Teams.Team, Matches.Match, Players.Player}
  alias FootballBackend.Football.{TeamProviderId, MatchProviderId, PlayerProviderId}

  @team_suffixes ["football club", "a f c", "f c", "afc", "fc", "cf", "sc"]
  @team_name_aliases %{
    "afc bournemouth" => "bournemouth",
    "brighton and hove albion" => "brighton",
    "brighton hove albion" => "brighton",
    "ipswich town" => "ipswich",
    "leeds united" => "leeds",
    "leicester city" => "leicester",
    "newcastle united" => "newcastle",
    "tottenham hotspur" => "tottenham",
    "west ham united" => "west ham",
    "wolverhampton wanderers" => "wolves"
  }
  @match_window_seconds 6 * 60 * 60

  def get_team_id(provider, external_id) do
    case Repo.get_by(TeamProviderId, provider: provider, external_id: external_id) do
      nil -> nil
      mapping -> mapping.team_id
    end
  end

  def get_match_id(provider, external_id) do
    case Repo.get_by(MatchProviderId, provider: provider, external_id: external_id) do
      nil -> nil
      mapping -> mapping.match_id
    end
  end

  def get_player_id(provider, external_id) do
    case Repo.get_by(PlayerProviderId, provider: provider, external_id: external_id) do
      nil -> nil
      mapping -> mapping.player_id
    end
  end

  def team_external_id(team_id, provider) do
    case Repo.get_by(TeamProviderId, team_id: team_id, provider: provider) do
      nil -> nil
      mapping -> mapping.external_id
    end
  end

  def match_external_id(match_id, provider) do
    case Repo.get_by(MatchProviderId, match_id: match_id, provider: provider) do
      nil -> nil
      mapping -> mapping.external_id
    end
  end

  def upsert_team(provider, external_id, attrs) do
    Repo.transaction(fn ->
      existing = get_team_id(provider, external_id)

      team =
        case existing && Repo.get(Team, existing) do
          %Team{} = team -> update_team(team, provider, external_id, attrs)
          nil ->
            case find_team_by_normalized_name(attrs.name, attrs[:country]) do
              {:ok, %Team{} = team} -> update_team(team, provider, external_id, attrs)
              {:ok, nil} -> create_team(provider, external_id, attrs)
              {:error, reason} -> Repo.rollback(reason)
            end
        end

      link_team!(team.id, provider, external_id)
      team
    end)
    |> unwrap_transaction()
  end

  def upsert_match(provider, external_id, attrs) do
    Repo.transaction(fn ->
      existing = get_match_id(provider, external_id)

      match =
        case existing && Repo.get(Match, existing) do
          %Match{} = match -> update_match(match, provider, external_id, attrs)
          nil ->
            case find_fixture(attrs) do
              {:ok, %Match{} = match} -> update_match(match, provider, external_id, attrs)
              {:ok, nil} -> create_match(provider, external_id, attrs)
              {:error, reason} -> Repo.rollback(reason)
            end
        end

      link_match!(match.id, provider, external_id)
      match
    end)
    |> unwrap_transaction()
  end

  def upsert_player(provider, external_id, attrs) do
    Repo.transaction(fn ->
      existing = get_player_id(provider, external_id)
      attrs = Enum.reject(attrs, fn {key, value} -> key in [:position, :jersey_number] and is_nil(value) end) |> Map.new()

      player =
        case existing && Repo.get(Player, existing) do
          %Player{} = player -> Repo.update!(Player.changeset(player, attrs))
          nil ->
            case find_player_by_name_and_team(attrs.name, attrs.team_id) do
              {:ok, %Player{} = player} -> Repo.update!(Player.changeset(player, attrs))
              {:ok, nil} -> Repo.insert!(Player.changeset(%Player{}, attrs))
              {:error, reason} -> Repo.rollback(reason)
            end
        end

      link_player!(player.id, provider, external_id)
      player
    end)
    |> unwrap_transaction()
  end

  defp update_team(team, provider, external_id, attrs) do
    attrs = attrs |> Map.delete(:name) |> Map.put(legacy_team_id_field(provider), external_id)
    Repo.update!(Team.changeset(team, attrs))
  end

  defp create_team(provider, external_id, attrs) do
    attrs = Map.put(attrs, legacy_team_id_field(provider), external_id)
    Repo.insert!(Team.changeset(%Team{}, attrs))
  end

  defp link_team!(team_id, provider, external_id) do
    mapping = Repo.get_by(TeamProviderId, provider: provider, external_id: external_id)
    team_mapping = Repo.get_by(TeamProviderId, team_id: team_id, provider: provider)

    cond do
      mapping && mapping.team_id != team_id -> Repo.rollback({:team_provider_id_conflict, provider, external_id})
      team_mapping && team_mapping.external_id != external_id -> Repo.rollback({:team_has_multiple_provider_ids, provider, team_id})
      mapping -> mapping
      team_mapping -> team_mapping
      true ->
        attrs = %{team_id: team_id, provider: provider, external_id: external_id}
        Repo.insert!(TeamProviderId.changeset(%TeamProviderId{}, attrs))
    end
  end

  defp find_team_by_normalized_name(name, country) do
    normalized = canonical_team_key(name)
    normalized_country = normalize_country(country)

    matches =
      Repo.all(from t in Team, select: t)
      |> Enum.filter(fn team ->
        canonical_team_key(team.name) == normalized and normalize_country(team.country) == normalized_country
      end)

    case matches do
      [] -> {:ok, nil}
      [team] -> {:ok, team}
      _ -> {:error, {:ambiguous_team_name, name, Enum.map(matches, & &1.id)}}
    end
  end

  defp find_player_by_name_and_team(name, team_id) do
    normalized = normalize_person_name(name)

    matches =
      Repo.all(from p in Player, where: p.team_id == ^team_id, select: p)
      |> Enum.filter(&(normalize_person_name(&1.name) == normalized))

    case matches do
      [] -> {:ok, nil}
      [player] -> {:ok, player}
      _ -> {:error, {:ambiguous_player_name, name, team_id, Enum.map(matches, & &1.id)}}
    end
  end

  defp normalize_person_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^[:alnum:]]/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp canonical_team_key(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^[:alnum:]]/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> strip_team_suffixes()
    |> strip_team_prefixes()
    |> then(&Map.get(@team_name_aliases, &1, &1))
  end

  defp normalize_country(nil), do: nil
  defp normalize_country(country), do: country |> String.downcase() |> String.trim()

  defp strip_team_suffixes(name) do
    case Enum.find(@team_suffixes, &String.ends_with?(name, " " <> &1)) do
      nil -> name
      suffix -> name |> String.replace_suffix(" " <> suffix, "") |> strip_team_suffixes()
    end
  end

  defp strip_team_prefixes(name) do
    case Enum.find(["association football club", "a f c", "f c", "afc", "fc"], &String.starts_with?(name, &1 <> " ")) do
      nil -> name
      prefix -> name |> String.replace_prefix(prefix <> " ", "") |> strip_team_prefixes()
    end
  end

  defp find_fixture(attrs) do
    league_id = attrs.league_id
    season = attrs.season
    home_team_id = attrs.home_team_id
    away_team_id = attrs.away_team_id
    window_start = DateTime.add(attrs.played_at, -@match_window_seconds, :second)
    window_end = DateTime.add(attrs.played_at, @match_window_seconds, :second)

    matches =
      Repo.all(
        from m in Match,
          where: m.league_id == ^league_id and m.season == ^season,
          where: m.home_team_id == ^home_team_id and m.away_team_id == ^away_team_id,
          where: m.played_at >= ^window_start and m.played_at <= ^window_end
      )

    case matches do
      [] -> {:ok, nil}
      [match] -> {:ok, match}
      _ -> {:error, {:ambiguous_fixture, league_id, season, home_team_id, away_team_id}}
    end
  end

  defp update_match(match, provider, external_id, attrs) do
    attrs = Map.put(attrs, legacy_match_id_field(provider), external_id)
    Repo.update!(Match.changeset(match, attrs))
  end

  defp create_match(provider, external_id, attrs) do
    attrs = Map.put(attrs, legacy_match_id_field(provider), external_id)
    Repo.insert!(Match.changeset(%Match{}, attrs))
  end

  defp link_match!(match_id, provider, external_id) do
    mapping = Repo.get_by(MatchProviderId, provider: provider, external_id: external_id)
    match_mapping = Repo.get_by(MatchProviderId, match_id: match_id, provider: provider)

    cond do
      mapping && mapping.match_id != match_id -> Repo.rollback({:match_provider_id_conflict, provider, external_id})
      match_mapping && match_mapping.external_id != external_id -> Repo.rollback({:match_has_multiple_provider_ids, provider, match_id})
      mapping -> mapping
      match_mapping -> match_mapping
      true ->
        attrs = %{match_id: match_id, provider: provider, external_id: external_id}
        Repo.insert!(MatchProviderId.changeset(%MatchProviderId{}, attrs))
    end
  end

  defp link_player!(player_id, provider, external_id) do
    mapping = Repo.get_by(PlayerProviderId, provider: provider, external_id: external_id)
    player_mapping = Repo.get_by(PlayerProviderId, player_id: player_id, provider: provider)

    cond do
      mapping && mapping.player_id != player_id -> Repo.rollback({:player_provider_id_conflict, provider, external_id})
      player_mapping && player_mapping.external_id != external_id -> Repo.rollback({:player_has_multiple_provider_ids, provider, player_id})
      mapping -> mapping
      player_mapping -> player_mapping
      true ->
        attrs = %{player_id: player_id, provider: provider, external_id: external_id}
        Repo.insert!(PlayerProviderId.changeset(%PlayerProviderId{}, attrs))
    end
  end

  defp legacy_team_id_field("api_football"), do: :api_football_id
  defp legacy_team_id_field("football_data"), do: :football_data_id
  defp legacy_match_id_field("api_football"), do: :api_football_id
  defp legacy_match_id_field("football_data"), do: :football_data_id

  defp unwrap_transaction({:ok, value}), do: {:ok, value}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}
end
