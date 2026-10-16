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
    field :clean_sheets, :integer
    field :passes, :integer
    field :key_passes, :integer
    field :yellow_cards, :integer
    field :red_cards, :integer
    field :rating, :string
    field :player_profile, :map
    field :league_data, :map
    field :team_data, :map
    field :games_data, :map
    field :substitutes_data, :map
    field :shots_data, :map
    field :goals_data, :map
    field :passes_data, :map
    field :tackles_data, :map
    field :duels_data, :map
    field :dribbles_data, :map
    field :fouls_data, :map
    field :cards_data, :map
    field :penalty_data, :map
    field :offsides, :integer
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
      :clean_sheets, :passes, :key_passes, :yellow_cards, :red_cards, :rating,
      :player_profile, :league_data, :team_data, :games_data, :substitutes_data,
      :shots_data, :goals_data, :passes_data, :tackles_data, :duels_data,
      :dribbles_data, :fouls_data, :cards_data, :penalty_data, :offsides,
      :provider_data, :fetched_at])
    |> validate_required([:player_id, :team_id, :provider, :league_id, :season, :goals,
      :provider_data, :fetched_at])
    |> foreign_key_constraint(:player_id)
    |> foreign_key_constraint(:team_id)
    |> unique_constraint([:provider, :league_id, :season, :player_id, :team_id],
      name: :player_season_stats_provider_player_index
    )
  end
end
