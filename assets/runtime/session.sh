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
  # Desktop shortcut for Windows programs
  mkdir -p /root/Desktop
  cat > /root/Desktop/wine-explorer.desktop <<'D'
[Desktop Entry]
Type=Application
Name=Windows Explorer
Exec=bash -lc "source /opt/pcemu/env.sh $PCEMU_RENDERER; box64 /opt/wine/bin/wine explorer"
Icon=folder
D
  cat > /root/Desktop/winecfg.desktop <<'D'
[Desktop Entry]
Type=Application
Name=Wine Settings
Exec=bash -lc "source /opt/pcemu/env.sh $PCEMU_RENDERER; box64 /opt/wine/bin/wine winecfg"
Icon=preferences-system
D
  chmod +x /root/Desktop/*.desktop
  dbus-launch --exit-with-session xfce4-session
else
  cd "$(dirname "$EXE")" 2>/dev/null
  echo "Launching $EXE"
  box64 /opt/wine/bin/wine explorer /desktop=PCEmu,"${W}x${H}" "$EXE" "$@"
  box64 /opt/wine/bin/wineserver -w
fi
echo "@@SESSION_END"
