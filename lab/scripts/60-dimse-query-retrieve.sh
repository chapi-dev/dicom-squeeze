#!/usr/bin/env bash
# The other half of DIMSE: query and retrieve.
#
# C-FIND answers "what do you have?" and C-MOVE says "send it to this AE".
# The detail that catches everyone out is that C-MOVE does not return the
# images to the caller. It tells the PACS to open a *separate, new* association
# back to a third node, identified only by AE Title. The PACS must therefore
# already know that AE Title's host and port from its own configuration. That
# is why adding a new workstation to a hospital PACS is a change request rather
# than a client-side setting, and it is the single biggest reason DICOM does
# not survive NAT or a cloud perimeter.
set -uo pipefail
. "$(dirname "$0")/00-env.sh"
require_password

AET_LOCAL="${AET_WORKSTATION:-WORKSTATION}"
AET_REMOTE="$ORTHANC_AET"
HOST=127.0.0.1
PORT="$ORTHANC_DIMSE_PORT"
AUTH="${ORTHANC_USER}:${ORTHANC_PASSWORD}"
INCOMING="$DATA_DIR/retrieved"

echo "=== 1. C-FIND at STUDY level: what does this PACS hold? ==="
# findscu only prints the response datasets at debug level, so instead ask it to
# write each response out (-X) and dump them. Each response is itself a DICOM
# object -- the query language of DIMSE is DICOM, not SQL and not JSON.
RSP=/tmp/find-study
rm -rf "$RSP"; mkdir -p "$RSP"; cd "$RSP" || exit 1
findscu -S -X -k "QueryRetrieveLevel=STUDY" \
        -k "PatientID=" -k "PatientName=" -k "StudyDate=" \
        -k "StudyInstanceUID=" -k "ModalitiesInStudy=" -k "NumberOfStudyRelatedInstances=" \
        -aet "$AET_LOCAL" -aec "$AET_REMOTE" "$HOST" "$PORT" 2>&1 | grep -E 'Association|Success' 
echo "responses returned: $(ls "$RSP"/rsp*.dcm 2>/dev/null | wc -l)"
for f in "$RSP"/rsp*.dcm; do [ -e "$f" ] || continue; echo "--- $(basename "$f") ---"; dcmdump "$f" | grep -vE 'Group Length|SpecificCharacterSet'; done

echo
echo "=== 2. C-FIND filtered, the way a worklist query narrows down ==="
echo "--- ask for PatientID=$PATIENT_ID at SERIES level ---"
RSP2=/tmp/find-series
rm -rf "$RSP2"; mkdir -p "$RSP2"; cd "$RSP2" || exit 1
findscu -S -X -k "QueryRetrieveLevel=SERIES" -k "PatientID=$PATIENT_ID" \
        -k "StudyInstanceUID=" -k "SeriesInstanceUID=" -k "Modality=" \
        -k "SeriesDescription=" -k "NumberOfSeriesRelatedInstances=" \
        -aet "$AET_LOCAL" -aec "$AET_REMOTE" "$HOST" "$PORT" >/dev/null 2>&1
echo "responses: $(ls "$RSP2"/rsp*.dcm 2>/dev/null | wc -l)"
for f in "$RSP2"/rsp*.dcm; do [ -e "$f" ] || continue; dcmdump "$f" | grep -vE 'Group Length|SpecificCharacterSet'; done

echo "--- ask for a patient that does not exist ---"
RSP3=/tmp/find-none
rm -rf "$RSP3"; mkdir -p "$RSP3"; cd "$RSP3" || exit 1
findscu -S -X -k "QueryRetrieveLevel=STUDY" -k "PatientID=NO-SUCH-PATIENT" -k "StudyInstanceUID=" \
        -aet "$AET_LOCAL" -aec "$AET_REMOTE" "$HOST" "$PORT" >/dev/null 2>&1
echo "responses: $(ls "$RSP3"/rsp*.dcm 2>/dev/null | wc -l) (association still succeeds, it just matches nothing)"
cd /

echo
echo "=== 3. set up a receiving node so C-MOVE has somewhere to send to ==="
mkdir -p "$INCOMING"
rm -rf "${INCOMING:?}"/* 2>/dev/null || true
pkill -f 'storescp' 2>/dev/null || true
sleep 1
storescp --fork -aet "$AET_LOCAL" -od "$INCOMING" --sort-on-study-uid ws 11112 &
SCP_PID=$!
sleep 2
ss -lntp 2>/dev/null | grep -q ':11112' && echo "storescp listening on 11112 as AE '$AET_LOCAL' (pid $SCP_PID)" \
  || { echo "storescp failed to bind 11112"; exit 1; }

# Orthanc runs in a container, so its 127.0.0.1 is the *container's* loopback,
# not the host's. C-MOVE opens the return association from inside the container
# and would get "Connection refused". The destination must therefore be the
# host as the container sees it: the docker bridge gateway.
#
# This is the container-era version of the classic DICOM firewall problem, and
# it is the same reason C-MOVE cannot cross NAT: the PACS dials *out* to an
# address it was told about, and that address has to be routable from where the
# PACS actually runs.
GW=$(docker network inspect bridge -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
echo "docker bridge gateway (the host, seen from the container): $GW"

curl -fsS -u "$AUTH" -X PUT ${ORTHANC_HTTP}/modalities/workstation \
     -H 'Content-Type: application/json' \
     -d "{\"AET\":\"${AET_LOCAL}\",\"Host\":\"${GW}\",\"Port\":11112}" >/dev/null
echo "registered in the PACS:"
curl -fsS -u "$AUTH" ${ORTHANC_HTTP}/modalities/workstation/configuration

echo
echo "--- the PACS verifies the destination with its own C-ECHO first ---"
curl -fsS -u "$AUTH" -X POST ${ORTHANC_HTTP}/modalities/workstation/echo -d '{}' \
  && echo "C-ECHO from PACS to WORKSTATION: OK" || echo "C-ECHO failed"

echo
echo "=== 4. C-MOVE: tell the PACS to push the series to WORKSTATION ==="

movescu -v -S -k "QueryRetrieveLevel=SERIES" -k "SeriesInstanceUID=${SERIES_UID}" \
        -aet "$AET_LOCAL" -aec "$AET_REMOTE" -aem "$AET_LOCAL" \
        "$HOST" "$PORT" 2>&1 | grep -E 'Move Response|Association|Status|Completed|Failed' | head -20

sleep 3
echo
echo "=== 5. did the files actually arrive at the third node? ==="
echo "files received by storescp: $(find "$INCOMING" -type f | wc -l)"
find "$INCOMING" -type d | head -5
FIRST=$(find "$INCOMING" -type f | head -1)
if [ -n "$FIRST" ]; then
  echo "confirming one of them is really DICOM:"
  dcmdump +P PatientID +P Modality +P SOPInstanceUID "$FIRST"
fi
pkill -f 'storescp' 2>/dev/null || true
echo
echo "disk usage after retrieve:"
du -sh "$DATA_DIR"/*
