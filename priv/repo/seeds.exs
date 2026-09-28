alias FootballBackend.{Repo, Teams.Team, Players.Player}

{:ok, arsenal} =
  %Team{}
  |> Team.changeset(%{name: "Arsenal", country: "England", founded_year: 1886})
  |> Repo.insert(on_conflict: :nothing)

{:ok, chelsea} =
  %Team{}
  |> Team.changeset(%{name: "Chelsea", country: "England", founded_year: 1905})
  |> Repo.insert(on_conflict: :nothing)

%Player{}
|> Player.changeset(%{name: "Bukayo Saka", position: "Forward", jersey_number: 7, team_id: arsenal.id})
|> Repo.insert(on_conflict: :nothing)

%Player{}
|> Player.changeset(%{name: "Cole Palmer", position: "Midfielder", jersey_number: 20, team_id: chelsea.id})
|> Repo.insert(on_conflict: :nothing)
