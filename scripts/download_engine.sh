#!/usr/bin/env bash
set -e
WINLATOR_URL="https://github.com/brunodev85/winlator/releases/download/v11.2.0/Winlator_11.2.apk"
mkdir -p /tmp/winlator && cd /tmp/winlator
wget -q "$WINLATOR_URL" -O winlator.apk
unzip -o winlator.apk 'lib/arm64-v8a/*' >/dev/null || true
mkdir -p "$1"
cp lib/arm64-v8a/*.so "$1"/
echo "Engine libs installed to $1"
