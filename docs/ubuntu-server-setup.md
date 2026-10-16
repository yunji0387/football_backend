# Ubuntu server setup and football sync runbook

This guide runs the current Docker Compose app as a private, single-server
football sync service. It keeps PostgreSQL and the API bound to the Ubuntu host's
loopback interface; administer it over SSH. The repository's Compose app uses
`MIX_ENV=dev`, source bind mounts, development database settings, and dependency
installation at startup. Use a production release and HTTPS reverse proxy before
making the API public. See [`DEPLOYMENT_PLAN.md`](DEPLOYMENT_PLAN.md) for that
work.

## 1. Prepare Ubuntu

Use a supported 64-bit Ubuntu LTS release, an SSH account with `sudo`, and enough
disk space for the PostgreSQL volume, Docker images, and backups. Docker's current
Ubuntu guide lists supported LTS releases and architectures; check it if your
server uses an Ubuntu derivative or a nonstandard architecture:
[Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

Update the system and install the tools used below:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y ca-certificates curl git jq ufw
```

Allow SSH before enabling UFW so the current SSH connection is not locked out:

```bash
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw status verbose
```

Docker-published ports can bypass UFW rules. The Compose port bindings below use
`127.0.0.1` so the API and database are reachable from the server and an SSH
tunnel, but are not published on the server's network interfaces. See Docker's
[firewall guidance](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
and [port publishing reference](https://docs.docker.com/engine/network/port-publishing/).

## 2. Install Docker Engine and Compose

Use Docker's APT repository rather than the convenience installer. The following
commands follow [Docker's official Ubuntu instructions](https://docs.docker.com/engine/install/ubuntu/):

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker run --rm hello-world
sudo docker compose version
```

Use `sudo` for Docker commands in this guide. Membership in the `docker` group
grants root-equivalent control of the host; only add trusted administrators to
it. Docker starts on boot on Ubuntu when installed as a service; the app and
database containers also use `restart: unless-stopped`.

## 3. Get the repository and set secrets

Clone the repository using your own Git URL (and SSH key if it is private):

```bash
mkdir -p ~/apps
cd ~/apps
git clone <your-repository-url> football_backend
cd football_backend
cp .env.example .env
chmod 600 .env
nano .env
```

Set the database and provider values in `.env`:

Generate a database password and copy its output into the `DB_PASSWORD` line:

```bash
openssl rand -hex 32
```

```dotenv
DB_PASSWORD=replace_with_a_long_unique_password
API_SPORT_FOOTBALL_API_KEY=your_api_football_key
FOOTBALL_DATA_TOKEN=your_football_data_token
FOOTBALL_COMPETITION=PL
FOOTBALL_SEASON=2024
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
```

`FOOTBALL_DATA_TOKEN` is optional. Leave `FOOTBALL_SEASON` empty to use the
current season supported by the application. In the earlier API check for this
project, the primary API-Football key could access seasons 2022–2024 but not
2026; set a season that the key currently allows. API access changes by provider
plan, so check provider access before starting a large backfill. `.env` contains
secrets: keep its permissions restricted and never commit or share it.
Compose uses `DB_PASSWORD` for both PostgreSQL initialization and the app
connection. Its fallback value `postgres` is for local development; replace it
before the first server startup. Changing `DB_PASSWORD` does not change the
password inside an already initialized database volume. For an existing volume,
change the PostgreSQL role password and `.env` value together.

The Compose ports are bound to `127.0.0.1` by default. Keep these bindings for a
private sync server; use SSH tunneling for access from your workstation.

## 4. Start the app and database

Build and start the services:

```bash
sudo docker compose up -d --build
sudo docker compose ps
sudo docker compose logs --tail=150 app
```

The entrypoint waits for PostgreSQL, creates the database if needed, and runs
Ecto migrations before launching Phoenix. The `sync_runs` migration creates the
page checkpoints. The sync worker waits about one minute after startup before
its first scheduled sync, then uses the configured six-hour interval.

Check the service locally on the Ubuntu host:

```bash
curl -fsS http://127.0.0.1:4000/api/health
curl -fsS 'http://127.0.0.1:4000/api/sync/coverage?league_id=39&season=2024' | jq
```

To reach the API from your workstation, create an SSH tunnel in a second local
terminal:

```bash
ssh -L 4000:127.0.0.1:4000 <ssh-user>@<server-address>
```

Then use `http://127.0.0.1:4000/api/sync/coverage?league_id=39&season=2024` on
your workstation. The server does not need inbound access to port 4000.

## 5. Run and monitor a sync

Start one season manually:

```bash
sudo docker compose exec app mix run -e 'IO.inspect(FootballBackend.Football.sync(39, 2024))'
```

League ID `39` is the configured Premier League ID. For several seasons, run a
bounded list in ascending order:

```bash
sudo docker compose exec app mix run -e 'IO.inspect(FootballBackend.Football.sync_seasons(Enum.to_list(2022..2024), 39))'
```

Backfills use provider quota. Start with a small season range that the API key is
allowed to access, inspect the result, then queue another batch. Avoid starting a
manual backfill while the scheduled sync is active. The normal startup worker
continues to sync the configured current season; historical seasons are not
automatically backfilled.

Player statistics are requested page by page. After each successful page, the
backend saves its rows and checkpoints the page number plus cumulative fetched
player records and saved player-team statistic rows in `sync_runs`. If the
process stops between pages, the next sync resumes from the next uncheckpointed
page. If it stops after saving a page but before checkpointing, that page is
requested again and upserted safely. Rows from the previous complete import are
kept until all pages of the new import succeed.

Read coverage and progress with:

```bash
curl -fsS 'http://127.0.0.1:4000/api/sync/coverage?league_id=39&season=2024' | jq
sudo docker compose logs --since=1h app
```

The coverage response distinguishes whole-table totals from counts for league
39/season 2024, and shows the latest player import's page, fetched count, saved
count, status, and error. A provider may return fewer records than expected or
reject a season; check both the stored counts and provider quota/access logs.

Requests to scorers, leaderboards, standings, rounds, or team statistics enqueue
a background sync when that scope has no local provider data. The request returns
the current local response without waiting for the upstream call. Check coverage
and repeat the read after the sync progresses.

## 6. Configure Telegram progress messages

1. In Telegram, open `@BotFather`, send `/newbot`, and follow its prompts. Save
   the bot token privately.
2. Open the new bot and send it `/start` so Telegram has a private-chat update for
   the bot.
3. On the Ubuntu server, read the token without echoing it, request updates, and
   print the chat IDs from the result:

   ```bash
   read -rsp 'Telegram bot token: ' TELEGRAM_TOKEN; echo
   curl -fsS "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getUpdates" \
     | jq -r '.result[]?.message.chat | [.id, .type, (.title // "private chat")] | @tsv'
   unset TELEGRAM_TOKEN
   ```

   For a group, add the bot to the group and send a message there before calling
   `getUpdates`; use the group chat ID shown in the output.
4. Put the bot token and chat ID into `.env` as `TELEGRAM_BOT_TOKEN` and
   `TELEGRAM_CHAT_ID`. Recreate the app to load the settings:

   ```bash
   sudo docker compose up -d --force-recreate app
   ```

The backend sends a progress message every ten completed player pages, at the
final page, and when the import completes or fails. Messages report league,
season, page, fetched provider records, and saved statistic rows. This is a
notification integration; use `/api/sync/coverage` to query current status.
Telegram's Bot API uses HTTPS and accepts JSON requests for methods such as
`sendMessage`; see [the official Bot API](https://core.telegram.org/bots/api).

## 7. Keep the server maintained

Check logs and disk space periodically:

```bash
sudo docker compose ps
sudo docker compose logs --since=24h app
df -h
sudo docker system df
```

Back up the database before updating the checkout or Docker image:

```bash
mkdir -p ~/backups/football_backend
sudo docker compose exec -T db pg_dump -U postgres football_backend_dev \
  > ~/backups/football_backend/football_backend_$(date +%F_%H%M%S).sql
```

Copy backups off the server and periodically verify that a backup can be
restored. Keep the Compose volume `db_data`; `docker compose down -v` deletes the
database volume and its contents.

To update the application after backing up:

```bash
cd ~/apps/football_backend
git pull
sudo docker compose up -d --build
sudo docker compose logs --tail=150 app
```

Migrations run from the entrypoint on startup. The process restarts with the
Docker service and Compose restart policy after a host reboot.

## Troubleshooting

- **App container restarts:** inspect `sudo docker compose logs --tail=200 app`
  and confirm the database is healthy with `sudo docker compose ps`.
- **Provider season access error:** set `FOOTBALL_SEASON` to an accessible season
  in `.env`, then run `sudo docker compose up -d --force-recreate app`.
- **No progress or zero rows:** inspect app logs, `/api/sync/coverage`, and
  provider quota headers. A successful container start does not prove the key
  can access the requested season.
- **Telegram sends no message:** confirm `TELEGRAM_BOT_TOKEN` and
  `TELEGRAM_CHAT_ID` are set in the server `.env`, send `/start` to the bot, and
  recreate the app. Look for Telegram HTTP errors in app logs.
- **Cannot connect from outside:** the guide intentionally binds API and database
  to loopback. Use the SSH tunnel above. For an internet-facing API, follow the
  production deployment plan and put an HTTPS reverse proxy in front of a
  production Phoenix release.
