#!/usr/bin/env bash
# Shadow Protocol - command-line Android APK export.
# Debug signing by default. Release signing only through the
# SHADOW_PROTOCOL_KEYSTORE / SHADOW_PROTOCOL_KEYSTORE_USER / SHADOW_PROTOCOL_KEYSTORE_PASSWORD
# environment variables - secrets are never stored in the repository.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
GODOT_VERSION="4.7.2-stable"
TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION%.*}.stable"
OUT="$ROOT/build/ShadowProtocol-v0.1.0-debug.apk"
PRESET="Android"

fail() { echo "ERROR: $1" >&2; exit 1; }

command -v "$GODOT_BIN" >/dev/null 2>&1 || fail "Godot '$GODOT_BIN' not found (set GODOT_BIN)."
"$GODOT_BIN" --version 2>/dev/null | grep -q "4.7.2" || fail "Expected Godot 4.7.2, got $("$GODOT_BIN" --version)."
[ -d "$TEMPLATES_DIR" ] || fail "Export templates missing. Run tools/setup_android.sh (step 3)."

mkdir -p "$ROOT/build"

if [ -n "${SHADOW_PROTOCOL_KEYSTORE:-}" ]; then
  echo "Release signing configured via environment variables."
  PRESET_CFG="$ROOT/export_presets.cfg"
  [ -f "$PRESET_CFG" ] || fail "export_presets.cfg missing."
  sed -i.bak \
    -e "s|keystore/release=.*|keystore/release=\"$SHADOW_PROTOCOL_KEYSTORE\"|" \
    -e "s|keystore/release_user=.*|keystore/release_user=\"${SHADOW_PROTOCOL_KEYSTORE_USER:-}\"|" \
    -e "s|keystore/release_password=.*|keystore/release_password=\"$SHADOW_PROTOCOL_KEYSTORE_PASSWORD\"|" \
    "$PRESET_CFG"
  OUT="$ROOT/build/ShadowProtocol-v0.1.0-release.apk"
  trap 'mv "$PRESET_CFG.bak" "$PRESET_CFG"' EXIT
fi

echo "Exporting APK (preset: $PRESET)..."
"$GODOT_BIN" --headless --path "$ROOT" --export-project "$PRESET" "$OUT" || fail "Export failed."

[ -s "$OUT" ] || fail "Export produced no APK."
echo "OK: $OUT ($(du -h "$OUT" | cut -f1))"
