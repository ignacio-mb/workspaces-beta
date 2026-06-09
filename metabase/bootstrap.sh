#!/usr/bin/env bash
#
# Initialise the Metabase instance defined in ../docker-compose.yml:
#   1. wait for Metabase to be healthy
#   2. run the setup wizard (create the admin user + site) if not already set up
#   3. connect the "Dirty Warehouse" Postgres database (warehouse-db)
#   4. trigger a schema sync so the events.* / crm.* tables show up
#
# Idempotent: re-running logs in instead of re-setting-up, and skips the
# database if it's already connected. Requires: bash, curl, jq.
#
# Override any of the defaults below via env vars, e.g.:
#   MB_URL=http://localhost:3000 ADMIN_PASSWORD=hunter2 ./metabase/bootstrap.sh

set -euo pipefail

MB_URL="${MB_URL:-http://localhost:3000}"

ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-metabase123}"
ADMIN_FIRST="${ADMIN_FIRST:-Demo}"
ADMIN_LAST="${ADMIN_LAST:-Admin}"
SITE_NAME="${SITE_NAME:-Dirty Data Sandbox}"

# Connection details as seen *from inside the Metabase container* (compose network).
WAREHOUSE_DB_NAME="${WAREHOUSE_DB_NAME:-Dirty Warehouse}"
WAREHOUSE_HOST="${WAREHOUSE_HOST:-warehouse-db}"
WAREHOUSE_PORT="${WAREHOUSE_PORT:-5432}"
WAREHOUSE_DBNAME="${WAREHOUSE_DBNAME:-warehouse}"
WAREHOUSE_USER="${WAREHOUSE_USER:-analyst}"
WAREHOUSE_PASSWORD="${WAREHOUSE_PASSWORD:-analyst}"

command -v jq >/dev/null 2>&1 || { echo "error: jq is required (brew install jq)" >&2; exit 1; }

note() { printf '  %s\n' "$*"; }

echo "==> Waiting for Metabase at ${MB_URL} ..."
for i in $(seq 1 120); do
  status="$(curl -fsS "${MB_URL}/api/health" 2>/dev/null | jq -r '.status // empty' 2>/dev/null || true)"
  if [ "${status}" = "ok" ]; then
    note "Metabase is up."
    break
  fi
  if [ "${i}" = "120" ]; then
    echo "error: Metabase did not become healthy in time" >&2
    exit 1
  fi
  sleep 2
done

# --- Authenticate: setup wizard on a fresh instance, else login. ----------
# `setup-token` lingers after setup, so branch on `has-user-setup` instead.
PROPS="$(curl -fsS "${MB_URL}/api/session/properties")"
HAS_USER_SETUP="$(echo "${PROPS}" | jq -r '.["has-user-setup"] // false')"
SETUP_TOKEN="$(echo "${PROPS}" | jq -r '.["setup-token"] // empty')"

if [ "${HAS_USER_SETUP}" != "true" ] && [ -n "${SETUP_TOKEN}" ]; then
  echo "==> Running setup wizard (fresh instance) ..."
  SETUP_BODY="$(jq -n \
    --arg token "${SETUP_TOKEN}" \
    --arg email "${ADMIN_EMAIL}" \
    --arg password "${ADMIN_PASSWORD}" \
    --arg first "${ADMIN_FIRST}" \
    --arg last "${ADMIN_LAST}" \
    --arg site "${SITE_NAME}" \
    '{
      token: $token,
      prefs: { site_name: $site, allow_tracking: false },
      user: { email: $email, password: $password, first_name: $first, last_name: $last, site_name: $site }
    }')"
  SESSION="$(curl -fsS -X POST "${MB_URL}/api/setup" \
    -H 'Content-Type: application/json' \
    -d "${SETUP_BODY}" | jq -r '.id // empty')"
  note "Created admin user ${ADMIN_EMAIL}"
else
  echo "==> Instance already set up; logging in ..."
  SESSION="$(curl -fsS -X POST "${MB_URL}/api/session" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg u "${ADMIN_EMAIL}" --arg p "${ADMIN_PASSWORD}" '{username: $u, password: $p}')" \
    | jq -r '.id // empty')"
fi

if [ -z "${SESSION}" ]; then
  echo "error: failed to obtain a Metabase session" >&2
  exit 1
fi
note "Authenticated."

auth=(-H "X-Metabase-Session: ${SESSION}")

# --- Connect the warehouse, unless it's already there. --------------------
echo "==> Connecting warehouse database '${WAREHOUSE_DB_NAME}' ..."
# Match on the physical connection (host + dbname), not the display name, so a
# re-run never duplicates the connection even if the database was renamed.
EXISTING_ID="$(curl -fsS "${auth[@]}" "${MB_URL}/api/database" \
  | jq -r --arg host "${WAREHOUSE_HOST}" --arg db "${WAREHOUSE_DBNAME}" \
    '(.data // .)[] | select(.details.host == $host and .details.dbname == $db) | .id' | head -n1)"

if [ -n "${EXISTING_ID}" ]; then
  note "Already connected (database id ${EXISTING_ID})."
  DB_ID="${EXISTING_ID}"
else
  DB_BODY="$(jq -n \
    --arg name "${WAREHOUSE_DB_NAME}" \
    --arg host "${WAREHOUSE_HOST}" \
    --argjson port "${WAREHOUSE_PORT}" \
    --arg dbname "${WAREHOUSE_DBNAME}" \
    --arg user "${WAREHOUSE_USER}" \
    --arg password "${WAREHOUSE_PASSWORD}" \
    '{
      name: $name,
      engine: "postgres",
      details: {
        host: $host, port: $port, dbname: $dbname,
        user: $user, password: $password,
        "schema-filters-type": "all",
        ssl: false, "tunnel-enabled": false
      }
    }')"
  DB_ID="$(curl -fsS "${auth[@]}" -X POST "${MB_URL}/api/database" \
    -H 'Content-Type: application/json' \
    -d "${DB_BODY}" | jq -r '.id // empty')"
  if [ -z "${DB_ID}" ]; then
    echo "error: failed to add the warehouse database" >&2
    exit 1
  fi
  note "Connected (database id ${DB_ID})."
fi

echo "==> Triggering a schema sync ..."
curl -fsS "${auth[@]}" -X POST "${MB_URL}/api/database/${DB_ID}/sync_schema" >/dev/null
note "Sync requested (tables appear once it finishes — a few seconds)."

cat <<EOF

Done.

  Metabase UI : ${MB_URL}
  Admin login : ${ADMIN_EMAIL} / ${ADMIN_PASSWORD}
  Warehouse   : '${WAREHOUSE_DB_NAME}' (id ${DB_ID}) -> schemas: events, crm

Point the CLI at it, e.g.:

  mb auth login --url ${MB_URL}
EOF
