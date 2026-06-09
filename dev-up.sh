#!/usr/bin/env bash
#
# One command to spin up + initialise the DEV Metabase instance (port 3001):
# starts metabase-dev (and its app-db-dev + the shared warehouse-db), then runs
# the same bootstrap as prod — same admin credentials, same warehouse database.
#
# Usage: ./dev-up.sh

set -euo pipefail
cd "$(dirname "$0")"

DEV_PORT="${METABASE_DEV_HOST_PORT:-3001}"

echo "==> Starting dev instance (metabase-dev + app-db-dev + warehouse-db) ..."
docker compose up -d metabase-dev

MB_URL="http://localhost:${DEV_PORT}" \
SITE_NAME="Dirty Data Sandbox (dev)" \
  ./metabase/bootstrap.sh
