#!/usr/bin/env python3
"""Neon Rust - procedural neon sprite generator (standard library only).

Every sprite is described as a signed distance field (SDF) and shaded in three
tones: a hot edge, a saturated body and a soft neon halo. Because the distance
field is analytic the shapes are crisp at any scale and there is zero dependency
on Pillow / numpy.

Usage:
    python3 tools/generate_assets.py
    python3 tools/generate_assets.py --preview /tmp/neon_sheet.png
"""

import argparse
import math
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ASSET_ROOT = os.path.normpath(os.path.join(HERE, "..", "modules"))
SPRITE_DIRS = {
    "player/assets/sprites": ["player.png"],
    "enemies/assets/sprites": ["enemy_chaser.png", "enemy_brute.png", "enemy_spitter.png"],
    "projectiles/assets/sprites": ["bullet_player.png", "bullet_enemy.png"],
    "pickups/assets/sprites": ["pickup_health.png", "pickup_overdrive.png"],
    "global/assets/sprites/ui": ["crosshair.png"],
    "global/assets/sprites/fx": ["particle.png", "flash.png"],
    "global/assets/sprites/legacy": ["floor_tile.png"],
    "global/assets/sprites/world": ["arena_floor.png"],
}


def out_path(name):
    """Resolve a generated sprite to its owning module's assets/ folder."""
    base = os.path.basename(name)
    for sub, names in SPRITE_DIRS.items():
        if base in names:
            return os.path.join(ASSET_ROOT, sub, base)
    raise KeyError("no destination for sprite " + base)


# --------------------------------------------------------------------------
# PNG writer
# --------------------------------------------------------------------------
def _chunk(tag, data):
    body = tag + data
    return (struct.pack(">I", len(data)) + body
            + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF))


def save_rgba_png(path, width, height, rows):
    raw = bytearray()
    for row in rows:
        raw.append(0)
        raw.extend(row)
    png = b"\x89PNG\r\n\x1a\n"
    png += _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += _chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(png)


def _u8(v):
    if v <= 0.0:
        return 0
    if v >= 1.0:
        return 255
    return int(round(v * 255))


# --------------------------------------------------------------------------
# geometry helpers (coordinates are local pixels, origin at sprite centre)
# --------------------------------------------------------------------------
def clamp01(v):
    return 0.0 if v < 0.0 else (1.0 if v > 1.0 else v)


def lerp(a, b, t):
    return a + (b - a) * t


def dist_point_segment(px, py, ax, ay, bx, by):
    abx, aby = bx - ax, by - ay
    apx, apy = px - ax, py - ay
    denom = abx * abx + aby * aby
    if denom <= 1e-9:
        return math.hypot(apx, apy)
    t = clamp01((apx * abx + apy * aby) / denom)
    return math.hypot(apx - abx * t, apy - aby * t)


def point_in_polygon(px, py, poly):
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > py) != (yj > py):
            x_cross = (xj - xi) * (py - yi) / (yj - yi) + xi
            if px < x_cross:
                inside = not inside
        j = i
    return inside


def poly_sdf(poly):
    def sdf(px, py):
        d = min(dist_point_segment(px, py, poly[i][0], poly[i][1],
                                   poly[(i + 1) % len(poly)][0],
                                   poly[(i + 1) % len(poly)][1])
                for i in range(len(poly)))
        return -d if point_in_polygon(px, py, poly) else d
    return sdf


def circle_sdf(cx, cy, r):
    return lambda px, py: math.hypot(px - cx, py - cy) - r


def capsule_sdf(ax, ay, bx, by, r):
    return lambda px, py: dist_point_segment(px, py, ax, ay, bx, by) - r


def ring_sdf(cx, cy, r, w):
    return lambda px, py: abs(math.hypot(px - cx, py - cy) - r) - w


def box_sdf(cx, cy, hw, hh):
    def sdf(px, py):
        dx = abs(px - cx) - hw
        dy = abs(py - cy) - hh
        outside = math.hypot(max(dx, 0.0), max(dy, 0.0))
        inside = min(max(dx, dy), 0.0)
        return outside + inside
    return sdf


def union(*fns):
    return lambda px, py: min(f(px, py) for f in fns)


