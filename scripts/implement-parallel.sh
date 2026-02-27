#!/usr/bin/env bash
# Implement-parallel command: run multiple independent slices in parallel using git worktrees.
#
# Usage: bash scripts/implement-parallel.sh <slice1> <slice2> [<slice3> [<slice4>]]
#
# Each slice gets its own git worktree with its own run-state. Runs
# graft run software-factory:implement-verified <slice> in each worktree
# as a background process. Waits for all, then prints a summary table.
#
# REQUIREMENTS:
# - Must be run from the consumer repo root (not inside Claude Code; CLAUDECODE must be unset)
# - All slice paths must exist before any worktrees are created
# - All worktree branch names (implement/<slug>) must be available before starting
#
# NOTE: Only use with slices that touch separate files. Slices with overlapping
# changes will produce merge conflicts requiring manual resolution.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

REPO_ROOT="$(pwd)"

if [ $# -lt 2 ]; then
  echo "Usage: bash scripts/implement-parallel.sh <slice1> <slice2> [<slice3> [<slice4>]]" >&2
  echo "Accepts 2 to 4 slice arguments." >&2
  exit 1
fi

# Collect and validate slice args (skip empty)
slices=()
for arg in "$@"; do
  [ -z "$arg" ] && continue
  normalize_slice_dir "$arg"
  slices+=("$SLICE_DIR")
done

if [ ${#slices[@]} -lt 2 ]; then
  echo "error: at least 2 non-empty slice args required" >&2
  exit 1
fi

if [ ${#slices[@]} -gt 4 ]; then
  echo "error: at most 4 slices supported (graft arg model limitation)" >&2
  exit 1
fi

# Pre-flight: validate all slice paths exist
echo "Pre-flight checks..."
for slice_dir in "${slices[@]}"; do
  if [ ! -d "$slice_dir" ]; then
    echo "error: slice path does not exist: $slice_dir" >&2
    exit 1
  fi
done

# Derive slugs
slugs=()
for slice_dir in "${slices[@]}"; do
  slugs+=("${slice_dir#slices/}")
done

# Pre-flight: validate all worktree branches are available (all-or-nothing)
for slug in "${slugs[@]}"; do
  branch="implement/$slug"
  if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    echo "error: branch already exists: $branch" >&2
    echo "Delete it first: git branch -D $branch" >&2
    exit 1
  fi
done

# Create all worktrees
echo "Creating worktrees..."
for slug in "${slugs[@]}"; do
  worktree_path=".worktrees/$slug"
  branch="implement/$slug"
  git worktree add "$worktree_path" -b "$branch"
  echo "  Created: $worktree_path (branch: $branch)"
done

# Launch implement-verified for each slice in its worktree (background)
pids=()
log_files=()
echo ""
echo "Launching parallel implementations..."
for i in "${!slugs[@]}"; do
  slug="${slugs[$i]}"
  slice_dir="${slices[$i]}"
  worktree_path=".worktrees/$slug"
  log_file="$REPO_ROOT/.worktrees/$slug.log"

  (
    cd "$worktree_path"
    graft run software-factory:implement-verified "$slice_dir" \
      > "$log_file" 2>&1
  ) &
  pids+=("$!")
  log_files+=(".worktrees/$slug.log")
  echo "  [$!] $slice_dir → $worktree_path"
done

echo ""
echo "Waiting for all implementations to complete..."
echo "(This may take several minutes per slice)"
echo ""

# Wait and collect exit codes
exit_codes=()
for i in "${!pids[@]}"; do
  pid="${pids[$i]}"
  wait "$pid"
  exit_codes+=("$?")
done

# Print summary table
echo "implement-parallel results:"
all_passed=true
for i in "${!slugs[@]}"; do
  slug="${slugs[$i]}"
  exit_code="${exit_codes[$i]}"
  branch="implement/$slug"
  if [ "$exit_code" -eq 0 ]; then
    echo "  slices/$slug  ✓ passed  (branch: $branch)"
  else
    echo "  slices/$slug  ✗ failed  (branch: $branch, exit: $exit_code)"
    all_passed=false
  fi
done

echo ""

# Print merge and cleanup instructions
passing_branches=()
for i in "${!slugs[@]}"; do
  if [ "${exit_codes[$i]}" -eq 0 ]; then
    passing_branches+=("implement/${slugs[$i]}")
  fi
done

if [ ${#passing_branches[@]} -gt 0 ]; then
  echo "To merge passing slices (review diffs first to avoid conflicts):"
  for branch in "${passing_branches[@]}"; do
    echo "  git merge $branch"
  done
  echo ""
fi

echo "To view logs:"
for i in "${!slugs[@]}"; do
  echo "  cat ${log_files[$i]}"
done
echo ""

echo "To clean up worktrees:"
for slug in "${slugs[@]}"; do
  echo "  git worktree remove .worktrees/$slug && git branch -D implement/$slug"
done

if $all_passed; then
  exit 0
else
  exit 1
fi
