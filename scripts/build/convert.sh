#!/usr/bin/env bash
# Fetch UUP files + convert to ISO using UUP-dump's conversion script.
# Usage: convert.sh <uuid> <edition> <output-dir>
# Runs on Windows (Git Bash) or Linux.
set -euo pipefail

UUID="$1"
EDITION="$2"
OUTDIR="$3"

mkdir -p "$OUTDIR"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "[convert] Fetching UUP files for $UUID / $EDITION..."
python -m scripts.uupd.download "$UUID" "$EDITION" --output-dir "$WORK/uup"

echo "[convert] Running UUP conversion..."
# The downloaded bundle contains platform-specific converter scripts
cd "$WORK/uup"

if [ -f "uup_download_windows.cmd" ]; then
    echo "[convert] Detected Windows converter"
    # On Windows runners (Git Bash), invoke the .cmd via cmd.exe
    cmd.exe //c "$(cygpath -w "$WORK/uup/uup_download_windows.cmd")" 2>&1 | tee "$OUTDIR/convert.log"
elif [ -f "uup_download_linux.sh" ]; then
    echo "[convert] Detected Linux converter"
    bash "$WORK/uup/uup_download_linux.sh" 2>&1 | tee "$OUTDIR/convert.log"
else
    echo "[convert] ERROR: No converter script found in $WORK/uup/"
    ls -la "$WORK/uup/"
    exit 1
fi

cd - >/dev/null

# The converter produces the ISO in the current working directory or a subdirectory
ISO=$(find "$WORK" -maxdepth 3 -name "*.iso" -type f | head -1)
if [ -n "$ISO" ]; then
    cp "$ISO" "$OUTDIR/iso-in.iso"
    echo "[convert] ISO created: $OUTDIR/iso-in.iso ($(du -h "$OUTDIR/iso-in.iso" | cut -f1))"
else
    echo "[convert] ERROR: No ISO produced. Check $OUTDIR/convert.log"
    find "$WORK" -maxdepth 3 -type f | head -20
    exit 1
fi