# --------------------------------------------------------------------------
# renderer
# --------------------------------------------------------------------------
class Layer:
    def __init__(self, sdf, edge, body, glow, glow_scale=12.0,
                 glow_alpha=0.55, shade=3.0):
        self.sdf = sdf
        self.edge = edge
        self.body = body
        self.glow = glow
        self.glow_scale = glow_scale
        self.glow_alpha = glow_alpha
        self.shade = shade


class Detail:
    """Small bright element drawn on top of the base shape (cockpit, core)."""

    def __init__(self, sdf, color, glow=None, glow_scale=5.0, alpha=1.0):
        self.sdf = sdf
        self.color = color
        self.glow = glow or color
        self.glow_scale = glow_scale
        self.alpha = alpha


def render(size, layers, details=()):
    rows = [bytearray(size * 4) for _ in range(size)]
    half = size / 2.0
    for y in range(size):
        py = y - half + 0.5
        row = rows[y]
        for x in range(size):
            px = x - half + 0.5
            r = g = b = a = 0.0
            edge_fade = clamp01((half - max(abs(px), abs(py))) / 12.0)
            for layer in layers:
                sd = layer.sdf(px, py)
                cov = clamp01(0.5 - sd)
                if cov > 0.0:
                    t = clamp01(-sd / layer.shade)
                    col = tuple(lerp(layer.edge[k], layer.body[k], t) for k in range(3))
                    if cov > a:
                        a, (r, g, b) = cov, col
                if sd > 0.0:
                    halo = layer.glow_alpha * math.exp(-sd / layer.glow_scale) * edge_fade
                    if halo > a:
                        a, (r, g, b) = halo, layer.glow
            for det in details:
                sd = det.sdf(px, py)
                if sd <= 0.0:
                    a, (r, g, b) = det.alpha, det.color
                else:
                    halo = det.alpha * 0.5 * math.exp(-sd / det.glow_scale) * edge_fade
                    if halo > a:
                        a, (r, g, b) = halo, det.glow
            row[x * 4 + 0] = _u8(r)
            row[x * 4 + 1] = _u8(g)
            row[x * 4 + 2] = _u8(b)
            row[x * 4 + 3] = _u8(a)
    return rows


def write_sprite(name, size, layers, details=()):
    save_rgba_png(out_path(name), size, size, render(size, layers, details))
    print("  sprite ->", name, f"{size}x{size}")


