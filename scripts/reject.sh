#!/usr/bin/env bash
# Reject command: reject a pending checkpoint for the current consumer repo.
#
# Usage: bash scripts/reject.sh [feedback]
#
# Reads checkpoint.json from $GRAFT_STATE_DIR. If the checkpoint is in
# "awaiting-review" phase, atomically writes {phase: "rejected"} (and optionally
# {feedback: "..."} when feedback text is provided) and exits 0.
# Exits 1 with an error message if no pending checkpoint exists.
#
# GRAFT_STATE_DIR is injected by graft. Graft enforces reads: [checkpoint]
# before calling this script, so the file is guaranteed to exist when present.

set -euo pipefail

CHECKPOINT_JSON="${GRAFT_STATE_DIR}/checkpoint.json"

if [ ! -f "$CHECKPOINT_JSON" ]; then
  echo "error: no checkpoint found at $CHECKPOINT_JSON" >&2
  echo "Run 'graft run software-factory:implement-verified <slice>' first." >&2
  exit 1
fi

phase=$(jq -r '.phase // empty' "$CHECKPOINT_JSON" 2>/dev/null || true)

if [ "$phase" != "awaiting-review" ]; then
  echo "error: checkpoint is not pending review (phase: ${phase:-unknown})" >&2
  exit 1
fi

FEEDBACK="${1:-}"

# Atomic write: write to .tmp then rename
TMP_FILE="${CHECKPOINT_JSON}.tmp"
if [ -n "$FEEDBACK" ]; then
  jq --arg fb "$FEEDBACK" 'del(.feedback) | . + {phase: "rejected", feedback: $fb}' \
    "$CHECKPOINT_JSON" > "$TMP_FILE"
  echo "Checkpoint rejected with feedback."
else
  jq 'del(.feedback) | .phase = "rejected"' "$CHECKPOINT_JSON" > "$TMP_FILE"
  echo "Checkpoint rejected."
fi
mv "$TMP_FILE" "$CHECKPOINT_JSON"
