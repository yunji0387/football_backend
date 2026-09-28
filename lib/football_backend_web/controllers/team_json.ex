defmodule FootballBackendWeb.TeamJSON do
  alias FootballBackend.Teams.Team

  def index(%{teams: teams}) do
    %{data: for(team <- teams, do: data(team))}
  end

  def show(%{team: team}) do
    %{data: data(team)}
  end

  defp data(%Team{} = team) do
    %{
      id: team.id,
      name: team.name,
      country: team.country,
      founded_year: team.founded_year,
      api_football_id: team.api_football_id,
      logo: team.logo
    }
  end
end
