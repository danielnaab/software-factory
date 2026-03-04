#!/usr/bin/env bash
# Diagnose wrapper: guards on verify pass, runs Claude, validates diagnose.json.
# Improvements A (skip when verify passed) + C (JSON validation fallback).
set -uo pipefail

VERIFY_JSON="${GRAFT_STATE_DIR}/verify.json"
DIAGNOSE_JSON="${GRAFT_STATE_DIR}/diagnose.json"

# --- A: Guard — skip Claude if verification passed ---
if [ -f "$VERIFY_JSON" ] && jq empty "$VERIFY_JSON" 2>/dev/null; then
  fmt_ok=$(jq -r '.format.status // .format // empty' "$VERIFY_JSON" 2>/dev/null || true)
  lint_ok=$(jq -r '.lint.status // .lint // empty' "$VERIFY_JSON" 2>/dev/null || true)
  test_ok=$(jq -r '.tests.status // .tests // empty' "$VERIFY_JSON" 2>/dev/null || true)

  if [ "$fmt_ok" = "pass" ] && [ "$lint_ok" = "pass" ] && [ "$test_ok" = "pass" ]; then
    echo "All verification checks passed — nothing to diagnose." >&2
    cat > "$DIAGNOSE_JSON" <<'SKIP'
{"root_cause":"none — all checks pass","affected_files":[],"suggested_approach":"no action needed","specific_fixes":[]}
SKIP
    exit 0
  fi
fi

# Capture rendered template from stdin, then run Claude
PROMPT=$(cat)
printf '%s' "$PROMPT" | claude -p --dangerously-skip-permissions
claude_rc=$?

# --- C: Validate diagnose.json ---
if [ ! -f "$DIAGNOSE_JSON" ] || ! jq empty "$DIAGNOSE_JSON" 2>/dev/null; then
  echo "warning: diagnose.json missing or invalid, writing fallback" >&2
  cat > "$DIAGNOSE_JSON" <<'FALLBACK'
{"root_cause":"diagnosis did not produce valid output","affected_files":[],"suggested_approach":"re-run diagnose or inspect verify.json manually","specific_fixes":[]}
FALLBACK
fi

exit $claude_rc
