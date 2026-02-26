#!/usr/bin/env bash
# Spec-check command: map acceptance criteria to implementation evidence in the diff.
#
# Usage: bash scripts/spec-check.sh
#
# Reads baseline_sha from session.json, reads the Acceptance Criteria section
# from the slice plan, gets git diff, and pipes criteria + diff to Claude with
# an evidence-mapping prompt. Writes spec-check.json with per-criterion coverage.
#
# This is a coverage check — flagging criteria with no diff evidence — not a
# correctness verification. overall: "covered" when all criteria are covered or
# not_diffable; "partial" when some are uncovered; "uncovered" when majority lack evidence.
#
# GRAFT_STATE_DIR is injected by graft into every command's environment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

SESSION_JSON="$GRAFT_STATE_DIR/session.json"

if [ ! -f "$SESSION_JSON" ]; then
  echo "error: no session found at $SESSION_JSON" >&2
  echo "Run 'graft run implement <slice>' first to start a session." >&2
  exit 1
fi

SLUG=$(jq -r '.slice // ""' "$SESSION_JSON" 2>/dev/null || echo "")
baseline_sha=$(jq -r '.baseline_sha // ""' "$SESSION_JSON" 2>/dev/null || echo "")

if [ -z "$SLUG" ] || [ "$SLUG" = "null" ]; then
  echo "error: session.json missing .slice field" >&2
  exit 1
fi

normalize_slice_dir "$SLUG"

PLAN_FILE="$SLICE_DIR/plan.md"
if [ ! -f "$PLAN_FILE" ]; then
  echo "error: slice plan not found at $PLAN_FILE" >&2
  exit 1
fi

# Extract Acceptance Criteria section
acceptance_criteria=$(awk '
  /^## Acceptance Criteria/ { found=1; next }
  found && /^## / { exit }
  found { print }
' "$PLAN_FILE")

if [ -z "$acceptance_criteria" ]; then
  echo "error: no Acceptance Criteria section found in $PLAN_FILE" >&2
  exit 1
fi

# Determine diff base
if [ -n "$baseline_sha" ] && [ "$baseline_sha" != "null" ]; then
  diff_base="$baseline_sha"
else
  diff_base="HEAD~1"
fi

implementation_diff=$(git diff "$diff_base" 2>/dev/null || echo "")

if [ -z "$implementation_diff" ]; then
  implementation_diff="(no diff — baseline_sha may equal HEAD)"
fi

# Construct evidence-mapping prompt
spec_check_prompt="You are performing a coverage check of an implementation against its acceptance criteria.

## Acceptance Criteria for ${SLUG}

${acceptance_criteria}

## Implementation Diff

\`\`\`diff
${implementation_diff}
\`\`\`

## Your Task

For each acceptance criterion listed above:
1. Identify what code changes in the diff implement it
2. If you find clear diff evidence, mark coverage as 'covered' with a brief evidence note
3. If evidence is present but thin, mark as 'covered' with a note about the gap
4. If NO code change in the diff addresses the criterion, mark as 'uncovered'
5. If the criterion describes runtime behavior or performance that cannot be inferred
   from a static diff (e.g. \"exits 0 when...\", \"produces correct output when...\"),
   mark as 'not_diffable'

Then compute overall:
- 'covered' when all criteria are 'covered' or 'not_diffable'
- 'partial' when some are 'uncovered' but others are 'covered'
- 'uncovered' when the majority of criteria are 'uncovered'

Output ONLY valid JSON (no markdown wrapper) in exactly this schema:
{
  \"overall\": \"covered | partial | uncovered\",
  \"uncovered_count\": 0,
  \"criteria\": [
    {
      \"text\": \"criterion text\",
      \"coverage\": \"covered | uncovered | not_diffable\",
      \"evidence\": \"one-line note\",
      \"note\": \"\"
    }
  ]
}"

SPEC_CHECK_JSON="$GRAFT_STATE_DIR/spec-check.json"
SPEC_CHECK_TMP="${SPEC_CHECK_JSON}.tmp"

# Run Claude spec check
raw_output=$(printf '%s\n' "$spec_check_prompt" | \
  claude -p --dangerously-skip-permissions 2>/dev/null || echo "")

# Extract JSON block from output
json_output=$(printf '%s\n' "$raw_output" | \
  awk '/^\{/{found=1} found{print} /^\}/{if(found) exit}' || echo "")

if [ -z "$json_output" ] || ! printf '%s\n' "$json_output" | jq . >/dev/null 2>&1; then
  # Write a fallback record
  json_output=$(jq -n \
    --arg raw "$raw_output" \
    '{overall: "partial", uncovered_count: -1, criteria: [], note: "spec-check failed to obtain valid JSON from Claude"}')
fi

# Write spec-check.json atomically
printf '%s\n' "$json_output" > "$SPEC_CHECK_TMP"
mv "$SPEC_CHECK_TMP" "$SPEC_CHECK_JSON"

# Print summary
overall=$(printf '%s\n' "$json_output" | jq -r '.overall // "unknown"')
uncovered=$(printf '%s\n' "$json_output" | jq -r '.uncovered_count // "?"')
echo "Spec-check: $overall ($uncovered uncovered criteria)"
echo "spec-check.json written to $SPEC_CHECK_JSON"
