# PC Emulator for Android

Run Windows PC games on Android (arm64). The app ships a full Linux engine that it installs on first launch:

- **Debian 13** (arm64) running in **proot** (no root needed)
- **box64**: x86_64 to ARM64 dynamic recompiler
- **Wine 11 (WoW64)**: runs 32-bit and 64-bit Windows games
- **Mesa Turnip**: open Vulkan driver for Adreno GPUs (Snapdragon)
- **DXVK 2.7**: Direct3D 8/9/10/11 to Vulkan
- **XFCE** Linux desktop

The display is an Xvfb framebuffer (`-fbdir`) that the app maps straight into a Flutter texture, and input goes through XTest via a small local daemon.

## Controls
- **Mouse**: drag to move, tap to click, two-finger tap to right-click, hold then drag to drag, two-finger swipe to scroll
- **Touch**: tap where you want to click
- **Gamepad**: left stick is WASD (or arrows), drag the right side to look, RT fire, LT aim, A jump, B crouch, X reload, Y use
- **Keys bar** with Esc, Tab, Ctrl/Alt/Shift/Win (sticky), arrows, F1 to F12, and the phone keyboard for typing

## Graphics modes
- **GPU**: Turnip + DXVK. Needs an Adreno 6xx/7xx GPU (Snapdragon). Frames are presented through Mesa's software WSI, since Xvfb has no DRI3.
- **Software**: llvmpipe + WineD3D. Works on any phone, best for older and 2D games.

## Build
CI builds a release APK on every push to `main` (see `.github/workflows/build-apk.yml`). Locally:

```bash
flutter pub get
bash scripts/fetch_proot.sh
flutter build apk --release --target-platform android-arm64
```

## Layout
- `lib/`: Flutter UI (home, setup, display and controls, settings)
- `android/app/src/main/kotlin/.../Runtime.kt`: rootfs install, proot processes
- `android/app/src/main/kotlin/.../Display.kt`: framebuffer to texture
- `assets/runtime/`: `setup.sh`, `session.sh`, `env.sh`, `input_daemon.py`, which run inside Debian

## Updates without reinstalling
- `remote/config.json` (download links, proot env/args) and `assets/runtime/*` scripts are fetched from this repo's `main` branch every time the app sets up or starts a session. Push a fix here and the app picks it up on the next launch, with no new APK.
- Changes to the Flutter/Kotlin code still need a new APK. CI publishes it as the `latest` release, and the app shows an "Update" banner when a newer build exists.
