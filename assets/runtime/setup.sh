#!/bin/bash
# PC Emulator runtime setup. Runs inside the Debian rootfs (proot, as root).
# Usage: setup.sh <wine_url> <dxvk_url> <mesa_url>
WINE_URL="$1"; DXVK_URL="$2"; MESA_URL="$3"
export DEBIAN_FRONTEND=noninteractive
STATE=/opt/pcemu/state; mkdir -p $STATE
step() { echo "@@STEP $1 $2"; }
fail() { echo "@@FAIL $1"; exit 1; }
done_() { touch "$STATE/$1"; }
has() { [ -f "$STATE/$1" ]; }

if ! has apt; then
  step 1 "Updating package lists"
  apt-get update || fail "apt-get update failed (check your internet)"
  done_ apt
fi

if ! has base; then
  step 2 "Installing desktop and X server"
  apt-get install -y --no-install-recommends \
    ca-certificates wget curl xz-utils tar unzip cabextract procps psmisc \
    xvfb x11-utils x11-xserver-utils xdotool dbus-x11 \
    xfwm4 xfce4-panel xfdesktop4 xfce4-session xfce4-settings xfconf thunar xfce4-terminal \
    adwaita-icon-theme-legacy fonts-dejavu-core fonts-liberation \
    python3 python3-xlib || fail "desktop install failed"
  done_ base
fi

if ! has libs; then
  step 3 "Installing box64 and graphics libraries"
  apt-get install -y --no-install-recommends \
    box64 libvulkan1 mesa-vulkan-drivers libgl1-mesa-dri libglx-mesa0 libegl1 libgles2 libgl1 \
    vulkan-tools mesa-utils \
    libx11-6 libxext6 libxrender1 libxrandr2 libxcomposite1 libxi6 libxcursor1 libxinerama1 libxfixes3 libxxf86vm1 \
    libfreetype6 libfontconfig1 libgnutls30t64 libasound2t64 libpulse0 libsdl2-2.0-0 libdbus-1-3 \
    libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 libncurses6 libunwind8 libusb-1.0-0 \
    || fail "box64/graphics install failed"
  done_ libs
fi

# Debian's box64 (0.3.4) is too old for Wine 11 ("could not load kernel32.dll").
# Replace it with a current build made for Linux-in-proot on Android.
if ! has box64new; then
  step 3 "Updating box64 to the latest build"
  B64_REPO="${BOX64_REPO:-https://pi-apps-coders.github.io/box64-debs/debian}"
  B64_PKG="${BOX64_PKG:-box64-android}"
  f=$(wget -q -O - "$B64_REPO/Packages" | awk -v p="$B64_PKG" '$1=="Package:"{c=$2} c==p&&$1=="Filename:"{x=$2} END{print x}')
  [ -n "$f" ] || fail "Could not find a newer box64 build (check your internet)"
  wget -q -O /tmp/box64.deb "$B64_REPO/${f#./}" || fail "box64 download failed"
  dpkg -i --force-overwrite --force-conflicts /tmp/box64.deb || fail "box64 install failed"
  rm -f /tmp/box64.deb; hash -r
  box64 --version 2>&1 | head -1
  rm -rf /root/.wine "$STATE/prefix"
  done_ box64new
fi

if ! has turnip; then
  step 4 "Installing Turnip GPU driver (Adreno)"
  if wget -q -O /tmp/mesa.tgz "$MESA_URL" && tar -xzf /tmp/mesa.tgz -C / && ldconfig; then
    rm -f /tmp/mesa.tgz; done_ turnip
  else
    echo "Turnip driver install failed; software rendering will still work"
  fi
fi

if ! has wine; then
  step 5 "Installing Wine"
  rm -rf /opt/wine /tmp/wine.txz; mkdir -p /opt/wine
  wget -q --show-progress --progress=dot:giga -O /tmp/wine.txz "$WINE_URL" || fail "Wine download failed"
  tar -xJf /tmp/wine.txz -C /opt/wine --strip-components=1 || fail "Wine unpack failed"
  rm -f /tmp/wine.txz
  done_ wine
fi

if ! has dxvk; then
  step 6 "Installing DXVK (DirectX to Vulkan)"
  rm -rf /opt/dxvk /tmp/dxvk.tgz; mkdir -p /opt/dxvk
  wget -q -O /tmp/dxvk.tgz "$DXVK_URL" && tar -xzf /tmp/dxvk.tgz -C /opt/dxvk --strip-components=1 \
    && rm -f /tmp/dxvk.tgz && done_ dxvk || echo "DXVK install failed; GPU mode will use WineD3D"
fi

if ! has prefix; then
  step 7 "Creating Windows environment (first boot takes a few minutes)"
  source /opt/pcemu/env.sh software
  rm -rf "$WINEPREFIX"
  Xvfb :9 -screen 0 1024x768x24 -nolisten tcp -extension MIT-SHM >/dev/null 2>&1 &
  XPID=$!; sleep 2
  echo "Creating Windows files. This can take 5-15 minutes on a phone, keep the app open."
  DISPLAY=:9 timeout 1200 box64 /opt/wine/bin/wine wineboot -i || echo "wineboot returned non-zero"
  DISPLAY=:9 timeout 180 box64 /opt/wine/bin/wineserver -w || DISPLAY=:9 box64 /opt/wine/bin/wineserver -k || true
  kill $XPID 2>/dev/null
  [ -d "$WINEPREFIX/drive_c/windows" ] || fail "Windows environment was not created"
  if [ -d /opt/dxvk/x64 ]; then
    cp -f /opt/dxvk/x64/*.dll "$WINEPREFIX/drive_c/windows/system32/" 2>/dev/null
    cp -f /opt/dxvk/x32/*.dll "$WINEPREFIX/drive_c/windows/syswow64/" 2>/dev/null
  fi
  # Drive D: = phone storage
  ln -sfn /sdcard "$WINEPREFIX/dosdevices/d:" 2>/dev/null
  done_ prefix
fi

step 8 "Done"
echo "@@READY"
