#!/usr/bin/env python3
"""Bake the Neon Rust arena floor (1600x1000) as one PNG.

Standalone so it can be re-run independently of the sprite sheet:
    python3 tools/generate_arena.py

Colours are authored directly in display space (what the PNG stores is what
the screen shows), so every value here is an 0-255 sRGB channel.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_assets import _hash, out_path, save_rgba_png  # noqa: E402

WIDTH = 1600
HEIGHT = 1000

BASE = (15.0, 18.0, 26.0)
NOISE = 5.0
MINOR_LINE = (10.0, 24.0, 34.0)
MAJOR_LINE = (22.0, 52.0, 70.0)


def set_pixel(rows, x, y, rgb):
    if 0 <= x < WIDTH and 0 <= y < HEIGHT:
        row = rows[y]
        base = x * 4
        row[base + 0] = int(max(0.0, min(255.0, rgb[0])))
        row[base + 1] = int(max(0.0, min(255.0, rgb[1])))
        row[base + 2] = int(max(0.0, min(255.0, rgb[2])))


def build():
    rows = [bytearray(WIDTH * 4) for _ in range(HEIGHT)]
    cx, cy = WIDTH / 2.0, HEIGHT / 2.0
    col_minor = [x % 64 == 0 for x in range(WIDTH)]
    col_major = [x % 256 == 0 for x in range(WIDTH)]

    for y in range(HEIGHT):
        row = rows[y]
        dy = y - cy
        ndy = dy / cy
        row_minor = y % 64 == 0
        row_major = y % 256 == 0
        for x in range(WIDTH):
            dx = x - cx
            ndx = dx / cx
            vignette = 1.0 - 0.22 * (ndx * ndx + ndy * ndy)
            if vignette < 0.72:
                vignette = 0.72
            n = (_hash(x, y) - 0.5) * NOISE

            r = BASE[0] * vignette + n * 0.6
            g = BASE[1] * vignette + n
            b = BASE[2] * vignette + n * 1.4

            if col_minor[x] or row_minor:
                r += MINOR_LINE[0]
                g += MINOR_LINE[1]
                b += MINOR_LINE[2]
            if col_major[x] or row_major:
                r += MAJOR_LINE[0]
                g += MAJOR_LINE[1]
                b += MAJOR_LINE[2]

            # 210 px centre ring, thin core plus a soft halo.
            dist = math.sqrt(dx * dx + dy * dy)
            ring = abs(dist - 210.0)
            if ring < 1.6:
                r += 30.0
                g += 120.0
                b += 150.0
            elif ring < 12.0:
                falloff = math.exp(-(ring - 1.6) / 4.0)
                r += 14.0 * falloff
                g += 52.0 * falloff
                b += 68.0 * falloff

            # Inner tick marks on the ring axes.
            if abs(dx) < 1.4 and 190.0 < abs(dy) < 232.0:
                r += 30.0
                g += 120.0
                b += 150.0
            if abs(dy) < 1.4 and 190.0 < abs(dx) < 232.0:
                r += 30.0
                g += 120.0
                b += 150.0

            # Outer rim: bright border plus a decaying glow along the walls.
            edge = min(x, y, WIDTH - 1 - x, HEIGHT - 1 - y)
            if edge < 3:
                r, g, b = 26.0, 168.0, 208.0
            elif edge < 90:
                glow = math.exp(-(edge - 3) / 24.0)
                r += 12.0 * glow
                g += 88.0 * glow
                b += 112.0 * glow

            base_i = x * 4
            row[base_i + 0] = int(max(0.0, min(255.0, r)))
            row[base_i + 1] = int(max(0.0, min(255.0, g)))
            row[base_i + 2] = int(max(0.0, min(255.0, b)))
            row[base_i + 3] = 255

    # Corner brackets, the only hard-edged decoration on the stage.
    arm = 130
    corners = [(22, 22, 1, 1), (WIDTH - 23, 22, -1, 1),
               (22, HEIGHT - 23, 1, -1), (WIDTH - 23, HEIGHT - 23, -1, -1)]
    for ox, oy, sx, sy in corners:
        for i in range(arm):
            for t in range(4):
                set_pixel(rows, ox + sx * i, oy + sy * t, (86, 232, 255))
                set_pixel(rows, ox + sx * t, oy + sy * i, (86, 232, 255))

    path = out_path("arena_floor.png")
    save_rgba_png(path, WIDTH, HEIGHT, rows)
    print("arena floor ->", path)


if __name__ == "__main__":
    build()
