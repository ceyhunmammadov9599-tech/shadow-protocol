#!/usr/bin/env bash
# Shadow Protocol - host-only release APK verification (P8-T2/P8-T1 prep).
# Verifies an APK's structure, package metadata, signature and the
# public release certificate fingerprint. Device-free: no ADB, no
# emulator, no install. Uses only public certificate metadata.
set -euo pipefail

# Public release certificate SHA-256 (matches shadow-protocol-upload.keystore)
EXPECTED_RELEASE_SHA256="74ec3b4ec475f65517f0676b30d801f9fc557a5bb733dcabd70a5f016c574a0b"
# Standard Android debug certificate SHA-256 (must never sign a release APK)
DEBUG_SHA256="38be10fad45c9dce9a12929324ce5bb7c586ba523cbdd2107e0f7c22beee1676"
EXPECTED_PACKAGE="com.shadowprotocol.game"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "  PASS: $1"; }

[ "$#" -eq 1 ] || fail "usage: $0 <release.apk>"
APK="$1"
[ -f "$APK" ] || fail "APK file not found: $APK"
[ -s "$APK" ] || fail "APK file is empty: $APK"

# Locate build-tools without environment-specific absolute paths.
SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/android-sdk}"
BT="$(ls -d "$SDK_ROOT"/build-tools/*/ 2>/dev/null | sort -V | tail -n1)"
[ -n "$BT" ] || fail "Android SDK build-tools not found under $SDK_ROOT (set ANDROID_SDK_ROOT)"
AAPT2="$BT/aapt2"; APKSIGNER="$BT/apksigner"
[ -x "$AAPT2" ] && [ -x "$APKSIGNER" ] || fail "aapt2/apksigner missing in $BT"
command -v python3 >/dev/null 2>&1 || fail "python3 not found"

# apksigner requires java; locate it without absolute paths.
if ! command -v java >/dev/null 2>&1; then
  for cand in "$SDK_ROOT/jdk/bin/java" "$HOME"/jdk-*/bin/java "${JAVA_HOME:-}/bin/java"; do
    if [ -x "$cand" ]; then export PATH="$(dirname "$cand"):$PATH"; break; fi
  done
fi
command -v java >/dev/null 2>&1 || fail "java not found (add a JDK to PATH or JAVA_HOME)"

# 1. ZIP structure and integrity (stored APK is a ZIP).
python3 - "$APK" <<'PY' || fail "APK ZIP structure corrupt"
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
if z.testzip() is not None: sys.exit(1)
PY
ok "ZIP archive integrity"

# 2. Package identity and version metadata.
BADGING="$($AAPT2 dump badging "$APK")" || fail "aapt2 cannot read the APK"
echo "$BADGING" | grep -q "package: name='$EXPECTED_PACKAGE'" || fail "unexpected package id"
echo "$BADGING" | grep -q "versionCode='1'" || fail "unexpected versionCode"
echo "$BADGING" | grep -q "versionName='0.1.0'" || fail "unexpected versionName"
echo "$BADGING" | grep -q "native-code: 'arm64-v8a'" || fail "expected arm64-v8a native code"
ok "package/version metadata ($EXPECTED_PACKAGE 0.1.0/1, arm64-v8a)"

# 3. Signature validity and schemes.
"$APKSIGNER" verify "$APK" >/dev/null 2>&1 || fail "apksigner: signature verification failed"
SCHEMES="$("$APKSIGNER" verify --verbose "$APK")"
echo "$SCHEMES" | grep -q "v2 scheme (APK Signature Scheme v2): true" || fail "APK Signature Scheme v2 not present"
echo "$SCHEMES" | grep -q "v3 scheme (APK Signature Scheme v3): true" || fail "APK Signature Scheme v3 not present"
ok "signature verifies (v2+v3)"

# 4. Release certificate identity (fingerprint) and debug-key exclusion.
CERTS="$("$APKSIGNER" verify --print-certs "$APK")"
echo "$CERTS" | grep -q "$EXPECTED_RELEASE_SHA256" || fail "release certificate fingerprint mismatch"
echo "$CERTS" | grep -q "$DEBUG_SHA256" && fail "APK is signed with the DEBUG certificate"
ok "release certificate fingerprint matches ($EXPECTED_RELEASE_SHA256)"
ok "debug certificate is not used"

echo "OK: $APK passes host-side release verification"
