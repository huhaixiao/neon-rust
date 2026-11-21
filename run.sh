#!/bin/zsh
# Launch Neon Rust straight from the terminal.
#
#   ./run.sh          # play
#   ./run.sh -e       # open the project in the Godot editor instead
#
# Needs Godot 4.7 at the default install location; override with GODOT_BIN.

set -e

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="${0:A:h}"

if [[ ! -x "$GODOT_BIN" ]]; then
	print -u2 "Godot not found at $GODOT_BIN"
	print -u2 "Install Godot 4.7 or set GODOT_BIN=/path/to/Godot"
	exit 1
fi

if [[ "$1" == "-e" || "$1" == "--editor" ]]; then
	exec "$GODOT_BIN" --path "$PROJECT_DIR" --editor
fi

exec "$GODOT_BIN" --path "$PROJECT_DIR"
