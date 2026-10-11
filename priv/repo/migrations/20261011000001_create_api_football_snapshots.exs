defmodule FootballBackend.Repo.Migrations.CreateApiFootballSnapshots do
  use Ecto.Migration

  def change do
    create table(:api_football_snapshots) do
      add :endpoint, :string, null: false
      add :league_id, :integer, null: false
      add :season, :integer, null: false
      add :resource_id, :string, null: false
      add :payload, :map, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:api_football_snapshots, [:endpoint, :league_id, :season, :resource_id],
      name: :api_football_snapshots_resource_index
    )
  end
end
