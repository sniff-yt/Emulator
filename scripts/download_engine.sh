#!/usr/bin/env bash
# Usage: download_engine.sh <destination dir for arm64-v8a .so files>
set -euo pipefail
DEST="${1:?destination directory required}"
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"   # make absolute before we cd elsewhere

WINLATOR_URL="https://github.com/brunodev85/winlator/releases/download/v11.2.0/Winlator_11.2.apk"
WORK="$(mktemp -d)"
cd "$WORK"
curl -fsSL "$WINLATOR_URL" -o winlator.apk
unzip -o -q winlator.apk 'lib/arm64-v8a/*.so'
# libc++_shared.so would clash with the NDK's copy; our own lib links libc++ statically.
rm -f lib/arm64-v8a/libc++_shared.so
cp lib/arm64-v8a/*.so "$DEST"/
echo "Engine libs installed to $DEST ($(ls "$DEST" | wc -l) files)"
