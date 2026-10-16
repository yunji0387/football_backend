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

## Connect with pgAdmin

Start the Docker Compose services with `docker compose up --build`. In pgAdmin, register a server and use these settings:

| Setting | Value |
| --- | --- |
| Name (General tab) | `Football Backend` (any label is fine) |
| Host name/address | `localhost` |
| Port | `5432` |
| Maintenance database | `football_backend_dev` |
| Username | `postgres` |
| Password | `postgres` |

The password is the local development default from `docker-compose.yml`. If pgAdmin itself is running in a container on the same Docker Compose network, use `db` for the host name instead of `localhost`. After connecting, expand **Databases → football_backend_dev → Schemas → public → Tables** to browse the application tables. The database port is exposed on the host by the `5432:5432` mapping in Compose.

## API

- `GET /api/health`
- `GET /api/teams`, `POST /api/teams`, `GET /api/teams/:id`, `PUT/PATCH /api/teams/:id`, `DELETE /api/teams/:id`
- `GET /api/players`, `POST /api/players`, `GET /api/players/:id`, `PUT/PATCH /api/players/:id`, `DELETE /api/players/:id`
- `GET /api/matches`, `POST /api/matches`, `GET /api/matches/:id`, `PUT/PATCH /api/matches/:id`, `DELETE /api/matches/:id`
- `GET /api/matches/:id/details`
- `GET /api/teams/:id/statistics`
- `GET /api/rounds?league_id=39&season=2026`
- `GET /api/standings?league_id=39&season=2026`
- `GET /api/scorers?league_id=39`
- `GET /api/leaderboards/players?metric=goals` (also `assists`, `passes`, `key_passes`, `clean_sheets`)
- `GET /api/leaderboards/teams?metric=clean_sheets` (also `played`, `wins`, `draws`, `losses`, `goals_for`, `goals_against`, `passes`, `key_passes`)

## API-Football sync

The backend syncs Premier League teams, fixtures/scores, standings, player season statistics, team statistics, fixture rounds, and selected fixture events, lineups, and statistics into PostgreSQL. Full player profiles and per-fixture player performances are not fetched. The sync runs one minute after startup and every six hours after that. Round, player season, and team statistics data is cached for 24 hours, and match detail calls are capped at three candidate fixtures per sync. API requests are spaced to stay within the free plan's per-minute limit; monitor the API's daily quota in the dashboard, especially when syncing fixture pages.

Set `API_SPORT_FOOTBALL_API_KEY` in the project `.env` file. Docker Compose passes it to the app container; never commit the key. Both data providers use the shared `FOOTBALL_SEASON` and `FOOTBALL_COMPETITION` settings. The season defaults to the current season and can be overridden explicitly; the competition defaults to `PL` (Premier League), which API-Football maps to league ID 39. `FOOTBALL_DATA_TOKEN` is only needed for the backup provider.

The existing `/api/teams` and `/api/matches` endpoints include synced records. Standings, rounds, and top scorers are available from `/api/standings`, `/api/rounds`, and `/api/scorers`; omitting `league_id` and `season` selects the configured league and current season. Player and team leaderboards are available at `/api/leaderboards/players` and `/api/leaderboards/teams`; pass a `metric` such as `goals`, `assists`, `passes`, `key_passes`, or `clean_sheets`. Team statistics are available at `/api/teams/:id/statistics`, where `:id` is the local database team ID. Fixture details are available at `/api/matches/:id/details`, where `:id` is the local database match ID. The sync does not make API-Football calls when the key is missing.

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

## football-data.org backup

If the primary API-Football sync fails, the backend attempts a football-data.org sync for the competition selected by `FOOTBALL_COMPETITION`. The free football-data.org plan delays scores and schedules, so this is intended as a continuity fallback, not a live-score source. Its match and team IDs are stored separately from API-Football IDs.

Set `FOOTBALL_DATA_TOKEN` in `.env` to enable the backup provider. Both providers follow `FOOTBALL_SEASON` (defaults to the current season) and `FOOTBALL_COMPETITION` (default `PL`). Database changes are applied by the existing migration workflow on app startup.

Provider ID mapping and deduplication behavior is documented in [Data source identity and deduplication](docs/data-source-mapping.md).

For provider endpoint and response-field comparisons, see the [API-Football reference](docs/api-football-reference.md) and the [football-data.org v4 reference](docs/football-data-reference.md).

The planned MVP reader experience and provider decisions are tracked in the [simple football app roadmap](docs/football-app-roadmap.md).
