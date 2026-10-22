#!/usr/bin/env bash
# Shadow Protocol - deploy to a connected device with ADB, then launch.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB="${ADB:-adb}"
PKG="com.shadowprotocol.game"
APK="$(ls -t "$ROOT"/build/*.apk 2>/dev/null | head -n1)"

command -v "$ADB" >/dev/null 2>&1 || { echo "ERROR: adb not found (set ADB=/path/to/adb)."; exit 1; }
[ -n "$APK" ] || { echo "ERROR: no APK in $ROOT/build. Run tools/build_android.sh first."; exit 1; }

"$ADB" get-state >/dev/null 2>&1 || { echo "ERROR: no Android device connected."; exit 1; }

echo "Installing $APK ..."
"$ADB" install -r "$APK"
echo "Launching $PKG ..."
"$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
echo "OK: installed and launched."
