#!/usr/bin/env bash
# Side-by-side probing of the two DICOMweb implementations. Same standard,
# same study, same queries -- the differences below are the ones that break
# client code when you migrate.
set -uo pipefail
. "$(dirname "$0")/00-env.sh"
require_password

AZ="$AZ_DICOM_URL"
OR="${ORTHANC_HTTP}/dicom-web"
AUTH="${ORTHANC_USER}:${ORTHANC_PASSWORD}"
STUDY="$STUDY_UID"
SER="$SERIES_UID"

TOKEN=$(az_dicom_token)
AZH=(-H "Authorization: Bearer $TOKEN" -H 'Accept: application/dicom+json')
ORH=(-u "$AUTH" -H 'Accept: application/dicom+json')

count() { python3 -c 'import json,sys
try: print(len(json.load(sys.stdin)))
except Exception: print("n/a")'; }

echo "=== A. default page size on QIDO-RS ==="
echo -n "  orthanc /instances            : "; curl -fsS "${ORH[@]}" "$OR/studies/$STUDY/series/$SER/instances" | count
echo -n "  azure   /instances            : "; curl -fsS "${AZH[@]}" "$AZ/studies/$STUDY/series/$SER/instances" | count
echo -n "  azure   /instances?limit=200  : "; curl -fsS "${AZH[@]}" "$AZ/studies/$STUDY/series/$SER/instances?limit=200" | count
echo -n "  azure   /instances?limit=201  : "; curl -s -o /dev/null -w 'HTTP %{http_code}\n' "${AZH[@]}" "$AZ/studies/$STUDY/series/$SER/instances?limit=201"
echo "  -> Azure paginates at 100 by default and documents 200 as the ceiling."
echo "     Orthanc returns the whole set. A client that assumes 'one call = all"
echo "     instances' silently loses 33 slices after a migration, and loses them"
echo "     without an error, which is the worst kind of bug in imaging."

echo
echo "=== B. which fields come back without asking ==="
echo "  orthanc study-level keys:"
curl -fsS "${ORH[@]}" "$OR/studies" | python3 -c 'import json,sys;print("   ", sorted(json.load(sys.stdin)[0].keys()))'
echo "  azure study-level keys:"
curl -fsS "${AZH[@]}" "$AZ/studies" | python3 -c 'import json,sys;print("   ", sorted(json.load(sys.stdin)[0].keys()))'
echo "  azure with includefield=ModalitiesInStudy:"
curl -fsS "${AZH[@]}" "$AZ/studies?includefield=00080061" | python3 -c '
import json,sys
d=json.load(sys.stdin)[0]
print("    00080061 ->", d.get("00080061",{}).get("Value"))'

echo
echo "=== C. empty result ==="
echo -n "  orthanc ?PatientID=NOBODY : HTTP "; curl -s -o /tmp/o.json -w '%{http_code}' "${ORH[@]}" "$OR/studies?PatientID=NOBODY"; echo "  body: $(head -c 40 /tmp/o.json)"
echo -n "  azure   ?PatientID=NOBODY : HTTP "; curl -s -o /tmp/a.json -w '%{http_code}' "${AZH[@]}" "$AZ/studies?PatientID=NOBODY"; echo "  body: $(head -c 40 /tmp/a.json)"
echo "  -> 204 has no body. Clients that call .json() unconditionally throw."

echo
echo "=== D. is PixelData present in WADO-RS metadata? ==="
curl -fsS "${ORH[@]}" "$OR/studies/$STUDY/series/$SER/metadata" -o /tmp/om.json
curl -fsS "${AZH[@]}" "$AZ/studies/$STUDY/series/$SER/metadata" -o /tmp/am.json
python3 - <<'PY'
import json
for name, path in (("orthanc", "/tmp/om.json"), ("azure", "/tmp/am.json")):
    d = json.load(open(path))[0]
    pd = d.get("7FE00010")
    print(f"  {name:8} instances={len(json.load(open(path)))} 7FE00010 present={pd is not None}", end="")
    if pd:
        print(f"  keys={list(pd.keys())}  (a reference, not the pixels)")
    else:
        print()
PY
echo "  size of the metadata document:"
ls -lh /tmp/om.json /tmp/am.json | awk '{print "   ", $9, $5}'

echo
echo "=== E. transfer syntax on retrieve ==="
echo "  what Azure will transcode to (Accept transfer-syntax):"
for ts in "1.2.840.10008.1.2.1" "1.2.840.10008.1.2.4.50" "1.2.840.10008.1.2.4.70" "1.2.840.10008.1.2.4.80" "1.2.840.10008.1.2.4.201"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" \
    -H "Accept: multipart/related; type=\"application/dicom\"; transfer-syntax=$ts" \
    "$AZ/studies/$STUDY/series/$SER/instances/$(curl -fsS "${AZH[@]}" "$AZ/studies/$STUDY/series/$SER/instances" | python3 -c 'import json,sys;print(json.load(sys.stdin)[0]["00080018"]["Value"][0])')")
  case "$ts" in
    1.2.840.10008.1.2.1)     n="Explicit VR Little Endian (uncompressed)";;
    1.2.840.10008.1.2.4.50)  n="JPEG Baseline (lossy)";;
    1.2.840.10008.1.2.4.70)  n="JPEG Lossless SV1";;
    1.2.840.10008.1.2.4.80)  n="JPEG-LS Lossless";;
    1.2.840.10008.1.2.4.201) n="HTJ2K Lossless RPCL";;
  esac
  printf "    %-42s %-24s HTTP %s\n" "$n" "$ts" "$code"
done
echo "  -> 406 means the service will not produce that syntax. JPEG-LS and HTJ2K"
echo "     are the two that matter for lossless archival compression, and they"
echo "     are exactly the ones missing."
