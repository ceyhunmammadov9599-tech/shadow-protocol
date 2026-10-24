#!/usr/bin/env bash
# Shadow Protocol - host-only regression checks for the Android build
# and signing scripts (P8-T2). No device, no ADB, no network, no
# keystores, no secrets. Runs against the repository only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/tools/build_android.sh"
GEN="$ROOT/tools/generate_release_keystore.sh"
LOC="$ROOT/tools/build_release_local.sh"
VER="$ROOT/tools/verify_release_keystore.sh"
PRESET_CFG="$ROOT/export_presets.cfg"
pass=0; failp=0
ok() { echo "  PASS: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; failp=$((failp+1)); }

echo "Android build/signing host checks:"
for f in "$BUILD" "$GEN" "$LOC" "$VER"; do
  bash -n "$f" && ok "$(basename "$f") passes bash -n syntax validation" \
    || bad "$(basename "$f") has syntax errors"
done

VN="$(grep -m1 '^version/name=' "$PRESET_CFG" | sed 's/.*"\(.*\)"/\1/')"
[ -n "$VN" ] && ok "version/name '$VN' readable from export_presets.cfg" \
  || bad "version/name not readable from export_presets.cfg"
EP="$(grep -m1 '^export_path=' "$PRESET_CFG" | sed 's/.*"\(.*\)"/\1/')"
case "$EP" in *"-v${VN}-debug.apk") ok "export_path filename agrees with version/name ($EP)";; *) bad "export_path '$EP' disagrees with version/name '$VN'";; esac

if grep -qE 'ShadowProtocol-v[0-9]+\.[0-9]+' "$BUILD"; then
  bad "build_android.sh hard-codes a version string in artifact names"
else ok "no hard-coded version string in build_android.sh artifact names"; fi
grep -q 'OUT="$ROOT/build/ShadowProtocol-v${VERSION_NAME}-debug.apk"' "$BUILD" \
  && ok "debug artifact name derived from export preset metadata" \
  || bad "debug artifact name is not derived from preset metadata"

# Signing-secret hygiene: export_presets.cfg must never be mutated by scripts.
if grep -q 'sed -i' "$BUILD" || grep -qE 'keystore/release(_password)?=' "$BUILD"; then
  bad "build_android.sh still writes signing values into export_presets.cfg"
else ok "build_android.sh never writes signing values into export_presets.cfg"; fi
grep -q 'GODOT_ANDROID_KEYSTORE_RELEASE_PATH' "$BUILD" \
  && ok "release signing uses Godot's documented env-var overrides" \
  || bad "release signing missing GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
grep -q -- '--export-release' "$BUILD" \
  && ok "release path uses --export-release (no debug-key fallback)" \
  || bad "release path missing --export-release"
grep -q -- '--export-debug' "$BUILD" \
  && ok "default debug path uses --export-debug" \
  || bad "default path missing --export-debug"
if grep -qE '\b(adb |emulator |gradlew |pm install)' "$BUILD"; then
  bad "build_android.sh invokes device/ADB/install commands"
else ok "no ADB/emulator/install invocation in build_android.sh"; fi

# Interactive scripts must guard the human-operation boundary.
grep -q '\[ -t 0 \]' "$GEN" && grep -q '\[ -t 0 \]' "$LOC" \
  && ok "generation and interactive build require a real TTY" \
  || bad "interactive TTY guard missing in generate/build_release_local"
if grep -qE '\-storepass|\-keypass' "$GEN"; then
  bad "generate_release_keystore.sh passes passwords as arguments"
else ok "no -storepass/-keypass command-line passwords in key generation"; fi
grep -q '\[ -e "$DEST" \]' "$GEN" \
  && ok "key generation refuses to overwrite an existing keystore" \
  || bad "keystore overwrite guard missing"
grep -q 'umask 077' "$GEN" \
  && ok "keystore directory created with restrictive umask" \
  || bad "umask 077 missing in key generation"
grep -q 'read -rs' "$LOC" \
  && ok "local release build reads the password hidden (read -rs)" \
  || bad "interactive build does not use read -rs"
grep -q 'unset SHADOW_PROTOCOL_KEYSTORE_PASSWORD' "$LOC" \
  && ok "password cleared from the environment after the build" \
  || bad "password not cleared after build"
if grep -qE '\-storepass|keystore/release_password=' "$LOC" "$VER"; then
  bad "password literals found in local build/verify scripts"
else ok "no password literals in local build/verify scripts"; fi
grep -qi 'android debug' "$VER" \
  && ok "keystore verifier rejects the debug certificate" \
  || bad "debug-certificate rejection missing in verifier"

echo "Android build/signing host checks: $pass PASS / $failp FAIL"
[ "$failp" -eq 0 ]
