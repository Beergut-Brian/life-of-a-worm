#!/usr/bin/env python3
"""Placeholder SFX for the polar-world prototype, synthesised from sine waves and noise.
Run from the repo root: python3 assets/proto/world/make_placeholders.py
Stdlib only; deterministic (fixed random seed)."""
import math, random, struct, wave, os

RATE = 22050
OUT = os.path.dirname(os.path.abspath(__file__))
rnd = random.Random(11)


def write(name, samples):
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        peak = max(1e-6, max(abs(s) for s in samples))
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * 0.85 / peak)) * 32767)) for s in samples))


def env(i, n, attack=0.005, release=0.5):
    t = i / RATE; d = n / RATE
    a = min(1.0, t / attack); r = min(1.0, (d - t) / (release * d))
    return max(0.0, a * r)


def tone(dur, f0, f1, noise=0.0, release=0.5):
    n = int(dur * RATE); out = []; ph = 0.0; lp = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * i / n
        ph += 2 * math.pi * f / RATE
        lp += 0.4 * (rnd.uniform(-1, 1) - lp)
        out.append((math.sin(ph) * (1 - noise) + lp * noise) * env(i, n, release=release))
    return out


write("world_munch", tone(0.09, 220, 120, noise=0.7))          # one mouthful of dirt
write("world_seed", tone(0.12, 500, 900) + tone(0.10, 900, 700))  # seed drops in, ding
write("world_sprout", tone(0.14, 600, 1400, release=0.7))       # a garden cell pops up
write("world_regrow", tone(0.18, 300, 520, noise=0.2, release=0.8))  # soft fill-in
write("world_blocked", tone(0.15, 160, 110, noise=0.3))          # too hard to bite: bonk
