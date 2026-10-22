#!/usr/bin/env bash
# Shadow Protocol - Android build environment preparation.
# Verifies every tool before use; installs the pieces it can install safely.
# Nothing here is destructive; every download comes from an official source.
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
GODOT_VERSION="4.7.2-stable"
TEMPLATES_TPH="Godot_v${GODOT_VERSION}_export_templates.tpz"
TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${TEMPLATES_TPH}"
TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION%.*}.stable"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/android-sdk}"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

step() { printf '\n==> %s\n' "$1"; }
ok()   { printf '    OK: %s\n' "$1"; }
missing() { printf '    MISSING: %s\n' "$1"; }

step "1. Java (17+)"
if command -v java >/dev/null 2>&1 && java -version 2>&1 | head -n1 | grep -qE 'version "?(1[7-9]|[2-9][0-9])'; then
  ok "java $(java -version 2>&1 | head -n1)"
else
  missing "Java 17+ (install: sudo apt install openjdk-17-jdk)"
fi

step "2. Godot 4.7.2"
if "$GODOT_BIN" --version 2>/dev/null | grep -q "4.7.2"; then
  ok "$($GODOT_BIN --version)"
else
  missing "Godot 4.7.2 (official: https://godotengine.org/download or GitHub releases)"
  echo "    Download example (editor binary, unzip and place on PATH):"
  echo "      curl -LO https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip"
  echo "      unzip Godot_v4.7.2-stable_linux.x86_64.zip && chmod +x Godot_v4.7.2-stable_linux.x86_64"
fi

step "3. Export templates ($GODOT_VERSION)"
if [ -d "$TEMPLATES_DIR" ]; then
  ok "$TEMPLATES_DIR"
else
  missing "export templates"
  echo "    Install with:"
  echo "      curl -L -o /tmp/$TEMPLATES_TPH $TEMPLATES_URL"
  echo "      mkdir -p \"\$(dirname $TEMPLATES_DIR)\""
  echo "      unzip /tmp/$TEMPLATES_TPH -d /tmp/tpz"
  echo "      mv /tmp/tpz/templates \"$(dirname $TEMPLATES_DIR)/${GODOT_VERSION%.*}.stable\""
fi

step "4. Android SDK"
if [ -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
  ok "$ANDROID_SDK_ROOT"
else
  missing "Android cmdline-tools at $ANDROID_SDK_ROOT"
  echo "    Install with:"
  echo "      mkdir -p $ANDROID_SDK_ROOT/cmdline-tools"
  echo "      curl -L -o /tmp/clt.zip $CMDLINE_TOOLS_URL"
  echo "      unzip -q /tmp/clt.zip -d $ANDROID_SDK_ROOT/cmdline-tools"
  echo "      mv $ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/latest"
  echo "      yes | $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager --sdk_root=$ANDROID_SDK_ROOT \"platform-tools\" \"build-tools;34.0.0\" \"platforms;android-34\""
fi

step "5. JDK keystore for debug signing"
KS="${SHADOW_PROTOCOL_DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
if [ -f "$KS" ]; then
  ok "$KS"
else
  echo "    No debug keystore yet. Create one with:"
  echo "      keytool -genkeypair -keystore $KS -storepass android -alias androiddebugkey -keypass android -dname 'CN=Android Debug,O=Android,C=US'"
fi

printf '\nSummary complete. Re-run this script until every step reports OK.\n'
