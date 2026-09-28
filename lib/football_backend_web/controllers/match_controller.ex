defmodule FootballBackendWeb.MatchController do
  use FootballBackendWeb, :controller

  alias FootballBackend.Matches
  alias FootballBackend.Matches.Match

  action_fallback FootballBackendWeb.FallbackController

  def index(conn, _params) do
    matches = Matches.list_matches()
    render(conn, :index, matches: matches)
  end

  def create(conn, %{"match" => match_params}) do
    with {:ok, %Match{} = match} <- Matches.create_match(match_params) do
      conn
      |> put_status(:created)
      |> render(:show, match: match)
    end
  end

  def show(conn, %{"id" => id}) do
    match = Matches.get_match!(id)
    render(conn, :show, match: match)
  end

  def update(conn, %{"id" => id, "match" => match_params}) do
    match = Matches.get_match!(id)

    with {:ok, %Match{} = match} <- Matches.update_match(match, match_params) do
      render(conn, :show, match: match)
    end
  end

  def delete(conn, %{"id" => id}) do
    match = Matches.get_match!(id)

    with {:ok, %Match{}} <- Matches.delete_match(match) do
      send_resp(conn, :no_content, "")
    end
  end
end
