# preToolUse guard: refuse to let the agent create or edit a DICOM binary inside this
# repository. DICOM Squeeze is a mockup and must never contain imaging data, anonymised
# or otherwise.
#
# Staying silent lets the normal permission flow continue. Only a deny decision is emitted.

$ErrorActionPreference = 'Stop'

$payload = [Console]::In.ReadToEnd()

if ($payload -imatch '\.(dcm|dicom|ima)([^a-z0-9]|$)') {
    Write-Output '{"permissionDecision":"deny","permissionDecisionReason":"This repository must never contain DICOM imaging files. See .github/copilot-instructions.md."}'
}
