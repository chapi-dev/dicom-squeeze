# The DICOM lab

A working radiology archive on Azure, holding a real CT scan, reachable both the
way a Philips PACS reaches one and the way a cloud service expects you to.

This exists because the app in this repository is a mockup about *compressing*
DICOM, and that premise only makes sense once you have seen what a DICOM file
actually is, how the pixels get in and out, and what the bytes cost per year.

Everything below was measured on the lab, not quoted from documentation. Where
the documentation disagreed with the running system, that is called out.

---

## What gets built

```
                      you (one IP, allow-listed)
                              │ 443
                    ┌─────────▼──────────┐
                    │  Caddy             │  Let's Encrypt cert on the
                    │  (auto TLS)        │  *.cloudapp.azure.com name
                    └─────────┬──────────┘
                              │ 8042
   4242 ┌────────────────────►│
  DIMSE │            ┌────────▼──────────┐
        │            │  Orthanc 1.12.9   │  the PACS stand-in
        │            │  AET: AZLABPACS   │
        │            └────────┬──────────┘
        │                     │
        │            ┌────────▼──────────┐
        │            │  /srv/dicom       │  128 GB managed disk,
        │            │  ext4             │  separate from the OS disk
        │            └───────────────────┘
        │
   vm-pacs-01, Standard_D2as_v6, Ubuntu 24.04


   ┌──────────────────────────────────────────┐
   │  Azure Health Data Services              │   the same study again,
   │  DICOM service (DICOMweb only)           │   managed, no DIMSE
   └──────────────────────────────────────────┘
```

---

## The data

