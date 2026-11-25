#!/bin/bash
# Desktop icons, taskbar, and lean Firefox settings. Safe to re-run every session.
REND="${1:-software}"
mkdir -p /root/Desktop /root/.config/tint2 /root/.config/openbox /root/.config/libfm /usr/local/bin

cat > /usr/local/bin/browser <<'B'
#!/bin/bash
export MOZ_DISABLE_CONTENT_SANDBOX=1 MOZ_DISABLE_GMP_SANDBOX=1 MOZ_DISABLE_RDD_SANDBOX=1 MOZ_DISABLE_SOCKET_PROCESS_SANDBOX=1 MOZ_FAKE_NO_SANDBOX=1
export MOZ_WEBRENDER=0 LIBGL_ALWAYS_SOFTWARE=1
exec firefox-esr "$@"
B
chmod +x /usr/local/bin/browser

# Fewer Firefox processes (Android limits how many an app may run).
mkdir -p /etc/firefox-esr
cat > /etc/firefox-esr/pcemu.js <<'P'
pref("dom.ipc.processCount", 1);
pref("dom.ipc.processCount.webIsolated", 1);
pref("fission.autostart", false);
pref("dom.ipc.processPrelaunch.enabled", false);
pref("media.rdd-process.enabled", false);
pref("network.process.enabled", false);
pref("extensions.webextensions.remote", false);
pref("security.sandbox.content.level", 0);
pref("gfx.webrender.software", true);
pref("layers.acceleration.disabled", true);
pref("browser.shell.checkDefaultBrowser", false);
pref("browser.aboutwelcome.enabled", false);
pref("datareporting.policy.dataSubmissionEnabled", false);
pref("toolkit.telemetry.enabled", false);
pref("browser.startup.homepage", "https://www.google.com");
P

app() { # file name exec icon
  cat > "/root/Desktop/$1.desktop" <<D
[Desktop Entry]
Type=Application
Name=$2
Exec=$3
Icon=$4
Terminal=false
D
}
WINE="bash -c 'source /opt/pcemu/env.sh $REND; box64 /opt/wine/bin/wine"
app firefox "Firefox" "browser" firefox-esr
app terminal "Terminal" "lxterminal" utilities-terminal
app files "Files" "pcmanfm /root" system-file-manager
app wine-explorer "Windows Explorer" "$WINE explorer'" folder
app winecfg "Wine Settings" "$WINE winecfg'" preferences-system
rm -f /root/Desktop/wine-explorer.desktop.bak
chmod +x /root/Desktop/*.desktop

# Run desktop icons without the "execute?" prompt
cat > /root/.config/libfm/libfm.conf <<'L'
[config]
quick_exec=1
[ui]
big_icon_size=48
L
mkdir -p /root/.config/pcmanfm/default
cat > /root/.config/pcmanfm/default/desktop-items-0.conf <<'C'
[*]
wallpaper_mode=color
desktop_bg=#0d0d14
desktop_fg=#ffffff
desktop_shadow=#000000
show_trash=0
show_mounts=0
C

cat > /root/.config/tint2/tint2rc <<'T'
panel_items = LTSC
panel_size = 100% 44
panel_position = bottom center horizontal
panel_background_id = 1
panel_padding = 6 4 6
rounded = 0
border_width = 0
background_color = #12162a 95
border_color = #000000 0
rounded = 10
border_width = 0
background_color = #7c5cff 60
border_color = #000000 0
launcher_padding = 4 4 6
launcher_icon_size = 32
launcher_item_app = /root/Desktop/firefox.desktop
launcher_item_app = /root/Desktop/terminal.desktop
launcher_item_app = /root/Desktop/files.desktop
launcher_item_app = /root/Desktop/wine-explorer.desktop
taskbar_mode = single_desktop
taskbar_padding = 4 2 4
task_text = 1
task_icon = 1
task_maximum_size = 200 36
task_font_color = #ffffff 100
task_active_background_id = 2
systray_padding = 4 2 4
time1_format = %H:%M
time1_font_color = #ffffff 100
clock_padding = 8 0
T
