# Football data sync operations

## Scope and limits

The backend stores a local copy of the resources it currently imports: teams,
matches, standings, player season statistics, team season statistics, and cached
round and selected match-detail responses. This is not every resource offered by
either provider. API-Football plan access, the configured competition, and the
requested season determine what can be copied. A successful sync means the
supported requests completed; it does not mean every football league or every
historical API resource is available to the account.

The scheduled worker syncs the configured league and current season at startup
after a short delay, then on the configured six-hour interval. API-Football
player statistics are fetched one page at a time and written to PostgreSQL as
each page completes. Page progress is stored in `sync_runs`, so an interrupted
player import resumes from its last committed page at the next sync. Replaying a
page is safe because player season rows are upserted by provider, league, season,
player, and team. Existing rows are only pruned after all pages complete, so a
partial provider response does not erase the last successful data.

Other sync stages use the existing endpoint snapshots and idempotent entity
upserts. The whole sync is serialized within the running app process. The app
should run as a single sync worker when deployed; multiple app replicas do not
share the in-memory request lock.

## Counts and progress

Use `GET /api/sync/coverage` for configured league/current season counts, or pass
`league_id` and `season` explicitly:

```text
GET /api/sync/coverage?league_id=39&season=2025
```

The response reports global canonical team count; scoped match, standings, and
snapshot counts; total and provider-specific `player_season_stats` rows and
distinct players; total and provider-specific `team_season_stats` rows; and the
latest API-Football player import's status, page checkpoint, fetched record
count, saved statistic-row count, timestamps, and last error. “Fetched” counts
provider player records returned by completed pages. “Saved” counts player-team
season-stat rows persisted; a player transferred during a season can have more
than one such row. Table totals are global for the table, while scope counts are
limited to the requested league and season.

On-demand requests to scorers, player/team leaderboards, standings, rounds, or
team statistics return the current local result immediately. If no provider data
exists for that league and season, they enqueue a background sync instead of
waiting on the upstream API. Repeated misses for the same scope are coalesced and
throttled for 15 minutes. The response may therefore be empty or unavailable on
the first request; query again after progress appears in `/api/sync/coverage`.

### Example: syncing one season

For example, to sync Premier League season 2024 (API-Football league ID 39), run:

```powershell
docker compose exec app mix run -e 'IO.inspect(FootballBackend.Football.sync(39, 2024))'
```

The sync runs its supported stages for that league and season, including teams,
fixtures, standings, team statistics, and player season statistics. Player
statistics are fetched page by page. After each page is saved, the backend
updates the `sync_runs` checkpoint with the page number and fetched/saved counts.
For example, after pages 1 and 2 complete, the checkpoint records page 2 and the
cumulative counts for both pages.

If the app stops after page 2, the next sync for league 39 and season 2024 resumes
at page 3. If it stops after saving a page but before recording that page's
checkpoint, it fetches the page again; upserts make that retry safe. Once the last
page completes, the backend removes stale player-stat rows for that provider,
league, and season, stores the completed player snapshot, and marks the run
complete.

Check counts and progress with:

```text
GET http://localhost:4000/api/sync/coverage?league_id=39&season=2024
```

The response includes global table totals, counts scoped to the selected season,
and the player import's page and record progress. The scheduled worker continues
to sync the configured current season; use `sync_seasons/2` to process a chosen
list of historical seasons sequentially.

## Historical season backfill

The public function `FootballBackend.Football.sync/2` syncs one league ID and
season. `sync_seasons/2` syncs a list in ascending order and stops on the first
error, so a quota or access failure is visible and the command can be resumed
later. Example from the app container:

```powershell
docker compose exec app mix run -e 'IO.inspect(FootballBackend.Football.sync_seasons(Enum.to_list(2018..2025), 39))'
```

Choose seasons that the API key can access. Backfills use provider quota and
should be run in bounded batches. Successfully stored snapshots and player
statistics are cached for 24 hours; rerunning a season can refresh expired data.
The configured periodic worker continues to target only the configured current
season; historical seasons are explicit backfill work.

## Telegram progress notifications

Create a Telegram bot with BotFather, obtain its bot token, and obtain the
destination chat ID (for a private chat, message the bot and read the chat ID from
`getUpdates`). Set `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` in `.env`; Compose
passes them into the app. Notifications are optional. With both values set, the
backend sends a message every ten completed player pages, at the final page, and
on completion or failure. Messages include league, season, page position,
provider records fetched, and player-stat rows saved. The bot token is never
included in logs or API responses. This integration sends progress notifications;
query `/api/sync/coverage` for current status and counts.

## Deployment notes

The existing Compose entrypoint waits for PostgreSQL and runs `mix ecto.migrate`
before starting the app, so the sync progress migration is applied automatically
for this single-server Compose deployment. Keep the PostgreSQL volume persistent
and include it in database backups; `sync_runs` checkpoints are what allow an
interrupted player import to resume. A database restore should restore the
checkpoint and data from the same backup point.
