defmodule FootballBackend.Football.TeamProviderId do
  use Ecto.Schema
  import Ecto.Changeset

  alias FootballBackend.Teams.Team

  schema "team_provider_ids" do
    field :provider, :string
    field :external_id, :integer
    belongs_to :team, Team
    timestamps(type: :utc_datetime)
  end

  def changeset(mapping, attrs) do
    mapping
    |> cast(attrs, [:team_id, :provider, :external_id])
    |> validate_required([:team_id, :provider, :external_id])
    |> unique_constraint([:provider, :external_id])
    |> unique_constraint([:team_id, :provider])
    |> foreign_key_constraint(:team_id)
  end
end
