defmodule FootballBackend.Football.TeamSeasonStat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "team_season_stats" do
    field :provider, :string
    field :league_id, :integer
    field :season, :integer
    field :played, :integer
    field :wins, :integer
    field :draws, :integer
    field :losses, :integer
    field :goals_for, :integer
    field :goals_against, :integer
    field :clean_sheets, :integer
    field :passes, :integer
    field :key_passes, :integer
    field :league_data, :map
    field :team_data, :map
    field :fixtures_data, :map
    field :goals_data, :map
    field :biggest_data, :map
    field :clean_sheet_data, :map
    field :failed_to_score_data, :map
    field :penalty_data, :map
    field :lineups_data, :map
    field :cards_data, :map
    field :form, :string
    field :provider_data, :map, default: %{}
    field :fetched_at, :utc_datetime

    belongs_to :team, FootballBackend.Teams.Team
    timestamps(type: :utc_datetime)
  end

  def changeset(stat, attrs) do
    stat
    |> cast(attrs, [:team_id, :provider, :league_id, :season, :played, :wins,
      :draws, :losses, :goals_for, :goals_against, :clean_sheets, :passes,
      :key_passes, :league_data, :team_data, :fixtures_data, :goals_data,
      :biggest_data, :clean_sheet_data, :failed_to_score_data, :penalty_data,
      :lineups_data, :cards_data, :form, :provider_data, :fetched_at])
    |> validate_required([:team_id, :provider, :league_id, :season, :provider_data, :fetched_at])
    |> foreign_key_constraint(:team_id)
    |> unique_constraint([:provider, :league_id, :season, :team_id],
      name: :team_season_stats_provider_team_index
    )
  end
end
