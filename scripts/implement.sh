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

# Record baseline SHA before launching Claude (reliable — not written by Claude)
baseline_sha=$(git rev-parse HEAD 2>/dev/null || echo "")

# Pre-generate session ID so we can use streaming text output
session_id=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c 'import uuid; print(uuid.uuid4())')

# Write session ID + baseline SHA to graft run-state store
mkdir -p "$GRAFT_STATE_DIR"
printf '{"id": "%s", "slice": "%s", "baseline_sha": "%s"}\n' \
  "$session_id" "$SLUG" "$baseline_sha" > "$GRAFT_STATE_DIR/session.json"

# Snapshot suffix: ask Claude to write a context snapshot as its final action (best-effort)
snapshot_suffix="
---
When you have completed your work for this session, write a JSON file to \$GRAFT_STATE_DIR/context-snapshot.json (where \$GRAFT_STATE_DIR is the value of the GRAFT_STATE_DIR environment variable) with exactly these fields: completed_work (string: what you did), current_state (string: state of the codebase now), next_steps (string: what remains to be done), known_issues (string: problems noticed but not fixed, or empty string). Do not include baseline_sha. Example: {\"completed_work\": \"...\", \"current_state\": \"...\", \"next_steps\": \"...\", \"known_issues\": \"\"}
---"

# Run iterate to build the prompt, append snapshot suffix, pipe to claude
{ "$SCRIPT_DIR/iterate.sh" "$SLUG"; printf '%s\n' "$snapshot_suffix"; } \
  | claude -p --session-id "$session_id" --dangerously-skip-permissions
