#!/usr/bin/env bash
# Puts the Android build of proot (arm64) into jniLibs so it ships inside the APK
# and can be exec'd from nativeLibraryDir.
set -euo pipefail
DEST="${1:-android/app/src/main/jniLibs/arm64-v8a}"
mkdir -p "$DEST"; DEST="$(cd "$DEST" && pwd)"
URL="https://raw.githubusercontent.com/green-green-avk/build-proot-android/master/packages/proot-android-aarch64.tar.gz"
WORK="$(mktemp -d)"
curl -fsSL "$URL" -o "$WORK/proot.tgz"
tar -xzf "$WORK/proot.tgz" -C "$WORK"
install -m 755 "$WORK/root/bin/proot" "$DEST/libproot.so"
install -m 755 "$WORK/root/libexec/proot/loader" "$DEST/libproot_loader.so"
echo "proot installed to $DEST"; ls -la "$DEST"
