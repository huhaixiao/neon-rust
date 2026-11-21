#!/usr/bin/env python3
"""Print pixel values from a PNG without any third-party library.

Usage:
    python3 tools/png_sample.py <png> x,y x,y ...
"""

import struct
import sys
import zlib


def load(path):
    data = open(path, "rb").read()
    pos = 8
    idat = b""
    channels = 4
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if tag == b"IHDR":
            width, height, _depth, colour_type = struct.unpack(">IIBB", chunk[:10])
            channels = 4 if colour_type == 6 else 3
        elif tag == b"IDAT":
            idat += chunk
        elif tag == b"IEND":
            break
    raw = zlib.decompress(idat)
    stride = width * channels
    prev = bytearray(stride)
    rows = []
    p = 0
    for _ in range(height):
        mode = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if mode == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 255
        elif mode == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif mode == 3:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + (left + prev[i]) // 2) & 255
        elif mode == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 255
        rows.append(line)
        prev = line
    return width, height, channels, rows


def main():
    path = sys.argv[1]
    width, height, channels, rows = load(path)
    print(f"{path} {width}x{height} channels={channels}")
    for arg in sys.argv[2:]:
        x, y = (int(v) for v in arg.split(","))
        x = max(0, min(width - 1, x))
        y = max(0, min(height - 1, y))
        print(f"  ({x},{y}) = {tuple(rows[y][x * channels:x * channels + 3])}")


if __name__ == "__main__":
    main()
