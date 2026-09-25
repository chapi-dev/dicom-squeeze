#!/usr/bin/env bash
# Complete the C-STORE and verify. Kept separate from 50-cstore.sh because
# piping verbose DIMSE output into `head` raises SIGPIPE, and with `pipefail`
# that aborts the transfer half-way -- which is exactly what happened on the
# first attempt.
set -uo pipefail
. "$(dirname "$0")/00-env.sh"
require_password

AET_LOCAL="${AET_SCANNER:-CT-SCANNER-01}"
AET_REMOTE="$ORTHANC_AET"
HOST=127.0.0.1
PORT="$ORTHANC_DIMSE_PORT"
SERIES="$DATA_DIR/incoming/series"
AUTH="${ORTHANC_USER}:${ORTHANC_PASSWORD}"

echo "=== instances held before ==="
curl -fsS -u "$AUTH" ${ORTHANC_HTTP}/instances | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))'

echo
echo "=== C-STORE, full series ==="
# --scan-pattern is essential: the TCIA archive ships a LICENSE text file next
# to the .dcm files, and without a filter storescu tries to parse it as DICOM,
# fails, and *aborts the whole association*. The instances already sent stay in
# the PACS, so the transfer silently ends up partial. This is the classic
# "the study is missing slices" incident.
LOG=/tmp/storescu.log
start=$SECONDS
storescu -v --scan-directories --scan-pattern '*.dcm' \
         -aet "$AET_LOCAL" -aec "$AET_REMOTE" "$HOST" "$PORT" "$SERIES" > "$LOG" 2>&1
rc=$?
elapsed=$(( SECONDS - start ))
echo "storescu exit code     : $rc"
echo "associations requested : $(grep -c 'Requesting Association' "$LOG")"
echo "store requests sent    : $(grep -c 'Sending Store Request' "$LOG")"
echo "store responses ok     : $(grep -c 'Received Store Response (Success)' "$LOG")"
echo "elapsed seconds        : ${elapsed}"
[ "$rc" -eq 0 ] || { echo "TRANSFER FAILED"; grep -E '^E:' "$LOG" | head; exit 1; }

echo
echo "=== what the PACS holds now ==="
curl -fsS -u "$AUTH" ${ORTHANC_HTTP}/patients?expand | python3 -c '
import json,sys
for p in json.load(sys.stdin):
    t = p["MainDicomTags"]
    print("patient :", t.get("PatientID"), "| name:", repr(t.get("PatientName","")), "| studies:", len(p["Studies"]))
'
curl -fsS -u "$AUTH" ${ORTHANC_HTTP}/studies?expand | python3 -c '
import json,sys
for s in json.load(sys.stdin):
    t = s["MainDicomTags"]
    print("study   :", t.get("StudyInstanceUID"))
    print("          date:", t.get("StudyDate"), "| desc:", t.get("StudyDescription","(none)"))
'
curl -fsS -u "$AUTH" ${ORTHANC_HTTP}/series?expand | python3 -c '
import json,sys
for s in json.load(sys.stdin):
    t = s["MainDicomTags"]
    print("series  :", t.get("SeriesInstanceUID"))
    print("          modality:", t.get("Modality"), "| instances:", len(s["Instances"]), "| thickness:", t.get("SliceThickness"))
'
echo "instances:" $(curl -fsS -u "$AUTH" ${ORTHANC_HTTP}/instances | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))')

echo
echo "=== proof the pixels live on the managed disk ==="
df -h / "$DATA_DIR"
echo
du -sh "$DATA_DIR"/orthanc-db "$DATA_DIR"/orthanc-index "$DATA_DIR"/incoming
echo
echo "how Orthanc lays a stored instance out (content-addressed, 2-level fan-out):"
find "$DATA_DIR/orthanc-db" -type f | head -2
echo
echo "total stored instances on disk: $(find "$DATA_DIR/orthanc-db" -type f | wc -l)"