# --------------------------------------------------------------------------
# palette
# --------------------------------------------------------------------------
CYAN = (0.10, 0.78, 1.00)
WHITE = (1.0, 1.0, 1.0)
MAGENTA = (1.00, 0.10, 0.48)
ORANGE = (1.00, 0.45, 0.06)
LIME = (0.72, 1.00, 0.18)
GREEN = (0.20, 1.00, 0.45)
AMBER = (1.00, 0.72, 0.12)
RED = (1.00, 0.18, 0.28)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default="", help="also write a contact sheet here")
    args = ap.parse_args()

    print("Generating sprites into", ASSET_ROOT)
    for sub in SPRITE_DIRS:
        os.makedirs(os.path.join(ASSET_ROOT, sub), exist_ok=True)

    # -- player ship -------------------------------------------------------
    ship = [(58, 0), (14, -12), (-10, -30), (-10, -14), (-30, -14),
            (-30, 14), (-10, 14), (-10, 30), (14, 12)]
    write_sprite(
        "player.png", 128,
        [Layer(poly_sdf(ship), (0.80, 1.0, 1.0), (0.02, 0.42, 0.62), CYAN,
               glow_scale=16.0, glow_alpha=0.60)],
        [
            Detail(circle_sdf(14, 0, 5.5), WHITE, (0.6, 1.0, 1.0), 6.0),
            Detail(circle_sdf(-27, 0, 3.2), (0.85, 1.0, 1.0), CYAN, 9.0),
        ],
    )

    # -- chaser -----------------------------------------------------------
    chaser = [(42, 0), (8, -20), (-14, -30), (-14, -10), (-26, 0),
              (-14, 10), (-14, 30), (8, 20)]
    write_sprite(
        "enemy_chaser.png", 96,
        [Layer(poly_sdf(chaser), (1.0, 0.72, 0.88), (0.42, 0.02, 0.20), MAGENTA,
               glow_scale=12.0, glow_alpha=0.60)],
        [Detail(circle_sdf(4, 0, 4.0), WHITE, (1.0, 0.45, 0.75), 6.0)],
    )

    # -- brute ------------------------------------------------------------
    hexagon = [(42 * math.cos(math.radians(a)), 42 * math.sin(math.radians(a)))
               for a in range(0, 360, 60)]
    write_sprite(
        "enemy_brute.png", 128,
        [Layer(poly_sdf(hexagon), (1.0, 0.86, 0.55), (0.40, 0.18, 0.02), ORANGE,
               glow_scale=16.0, glow_alpha=0.55)],
        [
            Detail(ring_sdf(0, 0, 22, 3.0), (1.0, 0.86, 0.5), ORANGE, 8.0, 0.85),
            Detail(circle_sdf(0, 0, 8.0), WHITE, (1.0, 0.8, 0.4), 7.0),
        ],
    )

    # -- spitter ----------------------------------------------------------
    spitter = [(38, 0), (6, -26), (-26, 0), (6, 26)]
    write_sprite(
        "enemy_spitter.png", 96,
        [Layer(poly_sdf(spitter), (0.95, 1.0, 0.65), (0.32, 0.40, 0.02), LIME,
               glow_scale=12.0, glow_alpha=0.60)],
        [Detail(circle_sdf(2, 0, 7.0), WHITE, LIME, 8.0)],
    )

    # -- bullets ----------------------------------------------------------
    write_sprite(
        "bullet_player.png", 48,
        [Layer(union(capsule_sdf(-9, 0, 9, 0, 3.2), circle_sdf(0, 0, 3.4)),
               WHITE, (0.75, 1.0, 1.0), CYAN, glow_scale=7.0, glow_alpha=0.85)],
    )
    write_sprite(
        "bullet_enemy.png", 48,
        [Layer(circle_sdf(0, 0, 6.0), (1.0, 0.9, 0.9), (0.75, 0.10, 0.18), RED,
               glow_scale=7.5, glow_alpha=0.85)],
        [Detail(circle_sdf(0, 0, 2.2), WHITE, RED, 4.0)],
    )

    # -- pickups ----------------------------------------------------------
    cross = union(capsule_sdf(-13, 0, 13, 0, 4.2), capsule_sdf(0, -13, 0, 13, 4.2))
    write_sprite(
        "pickup_health.png", 64,
        [Layer(cross, (0.85, 1.0, 0.9), (0.04, 0.45, 0.18), GREEN,
               glow_scale=9.0, glow_alpha=0.75)],
        [Detail(capsule_sdf(-6, 0, 6, 0, 1.6), WHITE, GREEN, 4.0, 0.9)],
    )

    chevrons = union(
        capsule_sdf(-20, -12, -8, 0, 2.6), capsule_sdf(-8, 0, -20, 12, 2.6),
        capsule_sdf(-10, -12, 2, 0, 2.6), capsule_sdf(2, 0, -10, 12, 2.6),
        capsule_sdf(0, -12, 12, 0, 2.6), capsule_sdf(12, 0, 0, 12, 2.6),
    )
    write_sprite(
        "pickup_overdrive.png", 64,
        [Layer(chevrons, (1.0, 0.95, 0.7), (0.45, 0.28, 0.01), AMBER,
               glow_scale=9.0, glow_alpha=0.75)],
        [Detail(circle_sdf(-14, 0, 2.0), WHITE, AMBER, 3.0)],
    )

    # -- fx ---------------------------------------------------------------
    write_sprite(
        "particle.png", 32,
        [Layer(circle_sdf(0, 0, 4.0), WHITE, (1.0, 1.0, 1.0), WHITE,
               glow_scale=6.0, glow_alpha=0.9)],
    )
    flash = union(
        capsule_sdf(-24, 0, 24, 0, 2.2), capsule_sdf(0, -24, 0, 24, 2.2),
        circle_sdf(0, 0, 7.0),
    )
    write_sprite(
        "flash.png", 72,
        [Layer(flash, WHITE, (1.0, 1.0, 1.0), WHITE, glow_scale=10.0, glow_alpha=0.85)],
    )

    # -- crosshair --------------------------------------------------------
    ticks = union(
        capsule_sdf(17, 0, 23, 0, 1.2), capsule_sdf(-17, 0, -23, 0, 1.2),
        capsule_sdf(0, 17, 0, 23, 1.2), capsule_sdf(0, -17, 0, -23, 1.2),
    )
    write_sprite(
        "crosshair.png", 48,
        [Layer(union(ring_sdf(0, 0, 12.0, 0.9), ticks), (0.85, 1.0, 1.0),
               (0.15, 0.7, 0.9), CYAN, glow_scale=6.0, glow_alpha=0.55)],
        [Detail(circle_sdf(0, 0, 1.3), WHITE, CYAN, 2.0, 0.9)],
    )

    # -- floor tile -------------------------------------------------------
    write_floor_tile("floor_tile.png", 64)

    if args.preview:
        write_contact_sheet(args.preview)
    print("done.")


