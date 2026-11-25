#!/bin/bash
# Runs INSIDE a debian:trixie arm64 container on GitHub's ARM runner.
# Does the whole phone setup ahead of time and packs it as one ready-made image.
set -uo pipefail
CFG=/src/remote/config.json
j() { python3 -c "import json,sys;print(json.load(open('$CFG'))['$1'])" 2>/dev/null || sed -n "s/.*\"$1\": *\"\([^\"]*\)\".*/\1/p" $CFG; }
apt-get update && apt-get install -y --no-install-recommends python3 ca-certificates wget
mkdir -p /opt/pcemu/state
cp /src/assets/runtime/* /opt/pcemu/
chmod +x /opt/pcemu/*.sh
bash /opt/pcemu/setup.sh "$(j wineUrl)" "$(j dxvkUrl)" "$(j mesaUrl)" 2>&1 | tee /out/setup.log
grep -q "@@READY" /out/setup.log || echo "WARNING: setup did not reach READY; the phone will finish the missing steps"
touch /opt/pcemu/state/desktop2
bash /opt/pcemu/desktop_files.sh software || true
echo "$(date -u +%F) $GITHUB_SHA" > /opt/pcemu/state/prebuilt
apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /root/.cache /var/log/*.log
ls /opt/pcemu/state
tar --one-file-system -C / --numeric-owner \
  --exclude=./proc --exclude=./sys --exclude=./dev --exclude=./out --exclude=./src --exclude=./.dockerenv \
  -cf - . | gzip -6 > /out/rootfs-arm64.tar.gz
ls -la /out
