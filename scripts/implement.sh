#!/usr/bin/env bash
# Implement command: run iterate output through Claude Code, capture session ID.
#
# Usage: bash scripts/implement.sh <slug>
#        bash scripts/implement.sh slices/<slug>
#
# Pre-generates a session ID so Claude streams text output in real-time
# (no buffering). Saves the session ID to $GRAFT_STATE_DIR/session.json
# for later resumption with resume.sh.
#
# GRAFT_STATE_DIR is injected by graft into every command's environment,
# pointing to the consumer repo's .graft/run-state/ directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if [ $# -eq 0 ]; then
  echo "Usage: bash scripts/implement.sh <slug>" >&2
  exit 1
fi

normalize_slice_dir "$1"

# Pre-generate session ID so we can use streaming text output
session_id=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c 'import uuid; print(uuid.uuid4())')

# Write session ID to graft run-state store (GRAFT_STATE_DIR injected by graft)
mkdir -p "$GRAFT_STATE_DIR"
printf '{"id": "%s", "slice": "%s"}\n' "$session_id" "$SLUG" > "$GRAFT_STATE_DIR/session.json"

# Run iterate to build the prompt, pipe to claude with streaming text output
"$SCRIPT_DIR/iterate.sh" "$SLUG" | claude -p --session-id "$session_id" --dangerously-skip-permissions
