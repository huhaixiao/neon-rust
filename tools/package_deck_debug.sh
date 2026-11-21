#!/usr/bin/env bash
# Debug build for live debugging on the Steam Deck: keeps symbols, exposes the
# in-game F3 (R3 click) stats overlay, and can attach to the editor with
#   ./neon-rust-debug.x86_64 --remote-debug tcp://<mac-lan-ip>:6007
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT="$ROOT/build/linux/neon-rust-debug.x86_64"
ZIP="$ROOT/build/neon-rust-linux-x86_64-debug.zip"

mkdir -p "$ROOT/build/linux"
rm -f "$OUT" "$ZIP"
"$GODOT" --headless --path "$ROOT" --export-debug "Linux Deck" "$OUT"
chmod +x "$OUT"
cp "$ROOT/tools/install-on-deck.sh" "$ROOT/build/install-on-deck.sh"
( cd "$ROOT/build" && zip -qr "$(basename "$ZIP")" linux/neon-rust-debug.x86_64 install-on-deck.sh )
ls -lh "$OUT" "$ZIP"
shasum -a 256 "$ZIP"
