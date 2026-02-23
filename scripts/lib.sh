#!/usr/bin/env bash
# Shared utilities for software factory scripts.

# Normalize a slice argument to a directory path.
# Accepts bare slug ("my-feature") or full path ("slices/my-feature" or "slices/my-feature/").
# Sets SLICE_DIR and SLUG variables in the caller's scope.
normalize_slice_dir() {
  SLICE_DIR="${1:?Usage: normalize_slice_dir <slug>}"
  SLICE_DIR="${SLICE_DIR%/}"
  case "$SLICE_DIR" in
    slices/*) ;;
    *) SLICE_DIR="slices/$SLICE_DIR" ;;
  esac
  SLUG="${SLICE_DIR#slices/}"
}
