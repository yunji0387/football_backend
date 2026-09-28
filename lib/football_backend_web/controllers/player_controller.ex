defmodule FootballBackendWeb.PlayerController do
  use FootballBackendWeb, :controller

  alias FootballBackend.Players
  alias FootballBackend.Players.Player

  action_fallback FootballBackendWeb.FallbackController

  def index(conn, _params) do
    players = Players.list_players()
    render(conn, :index, players: players)
  end

  def create(conn, %{"player" => player_params}) do
    with {:ok, %Player{} = player} <- Players.create_player(player_params) do
      conn
      |> put_status(:created)
      |> render(:show, player: player)
    end
  end

  def show(conn, %{"id" => id}) do
    player = Players.get_player!(id)
    render(conn, :show, player: player)
  end

  def update(conn, %{"id" => id, "player" => player_params}) do
    player = Players.get_player!(id)

    with {:ok, %Player{} = player} <- Players.update_player(player, player_params) do
      render(conn, :show, player: player)
    end
  end

  def delete(conn, %{"id" => id}) do
    player = Players.get_player!(id)

    with {:ok, %Player{}} <- Players.delete_player(player) do
      send_resp(conn, :no_content, "")
    end
  end
end
