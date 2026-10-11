defmodule FootballBackend.Football.ApiSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_football_snapshots" do
    field :endpoint, :string
    field :league_id, :integer
    field :season, :integer
    field :resource_id, :string
    field :payload, :map
    timestamps(type: :utc_datetime)
  end

  def changeset(snapshot, attrs) do
    cast(snapshot, attrs, ~w(endpoint league_id season resource_id payload)a)
    |> validate_required(~w(endpoint league_id season resource_id payload)a)
  end
end
