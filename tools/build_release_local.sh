#!/usr/bin/env bash
# Shadow Protocol - interactive LOCAL release build.
#
# SECURITY PROTOCOL (P8-T2): run this ON YOUR OWN TRUSTED MACHINE in a
# real interactive terminal, after creating the keystore with
# tools/generate_release_keystore.sh. The password is typed here (hidden),
# passed ONLY through the environment of the Godot child process, and
# cleared immediately after the build. Nothing is written to
# export_presets.cfg or any file.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYSTORE="${SHADOW_PROTOCOL_KEYSTORE:-$HOME/.local/share/shadow-protocol/signing/shadow-protocol-upload.keystore}"
ALIAS="${SHADOW_PROTOCOL_KEYSTORE_USER:-shadow_protocol_upload}"

fail() { echo "ERROR: $1" >&2; exit 1; }

[ -t 0 ] && [ -t 2 ] || fail "No interactive terminal. Run this script locally in your own terminal."
[ -f "$KEYSTORE" ] || fail "Keystore not found: $KEYSTORE (run tools/generate_release_keystore.sh first)."
[[ $- != *x* ]] || { set +x; echo "NOTE: shell tracing disabled for security."; }

echo "Release build with: $KEYSTORE (alias: $ALIAS)"
printf "Signing password (input hidden): "
IFS= read -rs SHADOW_PROTOCOL_KEYSTORE_PASSWORD
printf "\n"
[ -n "$SHADOW_PROTOCOL_KEYSTORE_PASSWORD" ] || fail "Empty password - aborting."

export SHADOW_PROTOCOL_KEYSTORE SHADOW_PROTOCOL_KEYSTORE_USER="$ALIAS" SHADOW_PROTOCOL_KEYSTORE_PASSWORD
if bash "$ROOT/tools/build_android.sh"; then STATUS=0; else STATUS=$?; fi
unset SHADOW_PROTOCOL_KEYSTORE_PASSWORD
exit $STATUS
