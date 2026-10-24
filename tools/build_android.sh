#!/usr/bin/env bash
# Shadow Protocol - command-line Android APK export.
# Debug signing by default. Release signing ONLY through environment
# variables (SHADOW_PROTOCOL_KEYSTORE / _USER / _PASSWORD), which are
# mapped to Godot's supported GODOT_ANDROID_KEYSTORE_RELEASE_* overrides
# for the export child process. export_presets.cfg is never modified:
# no signing secret is ever written into any project file.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
GODOT_VERSION="4.7.2-stable"
TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION%.*}.stable"
PRESET="Android"
PRESET_CFG="$ROOT/export_presets.cfg"

fail() { echo "ERROR: $1" >&2; exit 1; }

command -v "$GODOT_BIN" >/dev/null 2>&1 || fail "Godot '$GODOT_BIN' not found (set GODOT_BIN)."
"$GODOT_BIN" --version 2>/dev/null | grep -q "4.7.2" || fail "Expected Godot 4.7.2, got $("$GODOT_BIN" --version)."
[ -d "$TEMPLATES_DIR" ] || fail "Export templates missing. Run tools/setup_android.sh (step 3)."
SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/android-sdk}"
if [ ! -x "$SDK_ROOT/build-tools/34.0.0/aapt2" ]; then
  BT_ANY="$(ls -d "$SDK_ROOT"/build-tools/*/aapt2 2>/dev/null | head -n1)"
  [ -n "$BT_ANY" ] || fail "Android SDK build-tools (aapt2) missing under $SDK_ROOT (set ANDROID_SDK_ROOT; run tools/setup_android.sh step 4/6)."
fi
[ -f "$PRESET_CFG" ] || fail "export_presets.cfg missing."

# Authoritative version label comes from the export preset itself -
# never hard-coded here (acceptance audit: filename/version mismatch).
VERSION_NAME="$(grep -m1 '^version/name=' "$PRESET_CFG" | sed 's/.*"\(.*\)"/\1/')"
[ -n "$VERSION_NAME" ] || fail "Could not read version/name from export_presets.cfg."
OUT="$ROOT/build/ShadowProtocol-v${VERSION_NAME}-debug.apk"
EXPORT_MODE="--export-debug"

if [ -n "${SHADOW_PROTOCOL_KEYSTORE:-}" ]; then
  echo "Release signing requested via environment variables."
  [ -f "$SHADOW_PROTOCOL_KEYSTORE" ] || fail "SHADOW_PROTOCOL_KEYSTORE does not point to an existing keystore file."
  [ -n "${SHADOW_PROTOCOL_KEYSTORE_PASSWORD+x}" ] || fail "SHADOW_PROTOCOL_KEYSTORE_PASSWORD is not set."
  APKSIGNER="$(ls -d "$SDK_ROOT"/build-tools/*/apksigner 2>/dev/null | head -n1)"
  [ -n "$APKSIGNER" ] || fail "apksigner not found under $SDK_ROOT - cannot verify a release build."
  OUT="$ROOT/build/ShadowProtocol-v${VERSION_NAME}-release.apk"
  EXPORT_MODE="--export-release"
fi

mkdir -p "$ROOT/build"

echo "Exporting APK (preset: $PRESET, mode: ${EXPORT_MODE#--})..."
# Bounded execution: 15-minute cap on the export per the phase protocol.
# Godot reads signing from its documented environment overrides; the
# secret lives only in this process environment and the child's.
timeout 900 env \
  GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${SHADOW_PROTOCOL_KEYSTORE:-}" \
  GODOT_ANDROID_KEYSTORE_RELEASE_USER="${SHADOW_PROTOCOL_KEYSTORE_USER:-}" \
  GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${SHADOW_PROTOCOL_KEYSTORE_PASSWORD:-}" \
  "$GODOT_BIN" --headless --path "$ROOT" "$EXPORT_MODE" "$PRESET" "$OUT" || fail "Export failed."

[ -s "$OUT" ] || fail "Export produced no APK."
echo "OK: $OUT ($(du -h "$OUT" | cut -f1))"

# A release artifact that fails signature verification is a failed build.
if [ -n "${SHADOW_PROTOCOL_KEYSTORE:-}" ]; then
  "$APKSIGNER" verify --print-certs "$OUT" >/dev/null || fail "apksigner rejected the release APK signature."
  echo "OK: release APK signature verified by apksigner."
fi