def _hash(x, y):
    n = x * 374761393 + y * 668265263
    n = (n ^ (n >> 13)) * 1274126177
    return ((n ^ (n >> 16)) & 0xFFFFFFFF) / 0xFFFFFFFF


def write_floor_tile(name, size):
    rows = [bytearray(size * 4) for _ in range(size)]
    base = (0.030, 0.034, 0.052)
    for y in range(size):
        row = rows[y]
        for x in range(size):
            r, g, b = base
            # fine noise so the flat colour does not band
            n = _hash(x, y) * 0.018
            r, g, b = r + n, g + n, b + n * 1.3
            # major grid every 64 px (tile edge) + minor dots every 16 px
            if x == 0 or y == 0:
                r, g, b = 0.012, 0.16, 0.22
            elif x % 16 == 0 and y % 16 == 0:
                r, g, b = 0.06, 0.20, 0.26
            elif (x % 16 == 8) and (y % 16 == 8):
                r, g, b = 0.045, 0.10, 0.14
            row[x * 4 + 0] = _u8(r)
            row[x * 4 + 1] = _u8(g)
            row[x * 4 + 2] = _u8(b)
            row[x * 4 + 3] = 255
    save_rgba_png(out_path(name), size, size, rows)
    print("  sprite ->", name, f"{size}x{size} (tiling)")


def write_contact_sheet(path):
    """Compose the sprite set on a dark sheet so the art can be eyeballed."""
    names = ["player.png", "enemy_chaser.png", "enemy_brute.png",
             "enemy_spitter.png", "bullet_player.png", "bullet_enemy.png",
             "pickup_health.png", "pickup_overdrive.png", "crosshair.png",
             "particle.png", "flash.png"]
    cell = 160
    cols = 4
    rows_n = (len(names) + cols - 1) // cols
    sheet = [bytearray([12, 12, 18, 255] * (cell * cols)) for _ in range(cell * rows_n)]
    for i, name in enumerate(names):
        src = read_png(out_path(name))
        sw, sh, pixels = src
        ox = (i % cols) * cell + (cell - sw) // 2
        oy = (i // cols) * cell + (cell - sh) // 2
        for y in range(sh):
            for x in range(sw):
                si = (y * sw + x) * 4
                a = pixels[si + 3]
                if a == 0:
                    continue
                di = (ox + x) * 4
                row = sheet[oy + y]
                for k in range(3):
                    row[di + k] = min(255, row[di + k] + pixels[si + k] * a // 255)
    save_rgba_png(path, cell * cols, cell * rows_n, sheet)
    print("  preview ->", path)


def read_png(path):
    """Minimal reader for the RGBA PNGs we write ourselves."""
    with open(path, "rb") as fh:
        data = fh.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos = 8
    width = height = 0
    idat = b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if tag == b"IHDR":
            width, height = struct.unpack(">II", payload[:8])
        elif tag == b"IDAT":
            idat += payload
    raw = zlib.decompress(idat)
    pixels = bytearray(width * height * 4)
    stride = width * 4
    for y in range(height):
        src = y * (stride + 1) + 1
        pixels[y * stride:(y + 1) * stride] = raw[src:src + stride]
    return width, height, pixels


if __name__ == "__main__":
    main()
