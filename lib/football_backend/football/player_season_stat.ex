defmodule FootballBackend.Football.PlayerSeasonStat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "player_season_stats" do
    field :provider, :string
    field :league_id, :integer
    field :season, :integer
    field :appearances, :integer
    field :lineups, :integer
    field :minutes, :integer
    field :goals, :integer, default: 0
    field :assists, :integer
    field :penalties, :integer
    field :shots, :integer
    field :shots_on_target, :integer
    field :yellow_cards, :integer
    field :red_cards, :integer
    field :rating, :string
    field :provider_data, :map, default: %{}
    field :fetched_at, :utc_datetime

    belongs_to :player, FootballBackend.Players.Player
    belongs_to :team, FootballBackend.Teams.Team
    timestamps(type: :utc_datetime)
  end

  def changeset(stat, attrs) do
    stat
    |> cast(attrs, [:player_id, :team_id, :provider, :league_id, :season, :appearances,
      :lineups, :minutes, :goals, :assists, :penalties, :shots, :shots_on_target,
      :yellow_cards, :red_cards, :rating, :provider_data, :fetched_at])
    |> validate_required([:player_id, :team_id, :provider, :league_id, :season, :goals,
      :provider_data, :fetched_at])
    |> foreign_key_constraint(:player_id)
    |> foreign_key_constraint(:team_id)
    |> unique_constraint([:provider, :league_id, :season, :player_id, :team_id],
      name: :player_season_stats_provider_player_index
    )
  end
end
