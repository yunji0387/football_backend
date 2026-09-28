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
- `GET /api/standings?league_id=39&season=2026`

## API-Football sync

The backend syncs Premier League teams, fixtures/scores, and standings from API-Football into PostgreSQL. Player data is not fetched. The sync runs one minute after startup and every six hours after that. Fixtures may be fetched in pages; teams and standings are fetched once per page. This schedule is intended to keep API usage comfortably below the free plan's 100 requests per day, including fixture pagination.

Set `API_SPORT_FOOTBALL_API_KEY` in the project `.env` file. Docker Compose passes it to the app container; never commit the key. The initial league ID is 39 (Premier League), and the season is selected automatically based on the current date. To test against an older season allowed by the free plan, set `API_SPORT_FOOTBALL_SEASON=2024` in `.env`; remove it to return to automatic current-season selection. To add leagues later, change `league_id` in `config/config.exs` or extend it to a configured list.

The existing `/api/teams` and `/api/matches` endpoints include synced records. Standings are available from `/api/standings`; omitting `league_id` and `season` selects the configured league and current season. The sync does not make API-Football calls when the key is missing.

### TODO after upgrading the API-Football plan

- Remove `API_SPORT_FOOTBALL_SEASON` from `.env` if it was set to `2024` for free-plan testing. This restores automatic selection of the current season.
- Recreate the app container so it picks up the updated environment: `docker compose up -d --force-recreate app`.
- Run a manual sync with `docker compose exec app mix run -e 'IO.inspect(FootballBackend.Football.sync())'` and confirm it returns `:ok`.
- Verify current-season data at `/api/matches` and `/api/standings`. If API-Football still reports a season access error, confirm the API key belongs to the upgraded plan.

Example:

```sh
curl -X POST http://localhost:4000/api/teams \
  -H "Content-Type: application/json" \
  -d '{"team": {"name": "Real Madrid", "country": "Spain", "founded_year": 1902}}'
```

## Development

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
