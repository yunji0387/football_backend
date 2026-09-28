defmodule FootballBackendWeb.PlayerJSON do
  alias FootballBackend.Players.Player

  def index(%{players: players}) do
    %{data: for(player <- players, do: data(player))}
  end

  def show(%{player: player}) do
    %{data: data(player)}
  end

  defp data(%Player{} = player) do
    %{
      id: player.id,
      name: player.name,
      position: player.position,
      jersey_number: player.jersey_number,
      team_id: player.team_id
    }
  end
end
