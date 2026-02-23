#!/usr/bin/env bash
# Verify: run consumer project verification.
#
# The software factory lives at .graft/<name>/ inside a consumer project.
# This script discovers and delegates to the consumer's scripts/verify.sh
# (the graft convention for verification state queries).
#
# Output: JSON matching the consumer's verify format, or a status object
# if no verification is configured.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FACTORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONSUMER_ROOT="$(cd "$FACTORY_ROOT/../.." && pwd)"

VERIFY_SCRIPT="$CONSUMER_ROOT/scripts/verify.sh"

if [ ! -f "$VERIFY_SCRIPT" ]; then
  jq -n '{status: "unconfigured", message: "No scripts/verify.sh in consumer project"}'
  exit 0
fi

cd "$CONSUMER_ROOT"
bash "$VERIFY_SCRIPT"
