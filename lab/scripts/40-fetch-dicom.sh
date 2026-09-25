#!/usr/bin/env bash
# Pull a genuine, publicly redistributable DICOM study and send it into the PACS
# the same way a CT scanner would: over DIMSE C-STORE.
#
# Data: LIDC-IDRI-0001, a chest CT from The Cancer Imaging Archive. Licence
# CC-BY 3.0, de-identified by TCIA, no authentication needed. This is real
# clinical acquisition data, not a phantom or a synthesised file.
set -euo pipefail
. "$(dirname "$0")/00-env.sh"

TCIA="$TCIA_BASE"
DATA="$DATA_DIR"
IN="$DATA/incoming"

mountpoint -q "$DATA" || { echo "REFUSING: $DATA is not a mount point" >&2; exit 1; }

echo "=== installing dcmtk (the reference DIMSE toolkit) ==="
if ! command -v storescu >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  for _ in $(seq 1 60); do
    fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || break
    sleep 10
  done
  apt-get update -qq
  apt-get install -y -qq dcmtk unzip >/dev/null
fi
echo "dcmtk: $(storescu --version | head -1)"

echo
echo "=== disk before ==="
df -h "$DATA" | tail -1

echo
echo "=== downloading series from TCIA ==="
mkdir -p "$IN"
if [ ! -f "$IN/series.zip" ]; then
  curl -fsSL --retry 3 -o "$IN/series.zip" \
    "${TCIA}/getImage?SeriesInstanceUID=${SERIES_UID}&NewFileNames=Yes"
fi
ls -lh "$IN/series.zip"

rm -rf "$IN/series"
mkdir -p "$IN/series"
unzip -q -o "$IN/series.zip" -d "$IN/series"
echo "files extracted: $(find "$IN/series" -type f | wc -l)"
find "$IN/series" -type f -printf '%f\n' | sort | sed -n '1,3p'
echo "note: the archive also ships a LICENSE file next to the .dcm files."
echo "      That matters later -- see 50-cstore.sh."

echo
echo "=== what is actually inside one of these files ==="
FIRST=$(find "$IN/series" -type f -name '*.dcm' | sort | sed -n '1p')
echo "file: $FIRST"
echo "--- the 128-byte preamble then the DICM magic ---"
xxd -s 128 -l 16 "$FIRST"
echo "--- selected tags ---"
dcmdump +P PatientName +P PatientID +P StudyDate +P Modality +P Manufacturer \
        +P StudyDescription +P SeriesDescription +P SliceThickness \
        +P Rows +P Columns +P BitsAllocated +P PhotometricInterpretation \
        +P TransferSyntaxUID +P SOPClassUID "$FIRST"
echo "--- pixel data size ---"
dcmdump "$FIRST" 2>/dev/null | grep -i 'PixelData' || true
