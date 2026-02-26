#!/usr/bin/env bash
# Verify: run consumer project verification.
#
# The software factory lives at .graft/<name>/ inside a consumer project.
# This script discovers and delegates to the consumer's scripts/verify.sh
# (the graft convention for verification state queries).
#
# Output: JSON matching the consumer's verify format, or a status object
# if no verification is configured.
#
# When $GRAFT_STATE_DIR is set (command context), the result is also written
# to $GRAFT_STATE_DIR/verify.json for grove visibility and downstream use.
# When called via `state: verify` (state query context), $GRAFT_STATE_DIR is
# not set and this script remains read-only.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FACTORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONSUMER_ROOT="$(cd "$FACTORY_ROOT/../.." && pwd)"

VERIFY_SCRIPT="$CONSUMER_ROOT/scripts/verify.sh"

if [ ! -f "$VERIFY_SCRIPT" ]; then
  result=$(jq -n '{status: "unconfigured", message: "No scripts/verify.sh in consumer project"}')
  rc=0
else
  cd "$CONSUMER_ROOT"
  result=$(bash "$VERIFY_SCRIPT")
  rc=$?
fi

# Write to run-state only when called as a command (GRAFT_STATE_DIR is set).
# State queries do not set this variable and must remain read-only.
if [ -n "${GRAFT_STATE_DIR:-}" ]; then
  mkdir -p "$GRAFT_STATE_DIR"
  printf '%s\n' "$result" > "$GRAFT_STATE_DIR/verify.json"
fi

printf '%s\n' "$result"
exit $rc
