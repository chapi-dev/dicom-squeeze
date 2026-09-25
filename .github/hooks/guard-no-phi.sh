#!/usr/bin/env bash
# preToolUse guard: refuse to let the agent create or edit a DICOM binary inside this
# repository. DICOM Squeeze is a mockup and must never contain imaging data, anonymised
# or otherwise.
#
# Staying silent lets the normal permission flow continue. Only a deny decision is emitted.
set -euo pipefail

payload=$(cat)

if printf '%s' "$payload" | grep -Eiq '\.(dcm|dicom|ima)([^a-z0-9]|$)'; then
  printf '{"permissionDecision":"deny","permissionDecisionReason":"This repository must never contain DICOM imaging files. See .github/copilot-instructions.md."}'
fi
