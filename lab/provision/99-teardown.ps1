<#
.SYNOPSIS
    Deletes everything the lab created.

.DESCRIPTION
    The VM stops billing when deallocated, but the managed disks and the public
    IP do not: they cost roughly 13 EUR a month whether or not anything is
    running. If you are finished, delete the group.

.EXAMPLE
    .\99-teardown.ps1 -Mode Deallocate   # pause, keep the data
    .\99-teardown.ps1 -Mode Delete       # remove everything
#>
[CmdletBinding()]
param(
  [string]$ResourceGroup = 'rg-dicom-lab-we',
  [string]$VmName        = 'vm-pacs-01',
  [ValidateSet('Deallocate', 'Delete')]
  [string]$Mode          = 'Deallocate'
)

$ErrorActionPreference = 'Stop'

if ($Mode -eq 'Deallocate') {
  Write-Host "deallocating $VmName..." -ForegroundColor Cyan
  az vm deallocate -g $ResourceGroup -n $VmName -o none
  Write-Host @"
Done. Compute charges stop now. Still billing:
  data disk  128 GB StandardSSD   ~ 8.24 EUR/month
  os disk     32 GB StandardSSD   ~ 2.06 EUR/month
  public IP   Standard static     ~ 3.14 EUR/month
  DICOM svc   0.02 EUR/GB/month on what you stored
Restart with: az vm start -g $ResourceGroup -n $VmName
Note the public IP is static, so the DNS label and the TLS certificate survive.
"@ -ForegroundColor Yellow
}
else {
  Write-Host "deleting resource group $ResourceGroup and everything in it" -ForegroundColor Red
  $confirm = Read-Host "type the resource group name to confirm"
  if ($confirm -ne $ResourceGroup) { Write-Host "aborted"; exit 1 }
  az group delete -n $ResourceGroup --yes --no-wait
  Write-Host "deletion started in the background. Check with: az group exists -n $ResourceGroup"
}
