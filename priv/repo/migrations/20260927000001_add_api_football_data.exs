defmodule FootballBackend.Repo.Migrations.AddApiFootballData do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :api_football_id, :integer
      add :logo, :string
    end

    create unique_index(:teams, [:api_football_id])

    alter table(:matches) do
      add :api_football_id, :integer
      add :league_id, :integer, null: false, default: 39
      add :season, :integer
      add :status, :string
      add :elapsed, :integer
      add :round, :string
    end

    create unique_index(:matches, [:api_football_id])
    create index(:matches, [:league_id, :season, :played_at])

    create table(:standings) do
      add :league_id, :integer, null: false
      add :season, :integer, null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :rank, :integer, null: false
      add :points, :integer, null: false
      add :goals_diff, :integer, null: false
      add :played, :integer, null: false
      add :win, :integer, null: false
      add :draw, :integer, null: false
      add :lose, :integer, null: false
      add :goals_for, :integer, null: false
      add :goals_against, :integer, null: false
      add :form, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:standings, [:league_id, :season, :team_id])
    create index(:standings, [:league_id, :season, :rank])
  end
end
