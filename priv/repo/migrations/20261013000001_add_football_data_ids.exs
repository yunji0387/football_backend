defmodule FootballBackend.Repo.Migrations.AddFootballDataIds do
  use Ecto.Migration

  def change do
    alter table(:teams), do: add(:football_data_id, :integer)
    alter table(:matches), do: add(:football_data_id, :integer)

    create unique_index(:teams, [:football_data_id])
    create unique_index(:matches, [:football_data_id])
  end
end
