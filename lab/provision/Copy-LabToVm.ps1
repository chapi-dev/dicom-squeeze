<#
.SYNOPSIS
    Copies the lab scripts onto the VM.

.DESCRIPTION
    Outbound SSH is blocked on many corporate networks, so this lab drives the
    VM entirely through `az vm run-command`, which travels over the Azure
    control plane on 443. That channel only carries a script, not files, so the
    scripts directory is tarred, base64-encoded and unpacked on the far side.

    The alternative is to `git clone` the repo on the VM, which is cleaner once
    the code is public but useless while you are still iterating on it.
#>
[CmdletBinding()]
param(
  [string]$ResourceGroup = 'rg-dicom-lab-we',
  [string]$VmName        = 'vm-pacs-01',
  [string]$Source        = (Join-Path $PSScriptRoot '..\scripts'),
  [string]$Destination   = '/opt/dicom-lab'
)

$ErrorActionPreference = 'Stop'
$src = (Resolve-Path $Source).Path

$tar = Join-Path $env:TEMP ("lab-{0}.tar.gz" -f [guid]::NewGuid().ToString('N').Substring(0, 8))
# bsdtar ships with Windows 10+ as tar.exe.
tar -czf $tar -C $src .
if ($LASTEXITCODE -ne 0) { throw "tar failed" }

$b64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($tar))
Remove-Item $tar -Force
Write-Host ("payload: {0:N0} base64 chars" -f $b64.Length)

$script = @"
#!/usr/bin/env bash
set -euo pipefail
mkdir -p $Destination
echo '$b64' | base64 -d | tar -xz -C $Destination
# Line endings matter: a CRLF shebang makes the kernel look for an interpreter
# called "bash\r", which fails with a confusing "no such file or directory".
find $Destination -name '*.sh' -exec sed -i 's/\r$//' {} \;
chmod +x $Destination/*.sh
ls -la $Destination
"@

& (Join-Path $PSScriptRoot 'Invoke-VmScript.ps1') -Script $script -ResourceGroup $ResourceGroup -VmName $VmName
