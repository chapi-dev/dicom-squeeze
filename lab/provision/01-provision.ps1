<#
.SYNOPSIS
    Builds the DICOM lab from nothing.

.DESCRIPTION
    Creates a resource group, a VM with a dedicated managed disk for the image
    archive, an NSG locked to your own egress address, a DNS label so TLS can be
    issued automatically, and an Azure Health Data Services DICOM service.

    Run it once, then use Copy-LabToVm.ps1 and Invoke-VmScript.ps1 to drive the
    box. Tear it down with 99-teardown.ps1.

.EXAMPLE
    .\01-provision.ps1 -DnsLabel my-dicom-lab
#>
[CmdletBinding()]
param(
  [string]$ResourceGroup = 'rg-dicom-lab-we',
  [string]$Location      = 'westeurope',
  [string]$VmName        = 'vm-pacs-01',
  # B-series is not offered in West Europe at all, and D2s_v5 carries a zonal
  # restriction on many subscriptions. D2as_v6 was clean across all three zones.
  # If this fails with SkuNotAvailable, run the diagnostic at the bottom.
  [string]$VmSize        = 'Standard_D2as_v6',
  [int]$DataDiskGb       = 128,
  [Parameter(Mandatory)][string]$DnsLabel,
  # Health Data Services workspace names are globally unique -- they become the
  # DNS label <workspace>-<service>.dicom.azurehealthcareapis.com. Left empty,
  # it is derived from -DnsLabel, which you already had to make unique.
  [string]$WorkspaceName = '',
  [string]$DicomService  = 'dicomsvc',
  [string]$AdminUser     = 'azureuser',
  [string]$ShutdownTime  = '1900',
  [string]$ShutdownTz    = 'W. Europe Standard Time'
)

$ErrorActionPreference = 'Stop'

if (-not $WorkspaceName) {
  $WorkspaceName = ('ws' + ($DnsLabel -replace '[^a-zA-Z0-9]', '')).ToLower()
  if ($WorkspaceName.Length -gt 24) { $WorkspaceName = $WorkspaceName.Substring(0, 24) }
}

# $ErrorActionPreference does not apply to native executables: az can fail and
# the script sails on. Without this a failed vm create ran through fifteen more
# calls against resources that were never created, and still printed a green
# "done" with an empty FQDN.
function Invoke-Az {
  $out = az @args
  if ($LASTEXITCODE -ne 0) { throw "az $($args -join ' ') failed with exit code $LASTEXITCODE" }
  $out
}

function Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

Step 'your egress address'
# The NSG is pinned to this. If your ISP rotates it, the lab goes dark until you
# update the rules -- which is the correct failure mode for an imaging archive.
$myIp = (Invoke-RestMethod 'https://api.ipify.org?format=json').ip
Write-Host "  $myIp"

Step 'resource group'
Invoke-Az group create -n $ResourceGroup -l $Location --tags purpose=dicom-lab -o none

Step 'ssh key'
$keyPath = Join-Path $HOME '.ssh\dicom-lab'
if (-not (Test-Path $keyPath)) {
  ssh-keygen -t ed25519 -f $keyPath -N '""' -C 'dicom-lab' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "ssh-keygen failed with exit code $LASTEXITCODE" }
}

