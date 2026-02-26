#!/usr/bin/env bash
# Review command: run Claude as an adversarial reviewer against the implementation diff.
#
# Usage: bash scripts/review.sh
#
# Reads baseline_sha and slice path from $GRAFT_STATE_DIR/session.json, extracts
# the "Acceptance Criteria" section from the slice plan, runs git diff, and pipes
# criteria + diff to Claude with an adversarial review prompt.
#
# Always exits 0 — the review is advisory only. A "fail" verdict surfaces in
# grove's Run State for human review; it does not abort any sequence.
#
# If $GRAFT_STATE_DIR/checkpoint.json exists, its message field is updated to
# include the review verdict via atomic jq + tmp rename.
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

# Extract Acceptance Criteria section (from ## Acceptance Criteria to next ## heading)
acceptance_criteria=$(awk '
  /^## Acceptance Criteria/ { found=1; next }
  found && /^## / { exit }
  found { print }
' "$PLAN_FILE")

if [ -z "$acceptance_criteria" ]; then
  echo "error: no Acceptance Criteria section found in $PLAN_FILE" >&2
  exit 1
fi

# Determine diff base: prefer baseline_sha from session.json, fall back to HEAD~1
if [ -n "$baseline_sha" ] && [ "$baseline_sha" != "null" ]; then
  diff_base="$baseline_sha"
else
  diff_base="HEAD~1"
fi

implementation_diff=$(git diff "$diff_base" 2>/dev/null || echo "")

if [ -z "$implementation_diff" ]; then
  implementation_diff="(no diff — baseline_sha may equal HEAD)"
fi

# Construct adversarial review prompt
review_prompt="You are a skeptical reviewer who did NOT write this code.
Your goal is to find what is missing or wrong, NOT to confirm that it looks correct.
Do not be generous in your assessment. Probe for gaps.

## Acceptance Criteria for ${SLUG}

${acceptance_criteria}

## Implementation Diff

\`\`\`diff
${implementation_diff}
\`\`\`

## Your Task

For each acceptance criterion above:
1. Search the diff for direct evidence that the criterion is implemented
2. If you find clear evidence, mark it as 'met' with a one-line note
3. If evidence is partial or ambiguous, mark it 'partial' with your concern
4. If there is NO code change in the diff addressing the criterion, mark it 'unmet'
5. If the criterion describes runtime behavior that cannot be verified from a static diff, mark it 'not_diffable'

Then give an overall verdict:
- 'pass': all criteria are met or not_diffable, no significant concerns
- 'concerns': criteria are mostly met but you have notable concerns about correctness or completeness
- 'fail': one or more criteria are unmet

Output ONLY valid JSON (no markdown wrapper) in exactly this schema:
{
  \"verdict\": \"pass | concerns | fail\",
  \"summary\": \"one sentence summary\",
  \"criteria\": [
    {\"criterion\": \"...\", \"status\": \"met | unmet | partial | not_diffable\", \"evidence\": \"...\"}
  ],
  \"concerns\": [\"...\"]
}"

REVIEW_JSON="$GRAFT_STATE_DIR/review.json"
REVIEW_TMP="${REVIEW_JSON}.tmp"

# Run Claude review — always exits 0 regardless of verdict
# Capture only the JSON output from Claude (strip any preamble/trailing text)
raw_output=$(printf '%s\n' "$review_prompt" | \
  claude -p --dangerously-skip-permissions 2>/dev/null || echo "")

# Extract JSON block from output (find first { to last })
json_output=$(printf '%s\n' "$raw_output" | \
  awk '/^\{/{found=1} found{print} /^\}/{if(found) exit}' || echo "")

if [ -z "$json_output" ] || ! printf '%s\n' "$json_output" | jq . >/dev/null 2>&1; then
  # Claude output was not valid JSON — write a failure review record
  json_output=$(jq -n \
    --arg summary "Review script failed to obtain valid JSON from Claude" \
    --arg raw "$raw_output" \
    '{verdict: "concerns", summary: $summary, criteria: [], concerns: [$raw]}')
fi

# Write review.json atomically
printf '%s\n' "$json_output" > "$REVIEW_TMP"
mv "$REVIEW_TMP" "$REVIEW_JSON"

# Print summary to stdout
verdict=$(printf '%s\n' "$json_output" | jq -r '.verdict // "unknown"')
summary=$(printf '%s\n' "$json_output" | jq -r '.summary // ""')
echo "Review verdict: $verdict — $summary"

# If checkpoint.json exists, update its message field to include the verdict
CHECKPOINT_JSON="$GRAFT_STATE_DIR/checkpoint.json"
if [ -f "$CHECKPOINT_JSON" ]; then
  CHECKPOINT_TMP="${CHECKPOINT_JSON}.tmp"
  jq --arg v "$verdict" '.message += " Review: \($v)."' \
    "$CHECKPOINT_JSON" > "$CHECKPOINT_TMP" && mv "$CHECKPOINT_TMP" "$CHECKPOINT_JSON"
fi

# Always exit 0 — review is advisory only
exit 0
