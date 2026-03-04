#!/usr/bin/env bash
# Thin wrapper for new-slice. Validates slug, exports env vars,
# execs claude with stdin from graft.
set -euo pipefail

SLUG="${1:?Usage: new-slice-create.sh <slug> <description>}"
shift
DESC="${*:?Usage: new-slice-create.sh <slug> <description>}"

if [[ ! "$SLUG" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Error: slug must be kebab-case (e.g., my-feature)" >&2
  exit 1
fi

if [ -d "slices/$SLUG" ]; then
  echo "Error: slices/$SLUG already exists" >&2
  exit 1
fi

export GRAFT_NEW_SLUG="$SLUG"
export GRAFT_NEW_DESC="$DESC"
exec claude -p --dangerously-skip-permissions
