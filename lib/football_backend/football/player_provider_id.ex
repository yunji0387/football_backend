defmodule FootballBackend.Football.PlayerProviderId do
  use Ecto.Schema
  import Ecto.Changeset

  schema "player_provider_ids" do
    field :provider, :string
    field :external_id, :integer
    belongs_to :player, FootballBackend.Players.Player
    timestamps(type: :utc_datetime)
  end

  def changeset(mapping, attrs) do
    mapping
    |> cast(attrs, [:player_id, :provider, :external_id])
    |> validate_required([:player_id, :provider, :external_id])
    |> unique_constraint([:provider, :external_id])
    |> unique_constraint([:player_id, :provider])
  end
end
