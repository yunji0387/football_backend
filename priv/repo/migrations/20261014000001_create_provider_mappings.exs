defmodule FootballBackend.Repo.Migrations.CreateProviderMappings do
  use Ecto.Migration

  def up do
    create table(:team_provider_ids) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :external_id, :bigint, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:team_provider_ids, [:provider, :external_id])
    create unique_index(:team_provider_ids, [:team_id, :provider])

    create table(:match_provider_ids) do
      add :match_id, references(:matches, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :external_id, :bigint, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:match_provider_ids, [:provider, :external_id])
    create unique_index(:match_provider_ids, [:match_id, :provider])
    create index(:matches, [:league_id, :season, :home_team_id, :away_team_id, :played_at], name: :matches_provider_fixture_lookup_index)

    execute """
    INSERT INTO team_provider_ids (team_id, provider, external_id, inserted_at, updated_at)
    SELECT id, 'api_football', api_football_id, NOW(), NOW()
    FROM teams WHERE api_football_id IS NOT NULL
    """

    execute """
    INSERT INTO team_provider_ids (team_id, provider, external_id, inserted_at, updated_at)
    SELECT id, 'football_data', football_data_id, NOW(), NOW()
    FROM teams WHERE football_data_id IS NOT NULL
    """

    execute """
    INSERT INTO match_provider_ids (match_id, provider, external_id, inserted_at, updated_at)
    SELECT id, 'api_football', api_football_id, NOW(), NOW()
    FROM matches WHERE api_football_id IS NOT NULL
    """

    execute """
    INSERT INTO match_provider_ids (match_id, provider, external_id, inserted_at, updated_at)
    SELECT id, 'football_data', football_data_id, NOW(), NOW()
    FROM matches WHERE football_data_id IS NOT NULL
    """
  end

  def down do
    drop index(:matches, :matches_provider_fixture_lookup_index)
    drop table(:match_provider_ids)
    drop table(:team_provider_ids)
  end
end
