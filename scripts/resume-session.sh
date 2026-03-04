#!/usr/bin/env bash
# Thin session wrapper for resume. Reads session ID, execs claude --resume
# with stdin from graft.
set -euo pipefail

SLUG="${1:?Usage: resume-session.sh <slice>}"
SLUG="${SLUG#slices/}"
SLUG="${SLUG%/}"

if [ ! -f "$GRAFT_STATE_DIR/session.json" ]; then
  echo "Error: no session.json — run implement first" >&2
  exit 1
fi

session_id=$(jq -r '.id' "$GRAFT_STATE_DIR/session.json")
if [ -z "$session_id" ] || [ "$session_id" = "null" ]; then
  echo "Error: session.json missing .id field" >&2
  exit 1
fi

export GRAFT_SLICE="$SLUG"
exec claude --resume "$session_id" --dangerously-skip-permissions
