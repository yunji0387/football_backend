defmodule FootballBackend.Repo.Migrations.AddLeaderboardSeasonStatistics do
  use Ecto.Migration

  def change do
    alter table(:player_season_stats) do
      add :clean_sheets, :integer
      add :passes, :integer
      add :key_passes, :integer
    end

    create index(:player_season_stats, [:league_id, :season, :passes])
    create index(:player_season_stats, [:league_id, :season, :key_passes])
    create index(:player_season_stats, [:league_id, :season, :clean_sheets])

    create table(:team_season_stats) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :league_id, :integer, null: false
      add :season, :integer, null: false
      add :played, :integer
      add :wins, :integer
      add :draws, :integer
      add :losses, :integer
      add :goals_for, :integer
      add :goals_against, :integer
      add :clean_sheets, :integer
      add :passes, :integer
      add :key_passes, :integer
      add :provider_data, :map, null: false, default: %{}
      add :fetched_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:team_season_stats, [:provider, :league_id, :season, :team_id],
      name: :team_season_stats_provider_team_index
    )
    create index(:team_season_stats, [:league_id, :season, :clean_sheets])
    create index(:team_season_stats, [:league_id, :season, :passes])
    create index(:team_season_stats, [:league_id, :season, :key_passes])
  end
end
