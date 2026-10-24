#!/usr/bin/env bash
# Shadow Protocol - DEVELOPER-OWNED release keystore generation.
#
# SECURITY PROTOCOL (P8-T2): run this ON YOUR OWN TRUSTED MACHINE in a
# real interactive terminal. It must NOT be run inside an unattended
# remote/agent environment. You personally type the password; it is
# never echoed, never stored, never passed as a command-line argument.
set -euo pipefail

fail() { echo "ERROR: $1" >&2; exit 1; }

# Human-operation boundary: a real TTY is required so keytool can prompt.
[ -t 0 ] && [ -t 1 ] || fail "No interactive terminal. Run this script locally in your own terminal."
command -v keytool >/dev/null 2>&1 || fail "keytool not found (install a JDK first)."
# Refuse to run if shell tracing is on (would record the typed password).
[[ $- != *x* ]] || { set +x; echo "NOTE: shell tracing disabled for security."; }

DEST="${1:-$HOME/.local/share/shadow-protocol/signing/shadow-protocol-upload.keystore}"
ALIAS="${2:-shadow_protocol_upload}"

[ -e "$DEST" ] && fail "Refusing to overwrite existing file: $DEST (a published signing identity must never be replaced silently)."

umask 077
mkdir -p "$(dirname "$DEST")"
chmod 700 "$(dirname "$DEST")"

echo "Generating release signing key (you will be prompted for a NEW strong password)."
echo "Keystore: $DEST"
echo "Alias:    $ALIAS"
echo "Use the SAME password for keystore and key (Godot Android exporter requirement)."
echo

keytool -genkeypair \
  -keystore "$DEST" \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 3072 \
  -validity 10000 \
  -storetype PKCS12

chmod 600 "$DEST"

# Non-sensitive validation (keytool prompts for the password you set).
echo
echo "Validating (enter the same password when prompted)..."
keytool -list -v -keystore "$DEST" -storetype PKCS12 2>/dev/null \
  | grep -E "Alias name|Entry type|Signature algorithm|Valid from|SHA256:" | sed 's/^/  /'

PERM="$(stat -c '%a' "$DEST" 2>/dev/null || stat -f '%Lp' "$DEST")"
echo
echo "OK: keystore created: $DEST"
echo "Permissions: $PERM (expected 600). Owner-only access is enforced."
echo
echo "BACKUP (do this yourself, privately):"
echo "  1. Copy the keystore to an ENCRYPTED backup on separate storage."
echo "  2. Keep the password only in your password manager."
echo "  3. Verify the backup is readable with: keytool -list -keystore <backup>"
echo "  4. NEVER upload this file to GitHub, cloud storage or any agent."
