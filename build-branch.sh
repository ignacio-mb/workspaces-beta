#!/usr/bin/env bash
#
# Build the EE Metabase image from the `workspace-dev-instance-poc` branch.
# There is no prebuilt image for a feature branch, so we build from source.
#
# The build needs a real `.git` DIRECTORY in the context:
#   - the backend Dockerfile runs `git config --add safe.directory ...`
#   - the frontend embedding-SDK build runs `git rev-parse HEAD`
# A linked worktree's `.git` is a pointer file (breaks the backend step) and a
# `git archive` export has no `.git` (breaks the frontend step), so we make a
# normal clone off a throwaway branch. Objects are reused from the local clone
# next door, so this is fast and offline; the `master` checkout is untouched.
#
# Re-run any time to pick up new commits on the branch. The first build is slow
# (~20-40 min); Docker layer cache keeps unchanged steps fast afterwards.
#
# Usage: ./build-branch.sh

set -euo pipefail
cd "$(dirname "$0")"

BRANCH="workspace-dev-instance-poc"
REPO="${METABASE_REPO:-../../master/metabase}"
SRC="${METABASE_SRC:-../../master/metabase-src-${BRANCH}}"
TMP_BRANCH="tmp-build-${BRANCH}"

if [ ! -e "${REPO}/deps.edn" ]; then
  echo "error: no Metabase clone at ${REPO} (set METABASE_REPO)" >&2
  exit 1
fi

echo "==> Fetching ${BRANCH} ..."
git -C "${REPO}" fetch origin "${BRANCH}"

echo "==> Cloning a self-contained source tree (with .git) to ${SRC} ..."
rm -rf "${SRC}"
git -C "${REPO}" branch -f "${TMP_BRANCH}" "origin/${BRANCH}"
git clone --quiet --branch "${TMP_BRANCH}" --single-branch "${REPO}" "${SRC}"
git -C "${REPO}" branch -D "${TMP_BRANCH}"

echo "==> Building EE image from ${BRANCH} (grab a coffee) ..."
docker compose build metabase

echo "==> Done. Image: metabase-mb-cli:${BRANCH}"
