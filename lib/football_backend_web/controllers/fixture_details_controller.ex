defmodule FootballBackendWeb.FixtureDetailsController do
  use FootballBackendWeb, :controller

  def show(conn, %{"id" => id}) do
    with {match_id, ""} when match_id > 0 <- Integer.parse(id) do
      case FootballBackend.Football.fixture_details(match_id) do
        nil -> conn |> put_status(:not_found) |> json(%{error: "Match details are not available"})
        details -> json(conn, %{data: details})
      end
    else
      _ -> conn |> put_status(:bad_request) |> json(%{error: "Invalid match id"})
    end
  end
end
