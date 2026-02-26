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

# Build resume prompt: context snapshot + failure summary (both optional)
VERIFY_JSON="$GRAFT_STATE_DIR/verify.json"
SNAPSHOT_JSON="$GRAFT_STATE_DIR/context-snapshot.json"
resume_prompt=""

# Inject context snapshot summary if present and non-empty
if [ -f "$SNAPSHOT_JSON" ]; then
  completed=$(jq -r '.completed_work // ""' "$SNAPSHOT_JSON" 2>/dev/null || echo "")
  current=$(jq -r '.current_state // ""' "$SNAPSHOT_JSON" 2>/dev/null || echo "")
  next=$(jq -r '.next_steps // ""' "$SNAPSHOT_JSON" 2>/dev/null || echo "")
  issues=$(jq -r '.known_issues // ""' "$SNAPSHOT_JSON" 2>/dev/null || echo "")

  if [ -n "$completed" ] || [ -n "$current" ] || [ -n "$next" ]; then
    resume_prompt="## Context from previous session

Completed: $completed
Current state: $current
Next steps: $next
Known issues: $issues

"
  fi
fi

# Append failure summary from verify.json if failures exist
if [ -f "$VERIFY_JSON" ]; then
  has_failures=$(jq -r '
    to_entries |
    map(select(.value | type == "string" and (startswith("OK") | not))) |
    length
  ' "$VERIFY_JSON" 2>/dev/null || echo "0")

  if [ "$has_failures" -gt 0 ]; then
    failure_text=$(jq -r '
      "Verify failed. Please fix the following issues:\n\n" +
      (to_entries |
       map(select(.value | type == "string" and (startswith("OK") | not))) |
       map("## " + (.key | ascii_upcase) + "\n" + .value) |
       join("\n\n"))
    ' "$VERIFY_JSON" 2>/dev/null || echo "")
    resume_prompt="${resume_prompt}${failure_text}"
  fi
fi

# Snapshot suffix: ask Claude to update context snapshot as its final action
snapshot_suffix="
---
When you have completed your work for this session, write a JSON file to \$GRAFT_STATE_DIR/context-snapshot.json (where \$GRAFT_STATE_DIR is the value of the GRAFT_STATE_DIR environment variable) with exactly these fields: completed_work (string: what you did), current_state (string: state of the codebase now), next_steps (string: what remains to be done), known_issues (string: problems noticed but not fixed, or empty string). Do not include baseline_sha. Example: {\"completed_work\": \"...\", \"current_state\": \"...\", \"next_steps\": \"...\", \"known_issues\": \"\"}
---"

if [ -n "$resume_prompt" ]; then
  { printf '%s' "$resume_prompt"; printf '%s\n' "$snapshot_suffix"; } | \
    exec claude --resume "$session_id" --dangerously-skip-permissions "$@"
else
  printf '%s\n' "$snapshot_suffix" | \
    exec claude --resume "$session_id" --dangerously-skip-permissions "$@"
fi
