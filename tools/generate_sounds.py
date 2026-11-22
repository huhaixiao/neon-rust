#!/usr/bin/env python3
"""Neon Rust - procedural SFX generator (standard library only).

Synthesises the whole audio bed (shoot / hit / death / hurt / dash / pickup /
wave chime / game over) as 44.1 kHz mono 16-bit WAV files that Godot imports
natively. No samples are downloaded, everything is maths.

Usage:
    python3 tools/generate_sounds.py
"""

import math
import os
import random
import struct
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "modules", "global", "assets", "audio", "sfx"))
SR = 44100


def write_wav(name, samples, gain=1.0):
    path = os.path.join(OUT_DIR, name)
    frames = bytearray()
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = min(1.0, 0.98 / peak) * gain
    for s in samples:
        v = max(-1.0, min(1.0, s * norm))
        frames += struct.pack("<h", int(v * 32767))
    with wave.open(path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(bytes(frames))
    print("  sfx ->", name, f"{len(samples) / SR:.2f}s")


def env_exp(t, tau):
    return math.exp(-t / tau)


def sweep(t, f0, f1, dur, curve=1.0):
    """frequency sweep integrated into phase"""
    k = (f1 - f0) / max(dur, 1e-6)
    return math.sin(2 * math.pi * (f0 * t + 0.5 * k * t * t))


def noise():
    return random.uniform(-1.0, 1.0)


def lowpass(samples, alpha):
    out = []
    prev = 0.0
    for s in samples:
        prev += alpha * (s - prev)
        out.append(prev)
    return out


def make_shoot():
    dur = 0.105
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        body = sweep(t, 1500, 380, dur) * env_exp(t, 0.022)
        grit = noise() * env_exp(t, 0.010) * 0.35
        out.append(body * 0.9 + grit)
    return out


def make_hit():
    dur = 0.06
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        out.append((noise() * 0.9 + math.sin(2 * math.pi * 900 * t) * 0.4) * env_exp(t, 0.011))
    return out


def make_die():
    dur = 0.30
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        tone = sweep(t, 520, 70, dur) * env_exp(t, 0.10) * 0.8
        grit = noise() * env_exp(t, 0.055) * 0.6
        out.append(tone + grit)
    return lowpass(out, 0.55)


def make_player_hit():
    dur = 0.24
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        thump = math.sin(2 * math.pi * 118 * t) * env_exp(t, 0.055)
        grit = noise() * env_exp(t, 0.035) * 0.45
        out.append(thump + grit)
    return lowpass(out, 0.35)


def make_dash():
    dur = 0.22
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        rise = math.sin(math.pi * min(1.0, t / 0.09)) if t < 0.09 else env_exp(t - 0.09, 0.05)
        out.append(noise() * rise * 0.8)
    return lowpass(out, 0.18)


def _bell(t, start, freq, tau=0.16):
    if t < start:
        return 0.0
    return math.sin(2 * math.pi * freq * (t - start)) * env_exp(t - start, tau)


def make_pickup():
    dur = 0.30
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        out.append(_bell(t, 0.00, 660.0, 0.10) * 0.7
                   + _bell(t, 0.055, 990.0, 0.10)
                   + _bell(t, 0.105, 1320.0, 0.11))
    return out


def make_wave():
    dur = 0.72
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        out.append(_bell(t, 0.00, 523.25, 0.22) * 0.6
                   + _bell(t, 0.10, 698.66, 0.20) * 0.6
                   + _bell(t, 0.20, 1046.5, 0.26) * 0.7)
    return lowpass(out, 0.85)


def make_gameover():
    dur = 1.0
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        wobble = math.sin(2 * math.pi * 7.0 * t) * 0.04
        out.append(sweep(t, 380 + wobble * 100, 62, dur) * env_exp(t, 0.32)
                   + noise() * env_exp(t, 0.16) * 0.2)
    return lowpass(out, 0.5)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    random.seed(7)
    print("Generating sfx in", OUT_DIR)
    write_wav("shoot.wav", make_shoot())
    write_wav("hit.wav", make_hit(), 0.75)
    write_wav("die.wav", make_die())
    write_wav("player_hit.wav", make_player_hit())
    write_wav("dash.wav", make_dash(), 0.7)
    write_wav("pickup.wav", make_pickup(), 0.9)
    write_wav("wave.wav", make_wave(), 0.8)
    write_wav("gameover.wav", make_gameover(), 0.9)
    print("done.")


if __name__ == "__main__":
    main()
