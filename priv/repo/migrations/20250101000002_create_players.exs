defmodule FootballBackend.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players) do
      add :name, :string, null: false
      add :position, :string, null: false
      add :jersey_number, :integer
      add :team_id, references(:teams, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:players, [:team_id])
  end
end
