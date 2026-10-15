defmodule FootballBackend.Repo.Migrations.AddPlayerScorersAndNullableScores do
  use Ecto.Migration

  def up do
    alter table(:matches) do
      modify :home_score, :integer, null: true, default: nil
      modify :away_score, :integer, null: true, default: nil
    end

    alter table(:players) do
      modify :position, :string, null: true
    end

    create table(:player_provider_ids) do
      add :player_id, references(:players, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :external_id, :bigint, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:player_provider_ids, [:provider, :external_id])
    create unique_index(:player_provider_ids, [:player_id, :provider])

    create table(:player_season_stats) do
      add :player_id, references(:players, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :league_id, :integer, null: false
      add :season, :integer, null: false
      add :appearances, :integer
      add :lineups, :integer
      add :minutes, :integer
      add :goals, :integer, null: false, default: 0
      add :assists, :integer
      add :penalties, :integer
      add :shots, :integer
      add :shots_on_target, :integer
      add :yellow_cards, :integer
      add :red_cards, :integer
      add :rating, :string
      add :provider_data, :map, null: false, default: %{}
      add :fetched_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:player_season_stats,
      [:provider, :league_id, :season, :player_id, :team_id],
      name: :player_season_stats_provider_player_index
    )

    create index(:player_season_stats, [:league_id, :season, :goals, :assists],
      name: :player_season_stats_leaderboard_index
    )
  end

  def down do
    drop index(:player_season_stats, :player_season_stats_leaderboard_index)
    drop index(:player_season_stats, :player_season_stats_provider_player_index)
    drop table(:player_season_stats)
    drop index(:player_provider_ids, [:player_id, :provider])
    drop index(:player_provider_ids, [:provider, :external_id])
    drop table(:player_provider_ids)

    execute "UPDATE players SET position = 'Unknown' WHERE position IS NULL"
    alter table(:players) do
      modify :position, :string, null: false
    end

    execute "UPDATE matches SET home_score = 0 WHERE home_score IS NULL"
    execute "UPDATE matches SET away_score = 0 WHERE away_score IS NULL"
    alter table(:matches) do
      modify :home_score, :integer, null: false, default: 0
      modify :away_score, :integer, null: false, default: 0
    end
  end
end
