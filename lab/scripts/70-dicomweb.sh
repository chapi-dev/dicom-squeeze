#!/usr/bin/env bash
# The same archive, reached the modern way.
#
# DICOMweb is the 2011+ REST binding of the same data model. Three services:
#   QIDO-RS  search   (Query based on ID for DICOM Objects)
#   WADO-RS  retrieve (Web Access to DICOM Objects)
#   STOW-RS  store
#
# Note what disappears: no AE Titles, no association negotiation, no inbound
# port on the client, no firewall change to add a reader. Note also what stays:
# the payload is still DICOM, and multipart/related is still the wire format for
# pixel data.
set -uo pipefail
. "$(dirname "$0")/00-env.sh"
require_password

BASE="${ORTHANC_HTTP}/dicom-web"
AUTH="${ORTHANC_USER}:${ORTHANC_PASSWORD}"
STUDY="$STUDY_UID"
SERIES="$SERIES_UID"

echo "=== 1. QIDO-RS: search for studies ==="
echo "GET /dicom-web/studies"
curl -fsS -u "$AUTH" "$BASE/studies" | python3 -c '
import json,sys
# DICOMweb JSON keys are the raw 8-digit tags; values carry a VR and a list.
NAMES={"00100020":"PatientID","00100010":"PatientName","00080020":"StudyDate",
       "0020000D":"StudyInstanceUID","00080061":"ModalitiesInStudy",
       "00201208":"NumberOfStudyRelatedInstances"}
for s in json.load(sys.stdin):
    for tag,label in NAMES.items():
        e=s.get(tag)
        if e is None: continue
        v=e.get("Value",["(empty)"])
        print(f"  {tag} {label:32} {v}")
    print()
'

echo "=== 2. QIDO-RS with a filter, and note the tag-based query syntax ==="
echo "GET /dicom-web/studies?PatientID=$PATIENT_ID&includefield=00081030"
curl -fsS -u "$AUTH" "$BASE/studies?PatientID=$PATIENT_ID" | python3 -c 'import json,sys;print("  matches:",len(json.load(sys.stdin)))'
echo "GET /dicom-web/studies?PatientID=NOBODY"
code=$(curl -s -o /dev/null -w '%{http_code}' -u "$AUTH" "$BASE/studies?PatientID=NOBODY")
echo "  HTTP $code   <- Orthanc answers 200 with an empty array here; the standard"
echo "                 says 204 No Content, which is what Azure returns. Worth"
echo "                 knowing before a client assumes one or the other."

echo
echo "=== 3. QIDO-RS drill down: series, then instances ==="
curl -fsS -u "$AUTH" "$BASE/studies/$STUDY/series" | python3 -c '
import json,sys
for s in json.load(sys.stdin):
    print("  series:", s["0020000E"]["Value"][0])
    print("  modality:", s["00080060"]["Value"][0], "| instances:", s.get("00201209",{}).get("Value",["?"])[0])
'
echo "  instance count via QIDO: $(curl -fsS -u "$AUTH" "$BASE/studies/$STUDY/series/$SERIES/instances" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))')"

echo
echo "=== 4. WADO-RS: retrieve metadata without the pixels ==="
echo "GET /dicom-web/studies/{study}/series/{series}/metadata"
META=$(curl -fsS -u "$AUTH" "$BASE/studies/$STUDY/series/$SERIES/metadata")
echo "  metadata bytes for all 133 instances: $(printf '%s' "$META" | wc -c)"
printf '%s' "$META" | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("  instances described:",len(d))
i=d[0]
print("  first instance rows x cols:", i["00280010"]["Value"][0], "x", i["00280011"]["Value"][0])
print("  bits allocated:", i["00280100"]["Value"][0])
pd = i.get("7FE00010")
if pd is None:
    print("  PixelData absent from metadata entirely")
else:
    # Orthanc lists the tag but replaces the bytes with a BulkDataURI, so the
    # metadata document stays small while still telling you where the pixels
    # are. Azure omits the tag altogether. Same intent, different shape.
    print("  PixelData present as:", list(pd.keys()), "-> a pointer, not 66 MiB of pixels")
'

echo
echo "=== 5. WADO-RS: retrieve the actual instance ==="
FIRST_SOP=$(curl -fsS -u "$AUTH" "$BASE/studies/$STUDY/series/$SERIES/instances" \
  | python3 -c 'import json,sys;print(json.load(sys.stdin)[0]["00080018"]["Value"][0])')
echo "  SOPInstanceUID: $FIRST_SOP"
echo "--- as DICOM (multipart/related) ---"
curl -fsS -u "$AUTH" -o /tmp/wado.multipart -D /tmp/wado.headers \
     "$BASE/studies/$STUDY/series/$SERIES/instances/$FIRST_SOP"
grep -i '^content-type' /tmp/wado.headers
echo "  bytes: $(stat -c%s /tmp/wado.multipart)"
echo "--- rendered as an image, which DIMSE simply cannot do ---"
curl -fsS -u "$AUTH" -o /tmp/wado.jpg \
     "$BASE/studies/$STUDY/series/$SERIES/instances/$FIRST_SOP/rendered"
file /tmp/wado.jpg
echo "  bytes: $(stat -c%s /tmp/wado.jpg)"

echo
echo "=== 6. size comparison: this is the whole point of the compression tool ==="
RAW=$(du -sb "$DATA_DIR/incoming/series" | cut -f1)
echo "  133 uncompressed CT slices on disk : $(numfmt --to=iec $RAW)"
python3 - <<'PY'
rows, cols, bits, n = 512, 512, 16, 133
raw = rows*cols*(bits//8)*n
print(f"  pure pixel payload                 : {raw/1024/1024:.1f} MiB  ({rows}x{cols}x{bits//8} x {n})")
# Only `raw` above is measured. These ratios are unsourced placeholders -- no
# codec is run here and no published study backs these exact values -- so the
# sizes below are arithmetic, not results. See lab/README.md, "The data".
for name, ratio in [("JPEG-LS lossless", 2.6), ("JPEG 2000 lossless", 2.8), ("HTJ2K lossless", 2.9)]:
    print(f"  {name:35}: {raw/ratio/1024/1024:.1f} MiB  (assumed {ratio}:1, placeholder)")
PY
