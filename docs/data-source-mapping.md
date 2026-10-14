# Data source identity and deduplication

## Decision

The database keeps one canonical local team and match record while allowing each provider to have its own external ID. Provider IDs live in `team_provider_ids` and `match_provider_ids`, keyed uniquely by `(provider, external_id)`. This lets the API-Football and football-data.org records point to the same local entity without treating provider IDs as interchangeable.

Provider names used in these tables are `api_football` and `football_data`. The legacy `api_football_id` and `football_data_id` columns remain for existing API responses and compatibility; the mapping tables are the lookup source for synchronization. The migration backfills mapping rows from those columns.

## Team import flow

For every imported team, the sync:

1. Looks up `(provider, external_id)` in `team_provider_ids`. If found, it updates and reuses that canonical team.
2. If not found, it compares the provider's name with existing team names using normalized spelling and the curated Premier League aliases in `FootballBackend.Football.ProviderMappings`.
3. Links the provider ID to the sole matching local team, or creates a local team if no candidate exists.
4. Stops with an ambiguity error if more than one team matches. It does not guess between candidates.

The alias rules cover common provider naming differences such as “Manchester United FC” / “Manchester United”, “AFC Bournemouth” / “Bournemouth”, and “Wolverhampton Wanderers” / “Wolves”. Alias normalization is only used to find a candidate; the provider ID mapping records the durable identity link.

## Match import flow

For every imported fixture, the sync:

1. Looks up `(provider, external_id)` in `match_provider_ids` and reuses that local match if it exists.
2. Otherwise resolves both teams through `team_provider_ids`.
3. Searches for one existing fixture with the same competition, season, home team, away team, and kickoff within six hours. A unique candidate is reused and linked to the provider ID.
4. Creates a local match only when no candidate exists. If multiple candidates exist, it stops with an ambiguity error.

Unique database indexes prevent one provider ID from being linked to multiple local rows, and each local row can have at most one ID per provider. Repeated syncs therefore update the mapped record rather than insert another one.

## Standings and provider-specific detail

Standings are upserted by the existing `(league_id, season, team_id)` key, so a fallback refresh updates the current local table instead of adding duplicate rows. The source that supplied the latest table is not currently preserved as a separate snapshot. If the product later needs to compare providers or retain each provider's history, standings should become provider-specific snapshots keyed by provider, competition, season, and retrieval time.

Match events, lineups, team statistics, and similar details remain provider-specific snapshots and are not merged across providers.

## Existing data

The provider mapping migration backfills identities from the legacy provider ID columns. It does not delete or automatically merge any pre-existing duplicate local teams or matches. Review and reconcile any such rows before deleting them, because players, standings, fixtures, and provider snapshots may reference those IDs.
