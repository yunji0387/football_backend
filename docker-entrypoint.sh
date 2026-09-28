#!/bin/sh
set -e

echo "Waiting for database at ${DB_HOSTNAME:-db}:5432..."
until pg_isready -h "${DB_HOSTNAME:-db}" -U "${DB_USERNAME:-postgres}" >/dev/null 2>&1; do
  sleep 1
done
echo "Database is up."

mix deps.get
mix ecto.create
mix ecto.migrate

exec "$@"
