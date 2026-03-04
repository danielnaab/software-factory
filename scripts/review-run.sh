#!/usr/bin/env bash
# Review wrapper: runs Claude, validates review.json, updates checkpoint.
# Improvements B (deterministic checkpoint update) + C (JSON validation fallback).
set -uo pipefail

REVIEW_JSON="${GRAFT_STATE_DIR}/review.json"
CHECKPOINT_JSON="${GRAFT_STATE_DIR}/checkpoint.json"

# Capture rendered template from stdin, then run Claude
PROMPT=$(cat)
printf '%s' "$PROMPT" | claude -p --dangerously-skip-permissions
claude_rc=$?

# --- C: Validate review.json ---
if [ ! -f "$REVIEW_JSON" ] || ! jq empty "$REVIEW_JSON" 2>/dev/null; then
  echo "warning: review.json missing or invalid, writing fallback" >&2
  cat > "$REVIEW_JSON" <<'FALLBACK'
{"verdict":"error","summary":"Review did not produce valid output","criteria":[],"concerns":["review.json was missing or malformed"]}
FALLBACK
fi

# --- B: Deterministic checkpoint update ---
if [ -f "$CHECKPOINT_JSON" ]; then
  phase=$(jq -r '.phase // empty' "$CHECKPOINT_JSON" 2>/dev/null || true)
  if [ "$phase" = "awaiting-review" ]; then
    verdict=$(jq -r '.verdict // "unknown"' "$REVIEW_JSON" 2>/dev/null || echo "unknown")
    summary=$(jq -r '.summary // "no summary"' "$REVIEW_JSON" 2>/dev/null || echo "no summary")
    TMP_FILE="${CHECKPOINT_JSON}.tmp"
    jq --arg v "$verdict" --arg s "$summary" \
      '.message = "review: \($v) — \($s)"' \
      "$CHECKPOINT_JSON" > "$TMP_FILE" && mv "$TMP_FILE" "$CHECKPOINT_JSON"
  fi
fi

exit $claude_rc
