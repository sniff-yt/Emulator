#!/usr/bin/env bash
set -e
export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$FLUTTER_HOME/bin:$PATH"

if [ ! -d "$FLUTTER_HOME" ]; then
  echo "Cloning Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_HOME"
fi

if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
  echo "Downloading Android command-line tools..."
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  cd "$ANDROID_HOME/cmdline-tools"
  wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q commandlinetools-linux-*.zip
  mv cmdline-tools latest
  cd -
fi

yes | sdkmanager --licenses >/dev/null 2>&1 || true
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" >/dev/null 2>&1 || true

cd "$(dirname "$0")"
flutter pub get
flutter build apk --release
echo "APK: $(pwd)/build/app/outputs/flutter-apk/app-release.apk"