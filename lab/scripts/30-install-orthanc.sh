#!/usr/bin/env bash
# Install Orthanc as the PACS stand-in.
#
# Orthanc is the closest open-source equivalent to what a vendor PACS such as
# Philips IntelliSpace/Vue does at the protocol level: it speaks DIMSE (the 1990s
# TCP protocol every modality and legacy PACS still uses) *and* DICOMweb (the
# REST API the cloud services speak). Having both in one box is what makes the
# gap between them visible.
#
# Docker rather than apt: Ubuntu 24.04 ships Orthanc 1.12.2 with plugins as
# separate packages, while the official orthancteam image bundles DICOMweb, the
# Stone viewer and Explorer 2 already built and version-matched.
#
# Idempotent: safe to run again.
set -euo pipefail

ORTHANC_PASSWORD="${ORTHANC_PASSWORD:?ORTHANC_PASSWORD must be set}"
DATA="${DATA_DIR:-/srv/dicom}"
IMAGE="orthancteam/orthanc:25.10.1"

mountpoint -q "$DATA" || { echo "REFUSING: $DATA is not a mount point, the managed disk is not mounted" >&2; exit 1; }

echo "=== installing docker ==="
if ! command -v docker >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  # Fresh Ubuntu images run unattended-upgrades on first boot, which holds the
  # dpkg lock for several minutes. Wait it out instead of failing.
  for i in $(seq 1 60); do
    fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || break
    echo "waiting for dpkg lock (${i}/60)..."
    sleep 10
  done
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl gnupg >/dev/null
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null
  systemctl enable --now docker
else
  echo "docker already present"
fi
docker --version

echo
echo "=== orthanc configuration ==="
mkdir -p /etc/orthanc "$DATA/orthanc-db" "$DATA/orthanc-index"

# Written with a heredoc rather than env vars so the whole configuration is
# visible in one place and can be read as documentation.
cat > /etc/orthanc/orthanc.json <<JSON
{
  "Name": "AZ-LAB-PACS",

  // Where the pixel data actually lands. Both paths are on the mounted managed
  // disk, so the archive survives the VM and can be snapshotted or resized
  // independently of it.
  "StorageDirectory": "/var/lib/orthanc/db",
  "IndexDirectory": "/var/lib/orthanc/index",

  "HttpPort": 8042,
  "RemoteAccessAllowed": true,
  "AuthenticationEnabled": true,
  "RegisteredUsers": { "admin": "${ORTHANC_PASSWORD}" },

  // DIMSE. "AET" is the Application Entity Title: the name one DICOM node
  // answers to on the network. A modality or a Philips PACS is configured with
  // the tuple (AET, host, port) and will refuse to talk to a peer whose AET
  // does not match what it expects.
  "DicomAet": "AZLABPACS",
  "DicomPort": 4242,
  "DicomServerEnabled": true,

  // Open for the lab so C-ECHO/C-STORE can be demonstrated from any caller.
  // A real deployment whitelists peers in DicomModalities and sets these false.
  "DicomAlwaysAllowEcho": true,
  "DicomAlwaysAllowStore": true,
  "DicomAlwaysAllowFind": true,
  "DicomAlwaysAllowMove": true,

  // Remote DIMSE peers, keyed by a local alias. This is the entry a Philips
  // PACS would occupy in a real integration.
  "DicomModalities": {
    "self": [ "AZLABPACS", "127.0.0.1", 4242 ]
  },

  "DicomWeb": {
    "Enable": true,
    "Root": "/dicom-web/",
    "EnableWado": true,
    "WadoRoot": "/wado"
  },

  "StoneWebViewer": { "Enable": true },
  "OrthancExplorer2": { "Enable": true, "IsDefaultOrthancUI": true }
}
JSON
chmod 600 /etc/orthanc/orthanc.json

echo
echo "=== starting orthanc ==="
docker rm -f orthanc >/dev/null 2>&1 || true
docker pull -q "$IMAGE"
# The viewer plugins are gated by the image's entrypoint via env vars, not by
# orthanc.json, so the "StoneWebViewer" block alone does not load them.
docker run -d --name orthanc --restart unless-stopped \
  -p 8042:8042 -p 4242:4242 \
  -e DICOM_WEB_PLUGIN_ENABLED=true \
  -e STONE_WEB_VIEWER_PLUGIN_ENABLED=true \
  -e ORTHANC_EXPLORER_2_ENABLED=true \
  -v /etc/orthanc/orthanc.json:/etc/orthanc/orthanc.json:ro \
  -v "$DATA/orthanc-db":/var/lib/orthanc/db \
  -v "$DATA/orthanc-index":/var/lib/orthanc/index \
  "$IMAGE" >/dev/null

echo "waiting for orthanc to answer..."
for i in $(seq 1 30); do
  if curl -fsS -u "${ORTHANC_USER:-admin}:${ORTHANC_PASSWORD}" ${ORTHANC_HTTP:-http://localhost:8042}/system >/dev/null 2>&1; then
    echo "up after ${i}s"
    break
  fi
  sleep 1
done

echo
echo "=== system ==="
curl -fsS -u "${ORTHANC_USER:-admin}:${ORTHANC_PASSWORD}" ${ORTHANC_HTTP:-http://localhost:8042}/system
echo
echo "=== plugins ==="
curl -fsS -u "${ORTHANC_USER:-admin}:${ORTHANC_PASSWORD}" ${ORTHANC_HTTP:-http://localhost:8042}/plugins
echo
echo "=== anonymous access must be refused ==="
code=$(curl -s -o /dev/null -w '%{http_code}' ${ORTHANC_HTTP:-http://localhost:8042}/system)
echo "unauthenticated GET /system -> $code"
[ "$code" = "401" ] || { echo "SECURITY: expected 401, got $code" >&2; exit 1; }
