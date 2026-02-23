#!/usr/bin/env bash
# Resume command: resume a Claude Code session for a slice.
#
# Usage: bash scripts/resume.sh <slug> [extra claude args...]
#        bash scripts/resume.sh slices/<slug> [extra claude args...]
#
# Reads slices/<slug>/.session and launches claude --resume <id>
# --dangerously-skip-permissions. Any extra args are passed through to claude.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if [ $# -eq 0 ]; then
  echo "Usage: bash scripts/resume.sh <slug> [extra claude args...]" >&2
  exit 1
fi

normalize_slice_dir "$1"
shift

SESSION_FILE="$SLICE_DIR/.session"

if [ ! -f "$SESSION_FILE" ]; then
  echo "error: no session file found at $SESSION_FILE" >&2
  echo "Run 'graft run implement $SLUG' first to start a session." >&2
  exit 1
fi

session_id=$(cat "$SESSION_FILE")

if [ -z "$session_id" ]; then
  echo "error: session file $SESSION_FILE is empty" >&2
  exit 1
fi

exec claude --resume "$session_id" --dangerously-skip-permissions "$@"
