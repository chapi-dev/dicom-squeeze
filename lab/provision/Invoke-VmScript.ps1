<#
.SYNOPSIS
  Runs a local bash script on the lab VM through the Azure control plane.
.DESCRIPTION
  SSH is blocked outbound from this network, and passing a script inline to
  az.bat mangles it (cmd re-parses quotes and dashes). Writing the script to a
  file with LF endings and passing it as @file avoids both problems.
#>
param(
  [Parameter(Mandatory)][string]$Script,
  [hashtable]$Env = @{},
  [string]$ResourceGroup = 'rg-dicom-lab-we',
  [string]$VmName = 'vm-pacs-01'
)

$tmp = Join-Path $env:TEMP ("runcmd-{0}.sh" -f ([guid]::NewGuid().ToString('N').Substring(0, 8)))
# Azure runs this with bash; CRLF would break heredocs and shebangs.
$lf = ($Script -replace "`r`n", "`n")

# Environment assignments must land *after* the shebang. Prepending them pushes
# "#!/usr/bin/env bash" off line 1, at which point the agent runs the script
# with dash instead and constructs like "set -o pipefail" fail.
if ($Env.Count -gt 0) {
  $exports = ($Env.GetEnumerator() | ForEach-Object { "export {0}='{1}'" -f $_.Key, $_.Value }) -join "`n"
  $lines = $lf -split "`n", 2
  if ($lines[0] -like '#!*') {
    $lf = $lines[0] + "`n" + $exports + "`n" + $lines[1]
  }
  else {
    $lf = $exports + "`n" + $lf
  }
}

[System.IO.File]::WriteAllText($tmp, $lf, (New-Object System.Text.UTF8Encoding $false))

try {
  $raw = az vm run-command invoke -g $ResourceGroup -n $VmName `
    --command-id RunShellScript --scripts "@$tmp" `
    --query "value[0].message" -o tsv 2>&1
  $raw -join "`n"
}
finally {
  Remove-Item $tmp -ErrorAction SilentlyContinue
}
