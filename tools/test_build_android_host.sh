#!/usr/bin/env bash
# Shadow Protocol - host-only regression checks for the Android build
# script's naming and signing logic (P8-T2). No device, no ADB, no
# network. Runs against the repository without producing artifacts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/tools/build_android.sh"
PRESET_CFG="$ROOT/export_presets.cfg"
pass=0; failp=0
ok() { echo "  PASS: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; failp=$((failp+1)); }

echo "build_android host checks:"
bash -n "$BUILD" && ok "build_android.sh passes bash -n syntax validation" \
  || bad "build_android.sh has syntax errors"

VN="$(grep -m1 '^version/name=' "$PRESET_CFG" | sed 's/.*"\(.*\)"/\1/')"
if [ -n "$VN" ] && [ "$(grep -c "^export_path=" "$PRESET_CFG")" -ge 1 ]; then
  ok "version/name '$VN' readable from export_presets.cfg"
else
  bad "version/name not readable from export_presets.cfg"
fi
EP="$(grep -m1 '^export_path=' "$PRESET_CFG" | sed 's/.*"\(.*\)"/\1/')"
case "$EP" in *"-v${VN}-debug.apk") ok "export_path filename agrees with version/name ($EP)";; *) bad "export_path '$EP' disagrees with version/name '$VN)'";; esac

if grep -qE 'ShadowProtocol-v[0-9]+\.[0-9]+' "$BUILD"; then
  bad "build_android.sh hard-codes a version string in artifact names"
else
  ok "no hard-coded version string in build_android.sh artifact names"
fi
grep -q 'OUT="$ROOT/build/ShadowProtocol-v${VERSION_NAME}-debug.apk"' "$BUILD" \
  && ok "debug artifact name derived from export preset metadata" \
  || bad "debug artifact name is not derived from preset metadata"
grep -q -- '--export-release' "$BUILD" \
  && ok "release path uses --export-release (no debug-key fallback)" \
  || bad "release path missing --export-release"
grep -q -- '--export-debug' "$BUILD" \
  && ok "default debug path uses --export-debug" \
  || bad "default path missing --export-debug"
if grep -qE '\b(adb |emulator |gradlew |pm install)' "$BUILD"; then
  bad "build_android.sh invokes device/ADB/install commands"
else
  ok "no ADB/emulator/install invocation in build_android.sh"
fi
grep -q 'sed -i.bak -f - ' "$BUILD" \
  && ok "keystore credentials reach sed via stdin, not process arguments" \
  || bad "credential injection does not use stdin"

echo "build_android host checks: $pass PASS / $failp FAIL"
[ "$failp" -eq 0 ]
