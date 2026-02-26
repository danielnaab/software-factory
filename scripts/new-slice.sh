#!/usr/bin/env bash
# New-slice command: draft a new slice plan from a feature description.
#
# Usage: bash scripts/new-slice.sh "<description>"
#
# Reads current project context (slice list, recent git log), constructs a prompt
# combining the description + context + template format, and pipes it through
# claude -p to produce a complete draft plan file.
#
# Requires Claude to output "slug: <value>" as the very first non-empty line of
# its response. The script extracts the slug, validates it is kebab-case, and
# writes to slices/<slug>/plan.md. Exits 1 if the marker is absent, malformed,
# or the slug already exists.
#
# GRAFT_STATE_DIR is injected by graft, but this script does not use run-state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if [ $# -eq 0 ]; then
  echo "Usage: bash scripts/new-slice.sh \"<description>\"" >&2
  exit 1
fi

DESCRIPTION="$*"
TODAY=$(date +%Y-%m-%d)

# Gather context
slices_summary=$("$SCRIPT_DIR/list-slices.sh" 2>/dev/null || echo "(no slices found)")
recent_log=$(git log --oneline -10 2>/dev/null || echo "(no git log)")

# Plan template format for the prompt
template_format='---
status: draft
created: <YYYY-MM-DD>
depends_on: []
---

# <Title>

## Story

<2-3 paragraph explanation of the problem and why it matters>

## Approach

<Technical approach description>

## Acceptance Criteria

- <criterion 1>
- <criterion 2>
- `cargo test` passes with no regressions (or: no Rust changes required)

## Steps

- [ ] **<Step title>**
  - **Delivers** — <what this step delivers>
  - **Done when** — <specific, testable completion criteria>
  - **Files** — <list of files to create or modify>'

# Construct prompt
new_slice_prompt="You are drafting a new graft software-factory slice plan.

## Feature Description

${DESCRIPTION}

## Existing Slices (avoid duplication, use for depends_on)

${slices_summary}

## Recent Git History (for context)

${recent_log}

## Slice Plan Template

${template_format}

## Instructions

1. Derive a concise kebab-case slug from the description (e.g. \"add-retry-logic\" → slug: add-retry-logic)
2. Output \"slug: <value>\" as the VERY FIRST non-empty line of your response — nothing before it
3. Then output the complete plan file content (frontmatter through Steps section)
4. Use status: draft and created: ${TODAY} in the frontmatter
5. Set depends_on to the minimal set of slices that must land first (empty list if none)
6. Reference existing slices to avoid duplicating work already in progress or done
7. Include at least one Step with Delivers, Done when, and Files sub-bullets
8. The Acceptance Criteria section must include at least one cargo/script testable criterion
9. Do NOT wrap the output in markdown code fences — output raw text only

Remember: slug: <value> must be the very first non-empty line."

# Run Claude to generate the plan
raw_output=$(printf '%s\n' "$new_slice_prompt" | \
  claude -p --dangerously-skip-permissions 2>/dev/null)

if [ -z "$raw_output" ]; then
  echo "error: Claude returned no output" >&2
  exit 1
fi

# Extract slug from first non-empty line
first_line=$(printf '%s\n' "$raw_output" | awk 'NF{print; exit}')

if ! printf '%s\n' "$first_line" | grep -qE '^slug: [a-z][a-z0-9-]*$'; then
  echo "error: missing or malformed slug: marker on first line" >&2
  echo "Expected: slug: <kebab-case-name>" >&2
  echo "Got: $first_line" >&2
  exit 1
fi

slug=$(printf '%s\n' "$first_line" | sed 's/^slug: //')

# Check for existing slice
SLICE_DIR="slices/$slug"
if [ -d "$SLICE_DIR" ]; then
  echo "error: slice already exists: $SLICE_DIR" >&2
  exit 1
fi

# Extract plan content (everything after the first non-empty line)
plan_content=$(printf '%s\n' "$raw_output" | awk 'NF{found=1; next} found{print}' || echo "")

# Fallback: if awk produced nothing, strip just the slug line
if [ -z "$plan_content" ]; then
  plan_content=$(printf '%s\n' "$raw_output" | tail -n +2)
fi

if [ -z "$plan_content" ]; then
  echo "error: no plan content after slug line" >&2
  exit 1
fi

# Write plan file
mkdir -p "$SLICE_DIR"
printf '%s\n' "$plan_content" > "$SLICE_DIR/plan.md"

echo "Created: $SLICE_DIR/plan.md"
echo "Slug: $slug"
