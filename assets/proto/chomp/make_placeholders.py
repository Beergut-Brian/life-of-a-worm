#!/usr/bin/env python3
"""Placeholder SFX for the planet-chomp prototype, synthesised from sine waves and noise.
Run from the repo root: python3 assets/proto/chomp/make_placeholders.py
Stdlib only; deterministic (fixed random seed)."""
import math, random, struct, wave, os

RATE = 22050
OUT = os.path.dirname(os.path.abspath(__file__))
rnd = random.Random(4)


def write(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        peak = max(1e-6, max(abs(s) for s in samples))
        gain = 0.9 / peak
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))


def env(i, n, attack=0.01, release=0.3):
    t = i / RATE; d = n / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (d - t) / (release * d)) if release > 0 else 1.0
    return max(0.0, a * r)


def sweep(dur, f0, f1, noise=0.0, wob=0.0, wobf=0.0, release=0.3, shape=1.0):
    n = int(dur * RATE); out = []; ph = 0.0; lp = 0.0
    for i in range(n):
        k = i / n
        f = f0 + (f1 - f0) * (k ** shape)
        f *= 1.0 + wob * math.sin(2 * math.pi * wobf * i / RATE)
        ph += 2 * math.pi * f / RATE
        lp += 0.3 * (rnd.uniform(-1, 1) - lp)
        out.append((math.sin(ph) * (1 - noise) + lp * noise) * env(i, n, release=release))
    return out


def crunch(dur=0.22):
    n = int(dur * RATE); out = []; lp = 0.0
    for i in range(n):
        lp += 0.5 * (rnd.uniform(-1, 1) - lp)
        grit = 1.0 if (i // 300) % 2 == 0 else 0.4
        out.append(lp * grit * env(i, n, attack=0.002, release=0.6) + 0.5 * math.sin(2 * math.pi * 90 * i / RATE) * env(i, n, release=0.8))
    return out


def silence(dur):
    return [0.0] * int(dur * RATE)


write("chomp_bite", crunch())
# planet_gone: huge gulp, silence, tiny burp (GAME.md audio table). The burp starts at 2.2 s.
gulp = sweep(0.9, 140, 38, noise=0.35, wob=0.25, wobf=7, release=0.5, shape=0.6)
burp = sweep(0.32, 260, 170, noise=0.15, wob=0.3, wobf=28, release=0.5)
write("planet_gone", gulp + silence(2.2 - 0.9) + burp)
write("confirm_hold", sweep(2.0, 220, 660, release=0.05, shape=1.2))
write("confirm_cancel", sweep(0.28, 400, 180, release=0.6))
write("confirm_yes", sweep(0.12, 660, 660, release=0.4) + sweep(0.3, 990, 990, release=0.7))
write("jar_clink", [a + b for a, b in zip(sweep(0.5, 2400, 2380, release=0.95), sweep(0.5, 3610, 3600, release=0.98))])
write("space_bite", crunch(0.3) + sweep(0.25, 180, 70, noise=0.2, release=0.6))
write("space_bump", sweep(0.4, 300, 120, wob=0.35, wobf=18, release=0.7))
print("ok")
