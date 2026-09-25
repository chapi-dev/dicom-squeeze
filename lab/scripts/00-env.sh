# Shared settings for the lab scripts.
#
# Every value can be overridden from the environment, so the same scripts work
# against a lab you provisioned yourself. Source this file, do not execute it.

# --- Orthanc, the self-hosted PACS -------------------------------------------
export ORTHANC_AET="${ORTHANC_AET:-AZLABPACS}"
export ORTHANC_HTTP="${ORTHANC_HTTP:-http://localhost:8042}"
export ORTHANC_DIMSE_PORT="${ORTHANC_DIMSE_PORT:-4242}"
export ORTHANC_USER="${ORTHANC_USER:-admin}"
# ORTHANC_PASSWORD has no default on purpose: it must come from the environment.

# --- where the managed disk is mounted ----------------------------------------
export DATA_DIR="${DATA_DIR:-/srv/dicom}"

# --- the public study we work with --------------------------------------------
# LIDC-IDRI-0001, a chest CT from The Cancer Imaging Archive, CC-BY 3.0.
export TCIA_BASE="${TCIA_BASE:-https://nbia.cancerimagingarchive.net/nbia-api/services/v4}"
export SERIES_UID="${SERIES_UID:-1.3.6.1.4.1.14519.5.2.1.6279.6001.179049373636438705059720603192}"
export STUDY_UID="${STUDY_UID:-1.3.6.1.4.1.14519.5.2.1.6279.6001.298806137288633453246975630178}"
export PATIENT_ID="${PATIENT_ID:-LIDC-IDRI-0001}"

# --- Azure Health Data Services DICOM service ---------------------------------
export AZ_DICOM_URL="${AZ_DICOM_URL:-https://wsdicomlabwe-dicomsvc.dicom.azurehealthcareapis.com/v1}"

require_password() {
  if [ -z "${ORTHANC_PASSWORD:-}" ]; then
    echo "ORTHANC_PASSWORD is not set. Export it before running this script." >&2
    exit 1
  fi
}

# Token for the DICOM service, taken from the VM's managed identity. No secret
# is stored anywhere: the instance metadata endpoint is only reachable from
# inside the VM, and RBAC on the resource decides what the identity may do.
az_dicom_token() {
  curl -fsS -H Metadata:true \
    "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fdicom.healthcareapis.azure.com" \
    | python3 -c 'import json,sys;print(json.load(sys.stdin)["access_token"])'
}
