#!/usr/bin/env bash
# Shadow Protocol - non-secret keystore validation (interactive password).
# Verifies the release keystore is usable and NOT the debug certificate.
set -euo pipefail

fail() { echo "ERROR: $1" >&2; exit 1; }
KEYSTORE="${1:-$HOME/.local/share/shadow-protocol/signing/shadow-protocol-upload.keystore}"
[ -f "$KEYSTORE" ] || fail "Keystore not found: $KEYSTORE"
[ -t 0 ] || fail "Run this locally in an interactive terminal (keytool must prompt for the password)."
[[ $- != *x* ]] || { set +x; echo "NOTE: shell tracing disabled for security."; }

echo "Validating: $KEYSTORE (enter the keystore password when prompted)"
OUT="$(mktemp)"; trap 'rm -f "$OUT"' EXIT
keytool -list -v -keystore "$KEYSTORE" -storetype PKCS12 2>/dev/null > "$OUT" || fail "keytool could not read the keystore."

grep -q "shadow_protocol_upload" "$OUT" || fail "Alias 'shadow_protocol_upload' not found in the keystore."
grep -q "SHA256:" "$OUT" || fail "No public certificate found."
grep -q "SHA256withRSA" "$OUT" || echo "NOTE: signature algorithm is not SHA256withRSA - check key generation."
grep -qi "android debug" "$OUT" && fail "This looks like the DEBUG certificate, not a release key."
echo "PASS: PKCS12 keystore readable, alias present, public certificate present, not the debug certificate."
grep -E "Alias name|Signature algorithm|Valid from" "$OUT" | sed 's/^/  /'
grep "SHA256:" "$OUT" | head -1 | sed 's/^/  /'
PERM="$(stat -c '%a' "$KEYSTORE" 2>/dev/null || stat -f '%Lp' "$KEYSTORE")"
[ "$PERM" = "600" ] && echo "PASS: file permissions 600." || echo "NOTE: permissions are $PERM (expected 600; run: chmod 600)."
