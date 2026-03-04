#!/usr/bin/env bash
# Thin session wrapper for implement. Handles session bookkeeping, then
# execs claude with stdin from graft (stdin: literal piped through).
set -euo pipefail

SLUG="${1:?Usage: implement-session.sh <slice>}"
SLUG="${SLUG#slices/}"
SLUG="${SLUG%/}"

if [ ! -f "slices/$SLUG/plan.md" ]; then
  echo "Error: slices/$SLUG/plan.md not found" >&2
  exit 1
fi

session_id=$(cat /proc/sys/kernel/random/uuid 2>/dev/null \
  || python3 -c 'import uuid; print(uuid.uuid4())')
baseline_sha=$(git rev-parse HEAD 2>/dev/null || echo "")

mkdir -p "$GRAFT_STATE_DIR"
printf '{"id":"%s","slice":"%s","baseline_sha":"%s"}\n' \
  "$session_id" "$SLUG" "$baseline_sha" > "$GRAFT_STATE_DIR/session.json"

export GRAFT_SLICE="$SLUG"
exec claude -p --session-id "$session_id" --dangerously-skip-permissions
