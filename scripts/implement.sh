#!/usr/bin/env bash
# Implement command: run iterate output through Claude Code, capture session ID.
#
# Usage: bash scripts/implement.sh <slug>
#        bash scripts/implement.sh slices/<slug>
#
# Pre-generates a session ID so Claude streams text output in real-time
# (no buffering). Saves the session ID to slices/<slug>/.session for
# later resumption with resume.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if [ $# -eq 0 ]; then
  echo "Usage: bash scripts/implement.sh <slug>" >&2
  exit 1
fi

normalize_slice_dir "$1"
SESSION_FILE="$SLICE_DIR/.session"

# Pre-generate session ID so we can use streaming text output
session_id=$(uuidgen)
echo "$session_id" > "$SESSION_FILE"

# Run iterate to build the prompt, pipe to claude with streaming text output
"$SCRIPT_DIR/iterate.sh" "$SLUG" | claude -p --session-id "$session_id" --dangerously-skip-permissions
