#!/usr/bin/env bash
# Run inside the Steam Deck's Desktop Mode, after unzipping the build.
# It fixes the two things Steam's "Add a Non-Steam Game" cares about
# (executable bit + readable path) and drops a .desktop launcher that
# Steam's file picker can always see.
set -euo pipefail
BIN="${1:-$HOME/Games/neon-rust/linux/neon-rust-debug.x86_64}"
DESKTOP="$HOME/.local/share/applications/neon-rust.desktop"

if [ ! -f "$BIN" ]; then
	echo "找不到 $BIN，先解压到 ~/Games/neon-rust/ 再跑本脚本，或把路径作为参数传入"
	exit 1
fi

chmod 755 "$BIN"
chmod 755 "$(dirname "$BIN")"

cat > "$DESKTOP" <<DESK
[Desktop Entry]
Type=Application
Name=Neon Rust
Comment=Neon Rust - twin-stick shooter
Exec=$BIN --fullscreen --resolution 1280x800
Path=$(dirname "$BIN")
Icon=applications-games
Terminal=false
Categories=Game;
DESK

chmod 644 "$DESKTOP"
echo "已写入 $DESKTOP"
echo "接着在 Steam 库 → 添加非 Steam 游戏，选择 Neon Rust（或浏览 $DESKTOP）"
