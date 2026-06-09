# Dirty Data Sandbox

A throwaway **Metabase (Enterprise, `workspace-dev-instance-poc` branch)**
instance with a deliberately messy sample database, for poking at the
[`mb-cli`](../mb-cli) by hand.

Two Metabase instances (prod + dev) on the **same from-source image and the same
warehouse data**, each with its own application database (see
`docker-compose.yml`):

| Service        | What it is                                          | Host port    |
| -------------- | --------------------------------------------------- | ------------ |
| `metabase`     | **prod** instance — EE build of the branch          | `3000`       |
| `metabase-dev` | **dev** instance — same image + same data           | `3001`       |
| `warehouse-db` | Postgres — the dirty sample data (shared)           | `5433`       |
| `app-db`       | Postgres — prod app state                           | _(internal)_ |
| `app-db-dev`   | Postgres — dev app state                            | _(internal)_ |

## Quick start

**Build the image first** (from source — there's no prebuilt image for a feature
branch; ~20–40 min the first time, cached after):

```bash
cd metabase-demo
./build-branch.sh               # clones the branch source + docker build (EE)
```

**Prod (port 3000):**

```bash
cp .env.example .env            # optional — only to change ports / add an EE token
docker compose up -d            # boots prod on the built image
./metabase/bootstrap.sh         # creates the admin user + connects the warehouse
```

**Dev (port 3001) — one command:**

```bash
./dev-up.sh                     # spins up + initialises the dev instance
```

Both open with the same login `admin@example.com` / `metabase123`:
<http://localhost:3000> (prod) · <http://localhost:3001> (dev).

Point the CLI at either:

```bash
mb auth login --url http://localhost:3000     # prod
mb auth login --url http://localhost:3001     # dev
```

Tear down (`--profile dev` so the dev services are included):

```bash
docker compose --profile dev down       # stop, keep data
docker compose --profile dev down -v    # stop and wipe everything (re-seeds on next up)
```

## Two instances

Both instances run the identical from-source image and connect to the **same**
`warehouse-db`, so they see the same dirty data and the same `admin@example.com`
login — but they keep **separate application databases** (`app-db` / `app-db-dev`),
because two Metabase instances cannot share one app-db. Questions, models, and
transforms you create in one are invisible to the other; the underlying warehouse
tables are shared. The dev instance is gated behind the compose `dev` profile, so
a plain `docker compose up -d` only touches prod; `./dev-up.sh` (or
`docker compose --profile dev up -d`) brings up dev.

## The sample data

One warehouse database, two Postgres schemas representing **two different
business domains that describe the same people in totally different shapes** —
exactly the kind of raw connector output the CLI's data-cleaning skills are
built to flatten and reconcile.

### `events.*` — community-events platform export

- `evt_events` — events; coded `category_code`, a JSON `venue` blob, mixed date
  formats, mixed boolean spellings, a soft-deleted (`_deleted`) tombstone row.
- `evt_categories` — decode table for `category_code`.
- `evt_people` — attendees; one messy `full_name` column, junk null
  placeholders (`N/A`, `NULL`, `-`, ``) in phone/email.
- `evt_registrations` — person ↔ event, with dirty `status` variants
  (`going` / `GOING` / `Going ` / `cancelled`) and a mixed `checked_in` flag.
- `evt_custom_fields` / `evt_custom_responses` — coded custom fields
  (`cf_1021` → "Dietary restrictions") with single/multi answers as JSON text.

### `crm.*` — marketing / CRM tool export

- `crm_contacts` — the **same humans** as `evt_people`, but split `first`/`last`,
  numeric ids, a coded `lifecycle_code`, and `email_address` as the only (dirty,
  case-mismatched) bridge back to events. Includes a duplicate row and
  soft-deleted (`is_deleted = 1`) tombstones.
- `crm_lifecycle_stages` — decode table for `lifecycle_code`.
- `crm_companies` — the companies contacts belong to.

### What's intentionally dirty

Coded columns needing decode tables · JSON stuffed into text columns · mixed
date formats · mixed boolean spellings (`Y`/`N`/`true`/`1`/`yes`) · junk null
placeholders · inconsistent casing & whitespace · soft-delete tombstones · a
duplicate contact under one email · **no declared foreign keys** (relationships
must be inferred) · the same people modelled two different ways across domains.

Edit `warehouse/init/*.sql` and `docker compose down -v && docker compose up -d`
to reseed.

## Metabase version

Runs a **from-source EE build of the `workspace-dev-instance-poc` branch**.
There's no prebuilt image for a feature branch, so `build-branch.sh` clones the
branch into a self-contained source tree (with its `.git` — the frontend build
runs `git rev-parse`, so a worktree pointer or a `git archive` export won't do)
under `../../master/`, reusing the local clone's objects (fast, offline) and
leaving the `master` checkout untouched, then `docker build`s it via the repo's
`Dockerfile` with `MB_EDITION=ee`. The image is tagged
`metabase-mb-cli:workspace-dev-instance-poc`; both instances share it.

Knobs (override in `.env`):

- `METABASE_IMAGE` — use a registry image instead of building (e.g.
  `metabase/metabase-enterprise-head:latest` for master, or a pinned release).
- `METABASE_SRC` — path to the cloned branch source (defaults under `master/`).
- `MB_BUILD_VERSION` — the version string baked into the build.

Rebuild after new commits land on the branch (re-clones + rebuilds):

```bash
./build-branch.sh
docker compose --profile dev up -d --force-recreate
```

On its first boot against a fresh app-db, the EE build claims the connected
Postgres for its attached-data-warehouse feature and may relabel it "Data
Warehouse" in the UI — purely cosmetic. `bootstrap.sh` matches the connection by
host + database name (not display name), so re-runs never create a duplicate.

## Enterprise features

The image is the enterprise build, so the EE UI is present, but premium,
token-gated features (e.g. **transforms**) stay locked until you supply a token
via `MB_PREMIUM_EMBEDDING_TOKEN` in `.env`. Without one it behaves like OSS.