`LIDC-IDRI-0001` from [The Cancer Imaging Archive](https://www.cancerimagingarchive.net/),
a chest CT released under CC-BY 3.0. De-identified at source, no login needed,
freely redistributable. 133 slices.

What one slice actually contains:

```
(0002,0010) UI =LittleEndianExplicit          <- the transfer syntax
(0008,0016) UI =CTImageStorage                <- the SOP class
(0008,0060) CS [CT]
(0008,0070) LO [GE MEDICAL SYSTEMS]
(0010,0020) LO [LIDC-IDRI-0001]
(0010,0010) PN (no value available)           <- de-identified
(0028,0010) US 512                            Rows
(0028,0011) US 512                            Columns
(0028,0100) US 16                             BitsAllocated
(0028,0004) CS [MONOCHROME2]
(7fe0,0010) OW ...                            524288 bytes
```

512 × 512 × 2 bytes = 524,288, exactly the size of the pixel element. **The file
is not compressed at all.** That is not an oversight; `Explicit VR Little Endian`
is the safest interchange syntax in DICOM and huge numbers of real archives are
full of it.

| | |
|---|---|
| Pixel payload, 133 slices (measured) | **66.5 MiB** |
| Same data at an assumed 2.6:1 (JPEG-LS lossless) | 25.6 MiB |
| Same data at an assumed 2.8:1 (JPEG 2000 lossless) | 23.8 MiB |
| Same data at an assumed 2.9:1 (HTJ2K lossless) | 22.9 MiB |

> **Only the first row is a measurement.** The 2.6, 2.8 and 2.9 ratios are
> unsourced placeholders: no codec was run on this study and no published study
> or vendor datasheet backs these exact figures. They sit inside the planning
> ranges in [`src/lib/codecs.ts`](../src/lib/codecs.ts) and are here to show the
> arithmetic, not to report a result. Do not quote them as findings.

That gap, multiplied across an archive, is the entire business case for the tool
this repository mocks up.

---

## How a Philips PACS reads it: DIMSE

DIMSE is the original 1993 protocol and it is still how essentially every
modality, workstation and vendor PACS moves images. It is not HTTP. Two nodes
open a TCP socket and negotiate an **association**, agreeing on which SOP Classes
and Transfer Syntaxes they both support before a single byte of pixel data moves.

Every node has an **AE Title**, a 16-character name. A peer that does not
recognise the calling AE Title drops the association. This is why adding a
workstation to a hospital PACS is a change request and not a client setting.

### C-ECHO — is anyone there

```
I: Requesting Association
I: Association Accepted (Max Send PDV: 16372)
I: Sending Echo Request (MsgID 1)
I: Received Echo Response (Success)
```

### C-STORE — the scanner pushes

```
storescu exit code     : 0
associations requested : 1
store requests sent    : 133
store responses ok     : 133
elapsed seconds        : 3
```

133 instances over **one** association in 3 seconds.

> **The failure that bites you.** The TCIA archive ships a `LICENSE` text file
> next to the `.dcm` files. Without `--scan-pattern '*.dcm'`, `storescu` tries
> to parse it as DICOM, fails, and **aborts the entire association**. The 32
> instances already sent stay in the PACS. You get a partial study and an exit
> code you may not be checking. This is what "the study is missing slices" looks
> like from the sending side.

### C-FIND — what do you have

The query is itself a DICOM object. You send a dataset with empty tags, and the
peer returns one dataset per match with those tags filled in:

```
(0008,0052) CS [SERIES]                       QueryRetrieveLevel
(0008,0054) AE [AZLABPACS]                    RetrieveAETitle
(0008,0060) CS [CT]                           Modality
(0010,0020) LO [LIDC-IDRI-0001]               PatientID
(0020,000e) UI [1.3.6.1.4.1.14519...603192]   SeriesInstanceUID
(0020,1209) IS [133]                          NumberOfSeriesRelatedInstances
```

### C-MOVE — and this is the one that does not survive the cloud

C-MOVE does **not** return images to the caller. It instructs the PACS to open a
*separate, new* association **outbound** to a third node, named only by AE Title.
The PACS must already hold that AE Title's host and port in its own config.

```
  registered in the PACS:
  { "AET": "WORKSTATION", "Host": "172.17.0.1", "Port": 11112 }

I: Received Move Response 1..18 (Pending)
  files received by storescp: 133
```

> **The failure that bites you, again.** Orthanc runs in a container, so its
> `127.0.0.1` is the *container's* loopback. Registering the workstation as
> `127.0.0.1` produced `TCP Initialization Error: Connection refused` and a
> `Failed: UnableToProcess` status at the caller — which tells you nothing about
> the cause. The destination has to be routable *from where the PACS actually
> runs*: here, the Docker bridge gateway.
>
> This is the container-era restatement of why C-MOVE cannot cross NAT, a
> firewall or a cloud perimeter. The archive dials out to an address it was told
> about, and that address has to mean the same thing on both sides.

---

## How the cloud expects you to read it: DICOMweb

Same data model, REST binding, three services: **QIDO-RS** (search), **WADO-RS**
(retrieve), **STOW-RS** (store).

What disappears: AE Titles, association negotiation, inbound ports on the
client, and change requests to add a reader. What stays: the payload is still
DICOM and `multipart/related` is still the wire format for pixels.

```
GET /dicom-web/studies
  00100020 PatientID                     ['LIDC-IDRI-0001']
  00080061 ModalitiesInStudy             ['CT']
  00201208 NumberOfStudyRelatedInstances [133]

GET .../instances/{sop}/rendered
  JPEG image data, 512x512, 24474 bytes
```

That last one is worth pausing on: **WADO-RS can hand you a PNG or JPEG.** DIMSE
cannot. Every web viewer that shows a study without a plugin is doing this.

---

## The two implementations do not behave the same

Same standard, same study, same queries. These are the differences that break
client code on migration.

| | Orthanc | Azure DICOM service |
|---|---|---|
| `GET .../instances` | 133 | **100** |
| `?limit=200` | 133 | 133 |
| Empty result | `200` + `[]` | **`204`, no body** |
| Study-level fields returned | 15 tags incl. `ModalitiesInStudy` | 11 tags, **no** `ModalitiesInStudy` |
| `PixelData` in `/metadata` | present as `BulkDataURI` | absent |
| `/metadata` size (133 instances) | 879 KB | 528 KB |
| Re-`STOW` an existing instance | overwrite policy applies | **`409 Conflict`** |

Three of these fail silently:

- **Pagination.** Azure defaults to 100 and documents 200 as the ceiling. A
  client that assumes one call returns everything loses 33 slices with no error.
  In imaging that is the worst possible bug.
- **`204 No Content` has no body.** Any client calling `.json()` unconditionally
  throws where it previously got `[]`.
- **`ModalitiesInStudy` is absent** unless you pass `includefield=00080061`.

And `STOW-RS` is not idempotent the way `PUT` is. Re-sending a stored instance
is a *conflict*, not a no-op — a pipeline retrying a timed-out batch must not
read `409` as data loss:

```
  batch  1: HTTP 409  stored=0  <- 20 refused, 20 already present
  newly stored: 0, already present: 133
```

---

## The finding that decides your architecture

**The Azure DICOM service does not speak DIMSE. At all.**

```
resolving wsdicomlabwe-dicomsvc.dicom.azurehealthcareapis.com
48.199.209.130  mshapisg2-prod-k8s-westeu-03-gateway...
  port 104   : closed/filtered      <- the registered DICOM port
  port 11112 : closed/filtered
  port 4242  : closed/filtered
```

There is no listener. Nothing that speaks C-STORE, C-FIND or C-MOVE — which is
every scanner, every vendor workstation, and every existing PACS in the building
— can talk to it directly. **You need a gateway**, and that gateway is your
problem to run, monitor and pay for.

This single fact drives the design of any migration.

### And it will not transcode to the syntaxes that matter

Asking for specific transfer syntaxes on retrieve:

| Transfer syntax | UID | Result |
|---|---|---|
| Explicit VR Little Endian (uncompressed) | `1.2.840.10008.1.2.1` | **200** |
| JPEG Baseline (lossy) | `1.2.840.10008.1.2.4.50` | 406 |
| JPEG Lossless SV1 | `1.2.840.10008.1.2.4.70` | 406 |
| **JPEG-LS Lossless** | `1.2.840.10008.1.2.4.80` | **406** |
| **HTJ2K Lossless** | `1.2.840.10008.1.2.4.201` | **406** |

`406 Not Acceptable` means the service will not produce it. The two syntaxes
that matter for lossless archival compression are exactly the two missing. If
you want your archive stored compressed, **you compress it before it arrives.**

---

## What it costs

Source: the [Azure Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices),
West Europe, EUR, pay-as-you-go retail prices, retrieved September 2026. The
figures can be reproduced with these queries:

```bash
API='https://prices.azure.com/api/retail/prices?currencyCode=EUR'
# VM
curl -sG "$API" --data-urlencode "\$filter=armRegionName eq 'westeurope' and armSkuName eq 'Standard_D2as_v6' and priceType eq 'Consumption'"
# Standard SSD managed disks, E10 (data) and E4 (OS)
curl -sG "$API" --data-urlencode "\$filter=armRegionName eq 'westeurope' and (skuName eq 'E10 LRS' or skuName eq 'E4 LRS')"
# Standard static public IP
curl -sG "$API" --data-urlencode "\$filter=armRegionName eq 'westeurope' and contains(meterName, 'Static Public IP')"
# DICOM service storage
curl -sG "$API" --data-urlencode "\$filter=armRegionName eq 'westeurope' and contains(productName, 'DICOM')"
```

Retail prices change. If a rerun disagrees with the tables below, the API is
right and this page is out of date.

### The lab

| Item | Rate | Month (24×7) |
|---|---|---|
| VM `Standard_D2as_v6` | €0.0945/hr | €68.98 |
| Data disk, E10 128 GB StandardSSD | — | €8.24 |
| OS disk, E4 32 GB StandardSSD | — | €2.06 |
| Public IP, Standard static | €0.0043/hr | €3.14 |
| DICOM service, 67 MB stored | €0.02/GB/mo | €0.00 |
| | | **€82.42** |

With the auto-shutdown at 19:00 and ~10 h × 22 working days, compute drops to
€20.79 and the total to **€34.23**. Spot pricing would take the VM itself to
roughly €13.80/month.

**Disks and the public IP bill whether or not the VM is running.** Deallocating
saves €68.98; only deleting the group saves the remaining €13.44.

### The part that actually matters

The DICOM service charges **€0.02/GB/month** for storage, in one flat tier.
Azure meters storage with GB = 1024³ bytes, so:

| Archive | Per year |
|---|---|
| 1 TB | €246 |
| 1 PB | €251,658 |
| **3 PB** | **€754,975** |

There is **no Cool and no Archive tier** to demote a five-year-old study into.
Compare that with raw blob storage, where Cool and Archive exist precisely for
data that is written once and read rarely — which describes almost everything
in a radiology archive older than a few months.

Two conclusions follow, and they point the same way:

1. **Compression is not an optimisation, it is the architecture.** At an
   assumed 2.6:1 lossless (a placeholder, see [the data](#the-data)), 3 PB
   becomes 1.15 PB and €754,975 becomes **€290,375** — a saving of €464,600 a
   year, larger than most teams' entire infrastructure budget.
   At an assumed 2.9:1 for HTJ2K the bill falls to €260,336.
2. **A managed DICOM service is a metadata and access layer, not a bulk
   archive.** The economics point towards keeping the index in the DICOM
   service and the cold bytes in tiered blob storage.

---

## Running it

```powershell
cd lab\provision
.\01-provision.ps1 -DnsLabel my-dicom-lab      # ~10 minutes

$env:ORTHANC_PASSWORD = '<a strong password>'
.\Copy-LabToVm.ps1

# 01-provision.ps1 exports LAB_FQDN and AZ_DICOM_URL into this session.
# In a new session, set them again from its output first.
$run = { param($f) .\Invoke-VmScript.ps1 -Script "#!/usr/bin/env bash`ncd /opt/dicom-lab && ./$f" -Env @{
    ORTHANC_PASSWORD = $env:ORTHANC_PASSWORD
    LAB_FQDN         = $env:LAB_FQDN
    AZ_DICOM_URL     = $env:AZ_DICOM_URL
  } }

# then, in order
& $run '20-setup-disk.sh'
& $run '30-install-orthanc.sh'
& $run '35-tls.sh'
& $run '40-fetch-dicom.sh'
& $run '50-cstore.sh'
& $run '60-dimse-query-retrieve.sh'
& $run '70-dicomweb.sh'
& $run '80-azure-dicom.sh'
& $run '90-compare.sh'
```

Then open `https://<your-dns-label>.<region>.cloudapp.azure.com/ui/app/` and
click into the study. The Stone Web Viewer renders the CT in the browser.

When you are done:

```powershell
.\99-teardown.ps1 -Mode Deallocate   # pause, keep the data
.\99-teardown.ps1 -Mode Delete       # remove everything
```

| Script | What it demonstrates |
|---|---|
| `00-env.sh` | Shared settings; sourced by the rest |
| `20-setup-disk.sh` | Format the whole managed disk (no partition table) and mount it |
| `30-install-orthanc.sh` | Docker + Orthanc, storage on the data disk |
| `35-tls.sh` | Caddy and a real Let's Encrypt certificate |
| `40-fetch-dicom.sh` | Download from TCIA; dissect a real file |
| `50-cstore.sh` | C-ECHO and C-STORE, and the `LICENSE` trap |
| `60-dimse-query-retrieve.sh` | C-FIND and C-MOVE to a third node |
| `70-dicomweb.sh` | QIDO-RS, WADO-RS, rendered images |
| `80-azure-dicom.sh` | STOW-RS to Azure, and DIMSE failing against it |
| `90-compare.sh` | The behavioural differences, side by side |

---

## Notes from building it

Things that cost time and are not obvious from the documentation.

**VM sizes.** `Standard_B2ms` fails in West Europe with `SkuNotAvailable` —
B-series is not offered there at all. `D2s_v5` carries a zonal restriction on
many subscriptions. `D2as_v6` was clean across all three zones. Worse, `az vm
create` swallowed the ARM error behind an internal CLI fault
(`RuntimeError: The content for this response was already consumed`); the real
message only appeared under `--debug`.

**NVMe disk naming.** D-series v6 presents disks as NVMe, so the familiar
`/dev/disk/azure/scsi1/lun0` does not exist. Use
`/dev/disk/azure/data/by-lun/0`. And do not assume the numbering is intuitive:
`nvme0n1` was the *data* disk, `nvme0n2` the OS disk. `20-setup-disk.sh` refuses
to run if the symlink resolves to the root device.

**SSH may be blocked.** Outbound 22 is filtered on many corporate networks.
Everything here runs through `az vm run-command`, which travels over the control
plane on 443. `Invoke-VmScript.ps1` wraps it.

**Auto-shutdown is set in UTC** regardless of the VM's region. Fix it with
`az resource update --set properties.timeZoneId="W. Europe Standard Time"`.

**Regional availability documentation was wrong.** Microsoft's page listed the
DICOM service as GA in Canada Central, East US and East US 2 only. It deployed
and ran in West Europe without complaint. Ask ARM, not the docs:
`az provider show -n Microsoft.HealthcareApis --query "resourceTypes[?resourceType=='workspaces'].locations"`.

**Orthanc's viewer plugins are gated by environment variables**, not by
`orthanc.json`. A `"StoneWebViewer": {"Enable": true}` block does nothing on its
own; the image needs `STONE_WEB_VIEWER_PLUGIN_ENABLED=true`.

**Do not pipe verbose DIMSE output into `head`** in a script with `set -o
pipefail`. `SIGPIPE` aborts the transfer half-way and the script reports
success. This truncated the first C-STORE at 14 of 133 instances.

**Credentials over plain HTTP.** Orthanc's own listener on 8042 has no TLS. The
first version of this lab opened 8042 in the NSG to reach the UI, so the admin
password crossed the public internet Base64-encoded in a header. PowerShell's
`Invoke-WebRequest` refuses to send credentials over an unencrypted connection
without an explicit override, which is a good instinct to have inherited. Azure
gives every public IP a resolvable `*.cloudapp.azure.com` name, so a real
certificate is free and automatic — there is no reason to accept the warning.
`01-provision.ps1` as committed never opens 8042: the only inbound ports are
4242 and 443 from your own address, plus 80 for the ACME challenge. Orthanc
listens on 8042 inside the VM and Caddy reaches it over the loopback.
