defmodule FootballBackend.Players.Player do
  use Ecto.Schema
  import Ecto.Changeset

  schema "players" do
    field :name, :string
    field :position, :string
    field :jersey_number, :integer

    belongs_to :team, FootballBackend.Teams.Team

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(name position team_id)a
  @optional_fields ~w(jersey_number)a

  def changeset(player, attrs) do
    player
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:team_id)
  end
end
