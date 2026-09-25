#!/usr/bin/env bash
# Put the managed data disk under the DICOM store and mount it persistently.
#
# The point of the exercise is that pixel data lands on a managed disk that can
# be snapshotted, resized and priced independently of the VM, rather than on the
# OS disk where it would be lost with the machine.
#
# Idempotent: safe to run again.
set -euo pipefail

DISK=/dev/disk/azure/data/by-lun/0
MOUNT="${DATA_DIR:-/srv/dicom}"
LABEL=dicomdata

echo "=== target disk ==="
real=$(readlink -f "$DISK")
echo "$DISK -> $real"

# Refuse to touch the disk if it is the one carrying root. Cheap insurance
# against a symlink pointing somewhere unexpected.
root_disk=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)")
if [ "$(basename "$real")" = "$root_disk" ]; then
  echo "REFUSING: $DISK resolves to the OS disk /dev/$root_disk" >&2
  exit 1
fi

if blkid "$real" >/dev/null 2>&1; then
  echo "already formatted, leaving it alone:"
  blkid "$real"
else
  echo "=== formatting ==="
  # No partition table: a whole-disk filesystem is simpler to grow later, and
  # there is nothing else that needs to share this disk.
  mkfs.ext4 -L "$LABEL" -m 0 -E lazy_itable_init=0,lazy_journal_init=0 "$real"
fi

uuid=$(blkid -s UUID -o value "$real")
echo "uuid: $uuid"

mkdir -p "$MOUNT"

# Mount by UUID, never by device name: NVMe namespace numbering is not stable
# across reboots or resizes, and a wrong entry here makes the VM unbootable.
# nofail keeps a missing disk from blocking boot.
if ! grep -q "UUID=$uuid" /etc/fstab; then
  echo "=== adding fstab entry ==="
  printf 'UUID=%s  %s  ext4  defaults,discard,nofail  0  2\n' "$uuid" "$MOUNT" >> /etc/fstab
else
  echo "fstab entry already present"
fi

systemctl daemon-reload
mountpoint -q "$MOUNT" || mount "$MOUNT"

mkdir -p "$MOUNT/orthanc-db" "$MOUNT/incoming"

echo
echo "=== result ==="
findmnt -o SOURCE,TARGET,FSTYPE,SIZE,USED,AVAIL "$MOUNT"
echo
echo "fstab:"
grep "$MOUNT" /etc/fstab
