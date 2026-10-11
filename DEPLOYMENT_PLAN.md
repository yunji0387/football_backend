# Deployment Readiness Plan

**Estimated effort:** 4–6 working days for one engineer, assuming cloud access and credentials are available. Hosting, DNS, and credential provisioning may add calendar time.

## Implementation Sequence

| Order | Implementation | Estimate | Completion criteria |
|---|---|---:|---|
| 1 | Confirm deployment target, managed PostgreSQL option, domain/TLS requirements, API-Football key, and external API limits. | 0.5 day | Hosting target, database, required secrets, and deployment requirements are agreed. |
| 2 | Add production-relevant tests for core API flows, database behavior, and health/error handling; configure them to run in CI. | 0.5–1 day | Tests pass against a clean database, and CI blocks releases on failure. |
| 3 | Build a production Docker image using a compiled Phoenix release. Remove development bind mounts and runtime dependency fetching from the production path. | 0.75–1 day | Image builds reproducibly and starts from the release artifact. |
| 4 | Separate database migrations from application startup. Use an explicit one-off migration task or deployment release task so multiple app instances cannot race to migrate. | 0.5 day | A fresh database can be migrated before the application serves traffic. |
| 5 | Configure production runtime settings and secret injection for `DATABASE_URL`, `SECRET_KEY_BASE`, host/port, pool sizing, and optional API-Football settings. | 0.5 day | The app starts with externally supplied secrets and reports missing required configuration clearly. |
| 6 | Provision and deploy to staging with managed PostgreSQL, networking, TLS, and appropriately restricted database credentials. | 0.5–1 day | Staging is reachable over HTTPS and connects to its database. |
| 7 | Verify operations and release readiness: health/readiness checks, migrations, CRUD endpoints, standings and sync behavior, logs, restart behavior, backup/restore expectations, and rollback. | 0.5–1 day | Smoke checks pass and a recovery path is documented. |
| 8 | Deploy the validated image to production, run migrations, verify endpoints and logs, and monitor the first sync cycle. | 0.25–0.5 day | Production checks pass and the service remains healthy after restart. |

## Ready-to-Deploy Gate

Treat staging verification as the release gate. Before production deployment:

- The production image builds and starts without development bind mounts or dependency installation at startup.
- CI tests pass, and migrations have been run successfully against staging.
- Secrets are supplied by the deployment environment and are not committed to the repository.
- The service is reachable over HTTPS; health/readiness checks, logs, and restart behavior have been verified.
- API smoke tests pass, and the deployment and rollback steps are documented.
- If API-Football sync is required at launch, a real staging sync succeeds and usage is within the provider's plan limits.

## Current Deployment Gaps

- The current Docker Compose setup uses `MIX_ENV=dev`, local database credentials, and source/build/dependency volumes; it is for development rather than production.
- The current entrypoint fetches dependencies and runs database creation and migrations whenever the app starts. Production should use a built release and an explicit migration step.
- Production runtime configuration already expects `DATABASE_URL` and `SECRET_KEY_BASE`; these must be configured securely in the deployment environment.
- The current health endpoint only reports application status. Add or configure a database-aware readiness check if the hosting platform needs one before routing traffic.

## Assumptions and Scope

- Estimates are engineering effort for one engineer, not elapsed calendar time.
- The first release targets one production environment and an existing cloud account.
- API-Football sync can be optional for initial deployment unless product requirements say otherwise.
