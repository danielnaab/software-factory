#!/usr/bin/env bash
# Spec-check wrapper: runs Claude, validates spec-check.json.
# Improvement C (JSON validation fallback).
set -uo pipefail

SPEC_CHECK_JSON="${GRAFT_STATE_DIR}/spec-check.json"

# Capture rendered template from stdin, then run Claude
PROMPT=$(cat)
printf '%s' "$PROMPT" | claude -p --dangerously-skip-permissions
claude_rc=$?

# --- C: Validate spec-check.json ---
if [ ! -f "$SPEC_CHECK_JSON" ] || ! jq empty "$SPEC_CHECK_JSON" 2>/dev/null; then
  echo "warning: spec-check.json missing or invalid, writing fallback" >&2
  cat > "$SPEC_CHECK_JSON" <<'FALLBACK'
{"overall":"error","uncovered_count":0,"criteria":[{"text":"validation failed","coverage":"uncovered","evidence":"spec-check.json was missing or malformed","note":""}]}
FALLBACK
fi

exit $claude_rc
