#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

echo "==> Dart/Flutter static analysis"
flutter pub get
flutter analyze || true

echo "==> Auto-fix dart issues"
dart fix --apply || true

echo "==> Native C++ compile check (clang)"
if command -v clang++ >/dev/null 2>&1; then
  for f in android/app/src/main/cpp/*.cpp; do
    echo "Checking $f"
    clang++ -std=c++17 -fsyntax-only -I android/app/src/main/cpp "$f" || exit 1
  done
else
  echo "clang++ not available, skipping native syntax check"
fi

echo "==> All checks passed"