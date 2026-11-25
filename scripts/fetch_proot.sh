#!/usr/bin/env bash
# Bundles Termux's proot (maintained, works on Android 14-16) into jniLibs.
# Libraries are renamed to lib*.so so Android packages and extracts them, and
# the ELF NEEDED/SONAME entries are patched to match.
set -euo pipefail
DEST="${1:-android/app/src/main/jniLibs/arm64-v8a}"
mkdir -p "$DEST"; DEST="$(cd "$DEST" && pwd)"
REPO="https://packages.termux.dev/apt/termux-main"
WORK="$(mktemp -d)"; cd "$WORK"
curl -fsSL "$REPO/dists/stable/main/binary-aarch64/Packages" -o Packages
fname() { awk -v p="$1" '$1=="Package:"{cur=$2} cur==p && $1=="Filename:"{print $2; exit}' Packages; }
command -v patchelf >/dev/null || pip install -q patchelf
export PATH="$HOME/.local/bin:$PATH"
for pkg in proot libtalloc libandroid-shmem; do
  f=$(fname "$pkg"); echo "$pkg -> $f"
  curl -fsSL "$REPO/$f" -o "$pkg.deb"
  mkdir -p "x_$pkg"; python3 - "$pkg.deb" "x_$pkg" <<'PY'
import io, sys, tarfile
d = open(sys.argv[1], 'rb').read(); i = 8
while i < len(d):
    name = d[i:i+16].decode().strip().rstrip('/'); size = int(d[i+48:i+58])
    data = d[i+60:i+60+size]; i += 60 + size + (size % 2)
    if name.startswith('data.tar'):
        tarfile.open(fileobj=io.BytesIO(data)).extractall(sys.argv[2])
PY
done
U=data/data/com.termux/files/usr
install -m 755 "x_proot/$U/bin/proot" "$DEST/libproot.so"
install -m 755 "x_proot/$U/libexec/proot/loader" "$DEST/libproot_loader.so"
install -m 755 "x_proot/$U/libexec/proot/loader32" "$DEST/libproot_loader32.so"
install -m 755 "$(ls x_libtalloc/$U/lib/libtalloc.so.2.* | head -1)" "$DEST/libtalloc.so"
install -m 755 "x_libandroid-shmem/$U/lib/libandroid-shmem.so" "$DEST/libandroid-shmem.so"
patchelf --replace-needed libtalloc.so.2 libtalloc.so "$DEST/libproot.so"
patchelf --remove-rpath "$DEST/libproot.so"
patchelf --set-soname libtalloc.so "$DEST/libtalloc.so"
patchelf --print-needed "$DEST/libproot.so"
ls -la "$DEST"
