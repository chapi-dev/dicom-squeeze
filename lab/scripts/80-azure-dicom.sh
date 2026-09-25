#!/usr/bin/env bash
# Push the identical study to the managed Azure DICOM service and try to reach
# it the way a Philips PACS would.
#
# The VM authenticates with its own system-assigned managed identity, so there
# is no key, no connection string and nothing to rotate: it asks the instance
# metadata endpoint for a token scoped to the DICOM audience, and RBAC on the
# resource decides what it may do.
set -uo pipefail
. "$(dirname "$0")/00-env.sh"

SVC="$AZ_DICOM_URL"
SERIES="$DATA_DIR/incoming/series"

echo "=== 1. token from the instance metadata service, no secret involved ==="
TOKEN=$(az_dicom_token)
echo "token acquired, length ${#TOKEN}"
python3 - <<PY
import base64, json
tok = """$TOKEN"""
payload = tok.split(".")[1]
payload += "=" * (-len(payload) % 4)
c = json.loads(base64.urlsafe_b64decode(payload))
print("  audience :", c.get("aud"))
print("  tenant   :", c.get("tid"))
print("  identity :", c.get("oid"), "(the VM, not a user)")
PY

echo
echo "=== 2. STOW-RS: store the study over HTTPS ==="
export TOKEN SVC SERIES
python3 - <<'PY'
import os, glob, uuid, time, urllib.request, json

svc, token = os.environ["SVC"], os.environ["TOKEN"]
files = sorted(glob.glob(os.path.join(os.environ["SERIES"], "*.dcm")))
print(f"  instances to upload: {len(files)}")

def stow(batch):
    boundary = uuid.uuid4().hex
    body = bytearray()
    for path in batch:
        with open(path, "rb") as fh:
            data = fh.read()
        body += f"--{boundary}\r\nContent-Type: application/dicom\r\n".encode()
        body += f"Content-Length: {len(data)}\r\n\r\n".encode()
        body += data + b"\r\n"
    body += f"--{boundary}--".encode()
    req = urllib.request.Request(f"{svc}/studies", data=bytes(body), method="POST")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", f'multipart/related; type="application/dicom"; boundary={boundary}')
    req.add_header("Accept", "application/dicom+json")
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        # STOW-RS is not idempotent the way a PUT is. Re-sending an instance
        # that is already stored is a *conflict*, not a no-op:
        #   200 everything stored
        #   202 some stored, some refused -- read 00081198 to find out which
        #   409 nothing stored, typically because it is all already there
        # A pipeline that retries a timed-out batch will see 409 and must not
        # treat it as data loss.
        return e.code, json.loads(e.read() or b"{}")

# Batched because STOW-RS caps a single request at 4 GB and because a 133-part
# body is an awkward unit of retry.
start = time.time()
sent = dupe = 0
for i in range(0, len(files), 20):
    batch = files[i:i + 20]
    status, doc = stow(batch)
    ok = len(doc.get("00081199", {}).get("Value", []))
    failed = doc.get("00081198", {}).get("Value", [])
    # 0272 is "the object already exists"; anything else is a genuine refusal.
    already = sum(1 for f in failed
                  if f.get("00081197", {}).get("Value", [None])[0] in (0x0272, 45070))
    sent += ok
    dupe += already
    note = "" if status == 200 else f"  <- {len(failed)} refused, {already} already present"
    print(f"  batch {i//20 + 1:>2}: HTTP {status}  stored={ok}{note}")
print(f"  newly stored: {sent}, already present: {dupe}, in {time.time()-start:.1f}s")
if sent == 0 and dupe:
    print("  (the study was already in the service; STOW-RS answers 409, not 200)")
PY

echo
echo "=== 3. QIDO-RS against Azure: same query language, different host ==="
curl -fsS -H "Authorization: Bearer $TOKEN" -H 'Accept: application/dicom+json' \
     "$SVC/studies" | python3 -c '
import json,sys
for s in json.load(sys.stdin):
    print("  patient:", s.get("00100020",{}).get("Value",["?"])[0])
    print("  study  :", s.get("0020000D",{}).get("Value",["?"])[0])
    print("  modality:", s.get("00080061",{}).get("Value",["?"]))
'

echo
echo "=== 4. WADO-RS against Azure: pull one instance back ==="
STUDY="$STUDY_UID"
SER="$SERIES_UID"
echo "  instances in the series: $(curl -fsS -H "Authorization: Bearer $TOKEN" -H 'Accept: application/dicom+json' "$SVC/studies/$STUDY/series/$SER/instances?limit=200" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))')"
curl -fsS -H "Authorization: Bearer $TOKEN" \
     -H 'Accept: multipart/related; type="application/dicom"; transfer-syntax=*' \
     -o /tmp/azure-wado.bin -D /tmp/azure-wado.hdr \
     "$SVC/studies/$STUDY/series/$SER"
grep -i '^content-type' /tmp/azure-wado.hdr
echo "  whole series pulled over HTTPS: $(numfmt --to=iec $(stat -c%s /tmp/azure-wado.bin))"

echo
echo "=== 5. the point of the whole lab: DIMSE against Azure ==="
HOSTNAME_ONLY=$(printf '%s' "$SVC" | sed -E 's#^https?://##; s#/.*$##')
echo "  resolving $HOSTNAME_ONLY"
getent hosts "$HOSTNAME_ONLY" || echo "  (CNAME chain)"
for p in 104 11112 4242; do
  timeout 8 bash -c "echo > /dev/tcp/$HOSTNAME_ONLY/$p" 2>/dev/null \
    && echo "  port $p : OPEN" || echo "  port $p : closed/filtered"
done
echo "  C-ECHO attempt on the standard DICOM port:"
timeout 15 echoscu -aet CT-SCANNER-01 -aec AZUREDICOM "$HOSTNAME_ONLY" 104 2>&1 | tail -3 || true
echo
echo "  There is no DIMSE listener. The Azure DICOM service is DICOMweb only."
echo "  Anything that speaks C-STORE needs a gateway in front of it."

echo
echo "=== 6. what the service charges for is storage, and it is not tiered ==="
curl -fsS -H "Authorization: Bearer $TOKEN" -H 'Accept: application/dicom+json' \
     "$SVC/studies/$STUDY/series/$SER/metadata" -o /tmp/azmeta.json
echo "  series metadata over the wire: $(numfmt --to=iec $(stat -c%s /tmp/azmeta.json))"
echo
echo "  Blob storage under the DICOM service is charged at a single rate."
echo "  There is no Cool or Archive tier to demote a five-year-old study to,"
echo "  which is the whole reason the size of what you store matters so much."
