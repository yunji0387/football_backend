defmodule FootballBackend.Teams.Team do
  use Ecto.Schema
  import Ecto.Changeset

  schema "teams" do
    field :name, :string
    field :country, :string
    field :founded_year, :integer
    field :api_football_id, :integer
    field :logo, :string

    has_many :players, FootballBackend.Players.Player

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(name country)a
  @optional_fields ~w(founded_year api_football_id logo)a

  def changeset(team, attrs) do
    team
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 100)
  end
end
