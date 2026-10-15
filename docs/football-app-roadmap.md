# Football App Roadmap

This note records the agreed MVP direction and decisions for future review. Keep the first release focused on the configured Premier League competition.

## MVP reader experience

The first useful app should let a reader:

1. See the league table, today's matches, upcoming fixtures, and recent results.
2. Open a team page with its position/form and recent or upcoming matches.
3. Browse a top-scorers list with goals and assists.
4. Open a match page with score/status and the available goals, cards, lineups, and team statistics.

## Agreed implementation order

- [x] Preserve unavailable match scores as `null`; do not render an unplayed match as 0–0.
- [x] Import top scorers/player season statistics from both providers when available and expose a read endpoint.
- [ ] Add match list filters/useful date windows and a home-summary endpoint.
- [ ] Add team pages and match-center response shaping.
- [ ] Expose data freshness/provider information so delayed or missing backup data is clear.

## Data-source decisions

- API-Football remains the primary source because it supplies the richer team statistics, rounds, lineups, events, and match statistics used by the current backend.
- football-data.org remains the backup for core matches and standings. It may supply scorers where the account/competition supports that endpoint, but the app must tolerate the scorer resource being unavailable.
- Provider external IDs are never treated as interchangeable. Use a `player_provider_ids` mapping keyed by `(provider, external_id)` and resolve to one canonical local player.
- Keep provider-specific season statistics in rows keyed by provider, competition, season, player, and team. Do not merge conflicting provider statistics into one un-attributed record.
- When both providers have scorer data for the same competition and season, the read endpoint should return one coherent provider snapshot (prefer API-Football, fall back to football-data.org only when no primary snapshot exists) rather than duplicate leaderboard entries.
- Preserve missing score values. Existing historical zeros cannot be assumed to mean unknown; only new provider sync values can reliably distinguish null from a real 0–0.

## Current scope and known gaps

- The backend currently syncs fixtures, standings, teams, rounds, and team-season statistics from API-Football. Selected match detail requests are limited to three candidates per sync.
- The football-data.org adapter syncs matches and standings; team identity is derived from those payloads. Scorers are an optional enrichment, not required for core fallback success.
- The local `players` table/API supports basic CRUD and provider-linked players; full profile and per-fixture performance feeds are not in this milestone.
- Top-scorer ingestion is idempotent and replaces stale rows for that provider/competition/season only after a successful complete fetch.

## Review checklist

- Confirm the target plan provides the needed scorer fields and coverage.
- Confirm top-scorer rows represent players transferred between teams in a season without creating duplicate people.
- Confirm API responses expose local player/team IDs and include a `source` and `season` context.
- Confirm a provider failure leaves the last successful scorer snapshot available.
- Keep fixture scores nullable through database, schema, ingestion, and JSON response layers.
