#!/bin/bash
# pip-audit-warn.sh
# Runs pip-audit in advisory mode (never blocks push/commit).

set -euo pipefail

if [[ -x ".venv/bin/pip-audit" ]]; then
  PIP_AUDIT_BIN=".venv/bin/pip-audit"
else
  PIP_AUDIT_BIN="$(command -v pip-audit || true)"
fi

if [[ -z "$PIP_AUDIT_BIN" ]]; then
  echo "WARNING: pip-audit is not installed; skipping advisory dependency audit"
  exit 0
fi

"$PIP_AUDIT_BIN" --local || true
exit 0
