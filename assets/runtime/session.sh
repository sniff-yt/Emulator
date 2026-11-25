#!/bin/bash
# Usage: session.sh <desktop|game> <width> <height> <gpu|software> [exe path] [args...]
MODE="$1"; W="$2"; H="$3"; REND="$4"; shift 4
EXE="$1"; [ $# -gt 0 ] && shift
source /opt/pcemu/env.sh "$REND"
export DISPLAY=:1
pkill -f "Xvfb :1" 2>/dev/null; pkill -f input_daemon.py 2>/dev/null
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
mkdir -p /tmp/fb /tmp/.X11-unix; chmod 1777 /tmp/.X11-unix
rm -f /tmp/fb/Xvfb_screen0
echo "Starting display ${W}x${H} ($PCEMU_RENDERER)"
Xvfb :1 -screen 0 "${W}x${H}x24" -fbdir /tmp/fb -nolisten tcp -ac -extension MIT-SHM +extension XTEST +extension RANDR >/tmp/xvfb.log 2>&1 &
XPID=$!
for i in $(seq 1 50); do [ -e /tmp/.X11-unix/X1 ] && break; sleep 0.2; done
python3 /opt/pcemu/input_daemon.py >/tmp/input.log 2>&1 &
cleanup() { box64 /opt/wine/bin/wineserver -k 2>/dev/null; pkill -P $$ 2>/dev/null; kill $XPID 2>/dev/null; }
trap cleanup EXIT INT TERM
xsetroot -solid "#0d0d14" 2>/dev/null
echo "@@DISPLAY_READY"
if [ "$MODE" = "desktop" ]; then
  export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
  ST=/opt/pcemu/state
  # One-time upgrade: light desktop (few background processes) + Firefox.
  if [ ! -f $ST/desktop2 ]; then
    echo "Installing light desktop and Firefox (one time, ~150 MB)"
    xmessage -center -buttons "" "Installing the browser and a lighter desktop (one time, about 150 MB). Keep the app open, this takes a few minutes..." &
    MPID=$!
    { apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openbox tint2 pcmanfm lxterminal firefox-esr fonts-noto-color-emoji; } >/tmp/desktop-update.log 2>&1 \
      && touch $ST/desktop2 || echo "Desktop update failed: $(tail -2 /tmp/desktop-update.log)"
    kill $MPID 2>/dev/null
  fi
  # Newest desktop setup from the repo (older app versions don't ship this file)
  wget -q -T 10 -O /tmp/desktop_files.sh "https://raw.githubusercontent.com/sniff-yt/Emulator/main/assets/runtime/desktop_files.sh" \
    && [ -s /tmp/desktop_files.sh ] && mv /tmp/desktop_files.sh /opt/pcemu/desktop_files.sh
  [ -f /opt/pcemu/desktop_files.sh ] && bash /opt/pcemu/desktop_files.sh "$PCEMU_RENDERER"
  eval "$(dbus-launch --sh-syntax)"
  declare -A PIDS; declare -A TRIES
  launch() { "$@" >/dev/null 2>&1 & PIDS[$1]=$!; }
  if [ -f $ST/desktop2 ]; then
    launch openbox
    launch pcmanfm --desktop
    launch tint2
  else
    launch xfwm4
    launch xfdesktop
    launch xfce4-panel
  fi
  # Keep the desktop up until you quit from the app; bring back any part that crashes.
  while kill -0 $XPID 2>/dev/null; do
    sleep 3
    for k in "${!PIDS[@]}"; do
      if ! kill -0 "${PIDS[$k]}" 2>/dev/null && [ "${TRIES[$k]:-0}" -lt 5 ]; then
        TRIES[$k]=$(( ${TRIES[$k]:-0} + 1 ))
        case $k in pcmanfm) launch pcmanfm --desktop ;; *) launch $k ;; esac
      fi
    done
  done
else
  cd "$(dirname "$EXE")" 2>/dev/null
  echo "Launching $EXE"
  box64 /opt/wine/bin/wine explorer /desktop=PCEmu,"${W}x${H}" "$EXE" "$@"
  box64 /opt/wine/bin/wineserver -w
fi
echo "@@SESSION_END"
