#!/usr/bin/env bash
# Builds the Steam Deck / Linux package: exports the release binary, zips it
# (so the executable bit survives LocalSend), and prints the sha256.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT="$ROOT/build/linux/neon-rust.x86_64"
ZIP="$ROOT/build/neon-rust-linux-x86_64.zip"

mkdir -p "$ROOT/build/linux"
rm -f "$OUT" "$ZIP"
"$GODOT" --headless --path "$ROOT" --export-release "Linux Deck" "$OUT"
chmod +x "$OUT"
cp "$ROOT/tools/install-on-deck.sh" "$ROOT/build/install-on-deck.sh"
( cd "$ROOT/build" && rm -f "$(basename "$ZIP")" && zip -qr "$(basename "$ZIP")" linux/neon-rust.x86_64 install-on-deck.sh )
ls -lh "$OUT" "$ZIP"
shasum -a 256 "$ZIP"
