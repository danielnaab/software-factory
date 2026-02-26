#!/usr/bin/env bash
# Resume command: resume a Claude Code session for a slice.
#
# Usage: bash scripts/resume.sh <slug> [extra claude args...]
#        bash scripts/resume.sh slices/<slug> [extra claude args...]
#
# Reads the session ID from $GRAFT_STATE_DIR/session.json (written by implement.sh
# and tracked by graft via the run-state store) and launches claude --resume.
#
# When $GRAFT_STATE_DIR/verify.json exists and contains failures, a structured
# failure summary is injected into the Claude --resume prompt so Claude receives
# context about what went wrong without requiring manual explanation.
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

# Build failure prompt from verify.json if present and contains failures
VERIFY_JSON="$GRAFT_STATE_DIR/verify.json"
failure_prompt=""

if [ -f "$VERIFY_JSON" ]; then
  # Check if any field is not "OK" and does not start with "OK"
  has_failures=$(jq -r '
    to_entries |
    map(select(.value | type == "string" and (startswith("OK") | not))) |
    length
  ' "$VERIFY_JSON" 2>/dev/null || echo "0")

  if [ "$has_failures" -gt 0 ]; then
    failure_prompt=$(jq -r '
      "Verify failed. Please fix the following issues:\n\n" +
      (to_entries |
       map(select(.value | type == "string" and (startswith("OK") | not))) |
       map("## " + (.key | ascii_upcase) + "\n" + .value) |
       join("\n\n"))
    ' "$VERIFY_JSON" 2>/dev/null || echo "")
  fi
fi

if [ -n "$failure_prompt" ]; then
  printf '%s' "$failure_prompt" | \
    exec claude --resume "$session_id" --dangerously-skip-permissions "$@"
else
  exec claude --resume "$session_id" --dangerously-skip-permissions "$@"
fi
