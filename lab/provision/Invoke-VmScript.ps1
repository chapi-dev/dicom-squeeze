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
$preamble = @()
if ($Env.Count -gt 0) {
  # Values are single-quoted for bash, so the only character that needs
  # escaping is the single quote itself: close, emit \', reopen. Keys become
  # bare identifiers, so anything that is not a valid name is rejected.
  $preamble += $Env.GetEnumerator() | ForEach-Object {
    if ($_.Key -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
      throw "Invalid environment variable name: '$($_.Key)'"
    }
    $quoted = ([string]$_.Value) -replace "'", "'\''"
    "export {0}='{1}'" -f $_.Key, $quoted
  }
}
# The run-command API reports whether it managed to *launch* the script, not
# whether the script succeeded. Print the real exit status on the way out so it
# can be checked below.
$marker = '__DICOM_LAB_EXIT_STATUS__'
$preamble += "trap 'echo `"$marker=`$?`"' EXIT"
$exports = $preamble -join "`n"
$lines = $lf -split "`n", 2
if ($lines[0] -like '#!*') {
  $lf = $lines[0] + "`n" + $exports + "`n" + $(if ($lines.Count -gt 1) { $lines[1] } else { '' })
}
else {
  $lf = $exports + "`n" + $lf
}

[System.IO.File]::WriteAllText($tmp, $lf, (New-Object System.Text.UTF8Encoding $false))

try {
  $raw = az vm run-command invoke -g $ResourceGroup -n $VmName `
    --command-id RunShellScript --scripts "@$tmp" `
    --query "value[0].message" -o tsv 2>&1
  $cliExit = $LASTEXITCODE
  $output = $raw -join "`n"
  if ($cliExit -ne 0) {
    throw "az vm run-command invoke failed with exit code $cliExit`n$output"
  }
  $status = [regex]::Match($output, "$marker=(\d+)")
  if (-not $status.Success) {
    throw "The script on $VmName did not report an exit status; it may have been killed.`n$output"
  }
  $output = ($output -replace "(?m)^$marker=\d+\r?\n?", '').TrimEnd()
  if ([int]$status.Groups[1].Value -ne 0) {
    throw "The script on $VmName exited with status $($status.Groups[1].Value)`n$output"
  }
  $output
}
finally {
  Remove-Item $tmp -ErrorAction SilentlyContinue
}
