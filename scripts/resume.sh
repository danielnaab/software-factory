#!/usr/bin/env bash
# Resume command: resume a Claude Code session for a slice.
#
# Usage: bash scripts/resume.sh <slug> [extra claude args...]
#        bash scripts/resume.sh slices/<slug> [extra claude args...]
#
# Reads the session ID from $GRAFT_STATE_DIR/session.json (written by implement.sh
# and tracked by graft via the run-state store) and launches claude --resume.
#
# GRAFT_STATE_DIR is injected by graft. Graft also enforces reads: [session]
# before calling this script, so the file is guaranteed to exist.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if [ $# -eq 0 ]; then
  echo "Usage: bash scripts/resume.sh <slug> [extra claude args...]" >&2
  exit 1
fi

normalize_slice_dir "$1"
shift

SESSION_JSON="$GRAFT_STATE_DIR/session.json"

if [ ! -f "$SESSION_JSON" ]; then
  echo "error: no session found at $SESSION_JSON" >&2
  echo "Run 'graft run implement $SLUG' first to start a session." >&2
  exit 1
fi

session_id=$(jq -r '.id' "$SESSION_JSON")

if [ -z "$session_id" ] || [ "$session_id" = "null" ]; then
  echo "error: session.json missing .id field" >&2
  exit 1
fi

exec claude --resume "$session_id" --dangerously-skip-permissions "$@"
