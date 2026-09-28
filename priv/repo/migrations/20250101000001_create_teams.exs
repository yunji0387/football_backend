defmodule FootballBackend.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams) do
      add :name, :string, null: false
      add :country, :string, null: false
      add :founded_year, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:teams, [:name])
  end
end
