defmodule FootballBackend.Football.Standing do
  use Ecto.Schema
  import Ecto.Changeset

  schema "standings" do
    field :league_id, :integer
    field :season, :integer
    field :rank, :integer
    field :points, :integer
    field :goals_diff, :integer
    field :played, :integer
    field :win, :integer
    field :draw, :integer
    field :lose, :integer
    field :goals_for, :integer
    field :goals_against, :integer
    field :form, :string
    belongs_to :team, FootballBackend.Teams.Team
    timestamps(type: :utc_datetime)
  end

  def changeset(standing, attrs) do
    cast(standing, attrs, ~w(league_id season team_id rank points goals_diff played win draw lose goals_for goals_against form)a)
    |> validate_required(~w(league_id season team_id rank points goals_diff played win draw lose goals_for goals_against)a)
    |> foreign_key_constraint(:team_id)
  end
end
