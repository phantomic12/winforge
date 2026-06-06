#!/usr/bin/env bash
# Repack an ISO with a patched install.wim and autounattend.xml.
# Usage: repack.sh <iso-in> <iso-out> <wim-in> <autounattend-xml>
# Runs on Windows (Git Bash) or Linux.
set -euo pipefail

ISO_IN="$1"
ISO_OUT="$2"
WIM_IN="$3"
AUTOU="$4"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "[repack] Extracting ISO: $ISO_IN"
7z x "$ISO_IN" -o"$WORK" -bd -y >/dev/null

echo "[repack] Replacing install.wim"
cp "$WIM_IN" "$WORK/sources/install.wim"

echo "[repack] Injecting autounattend.xml"
cp "$AUTOU" "$WORK/autounattend.xml"

# Find boot files — handle both UEFI and BIOS
BIOS_BOOT="$WORK/boot/etfsboot.com"
UEFI_BOOT="$WORK/efi/microsoft/boot/efisys.bin"

if [ ! -f "$BIOS_BOOT" ]; then
    echo "[repack] WARN: etfsboot.com not found, building UEFI-only ISO"
fi
if [ ! -f "$UEFI_BOOT" ]; then
    echo "[repack] ERROR: efisys.bin not found"
    exit 1
fi

# Find oscdimg — prefer Windows SDK, then PATH
OSCDIMG=""
for candidate in \
    "/c/Program Files (x86)/Windows Kits/10/Assessment and Deployment Kit/Deployment Tools/amd64/Oscdimg/oscdimg.exe" \
    "/c/Program Files (x86)/Windows Kits/10/Assessment and Deployment Kit/Deployment Tools/x86/Oscdimg/oscdimg.exe" \
    "oscdimg"; do
    if [ -f "$candidate" ] || command -v "$candidate" >/dev/null 2>&1; then
        OSCDIMG="$candidate"
        break
    fi
done

if [ -z "$OSCDIMG" ]; then
    echo "[repack] ERROR: oscdimg not found. Install Windows ADK or add oscdimg to PATH."
    exit 1
fi

echo "[repack] Building ISO with oscdimg: $ISO_OUT"

if [ -f "$BIOS_BOOT" ]; then
    # Dual-boot (BIOS + UEFI)
    "$OSCDIMG" -m -o -u2 -udfver102 \
        -bootdata:2#p0,e,b"$BIOS_BOOT"#pEF,e,b"$UEFI_BOOT" \
        "$WORK" "$ISO_OUT"
else
    # UEFI-only
    "$OSCDIMG" -m -o -u2 -udfver102 \
        -bootdata:1#pEF,e,b"$UEFI_BOOT" \
        "$WORK" "$ISO_OUT"
fi

echo "[repack] ISO created: $ISO_OUT ($(du -h "$ISO_OUT" | cut -f1))"
