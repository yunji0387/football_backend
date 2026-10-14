defmodule FootballBackend.Football.MatchProviderId do
  use Ecto.Schema
  import Ecto.Changeset

  alias FootballBackend.Matches.Match

  schema "match_provider_ids" do
    field :provider, :string
    field :external_id, :integer
    belongs_to :match, Match
    timestamps(type: :utc_datetime)
  end

  def changeset(mapping, attrs) do
    mapping
    |> cast(attrs, [:match_id, :provider, :external_id])
    |> validate_required([:match_id, :provider, :external_id])
    |> unique_constraint([:provider, :external_id])
    |> unique_constraint([:match_id, :provider])
    |> foreign_key_constraint(:match_id)
  end
end
