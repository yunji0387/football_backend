# API Endpoint and Data Source Guidelines

Follow this guide whenever adding or changing an API endpoint, response shape, or football data provider integration in this repository.

## Endpoint design

Before implementation, define:

- The HTTP method and route, resource represented, accepted path/query/body parameters, and response shape.
- Expected behavior for missing, invalid, and optional values. Keep defaults explicit; do not silently replace invalid input with a default.
- Status codes and error responses for success, validation failures, missing resources, and unexpected provider failures.
- Whether the endpoint reads canonical local data or intentionally calls an upstream provider.

Keep local database IDs as the IDs exposed by the API. Provider IDs belong in provider mapping records, not in place of local IDs.

## Project architecture

- Register routes in `lib/football_backend_web/router.ex` under the appropriate API scope.
- Keep controllers thin: parse and validate request input, call a domain context, and render the response.
- Put domain rules and database queries in the relevant context (for example, `Teams` or `Matches`), not in controllers.
- Use Ecto schemas and changesets for casting and validation. Add database constraints for invariants that must hold under concurrent requests.
- Render JSON through the endpoint's JSON view/serializer and use the existing fallback-controller conventions for errors.
- Do not expose secrets, raw provider credentials, or unnecessary internal database fields in API responses.

Use consistent HTTP behavior: invalid request input should return 400, a missing local resource should return 404, validation errors should return 422, successful creation should return 201, and successful deletion should return 204, unless an established endpoint contract requires otherwise. Parse IDs and filters explicitly.

## Canonical data and multiple providers

Read [`docs/data-source-mapping.md`](docs/data-source-mapping.md) before changing provider ingestion or canonical football entities. Its mapping rules are part of the data model contract.

- Treat local teams, matches, competitions, players, and standings as canonical entities where the domain model supports that entity.
- Identify an upstream record by the pair `(provider, provider_external_id)`. Provider IDs are not interchangeable, even when their numbers happen to match.
- Before inserting an upstream team or match, look up its provider mapping. If one exists, update or link to that canonical local entity instead of creating another one.
- For a new team, use a deliberate identity-resolution flow. Names and normalized names can suggest a match, but must not silently merge records. Require a unique match; surface ambiguity for review.
- For a new match, check its provider mapping first. If absent, resolve the canonical home team, away team, competition, season, and kickoff time before deciding whether it matches an existing fixture. Do not merge ambiguous fixtures automatically.
- Keep provider-specific statistics, events, lineups, and source timestamps attributable to their provider. Do not combine conflicting provider data as though it came from one source.
- Make standings writes idempotent and respect their canonical uniqueness key (competition/league, season, and team). Keep source provenance where needed; do not overwrite one provider's row with another provider's values without an explicit policy.
- Add a database unique constraint for each provider mapping key so concurrent ingestion cannot create duplicate mappings.
- Do not add a provider-only numeric ID directly to a canonical entity as its identity unless a migration and compatibility rationale explicitly require it.
- Do not silently delete, merge, or rewrite existing entities to resolve duplicates. Use a reviewed, reversible data migration or an explicit admin repair process.

Provider fallback behavior must be explicit. A secondary provider should fill missing data only under a documented policy and must pass through the same identity checks as the primary provider. Avoid making upstream calls in a normal request path when the API can serve stored data, unless that behavior is intentional and documented.

## Database changes

- Add a reversible Ecto migration for schema changes.
- Preserve existing foreign keys and references to canonical local IDs.
- Backfill provider mappings for existing provider IDs when applicable, and make the migration safe for the current data.
- Enforce uniqueness and other durable invariants in PostgreSQL as well as in application code.
- Consider transaction boundaries and concurrent ingestion when inserting an entity and its provider mapping.

## Implementation documentation

Record important implementation details in repository Markdown as part of the same change. Update the existing document closest to the behavior, such as the README, API endpoint inventory, provider reference, data-source mapping, or operational guide. For substantial changes without a suitable home, add a focused document and link it from the README or relevant index.

Document durable information that a future maintainer or API consumer needs, including:

- New or changed API routes, parameters, response fields, validation, and examples.
- Data model changes, provider mappings, source precedence, sync behavior, and idempotency rules.
- Configuration defaults and overrides, provider coverage or quota limits, known gaps, and operational or migration steps.
- Important design decisions and their practical consequences.

Keep documentation aligned with the implemented behavior. Do not rely on chat history, commit messages, or code comments as the only record of an important decision. Avoid creating or changing documentation for routine edits that do not affect durable behavior.

## Implementation checklist

- [ ] Route and HTTP contract are clear and documented.
- [ ] Controller validates/parses input and delegates to a context.
- [ ] Context owns domain rules and database access.
- [ ] Schema/changeset and database constraints enforce valid, unique data.
- [ ] JSON response exposes local IDs and only intended fields.
- [ ] Provider ingestion checks mappings before inserting and handles ambiguous identity safely.
- [ ] Relevant Markdown documentation records important behavior, decisions, configuration, limitations, and operational steps.
- [ ] Tests are added or updated for input validation, status codes, and persistence behavior. Provider work also covers idempotent re-imports, one canonical entity associated with multiple provider IDs, and ambiguous matches.

