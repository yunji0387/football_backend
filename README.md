# Football Backend

A Phoenix (Elixir) JSON API backend for managing football teams, players, and matches.

## Stack

- Elixir 1.17 / Phoenix 1.7 (API only, no HTML/assets)
- Ecto + PostgreSQL
- Runs entirely via Docker Compose (no local Elixir install required)

## Run with Docker

```sh
docker compose up --build
```

This starts:
- `db`: PostgreSQL 16
- `app`: Phoenix server on http://localhost:4000, automatically waiting for the
  database, installing deps, creating the database, and running migrations on boot.

Seed sample data (Arsenal/Chelsea + a couple of players):

```sh
docker compose exec app mix run priv/repo/seeds.exs
```

## API

- `GET /api/health`
- `GET /api/teams`, `POST /api/teams`, `GET /api/teams/:id`, `PUT/PATCH /api/teams/:id`, `DELETE /api/teams/:id`
- `GET /api/players`, `POST /api/players`, `GET /api/players/:id`, `PUT/PATCH /api/players/:id`, `DELETE /api/players/:id`
- `GET /api/matches`, `POST /api/matches`, `GET /api/matches/:id`, `PUT/PATCH /api/matches/:id`, `DELETE /api/matches/:id`
- `GET /api/matches/:id/details`
- `GET /api/teams/:id/statistics`
- `GET /api/rounds?league_id=39&season=2026`
- `GET /api/standings?league_id=39&season=2026`

## API-Football sync

The backend syncs Premier League teams, fixtures/scores, standings, team statistics, fixture rounds, and selected fixture events, lineups, and statistics into PostgreSQL. Player data is not fetched. The sync runs one minute after startup and every six hours after that. Round and team statistics data is cached for 24 hours, and match detail calls are capped at three candidate fixtures per sync. API requests are spaced to stay within the free plan's per-minute limit; monitor the API's daily quota in the dashboard, especially when syncing fixture pages.

Set `API_SPORT_FOOTBALL_API_KEY` in the project `.env` file. Docker Compose passes it to the app container; never commit the key. The initial league ID is 39 (Premier League), and the season is selected automatically based on the current date. To test against an older season allowed by the free plan, set `API_SPORT_FOOTBALL_SEASON=2024` in `.env`; remove it to return to automatic current-season selection. To add leagues later, change `league_id` in `config/config.exs` or extend it to a configured list.

The existing `/api/teams` and `/api/matches` endpoints include synced records. Standings and rounds are available from `/api/standings` and `/api/rounds`; omitting `league_id` and `season` selects the configured league and current season. Team statistics are available at `/api/teams/:id/statistics`, where `:id` is the local database team ID. Fixture details are available at `/api/matches/:id/details`, where `:id` is the local database match ID. The sync does not make API-Football calls when the key is missing.

### TODO after upgrading the API-Football plan

- Remove `API_SPORT_FOOTBALL_SEASON` from `.env` if it was set to `2024` for free-plan testing. This restores automatic selection of the current season.
- Recreate the app container so it picks up the updated environment: `docker compose up -d --force-recreate app`.
- Run a manual sync with `docker compose exec app mix run -e 'IO.inspect(FootballBackend.Football.sync())'` and confirm it returns `:ok`.
- Verify current-season data at `/api/matches`, `/api/standings`, and `/api/rounds`. If API-Football still reports a season access error, confirm the API key belongs to the upgraded plan.

Example:

```sh
curl -X POST http://localhost:4000/api/teams \
  -H "Content-Type: application/json" \
  -d '{"team": {"name": "Real Madrid", "country": "Spain", "founded_year": 1902}}'
```

## Development

For PowerShell commands to check the API endpoints, trigger a manual API-Football sync, and run the test suite, see [the testing guide](docs/testing-guide.md).

```sh
docker compose exec app mix test
docker compose logs -f app
```

Stop and remove containers:

```sh
docker compose down
```

Stop and wipe the database volume too:

```sh
docker compose down -v
```
