defmodule FootballBackend.Repo.Migrations.CreateSyncRuns do
  use Ecto.Migration

  def change do
    create table(:sync_runs) do
      add :provider, :string, null: false
      add :resource, :string, null: false
      add :league_id, :integer, null: false
      add :season, :integer, null: false
      add :status, :string, null: false, default: "running"
      add :current_page, :integer, null: false, default: 0
      add :total_pages, :integer
      add :records_fetched, :integer, null: false, default: 0
      add :records_saved, :integer, null: false, default: 0
      add :error, :text
      add :started_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:sync_runs, [:provider, :resource, :league_id, :season, :inserted_at])
    create index(:sync_runs, [:status, :updated_at])
  end
end
