#!/usr/bin/env bash
# Diagnose command: targeted root-cause analysis for verify failures.
#
# Usage: bash scripts/diagnose.sh
#
# Reads verify.json to find failures. Reads recently changed files from
# git diff <baseline_sha> (from session.json). Reads slice acceptance criteria
# from session.json's slice field. Pipes a structured diagnosis prompt through
# claude -p to produce diagnose.json with root_cause, affected_files,
# suggested_approach, and specific_fixes.
#
# Exits 1 if verify shows no failures (nothing to diagnose).
# Exits 1 if verify.json is absent.
#
# COST NOTE: This command launches a full Claude session (~$0.10-0.50 per run).
# Use it manually when verify failures are complex and resume is struggling.
#
# GRAFT_STATE_DIR is injected by graft into every command's environment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

VERIFY_JSON="$GRAFT_STATE_DIR/verify.json"
SESSION_JSON="$GRAFT_STATE_DIR/session.json"

# Check verify.json exists
if [ ! -f "$VERIFY_JSON" ]; then
  echo "error: verify.json not found at $VERIFY_JSON" >&2
  echo "Run 'graft run software-factory:verify' first." >&2
  exit 1
fi

# Check for failures (fields not starting with "OK")
failures=$(jq -r '
  to_entries |
  map(select(.value | type == "string" and (startswith("OK") | not))) |
  map("## " + (.key | ascii_upcase) + "\n" + .value) |
  join("\n\n")
' "$VERIFY_JSON" 2>/dev/null || echo "")

failure_count=$(jq -r '
  [to_entries[] | select(.value | type == "string" and (startswith("OK") | not))] | length
' "$VERIFY_JSON" 2>/dev/null || echo "0")

if [ "$failure_count" -eq 0 ] || [ -z "$failures" ]; then
  echo "Nothing to diagnose: verify passed"
  exit 1
fi

# Read session context
slice_path=""
baseline_sha=""
if [ -f "$SESSION_JSON" ]; then
  slice_path=$(jq -r '.slice // ""' "$SESSION_JSON" 2>/dev/null || echo "")
  baseline_sha=$(jq -r '.baseline_sha // ""' "$SESSION_JSON" 2>/dev/null || echo "")
fi

# Get changed files
if [ -n "$baseline_sha" ] && [ "$baseline_sha" != "null" ]; then
  changed_files=$(git diff --name-only "$baseline_sha" 2>/dev/null || git status --short)
else
  changed_files=$(git status --short 2>/dev/null || echo "(unknown)")
fi

# Read acceptance criteria from slice plan (if available)
acceptance_criteria=""
if [ -n "$slice_path" ] && [ "$slice_path" != "null" ]; then
  normalize_slice_dir "$slice_path"
  PLAN_FILE="$SLICE_DIR/plan.md"
  if [ -f "$PLAN_FILE" ]; then
    acceptance_criteria=$(awk '
      /^## Acceptance Criteria/ { found=1; next }
      found && /^## / { exit }
      found { print }
    ' "$PLAN_FILE")
  fi
fi

# Construct diagnosis prompt
criteria_section=""
if [ -n "$acceptance_criteria" ]; then
  criteria_section="## What this step was supposed to achieve (Acceptance Criteria)

${acceptance_criteria}

"
fi

diagnose_prompt="You are diagnosing why a software implementation failed verification.
Provide a structured root-cause analysis.

## Verify Failures

${failures}

## Recently Changed Files

${changed_files}

${criteria_section}## Your Task

Diagnose the root cause of these verify failures. Be specific and actionable.

Output ONLY valid JSON (no markdown wrapper) in exactly this schema:
{
  \"root_cause\": \"concise one-sentence root cause\",
  \"affected_files\": [\"file/path.rs\", \"...\"],
  \"suggested_approach\": \"paragraph explaining what needs to change and why\",
  \"specific_fixes\": [
    {\"file\": \"path/to/file.rs\", \"issue\": \"what's wrong\", \"fix\": \"what to change\"}
  ]
}"

DIAGNOSE_JSON="$GRAFT_STATE_DIR/diagnose.json"
DIAGNOSE_TMP="${DIAGNOSE_JSON}.tmp"

# Run Claude diagnosis
raw_output=$(printf '%s\n' "$diagnose_prompt" | \
  claude -p --dangerously-skip-permissions 2>/dev/null || echo "")

# Extract JSON block from output
json_output=$(printf '%s\n' "$raw_output" | \
  awk '/^\{/{found=1} found{print} /^\}/{if(found) exit}' || echo "")

if [ -z "$json_output" ] || ! printf '%s\n' "$json_output" | jq . >/dev/null 2>&1; then
  # Write a fallback diagnosis record
  json_output=$(jq -n \
    --arg raw "$raw_output" \
    --arg failures "$failures" \
    '{root_cause: "Diagnosis script failed to obtain valid JSON from Claude", affected_files: [], suggested_approach: $failures, specific_fixes: []}')
fi

# Write diagnose.json atomically
printf '%s\n' "$json_output" > "$DIAGNOSE_TMP"
mv "$DIAGNOSE_TMP" "$DIAGNOSE_JSON"

# Print summary
root_cause=$(printf '%s\n' "$json_output" | jq -r '.root_cause // ""')
approach=$(printf '%s\n' "$json_output" | jq -r '.suggested_approach // ""')
echo "Root cause: $root_cause"
echo ""
echo "Approach: $approach"
echo ""
echo "diagnose.json written to $DIAGNOSE_JSON"
