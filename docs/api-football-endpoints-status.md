# API-Football Endpoints and Implementation Status

This inventory is based on [`api-football-reference.md`](api-football-reference.md), generated from the API-Football OpenAPI 3.9.3 definition. It compares the provider's documented GET endpoints with the current implementation in this backend.

**Status key:**

- **Implemented** — this backend calls the provider endpoint during scheduled sync and stores the resulting data in PostgreSQL.
- **Not implemented** — this backend does not currently call the provider endpoint.

| API-Football endpoint | Data provided | Status in this backend | Local backend route / notes |
| --- | --- | --- | --- |
| `GET /timezone` | Supported time zones | Not implemented | — |
| `GET /countries` | Countries with covered leagues | Not implemented | — |
| `GET /leagues` | Leagues, seasons, and coverage | Not implemented | League ID is currently configured as `39` (Premier League). |
| `GET /leagues/seasons` | Available season years | Not implemented | Season is selected automatically, with an optional `.env` override. |
| `GET /teams` | League teams and team details | **Implemented** | Synced to PostgreSQL; exposed by `GET /api/teams`. |
| `GET /teams/statistics` | Team statistics for a league season | **Implemented** | Cached daily; exposed by `GET /api/teams/:id/statistics` using the local team ID. |
| `GET /teams/seasons` | Seasons available for a team | Not implemented | — |
| `GET /teams/countries` | Countries associated with teams | Not implemented | — |
| `GET /venues` | Venue details | Not implemented | — |
| `GET /standings` | League table and team records | **Implemented** | Synced to PostgreSQL; exposed by `GET /api/standings`. |
| `GET /fixtures/rounds` | Rounds for a league season | **Implemented** | Cached daily; exposed by `GET /api/rounds`. |
| `GET /fixtures` | Fixtures, dates, statuses, and scores | **Implemented** | Synced to PostgreSQL; exposed by `GET /api/matches`. |
| `GET /fixtures/headtohead` | Head-to-head fixtures between teams | Not implemented | — |
| `GET /fixtures/statistics` | Match statistics | **Implemented** | Cached for selected recent/upcoming matches; returned by `GET /api/matches/:id/details`. |
| `GET /fixtures/events` | Goals, cards, and substitutions | **Implemented** | Cached for selected live/recent matches; returned by `GET /api/matches/:id/details`. |
| `GET /fixtures/lineups` | Starting lineups and formations | **Implemented** | Cached for selected upcoming/recent matches; returned by `GET /api/matches/:id/details`. |
| `GET /fixtures/players` | Player performances for a fixture | Not implemented | Player data was deferred from the first version. |
| `GET /injuries` | Injuries and unavailable players | Not implemented | — |
| `GET /predictions` | Fixture predictions | Not implemented | — |
| `GET /coachs` | Coaches and coach details | Not implemented | — |
| `GET /players/seasons` | Seasons available for a player | Not implemented | Player data was deferred from the first version. |
| `GET /players/profiles` | Player profiles | Not implemented | Player data was deferred from the first version. |
| `GET /players` | Player profiles and season statistics | **Implemented** | Full league-season player statistics are paginated and imported to `player_season_stats`; cached daily. |
| `GET /players/squads` | Current squad members for a team | Not implemented | Player data was deferred from the first version. |
| `GET /players/teams` | Teams associated with a player | Not implemented | Player data was deferred from the first version. |
| `GET /players/topscorers` | League top scorers | Not called | `GET /api/scorers` and player goal/assist boards use the full season statistics imported through `GET /players`. |
| `GET /players/topassists` | League top assists | Not called | Assists are read from full season statistics imported through `GET /players`. |
| `GET /players/topyellowcards` | Players with the most yellow cards | Not implemented | Player data was deferred from the first version. |
| `GET /players/topredcards` | Players with the most red cards | Not implemented | Player data was deferred from the first version. |
| `GET /transfers` | Player transfer history | Not implemented | — |
| `GET /trophies` | Player and coach trophies | Not implemented | — |
| `GET /sidelined` | Injured or suspended players | Not implemented | — |
| `GET /odds/live` | Live odds for fixtures in progress | Not implemented | — |
| `GET /odds/live/bets` | Available live odds bet types | Not implemented | — |
| `GET /odds` | Pre-match odds | Not implemented | — |
| `GET /odds/mapping` | Fixture mapping for odds | Not implemented | — |
| `GET /odds/bookmakers` | Available bookmakers | Not implemented | — |
| `GET /odds/bets` | Available pre-match bet types | Not implemented | — |

## Current sync scope

The scheduled sync calls `GET /teams`, `GET /fixtures`, `GET /standings`, `GET /players`, `GET /teams/statistics`, `GET /fixtures/rounds`, `GET /fixtures/events`, `GET /fixtures/lineups`, and `GET /fixtures/statistics` for the configured league and season. Player season statistics and team statistics are cached in PostgreSQL; player season stats are refreshed daily and imported only after all pages are fetched successfully. Match detail calls are limited to three candidate fixtures per sync, with endpoint-specific caching, to control API usage. Full player profile records and fixture player performance endpoints are not fetched. The app's local `/api/players` CRUD routes remain separate from the league scorer feed.