Step "virtual machine ($VmSize)"
Invoke-Az vm create `
  -g $ResourceGroup -n $VmName `
  --image 'Canonical:ubuntu-24_04-lts:server:latest' `
  --size $VmSize `
  --admin-username $AdminUser `
  --ssh-key-values "$keyPath.pub" `
  --public-ip-sku Standard `
  --public-ip-address-dns-name $DnsLabel `
  --os-disk-size-gb 30 `
  --storage-sku StandardSSD_LRS `
  --data-disk-sizes-gb $DataDiskGb `
  --nsg-rule NONE `
  --assign-identity `
  -o none

Step 'network rules'
# Nothing is open to the world except port 80, and that only because the ACME
# HTTP-01 challenge is validated from addresses Let's Encrypt does not publish.
Invoke-Az network nsg rule create -g $ResourceGroup --nsg-name "${VmName}NSG" -n allow-dimse `
  --priority 120 --access Allow --protocol Tcp --direction Inbound `
  --source-address-prefixes "$myIp/32" --destination-port-ranges 4242 -o none
Invoke-Az network nsg rule create -g $ResourceGroup --nsg-name "${VmName}NSG" -n allow-http-acme `
  --priority 340 --access Allow --protocol Tcp --direction Inbound `
  --source-address-prefixes Internet --destination-port-ranges 80 -o none
Invoke-Az network nsg rule create -g $ResourceGroup --nsg-name "${VmName}NSG" -n allow-https `
  --priority 350 --access Allow --protocol Tcp --direction Inbound `
  --source-address-prefixes "$myIp/32" --destination-port-ranges 443 -o none

Step 'auto-shutdown'
Invoke-Az vm auto-shutdown -g $ResourceGroup -n $VmName --time $ShutdownTime -o none
# The CLI writes the schedule in UTC regardless of the location, so correct it.
$sub = Invoke-Az account show --query id -o tsv
Invoke-Az resource update `
  --ids "/subscriptions/$sub/resourceGroups/$ResourceGroup/providers/microsoft.devtestlab/schedules/shutdown-computevm-$VmName" `
  --set "properties.timeZoneId=$ShutdownTz" -o none

Step 'health data services workspace'
Invoke-Az healthcareapis workspace create -g $ResourceGroup -n $WorkspaceName -l $Location -o none

Step 'dicom service'
# Microsoft's own regional availability page still lists only Canada Central,
# East US and East US 2 at the time of writing. West Europe works. Trust ARM.
Invoke-Az healthcareapis workspace dicom-service create `
  -g $ResourceGroup --workspace-name $WorkspaceName -n $DicomService -l $Location -o none

Step 'rbac'
$scope = "/subscriptions/$sub/resourceGroups/$ResourceGroup/providers/Microsoft.HealthcareApis/workspaces/$WorkspaceName/dicomservices/$DicomService"
$vmMi  = Invoke-Az vm identity show -g $ResourceGroup -n $VmName --query principalId -o tsv
$me    = Invoke-Az ad signed-in-user show --query id -o tsv
# There are exactly two data-plane roles: DICOM Data Owner and DICOM Data Reader.
Invoke-Az role assignment create --assignee-object-id $vmMi --assignee-principal-type ServicePrincipal `
  --role 'DICOM Data Owner' --scope $scope -o none
Invoke-Az role assignment create --assignee-object-id $me --assignee-principal-type User `
  --role 'DICOM Data Owner' --scope $scope -o none

Step 'done'
$fqdn = Invoke-Az network public-ip show -g $ResourceGroup -n "${VmName}PublicIP" --query dnsSettings.fqdn -o tsv
$svc  = Invoke-Az healthcareapis workspace dicom-service show -g $ResourceGroup --workspace-name $WorkspaceName -n $DicomService --query serviceUrl -o tsv
# The lab scripts read these two. Exporting them here means the names chosen by
# the parameters above are the ones the scripts use, with nothing to copy by hand.
$env:LAB_FQDN     = $fqdn
$env:AZ_DICOM_URL = "$svc/v1"
Write-Host @"

  VM FQDN        : $fqdn   (exported as `$env:LAB_FQDN)
  DICOM service  : $svc/v1   (exported as `$env:AZ_DICOM_URL)

  Next:
    `$env:ORTHANC_PASSWORD = '<pick a strong one>'
    .\Copy-LabToVm.ps1
    .\Invoke-VmScript.ps1 -Script (Get-Content ..\scripts\20-setup-disk.sh -Raw)

  If ``az vm create`` failed with SkuNotAvailable, the real message is hidden
  behind an az CLI bug ("The content for this response was already consumed").
  Recover it with:
    az vm create ... --debug *> debug.log ; Select-String 'Code:' debug.log
  and list what your subscription may actually use:
    az vm list-skus -l $Location --size Standard_D --all -o table
"@ -ForegroundColor Green
