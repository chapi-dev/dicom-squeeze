#!/usr/bin/env bash
# Put real TLS in front of Orthanc.
#
# Until now the admin password crossed the public internet in a Base64 header
# over plain HTTP -- PowerShell's Invoke-WebRequest actually refuses to send
# credentials that way without an explicit override, which is a good instinct.
# Azure hands every public IP a *.cloudapp.azure.com name, which is a real
# resolvable name, so Caddy can obtain a genuine Let's Encrypt certificate for
# it automatically. No self-signed warnings, nothing to click through.
set -uo pipefail
. "$(dirname "$0")/00-env.sh" 2>/dev/null || true
require_password

FQDN="${LAB_FQDN:?LAB_FQDN must be set, e.g. az-lab-pacs.westeurope.cloudapp.azure.com}"

echo "=== dns ==="
getent hosts "$FQDN"

mkdir -p /etc/caddy ${DATA_DIR}/caddy-data
cat > /etc/caddy/Caddyfile <<CADDY
${FQDN} {
    # Orthanc does its own HTTP Basic auth; pass the header straight through.
    reverse_proxy localhost:8042 {
        # DICOMweb responses can be large multipart bodies; do not buffer them.
        flush_interval -1
    }
}
CADDY

docker rm -f caddy >/dev/null 2>&1 || true
docker run -d --name caddy --restart unless-stopped --network host \
  -v /etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
  -v ${DATA_DIR}/caddy-data:/data \
  caddy:2 >/dev/null

echo "waiting for the certificate..."
for i in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "https://${FQDN}/system" 2>/dev/null || echo 000)
  if [ "$code" = "401" ]; then echo "TLS up after $((i*2))s (401 = cert valid, auth required)"; break; fi
  sleep 2
done

echo
echo "=== certificate ==="
echo | timeout 15 openssl s_client -connect "${FQDN}:443" -servername "$FQDN" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates || echo "  (openssl not available)"

echo
echo "=== checks ==="
# Every curl below carries --max-time. Without it, a handshake that stalls while
# Caddy is still negotiating with Let's Encrypt hangs the whole script, which is
# awkward when the only channel to the box is `az vm run-command`.
echo -n "  https, no credentials      : HTTP "; curl -s --max-time 15 -o /dev/null -w '%{http_code}\n' "https://${FQDN}/system"
echo -n "  https, with credentials    : HTTP "; curl -s --max-time 15 -o /dev/null -w '%{http_code}\n' -u "${ORTHANC_USER}:${ORTHANC_PASSWORD}" "https://${FQDN}/system"
echo -n "  http redirects to https    : "; curl -s --max-time 15 -o /dev/null -w '%{http_code} -> %{redirect_url}\n' "http://${FQDN}/system"
echo -n "  dicomweb over tls          : HTTP "; curl -s --max-time 30 -o /dev/null -w '%{http_code}\n' -u "${ORTHANC_USER}:${ORTHANC_PASSWORD}" "https://${FQDN}/dicom-web/studies"
echo -n "  stone web viewer           : HTTP "; curl -s --max-time 15 -o /dev/null -w '%{http_code}\n' -u "${ORTHANC_USER}:${ORTHANC_PASSWORD}" "https://${FQDN}/stone-webviewer/index.html"
echo
docker ps --format '  {{.Names}}\t{{.Status}}'
