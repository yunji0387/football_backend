defmodule FootballBackend.Matches.Match do
  use Ecto.Schema
  import Ecto.Changeset

  schema "matches" do
    field :played_at, :utc_datetime
    field :home_score, :integer, default: 0
    field :away_score, :integer, default: 0
    field :api_football_id, :integer
    field :league_id, :integer, default: 39
    field :season, :integer
    field :status, :string
    field :elapsed, :integer
    field :round, :string

    belongs_to :home_team, FootballBackend.Teams.Team
    belongs_to :away_team, FootballBackend.Teams.Team

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(home_team_id away_team_id played_at)a
  @optional_fields ~w(home_score away_score api_football_id league_id season status elapsed round)a

  def changeset(match, attrs) do
    match
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:home_team_id)
    |> foreign_key_constraint(:away_team_id)
  end
end
