defmodule FootballBackend.Repo.Migrations.CreateMatches do
  use Ecto.Migration

  def change do
    create table(:matches) do
      add :home_team_id, references(:teams, on_delete: :delete_all), null: false
      add :away_team_id, references(:teams, on_delete: :delete_all), null: false
      add :home_score, :integer, null: false, default: 0
      add :away_score, :integer, null: false, default: 0
      add :played_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:matches, [:home_team_id])
    create index(:matches, [:away_team_id])
  end
end
