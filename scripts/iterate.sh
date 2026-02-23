#!/usr/bin/env bash
# Iterate command: read a slice plan and output a prompt for the next unchecked step.
#
# Usage: bash scripts/iterate.sh <slug>
#        bash scripts/iterate.sh slices/<slug>
#
# Accepts a bare slug (e.g. "my-feature") or a full path (e.g. "slices/my-feature").
# Reads the slice's plan.md, identifies the next unchecked step, and outputs
# a focused implementation prompt with project context.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# No args: list available slices
if [ $# -eq 0 ]; then
  slices_json=$("$SCRIPT_DIR/list-slices.sh")
  count=$(echo "$slices_json" | jq '.slices | length')

  if [ "$count" -eq 0 ]; then
    echo "No slices found. Run \`graft run plan\` to create one." >&2
    exit 1
  fi

  echo "Available slices:" >&2
  echo "" >&2
  echo "$slices_json" | jq -r '.slices[] | "  \(.slug)  (\(.status), \(.steps_done)/\(.steps_total) steps)"' >&2
  echo "" >&2
  echo "Usage: graft run iterate slices/<slug>" >&2
  exit 1
fi

normalize_slice_dir "$1"
PLAN_FILE="$SLICE_DIR/plan.md"

if [ ! -f "$PLAN_FILE" ]; then
  echo "Error: $PLAN_FILE not found" >&2
  exit 1
fi

# Read slice metadata via read-slice.sh
slice_json=$("$SCRIPT_DIR/read-slice.sh" "$SLICE_DIR")

status=$(echo "$slice_json" | jq -r '.status')
slug=$(echo "$slice_json" | jq -r '.slug')

# Detect consumer project verification
FACTORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONSUMER_ROOT="$(cd "$FACTORY_ROOT/../.." && pwd)"
CONSUMER_VERIFY=""
if [ -f "$CONSUMER_ROOT/scripts/verify.sh" ]; then
  CONSUMER_VERIFY="$CONSUMER_ROOT/scripts/verify.sh"
fi

steps_total=$(echo "$slice_json" | jq -r '.steps_total')
steps_done=$(echo "$slice_json" | jq -r '.steps_done')
next_step_number=$(echo "$slice_json" | jq -r '.next_step_number')
next_step=$(echo "$slice_json" | jq -r '.next_step')
story=$(echo "$slice_json" | jq -r '.story')
approach=$(echo "$slice_json" | jq -r '.approach')
acceptance_criteria=$(echo "$slice_json" | jq -r '.acceptance_criteria')

# Handle completed slice
if [ "$next_step_number" -eq 0 ]; then
  cat <<EOF
## Slice Complete

All steps in \`$slug\` are done ($steps_done/$steps_total).

Update the frontmatter status in \`$PLAN_FILE\` to \`done\`:

\`\`\`yaml
---
status: done
---
\`\`\`
EOF
  exit 0
fi

# Output the implementation prompt
cat <<EOF
## Implement Step $next_step_number of $steps_total: $slug

**Slice status:** $status | **Progress:** $steps_done/$steps_total steps done

### Story

$story

### Approach

$approach

### Acceptance Criteria

$acceptance_criteria

### Current Step

$next_step

### Instructions

Implement this step. When done:

1. Verify the changes work:
$(if [ -n "$CONSUMER_VERIFY" ]; then
  echo "   Run \`bash $CONSUMER_VERIFY\` from \`$CONSUMER_ROOT\`"
else
  echo "   Run the project's test/lint/format checks"
fi)
2. Check off the step in \`$PLAN_FILE\` by changing \`- [ ]\` to \`- [x]\`
EOF
