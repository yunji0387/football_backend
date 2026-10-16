# football-data.org API v4 Reference

This is a repository-side field reference for comparing football-data.org v4 responses with [`api-football-reference.md`](api-football-reference.md). It focuses on the football resources relevant to this backend; it is not a verbatim copy of the provider's exhaustive reference. Field lists and examples are based on the [official v4 documentation](https://docs.football-data.org/general/v4/index.html).

## API basics

- **Base URL:** `https://api.football-data.org/v4`
- **Method:** `GET`
- **Authentication:** send the token in the `X-Auth-Token` request header.
- **Content:** JSON.
- **Premier League competition code:** `PL`.
- **Season filter:** a four-digit starting year, e.g. `2024`; omit it when you want the API's default current season.

```http
GET /competitions/PL/matches?season=2024 HTTP/1.1
Host: api.football-data.org
X-Auth-Token: YOUR_TOKEN
```

The provider documents request and response headers, filters, and resource conventions in [Lookup Tables](https://docs.football-data.org/general/v4/lookup_tables.html) and [Resources](https://docs.football-data.org/general/v4/resources.html). List responses commonly include `filters` plus the list resource; match lists also include `resultSet`. Exact response fields vary by resource and unfold headers.

## Resource and endpoint index

| Resource | Method and URI | Purpose |
| --- | --- | --- |
| Competitions | `GET /competitions` | List competitions available to the token. |
| Competition | `GET /competitions/{code}` | Competition metadata and seasons. |
| Competition teams | `GET /competitions/{code}/teams?season={year}` | Teams participating in a competition season. |
| Competition matches | `GET /competitions/{code}/matches?season={year}` | Fixtures and results for a competition season. |
| Competition standings | `GET /competitions/{code}/standings?season={year}` | Standings tables for a competition. |
| Competition scorers | `GET /competitions/{code}/scorers?season={year}` | Top scorers for a competition season. |
| Team | `GET /teams/{id}` | Team details, current squad, running competitions, and coach where available. |
| Team matches | `GET /teams/{id}/matches` | Matches filtered to a team. |
| Match | `GET /matches/{id}` | One match and its available details. |
| Person | `GET /persons/{id}` | Person/player profile. |
| Person matches | `GET /persons/{id}/matches` | Matches involving a person, with filters. |

See the official [Competition](https://docs.football-data.org/general/v4/competition.html), [Team](https://docs.football-data.org/general/v4/team.html), [Match](https://docs.football-data.org/general/v4/match.html), and [Person](https://docs.football-data.org/general/v4/person.html) resource references for full filters and provider-specific behavior.

## Teams

### Competition teams

`GET /competitions/{code}/teams?season={year}` returns a list resource with competition and season context and a `teams` array. Team fields commonly include:

| Field | Meaning |
| --- | --- |
| `id` | football-data.org team ID. |
| `name` | Full provider team name. |
| `shortName` | Provider's short display name. |
| `tla` | Three-letter abbreviation. |
| `crest` | Team crest URL. |
| `area` | Area/country object when included. |
| `address`, `website`, `founded`, `clubColors`, `venue` | Additional team profile data when available in this representation. |
| `coach`, `squad`, `staff`, `lastUpdated` | Extended team data; availability depends on resource and access. |

### Representative shape

```json
{
  "count": 20,
  "filters": { "season": "2024" },
  "competition": { "id": 2021, "name": "Premier League", "code": "PL" },
  "season": { "id": 0000, "startDate": "...", "endDate": "..." },
  "teams": [
    {
      "id": 66,
      "name": "Manchester United FC",
      "shortName": "Man United",
      "tla": "MUN",
      "crest": "https://..."
    }
  ]
}
```

This is a field-shape illustration, not a captured response; omitted fields and returned teams depend on the request and account access. The full [Team reference](https://docs.football-data.org/general/v4/team.html) shows a single-team representation.

## Matches

### Competition match list

`GET /competitions/{code}/matches` supports filters including `season`, `matchday`, `stage`, `group`, `status`, `dateFrom`, and `dateTo`. List responses use `matches[]`; the match object commonly has:

| Field | Meaning |
| --- | --- |
| `id` | football-data.org match ID. |
| `utcDate` | Kickoff timestamp in UTC. |
| `status`, `minute`, `injuryTime` | Match state and elapsed-time details when available. |
| `competition`, `season`, `area` | Competition and season context. |
| `matchday`, `stage`, `group` | Competition scheduling context. |
| `homeTeam`, `awayTeam` | Team objects (IDs and display names, plus available team metadata). |
| `score` | Winner, duration, full-time and half-time scores; extra-time/penalty scores can also be present. |
| `venue`, `attendance`, `referees`, `lastUpdated` | Additional match details when supplied. |

### Representative shape

```json
{
  "filters": { "season": "2024" },
  "resultSet": { "count": 380, "first": "...", "last": "...", "played": 0 },
  "competition": { "id": 2021, "name": "Premier League", "code": "PL" },
  "matches": [
    {
      "id": 000000,
      "utcDate": "...",
      "status": "FINISHED",
      "matchday": 1,
      "homeTeam": { "id": 65, "name": "Manchester City FC", "shortName": "Man City" },
      "awayTeam": { "id": 66, "name": "Manchester United FC", "shortName": "Man United" },
      "score": {
        "winner": "HOME_TEAM",
        "duration": "REGULAR",
        "fullTime": { "home": 2, "away": 1 },
        "halfTime": { "home": 1, "away": 0 }
      }
    }
  ]
}
```

`score` values may be `null` before the match has been played. Do not interpret missing scores as 0–0. The official [Match reference](https://docs.football-data.org/general/v4/match.html) explains score durations and match statuses. Match lists fold some deeper detail by default; supported `X-Unfold-*` headers can request lineups, bookings, substitutions, and goals where available. See [Lookup Tables](https://docs.football-data.org/general/v4/lookup_tables.html).

## Standings

`GET /competitions/{code}/standings` supports `season`, `matchday`, and `date` filters. The response includes competition and season context and a `standings[]` array. Each standings entry has a `stage`, `type`, optional `group`, and `table[]`.

Common table row fields:

| Field | Meaning |
| --- | --- |
| `position` | Rank. |
| `team` | Team object. |
| `playedGames`, `won`, `draw`, `lost` | Played and result counts. |
| `points` | League points. |
| `goalsFor`, `goalsAgainst`, `goalDifference` | Goals and goal difference. |
| `form` | Recent form string when available. |

The API may return different table types such as `TOTAL`, `HOME`, and `AWAY`; consumers should select the intended table type explicitly.

```json
{
  "competition": { "id": 2021, "name": "Premier League", "code": "PL" },
  "season": { "id": 0000, "startDate": "...", "endDate": "..." },
  "standings": [
    {
      "stage": "REGULAR_SEASON",
      "type": "TOTAL",
      "group": null,
      "table": [
        {
          "position": 1,
          "team": { "id": 65, "name": "Manchester City FC" },
          "playedGames": 38,
          "won": 28,
          "draw": 7,
          "lost": 3,
          "points": 91,
          "goalsFor": 96,
          "goalsAgainst": 34,
          "goalDifference": 62,
          "form": "..."
        }
      ]
    }
  ]
}
```

See the [Competition reference](https://docs.football-data.org/general/v4/competition.html) for the standings subresource.

## Scorers and people

- `GET /competitions/{code}/scorers` returns a competition/season context and a `scorers[]` list. Scorer records include a person, team, goals, and potentially assists, penalties, and played-match counts, subject to availability and access.
- `GET /persons/{id}` returns person profile data. The provider uses `Person` rather than `Player`, because the resource can include referees and coaches as well as players.
- `GET /persons/{id}/matches` returns a match list and supports person-related filters such as lineup and events.

These are not a one-to-one replacement for API-Football's full player season statistics and fixture-player performance endpoints. Check competition coverage and plan access before depending on them. See [Person](https://docs.football-data.org/general/v4/person.html) and the [Quickstart](https://www.football-data.org/documentation/quickstart).

## Field mapping to API-Football

| Canonical concept | API-Football v3 | football-data.org v4 | Mapping note |
| --- | --- | --- | --- |
| Provider entity ID | `team.id`, `fixture.id` | `team.id`, `match.id` | Store each ID with its provider; never equate numeric IDs between providers. |
| Team display name | `team.name` | `team.name` | Names can differ, e.g. `Manchester United` vs `Manchester United FC`; use the provider mapping/curated alias flow to resolve identity. |
| Team abbreviation | `team.code` | `team.tla` | Both are provider values; do not assume codes always match. |
| Team logo | `team.logo` | `team.crest` | Provider-hosted image URLs. |
| Match kickoff | `fixture.date` | `utcDate` | Both are timestamps; football-data names it explicitly as UTC. |
| Match status | `fixture.status.short` / `.long` | `status` | Different enums; normalize through an explicit status mapping. |
| Home/away participants | `teams.home` / `teams.away` | `homeTeam` / `awayTeam` | Similar concept, different structure and field names. |
| Full-time score | `goals.home/away` and `score.fulltime` | `score.fullTime.home/away` | May be absent/null for unplayed matches; preserve that state. |
| Standings rank | `rank` | `position` | Same concept, different field name. |
| Standings results | `all.played/win/draw/lose` | `playedGames/won/draw/lost` | API-Football nests aggregate stats; football-data uses flat row fields and distinct table types. |
| Goals for/against | `all.goals.for/against` | `goalsFor/goalsAgainst` | Different nesting. |

## Differences from API-Football response envelopes

API-Football commonly wraps results in `get`, `parameters`, `errors`, `results`, `paging`, and `response`. football-data.org uses resource-specific top-level fields such as `filters`, `competition`, `season`, `resultSet`, `matches`, `teams`, or `standings`. Do not share a raw JSON decoder between providers; map each provider response into the backend's canonical schema.

football-data.org match data is also selectively unfolded: deeper fields such as goals, bookings, substitutions, and lineups may require headers and may not be available for every competition/plan. API-Football exposes separate fixture endpoints for events, lineups, statistics, and fixture player performances. The two providers therefore differ in both response shape and coverage, not just field names.

## Backend implementation note

The current football-data adapter requests competition matches and standings, extracts teams from those responses, maps provider IDs to canonical teams/matches, and imports the `TOTAL` standings table. It does not currently request `/competitions/{code}/teams`, scorer lists, person details, match unfolding headers, or API-Football-style fixture statistics/events/lineups. For identity and duplicate handling, follow [`data-source-mapping.md`](data-source-mapping.md).


## Request size and quota visibility

Successful football-data.org responses are logged with the endpoint path and the
number of returned matches, scorers, teams, or standings rows. When present, the
log also includes X-RequestsAvailable (remaining requests) and
X-RequestCounter-Reset (seconds until the counter resets). These values show
response sizes and the provider's current request budget without logging the
authentication token.
