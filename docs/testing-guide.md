# API and test guide

This guide includes Docker Compose commands for PowerShell and Bash. Start the app and PostgreSQL from the project directory:

```powershell
docker compose up -d --build
docker compose ps
```

```bash
docker compose up -d --build
docker compose ps
```

The API listens on `http://localhost:4000`. Check the app logs if the container is not running:

```powershell
docker compose logs -f app
```

```bash
docker compose logs -f app
```

## Test API endpoints

Use `Invoke-RestMethod` to call the endpoints and display the decoded JSON response:

```powershell
$base = "http://localhost:4000/api"
Invoke-RestMethod "$base/health"
Invoke-RestMethod "$base/teams"
Invoke-RestMethod "$base/matches"
Invoke-RestMethod "$base/standings?league_id=39&season=2024"
Invoke-RestMethod "$base/rounds?league_id=39&season=2024"
```

With Bash, use `curl` (the examples below use `jq` to extract IDs):

```bash
base="http://localhost:4000/api"
curl -sS "$base/health"
curl -sS "$base/teams"
curl -sS "$base/matches"
curl -sS "$base/standings?league_id=39&season=2024"
curl -sS "$base/rounds?league_id=39&season=2024"
```

League `39` is the Premier League. Use season `2024` when the API-Football free plan is limited to seasons 2022–2024; after upgrading, omit `season` to use the backend's configured current season.

The list responses contain a `data` array. To call the team and match detail endpoints, use the local database `id` from those arrays (not `api_football_id`):

```powershell
$teams = Invoke-RestMethod "$base/teams"
$teamId = $teams.data[0].id
Invoke-RestMethod "$base/teams/$teamId/statistics?league_id=39&season=2024"

$matches = Invoke-RestMethod "$base/matches"
$matchId = $matches.data[0].id
Invoke-RestMethod "$base/matches/$matchId/details"
```

```bash
teams=$(curl -sS "$base/teams")
team_id=$(printf '%s' "$teams" | jq -r '.data[0].id')
curl -sS "$base/teams/$team_id/statistics?league_id=39&season=2024"

matches=$(curl -sS "$base/matches")
match_id=$(printf '%s' "$matches" | jq -r '.data[0].id')
curl -sS "$base/matches/$match_id/details"
```

The team statistics endpoint returns a 404 if a snapshot is not available yet for that team and season. Fixture details may contain `null` values when the sync has not fetched details for that fixture.

Other CRUD routes are available for teams, players, and matches. For example, list a specific record with `Invoke-RestMethod "$base/teams/1"`; create/update/delete operations use `Invoke-RestMethod` with `-Method Post`, `-Method Put`/`-Method Patch`, or `-Method Delete`, and JSON bodies where required.

## Run a manual API-Football sync

Make sure `API_SPORT_FOOTBALL_API_KEY` is set in `.env` and the app service has been recreated since changing `.env`. Trigger a sync with:

```powershell
docker compose exec app mix run -e 'IO.inspect(FootballBackend.Football.sync())'
```

```bash
docker compose exec app mix run -e 'IO.inspect(FootballBackend.Football.sync())'
```

It should return `:ok` and the app log should include `API-Football sync completed`. A sync uses API requests, so check your daily quota before repeating it. The scheduled worker also syncs after startup and then every six hours.

## Run the Elixir test suite

With the Compose services available, run:

```powershell
docker compose exec app mix test
```

```bash
docker compose exec app mix test
```

To run tests whenever files change, start the command again after editing. If tests need a newly rebuilt image or dependency changes, use:

```powershell
docker compose up -d --build app
docker compose exec app mix test
```

```bash
docker compose up -d --build app
docker compose exec app mix test
```

