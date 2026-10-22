#!/usr/bin/env bash
# Shadow Protocol - headless project validation.
# Imports resources, boots the main scene for a few seconds of headless
# simulation and fails on any script/scene error. No display required.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
FRAMES="${FRAMES:-180}"   # ~3 seconds at 60 FPS of game logic
LOG="$(mktemp /tmp/shadow-protocol-validate.XXXXXX.log)"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "ERROR: Godot binary '$GODOT_BIN' not found." >&2
  echo "Set GODOT_BIN=/path/to/godot or install Godot 4.7.2." >&2
  exit 1
fi
echo "Using Godot: $($GODOT_BIN --version 2>&1 | head -n1)"

echo "[1/3] Importing resources..."
"$GODOT_BIN" --headless --path "$ROOT" --import >"$LOG" 2>&1 || {
  tail -n 40 "$LOG"; echo "ERROR: resource import failed."; exit 1; }

echo "[2/3] Running main scene headless for $FRAMES frames..."
"$GODOT_BIN" --headless --path "$ROOT" --quit-after "$FRAMES" >"$LOG" 2>&1 || {
  tail -n 60 "$LOG"; echo "ERROR: headless run failed."; exit 1; }

echo "[3/4] Scanning output for script and scene errors..."
if grep -nEi "script error|parse error|failed to load" "$LOG"; then
  echo "ERROR: errors detected during headless run."; exit 1
fi

echo "[4/4] Running headless smoke test (movement, crouch, joystick, stealth)..."
"$GODOT_BIN" --headless --path "$ROOT" res://tools/smoke_test.tscn >"$LOG" 2>&1 || {
  tail -n 40 "$LOG"; echo "ERROR: smoke test failed."; exit 1; }
grep -q "SMOKE TEST: all checks passed" "$LOG" || {
  tail -n 40 "$LOG"; echo "ERROR: smoke test did not pass."; exit 1; }

echo "OK: project validated headless (import + $FRAMES frames + smoke test, no errors)."
