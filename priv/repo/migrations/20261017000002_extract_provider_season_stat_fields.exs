defmodule FootballBackend.Repo.Migrations.ExtractProviderSeasonStatFields do
  use Ecto.Migration

  def change do
    alter table(:player_season_stats) do
      add :player_profile, :map
      add :league_data, :map
      add :team_data, :map
      add :games_data, :map
      add :substitutes_data, :map
      add :shots_data, :map
      add :goals_data, :map
      add :passes_data, :map
      add :tackles_data, :map
      add :duels_data, :map
      add :dribbles_data, :map
      add :fouls_data, :map
      add :cards_data, :map
      add :penalty_data, :map
      add :offsides, :integer
    end

    alter table(:team_season_stats) do
      add :league_data, :map
      add :team_data, :map
      add :fixtures_data, :map
      add :goals_data, :map
      add :biggest_data, :map
      add :clean_sheet_data, :map
      add :failed_to_score_data, :map
      add :penalty_data, :map
      add :lineups_data, :map
      add :cards_data, :map
      add :form, :string
    end

    execute("""
    UPDATE player_season_stats
    SET player_profile = COALESCE(provider_data->'player', provider_data->'statistics'->'player'),
        league_data = COALESCE(provider_data->'league', provider_data->'statistics'->'league'),
        team_data = COALESCE(provider_data->'team', provider_data->'statistics'->'team'),
        games_data = COALESCE(provider_data->'games', provider_data->'statistics'->'games'),
        substitutes_data = COALESCE(provider_data->'substitutes', provider_data->'statistics'->'substitutes'),
        shots_data = COALESCE(provider_data->'shots', provider_data->'statistics'->'shots'),
        goals_data = COALESCE(provider_data->'goals', provider_data->'statistics'->'goals'),
        passes_data = COALESCE(provider_data->'passes', provider_data->'statistics'->'passes'),
        tackles_data = COALESCE(provider_data->'tackles', provider_data->'statistics'->'tackles'),
        duels_data = COALESCE(provider_data->'duels', provider_data->'statistics'->'duels'),
        dribbles_data = COALESCE(provider_data->'dribbles', provider_data->'statistics'->'dribbles'),
        fouls_data = COALESCE(provider_data->'fouls', provider_data->'statistics'->'fouls'),
        cards_data = COALESCE(provider_data->'cards', provider_data->'statistics'->'cards'),
        penalty_data = COALESCE(provider_data->'penalty', provider_data->'statistics'->'penalty'),
        offsides = CASE
          WHEN COALESCE(provider_data->>'offsides', provider_data->'statistics'->>'offsides') ~ '^-?[0-9]+$'
          THEN COALESCE(provider_data->>'offsides', provider_data->'statistics'->>'offsides')::integer
          ELSE NULL
        END
    """, "SELECT 1")

    execute("""
    UPDATE team_season_stats
    SET league_data = provider_data->'league',
        team_data = provider_data->'team',
        fixtures_data = provider_data->'fixtures',
        goals_data = provider_data->'goals',
        biggest_data = provider_data->'biggest',
        clean_sheet_data = provider_data->'clean_sheet',
        failed_to_score_data = provider_data->'failed_to_score',
        penalty_data = provider_data->'penalty',
        lineups_data = CASE WHEN provider_data ? 'lineups'
          THEN jsonb_build_object('data', provider_data->'lineups') ELSE NULL END,
        cards_data = provider_data->'cards',
        form = provider_data->>'form'
    """, "SELECT 1")
  end
end
