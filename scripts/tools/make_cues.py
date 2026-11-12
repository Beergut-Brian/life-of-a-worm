#!/usr/bin/env python3
"""Regenerate every Life of a Worm sound effect and ambience loop. Standard library + ffmpeg only.

    python3 scripts/tools/make_cues.py                     # everything (parallel)
    python3 scripts/tools/make_cues.py chomp_1_1 stage_up  # just these files
    python3 scripts/tools/make_cues.py --list              # stems, kinds and trims
    python3 scripts/tools/make_cues.py --preview handoff/previews/worm_cues_preview.ogg

The primitives, the loudness pass and the layout are copied from the-hill's
assets/audio/tools/make_cues.py (itself from spaceballs and openjar-launcher). Every sound is
synthesised here, seeded per file ("openjar-life-of-a-worm:<stem>") so the output is
reproducible. WAV sources go to .scratch/cue-wav/ and never into git. Each file is Ogg Vorbis q5,
44.1 kHz mono in assets/audio/sfx/ (Audio.play and Audio.loop_player only look for .ogg):
  - sfx: -16 LUFS integrated, the sibling games' target (short cues measured looped 10x, so "as
    loud as the rest while it sounds"), with a per-file trim (frequent cues sit lower).
  - loop (tunnel, space_drift, the ring beds amb_*): seamless (every oscillator on a whole number
    of cycles, every filter circular, every event wrapped), measured whole, trimmed under the SFX.
  - everything: true peak at or below -1 dBTP (checked after encoding).
Kid rules, checked at the end of a full build: stage_up is the loudest cue in the game (nothing
measures louder); nothing scary, no pain sounds, no minor stingers. Key: C major pentatonic.
Nothing above 9.5 kHz in the synths.
"""
import argparse
import math
import os
import random
import re
import struct
import subprocess
import sys
import wave
from multiprocessing import Pool

SR = 44100
TAU = 2.0 * math.pi
PARTIAL_CEILING = 9500.0

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUDIO_DIR = os.path.join(REPO, "assets", "audio")
SFX_TARGET = -16.0
TP_CEILING = -1.0
SHORT_CUE = 0.6
SEED = "openjar-life-of-a-worm:"

# ---------------------------------------------------------------- primitives

def midi(n):
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


def silence(sec):
    return [0.0] * int(round(sec * SR))


def mix(dst, src, at=0.0, gain=1.0, wrap=False):
    """Add src into dst at `at` seconds. wrap=True folds overhang back to the start (loops)."""
    o = int(round(at * SR))
    n = len(dst)
    if wrap:
        for i, s in enumerate(src):
            dst[(o + i) % n] += s * gain
    else:
        for i in range(max(0, -o), min(len(src), n - o)):
            dst[o + i] += src[i] * gain
    return dst


def osc(dur, freq, partials=((1, 1.0, 1.0),), decay=None, attack=0.002, amp=None):
    """Additive oscillator. freq: Hz or f(t). partials: (ratio, gain, decay_scale); partial k
    decays as exp(-t * decay_scale / decay). amp: optional overall envelope f(t).
    Partials above PARTIAL_CEILING are skipped."""
    n = int(dur * SR)
    out = [0.0] * n
    ph = [0.0] * len(partials)
    fixed = not callable(freq)
    for i in range(n):
        t = i / SR
        f = freq if fixed else freq(t)
        s = 0.0
        for k, (r, g, ds) in enumerate(partials):
            fk = f * r
            ph[k] += TAU * fk / SR
            if fk < PARTIAL_CEILING:
                s += (g if decay is None else g * math.exp(-t * ds / decay)) * math.sin(ph[k])
        a = min(1.0, t / attack) if attack > 0 else 1.0
        if amp is not None:
            a *= amp(t)
        out[i] = s * a
    return fades(out, 0.0, 0.003)   # never stop a ringing partial dead


def noise(sec, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(sec * SR))]


def envelope(x, fn):
    return [v * fn(i / SR) for i, v in enumerate(x)]


def svf(x, fc, q=0.707, mode="low", circular=False):
    """TPT state-variable filter. fc: Hz or f(t). circular: run twice so the state at the
    start equals the state at the end (seamless loops)."""
    k = 1.0 / q
    ic1 = ic2 = 0.0
    out = [0.0] * len(x)
    moving = callable(fc)

    def coeffs(f):
        g = math.tan(math.pi * min(f, SR * 0.45) / SR)
        a1 = 1.0 / (1.0 + g * (g + k))
        return a1, g * a1, g * g * a1

    a1, a2, a3 = coeffs(fc) if not moving else (0, 0, 0)
    for _ in range(2 if circular else 1):
        for i, v in enumerate(x):
            if moving:
                a1, a2, a3 = coeffs(fc(i / SR))
            v3 = v - ic2
            v1 = a1 * ic1 + a2 * v3
            v2 = ic2 + a2 * ic1 + a3 * v3
            ic1 = 2.0 * v1 - ic1
            ic2 = 2.0 * v2 - ic2
            out[i] = v2 if mode == "low" else (k * v1 if mode == "band" else v - k * v1 - v2)
    return out


def soft(x, fc, circular=False):
    """4-pole low-pass (two cascaded SVFs): keeps noise sources out of the top octave."""
    return svf(svf(x, fc, circular=circular), fc, circular=circular)


def dc_block(x, circular=False):
    r = 0.9972  # ~20 Hz
    x1 = y1 = 0.0
    out = [0.0] * len(x)
    for _ in range(2 if circular else 1):
        for i, v in enumerate(x):
            y1 = v - x1 + r * y1
            x1 = v
            out[i] = y1
    return out


def fades(x, fade_in=0.001, fade_out=0.02):
    n = len(x)
    fi, fo = max(1, int(fade_in * SR)), max(1, int(fade_out * SR))
    for i in range(min(fi, n)):
        x[i] *= i / fi
    for i in range(min(fo, n)):
        x[n - 1 - i] *= (i / fo) ** 2
    return x


def limit(x, threshold, lookahead=0.002, release=0.06):
    """Lookahead peak limiter: shaves transients so loudness can rise under the peak ceiling."""
    n = len(x)
    la = int(lookahead * SR)
    need = [min(1.0, threshold / abs(v)) if v else 1.0 for v in x]
    gain = [1.0] * n
    for i in range(n):   # n is small (SFX only), so a plain window minimum is fine
        gain[i] = min(need[max(0, i - la):i + la + 1])
    rel = math.exp(-1.0 / (release * SR))
    g = 1.0
    for i in range(n):
        g = gain[i] if gain[i] < g else gain[i] + (g - gain[i]) * rel
        gain[i] = g
    return [v * gain[i] for i, v in enumerate(x)]


def peak_normalise(x, peak=0.5):
    m = max(abs(v) for v in x) or 1.0
    return [v * peak / m for v in x]


# ---------------------------------------------------------------- instruments

MARIMBA = ((1, 1.0, 1.0), (3.98, 0.30, 3.0), (9.85, 0.06, 6.0))
XYLO = ((1, 1.0, 1.0), (3.0, 0.28, 2.5), (6.1, 0.07, 5.0))
BELL = ((1, 1.0, 1.0), (2.76, 0.40, 1.8), (5.40, 0.12, 3.0), (8.93, 0.04, 4.0))
WOOD = ((1, 1.0, 1.0), (2.57, 0.35, 1.6), (4.80, 0.12, 2.6))


def mallet(rng, fc=3000.0, sec=0.005, gain=0.25):
    n = int(sec * SR)
    x = [rng.uniform(-1, 1) * (1 - i / n) ** 2 for i in range(n)]
    return [v * gain for v in svf(x, fc)]


def struck(f, decay, rng, partials=MARIMBA, vel=1.0, click=0.2):
    """Marimba / xylophone / bell note: decaying partials plus a mallet tick."""
    x = osc(min(decay * 7.0, 3.0), f, partials, decay=decay, attack=0.0015)
    mix(x, mallet(rng, fc=min(4000.0, f * 4.0)), 0.0, click)
    return [v * vel for v in x]


def formant(x):
    return (0.25 + math.exp(-((x - 650) / 260) ** 2) + 0.6 * math.exp(-((x - 1700) / 420) ** 2)
            + 0.25 * math.exp(-((x - 2800) / 500) ** 2))


def kazoo(f, sec, vib_rate=5.5, vib_depth=0.012, attack=0.015, release=0.06):
    """Buzzy, voice-like toy horn: band-limited saw shaped by fixed formants, with vibrato."""
    parts = []
    n = 1
    while n * f < PARTIAL_CEILING:
        parts.append((n, formant(n * f) / n, 0.0))
        n += 1
    total = sec

    def amp(t):
        return min(1.0, (total - t) / release) if t > total - release else 1.0

    def freq(t):
        return f * (1.0 + vib_depth * min(1.0, t / 0.12) * math.sin(TAU * vib_rate * t))

    return osc(sec, freq, tuple(parts), attack=attack, amp=amp)


def chirp(f0, f1, sec, partials=((1, 1.0, 0.0),), attack=0.004):
    """Pitch glide f0 -> f1 (exponential) with a rounded envelope."""
    return osc(sec, lambda t: f0 * (f1 / f0) ** min(1.0, t / sec), partials, attack=attack,
               amp=lambda t: math.sin(math.pi * min(1.0, t / sec)) ** 0.6)


def sparkle(rng, count, start, end, gain=0.12, notes=(96, 98, 100, 103, 105)):
    """A few quiet glockenspiel pings from a high C-major pentatonic."""
    out = silence(end + 0.3)
    for _ in range(count):
        mix(out, struck(midi(rng.choice(notes)), 0.05, rng, BELL, click=0.05),
            rng.uniform(start, end), gain * rng.uniform(0.6, 1.0))
    return out


def chord(notes, decay, rng, partials=MARIMBA, vel=1.0):
    out = silence(min(decay * 7.0, 3.0) + 0.01)
    for n in notes:
        mix(out, struck(midi(n), decay, rng, partials, click=0.12), 0.0, vel / len(notes) ** 0.5)
    return out

# ---------------------------------------------------------------- spaceballs primitives

# Cartoon formants (F1, F2, F3), a little brighter than an adult voice so it reads as a Jarling.
VOWELS = {"a": (820, 1250, 2650), "e": (520, 1900, 2650), "i": (330, 2350, 3050),
          "o": (520, 880, 2500), "u": (360, 760, 2400), "l": (320, 1100, 2600)}
METAL = ((1, 1.0, 1.0), (2.41, 0.6, 1.4), (3.93, 0.4, 2.0), (5.33, 0.25, 3.0), (6.9, 0.12, 4.0))


def saw(freq, sec):
    """PolyBLEP sawtooth (cheap, nearly alias-free); freq: Hz or f(t)."""
    n = int(sec * SR)
    out = [0.0] * n
    ph = 0.0
    fixed = not callable(freq)
    for i in range(n):
        dt = (freq if fixed else freq(i / SR)) / SR
        ph += dt
        if ph >= 1.0:
            ph -= 1.0
        v = 2.0 * ph - 1.0
        if ph < dt:
            x = ph / dt
            v -= x + x - x * x - 1.0
        elif ph > 1.0 - dt:
            x = (ph - 1.0) / dt
            v -= x * x + x + x + 1.0
        out[i] = v
    return out


def ar(total, attack=0.01, release=0.05):
    """Attack / release envelope as f(t)."""
    def f(t):
        a = min(1.0, t / attack) if attack > 0 else 1.0
        return a * (max(0.0, (total - t) / release) if t > total - release else 1.0)
    return f


def voice(f0, sec, vowel="a", amp=None, rng=None, breath=0.04, scale=1.0, rough=0.0,
          gains=(1.0, 0.55, 0.22), qs=(4.0, 7.0, 9.0)):
    """Formant voice: a saw through three band-pass filters. vowel: key of VOWELS, a tuple, or
    f(t) -> (F1, F2, F3) for glides (\"mi-a-ow\"). rough: amplitude flutter for croaks."""
    src = saw(f0, sec)
    if rng is not None and breath:
        src = [v + breath * rng.uniform(-1, 1) for v in src]
    if rough:
        src = [v * (1.0 - rough + rough * abs(math.sin(math.pi * 38.0 * i / SR)))
               for i, v in enumerate(src)]
    out = [0.0] * len(src)
    for k in range(3):
        if callable(vowel):
            fc = (lambda t, k=k: vowel(t)[k] * scale)
        else:
            fc = (VOWELS[vowel] if isinstance(vowel, str) else vowel)[k] * scale
        mix(out, svf(src, fc, qs[k], "band"), 0.0, gains[k])
    env = amp or ar(sec)
    return fades([v * env(i / SR) for i, v in enumerate(out)], 0.002, 0.01)


def glide(a, b, t0, t1):
    """Vowel glide a -> b between t0 and t1 as f(t) -> formants."""
    va, vb = VOWELS[a], VOWELS[b]

    def f(t):
        u = min(1.0, max(0.0, (t - t0) / (t1 - t0)))
        return tuple(x + (y - x) * u for x, y in zip(va, vb))
    return f


def burst(rng, sec, fc, q=1.0, decay=0.01, mode="band"):
    """Filtered noise hit with an exponential tail: cracks, slaps, claps, ticks."""
    x = svf(noise(sec, rng), fc, q, mode)
    return fades([v * math.exp(-i / SR / decay) for i, v in enumerate(x)], 0.0005, 0.004)


def thump(f0, f1, sec, decay):
    """Sine with a falling pitch: the body of every kick and landing."""
    return osc(sec, lambda t: f1 + (f0 - f1) * math.exp(-t / (decay * 0.6)), decay=decay,
               attack=0.001)


def rumble(rng, sec, fc, decay, attack=0.003):
    x = soft(noise(sec, rng), fc)
    return fades([v * min(1.0, i / SR / attack) * math.exp(-i / SR / decay)
                  for i, v in enumerate(x)], 0.0, 0.05)


def whistle(f0, f1, sec, rng, curve=1.3, vib=0.018, breath=0.06):
    """Slide whistle: a near-sine rising f0 -> f1 with vibrato and a little breath."""
    def freq(t):
        u = min(1.0, t / sec) ** curve
        return f0 * (f1 / f0) ** u * (1.0 + vib * math.sin(TAU * 6.0 * t))
    x = osc(sec, freq, ((1, 1.0, 0.0), (2, 0.07, 0.0), (3, 0.02, 0.0)), attack=0.03,
            amp=lambda t: min(1.0, (sec - t) / 0.08) if t > sec - 0.08 else 1.0)
    air = svf(noise(sec, rng), (f0 + f1) * 0.6, 2.0, "band")
    return [v + breath * a for v, a in zip(x, air)]


def notes_seq(seq, rng, partials=MARIMBA, decay=0.12, vel=1.0):
    """[(midi_note, at_seconds), ...] of struck notes."""
    end = max(at for _, at in seq)
    out = silence(end + min(decay * 7.0, 3.0) + 0.02)
    for n, at in seq:
        mix(out, struck(midi(n), decay, rng, partials, click=0.12), at, vel)
    return out


def brass(f, sec, rng, wah=None, vib=0.0, scoop=0.0, bright=2200.0):
    """Toy trombone / fanfare horn: saw, brightness follows the envelope (wah: f(t) 0..1)."""
    def freq(t):
        s = 1.0 - scoop * math.exp(-t / 0.04)
        return f * s * (1.0 + vib * min(1.0, t / 0.4) * math.sin(TAU * 5.0 * t))
    src = saw(freq, sec)
    w = wah or (lambda t: 1.0)
    x = svf(src, lambda t: 250.0 + bright * w(t), 1.2)
    env = ar(sec, 0.02, 0.08)
    return [v * env(i / SR) for i, v in enumerate(x)]


def clap(rng):
    x = burst(rng, 0.06, rng.uniform(1100, 1700), 1.4, 0.008)
    mix(x, burst(rng, 0.06, rng.uniform(700, 900), 2.0, 0.012), 0.0, 0.4)
    return x
def at_len(x, sec):
    n = int(sec * SR)
    return (x + [0.0] * (n - len(x)))[:n]


def grains(rng, sec, count, fc_lo, fc_hi, dec_lo, dec_hi, gain=1.0, spread=1.0):
    """Many tiny noise bursts: crumbles, rattles, crunches, debris."""
    out = silence(sec + 0.1)
    for _ in range(count):
        t = (rng.random() ** spread) * sec * 0.8
        mix(out, burst(rng, 0.05, rng.uniform(fc_lo, fc_hi), 1.2, rng.uniform(dec_lo, dec_hi)),
            t, gain * rng.uniform(0.4, 1.0))
    return out


def echo(x, delay, fb, n=4):
    out = x + silence(delay * n)
    for k in range(1, n + 1):
        mix(out, x, delay * k, fb ** k)
    return out


# ================================================================ life of a worm
# C major pentatonic everywhere (C D E G A), so cues layered on each other never clash.

PENT_HI = (84, 86, 88, 91, 93, 96)      # C6 .. C7
PENT_MID = (72, 74, 76, 79, 81, 84)     # C5 .. C6


def worm_chirp(f0, f1, sec, rng, vowel=("u", "i"), scale=1.35):
    """The worms' voice: a tiny formant chirp, never a word. f0 -> f1 glide (Hz)."""
    return voice(lambda t: f0 * (f1 / f0) ** min(1.0, t / sec), sec, glide(vowel[0], vowel[1], 0.0, sec),
                 rng=rng, breath=0.03, scale=scale, amp=ar(sec, 0.012, sec * 0.5))


def shaker(rng, times, gain=0.5, fc=6500.0):
    """Tiny maracas: one bright noise shake per time."""
    out = silence(max(times) + 0.1)
    for t in times:
        g = gain * rng.uniform(0.7, 1.0)
        mix(out, burst(rng, 0.06, fc * rng.uniform(0.9, 1.1), 1.6, 0.018), t, g)
        mix(out, burst(rng, 0.03, fc * 0.6, 2.0, 0.006), t + 0.012, g * 0.4)
    return out


def crunch(rng, sec, count, lo, hi, body=(300, 140), body_sec=0.08, gain=1.0):
    """Bite: a soft body thump and a scatter of crumbs."""
    x = silence(sec + 0.15)
    mix(x, thump(body[0], body[1], body_sec + 0.05, body_sec), 0.0, 0.8 * gain)
    mix(x, grains(rng, sec, count, lo, hi, 0.003, 0.012, spread=0.8), 0.0, 0.9 * gain)
    return x


def gulp_tone(f0, f1, sec, rng, rough=0.0, scale=1.0):
    """Cartoon gulp: a round 'o' that drops in pitch (the swallow) then bloops up a little."""
    def f(t):
        u = t / sec
        return f0 * (f1 / f0) ** min(1.0, u / 0.7) * (1.0 + 0.25 * max(0.0, u - 0.7) / 0.3)
    return voice(f, sec, glide("u", "o", 0.0, sec * 0.5), rng=rng, breath=0.02, rough=rough,
                 scale=scale, amp=ar(sec, 0.02, sec * 0.4))


def earned(rng, at=0.0):
    """The little 'you got it' bell every trait ends on (C6 then G6)."""
    return notes_seq([(84, at), (91, at + 0.09)], rng, BELL, 0.12, 0.55)


def whole(f, sec):
    """f rounded to a whole number of cycles in sec (seamless loops)."""
    return max(1, round(f * sec)) / sec


def loop_tone(sec, f, partials=((1, 1.0),), lfo=None):
    """Sustained tone that loops cleanly: every partial on whole cycles, no fades.
    lfo: (rate Hz, depth) amplitude wobble, rate also rounded to whole cycles."""
    n = int(round(sec * SR))
    out = [0.0] * n
    for r, g in partials:
        fk = whole(f * r, sec)
        if fk >= PARTIAL_CEILING:
            continue
        w = TAU * fk / SR
        for i in range(n):
            out[i] += g * math.sin(w * i)
    if lfo:
        rate, depth = lfo
        lr = whole(rate, sec)
        out = [v * (1.0 - depth + depth * 0.5 * (1 + math.sin(TAU * lr * i / SR))) for i, v in enumerate(out)]
    return out


def loop_noise(sec, rng, fc, mode="low", q=0.707):
    n = int(round(sec * SR))
    x = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    if mode == "low":
        return soft(x, fc, circular=True)
    return svf(x, fc, q, mode, circular=True)


def lfo_env(x, sec, rate, depth, phase=0.0):
    lr = whole(rate, sec)
    return [v * (1.0 - depth + depth * 0.5 * (1 + math.sin(TAU * lr * i / SR + phase)))
            for i, v in enumerate(x)]


def wings(rng, sec, rate=22.0, fc=700.0, gain=0.5):
    """Little wing flutter: a train of soft low noise puffs."""
    out = silence(sec + 0.05)
    t = 0.0
    while t < sec:
        mix(out, burst(rng, 0.03, fc * rng.uniform(0.8, 1.2), 1.2, 0.008), t,
            gain * math.sin(math.pi * t / sec) ** 0.5)
        t += 1.0 / rate * rng.uniform(0.85, 1.15)
    return out


def buzz(f, sec, rng, vib=0.04, fc=900.0):
    """Ladybird wing hum: a soft saw low-passed, with a flutter."""
    src = saw(lambda t: f * (1 + vib * math.sin(TAU * 31 * t)), sec)
    x = svf(src, fc, 1.0)
    env = ar(sec, 0.04, 0.12)
    return [v * env(i / SR) for i, v in enumerate(x)]


def paper(rng, sec=0.18, fc=3200.0, up=True):
    """Page swish: band noise sweeping across the page."""
    f0, f1 = (fc * 0.5, fc * 1.3) if up else (fc * 1.3, fc * 0.5)
    x = svf(noise(sec, rng), lambda t: f0 + (f1 - f0) * t / sec, 1.4, "band")
    return envelope(x, lambda t: math.sin(math.pi * min(1.0, t / sec)) ** 1.5)


def ratchet(rng, sec, n, f0, f1, partials=WOOD, accel=1.6):
    """Wind-up clicks that speed up and rise in pitch."""
    out = silence(sec + 0.2)
    for k in range(n):
        u = (k / max(1, n - 1))
        t = sec * (1 - (1 - u) ** accel)
        mix(out, struck(f0 * (f1 / f0) ** u, 0.02, rng, partials, click=0.5), t, 0.5)
    return out


# ---------------------------------------------------------------- the chomp is the game

def chomp_crunch(rng, pitch=1.0):          # chomp_1: tiny food, a crisp little crunch
    x = crunch(rng, 0.10, 12, 2200 * pitch, 5200 * pitch, (420 * pitch, 200 * pitch), 0.04, 0.9)
    return at_len(x, 0.22)


def chomp_munch(rng, pitch=1.0):           # chomp_2: smaller food, munch-munch
    x = silence(0.45)
    for k, t in enumerate((0.0, 0.14)):
        b = crunch(rng, 0.09, 9, 900 * pitch, 2600 * pitch, (260 * pitch, 120 * pitch), 0.07)
        mix(b, rumble(rng, 0.12, 600 * pitch, 0.05), 0.0, 0.5)
        mix(x, b, t, 1.0 if k == 0 else 0.8)
    return x


def chomp_big_crunch(rng, pitch=1.0):      # chomp_3: your size, a big CRUNCH
    x = silence(0.6)
    mix(x, thump(170 * pitch, 60 * pitch, 0.3, 0.12), 0.0, 1.0)
    mix(x, burst(rng, 0.08, 1800 * pitch, 0.9, 0.02), 0.0, 0.8)
    mix(x, grains(rng, 0.32, 34, 500 * pitch, 4200 * pitch, 0.004, 0.02, spread=0.7), 0.0, 1.0)
    mix(x, grains(rng, 0.2, 10, 300, 900, 0.01, 0.03), 0.12, 0.5)
    return x


def chomp_gulp(rng):                        # chomp_4: one stage bigger, a gulp
    x = silence(0.75)
    mix(x, crunch(rng, 0.08, 8, 700, 2000, (220, 100), 0.07), 0.0, 0.7)
    mix(x, gulp_tone(420, 150, 0.32, rng, scale=0.9), 0.12, 1.0)
    mix(x, thump(160, 70, 0.25, 0.1), 0.14, 0.7)
    mix(x, chirp(500, 900, 0.07), 0.48, 0.25)                    # tiny bloop after
    return x


def chomp_boom(rng):                        # chomp_5: way bigger, the planet-swallowing boom
    x = silence(1.6)
    mix(x, crunch(rng, 0.12, 14, 400, 1800, (200, 80), 0.1), 0.0, 0.6)
    mix(x, thump(110, 34, 1.2, 0.45), 0.1, 1.2)
    mix(x, rumble(rng, 1.3, 220, 0.4, attack=0.01), 0.1, 0.7)
    mix(x, gulp_tone(260, 85, 0.5, rng, rough=0.15, scale=0.75), 0.1, 0.9)
    mix(x, sparkle(rng, 4, 0.8, 1.2, 0.5), 0.0, 0.5)              # stars: it was funny
    return x


# ---------------------------------------------------------------- the worm's moves

def tunnel_loop(rng):
    """Soft scrunch through dirt: low crumbly bed, 8 gentle pushes, crumbs wrapped round."""
    sec = 2.0
    bed = loop_noise(sec, rng, 700)
    bed = lfo_env(bed, sec, 4.0, 0.55)
    crumbs = [0.0] * len(bed)
    for _ in range(46):
        mix(crumbs, burst(rng, 0.05, rng.uniform(500, 1600), 1.2, rng.uniform(0.006, 0.016)),
            rng.uniform(0, sec), rng.uniform(0.15, 0.45), wrap=True)
    return [a * 1.0 + b * 0.6 for a, b in zip(bed, crumbs)]


def burst_zip(rng):
    x = whistle(500, 2300, 0.2, rng, curve=0.8, vib=0.0, breath=0.08)
    air = svf(noise(0.3, rng), lambda t: 700 + 5000 * min(1.0, t / 0.2), 1.6, "band")
    mix(x, envelope(air, lambda t: math.sin(math.pi * min(1.0, t / 0.3))), 0.0, 0.6)
    return at_len(x, 0.36)


def wiggle(rng):
    x = silence(0.6)
    mix(x, worm_chirp(700, 1050, 0.13, rng), 0.0, 1.0)
    mix(x, worm_chirp(950, 780, 0.12, rng, ("i", "u")), 0.15, 0.8)
    mix(x, shaker(rng, (0.02, 0.09, 0.16, 0.25, 0.3, 0.37), 0.45), 0.0, 1.0)
    return x


def stage_up(rng):
    """The biggest moment: a swell, a bell chord, an arpeggio and the worm's happiest chirp."""
    x = silence(2.6)
    sw = svf(noise(1.0, rng), lambda t: 300 + 3200 * t, 0.9, "band")
    mix(x, envelope(sw, lambda t: (t / 1.0) ** 2), 0.0, 0.45)
    mix(x, osc(1.0, lambda t: 130.8 * (1 + t), ((1, 1.0, 0.0), (2, 0.3, 0.0)),
               amp=lambda t: (t / 1.0) ** 1.5), 0.0, 0.35)
    mix(x, notes_seq([(60, 0.0), (64, 0.18), (67, 0.36), (72, 0.54), (76, 0.68), (79, 0.82)],
                     rng, MARIMBA, 0.14), 0.0, 0.55)
    mix(x, thump(130, 60, 0.4, 0.18), 1.0, 0.8)
    mix(x, chord((72, 76, 79, 84), 0.55, rng, BELL), 1.0, 1.0)
    mix(x, brass(261.6, 0.9, rng, vib=0.01, bright=1800), 1.0, 0.18)
    mix(x, brass(392.0, 0.9, rng, vib=0.01, bright=1800), 1.0, 0.14)
    mix(x, sparkle(rng, 10, 1.05, 2.0, 0.9, PENT_HI), 0.0, 0.5)
    mix(x, worm_chirp(800, 1500, 0.22, rng), 1.35, 0.9)
    mix(x, worm_chirp(1300, 1700, 0.12, rng, ("i", "i")), 1.6, 0.6)
    return x


def threat_near(rng):
    """A bigger bug is close: one second of low, soft rumble and a curious 'bom... bom?'."""
    x = rumble(rng, 1.0, 150, 0.6, attack=0.25)
    x = envelope(x, lambda t: math.sin(math.pi * min(1.0, t / 1.0)))
    mix(x, brass(65.4, 0.32, rng, bright=500), 0.15, 0.55)     # C2
    mix(x, brass(98.0, 0.42, rng, bright=600), 0.55, 0.5)      # G2: rising, a question, not a threat
    return at_len(x, 1.05)


def eaten(rng):
    """Gulped by a bug: cartoon gulp, pop out the other end, dizzy stars. No pain, ever."""
    x = silence(1.7)
    mix(x, gulp_tone(380, 120, 0.34, rng, scale=0.9), 0.0, 1.0)
    mix(x, thump(140, 60, 0.2, 0.08), 0.05, 0.5)
    mix(x, pop(rng, 650), 0.42, 0.9)
    for k in range(8):                                          # stars going round the head
        n = (88, 91, 93, 91)[k % 4]
        mix(x, struck(midi(n), 0.08, rng, BELL, click=0.05), 0.56 + k * 0.11, 0.38 * (1 - k / 10))
    mix(x, osc(0.9, lambda t: 1046 * (1 + 0.06 * math.sin(TAU * 6 * t)), ((1, 1.0, 0.0),),
               amp=lambda t: 0.3 * (1 - t / 0.9)), 0.56, 0.15)
    return x


def now_i_eat_you(rng):
    """Your old threat is food now: a ta-ta-TAAA fanfare and a grin."""
    x = silence(1.5)
    for at, f, d in ((0.0, 392.0, 0.11), (0.13, 392.0, 0.11), (0.26, 523.3, 0.6)):
        mix(x, brass(f, d, rng, vib=0.012 if d > 0.3 else 0.0, scoop=0.04), at, 0.6)
        mix(x, brass(f * 1.26, d, rng, scoop=0.04), at, 0.3)    # a major third on top
    mix(x, chord((60, 64, 67, 72), 0.3, rng, MARIMBA), 0.26, 0.6)
    mix(x, burst(rng, 0.5, 5200, 0.7, 0.18), 0.26, 0.22)       # soft cymbal
    mix(x, worm_chirp(900, 1400, 0.16, rng), 0.95, 0.6)
    return x


def breakthrough(rng):
    """Crust broken at stage 4: a crumble, daylight, then birds scatter (flutter and tweets)."""
    x = silence(2.2)
    mix(x, rumble(rng, 0.9, 380, 0.28), 0.0, 0.8)
    mix(x, grains(rng, 0.9, 50, 300, 2200, 0.006, 0.03, spread=0.7), 0.0, 0.9)
    mix(x, thump(120, 50, 0.4, 0.14), 0.0, 0.6)
    for k in range(4):
        mix(x, wings(rng, 0.35, 24, rng.uniform(600, 900), 0.5), 0.45 + k * 0.12, 0.6)
    for k in range(7):
        f = rng.uniform(1900, 2600)
        t = 0.5 + k * 0.17 + rng.uniform(0, 0.05)
        mix(x, whistle(f, f * 1.35, 0.06, rng, vib=0.0, breath=0.02), t, 0.35)
        mix(x, whistle(f * 1.3, f * 1.05, 0.05, rng, vib=0.0, breath=0.02), t + 0.07, 0.3)
    mix(x, sparkle(rng, 3, 0.4, 0.7, 0.4, PENT_HI), 0.0, 0.5)
    return x


BURP_AT = 2.2   # scripts/chomp/planet_chomp.gd BURP_AT: the worm's burp animation fires here


def planet_gone(rng):
    """Stage 6 final chomp: a huge gulp, then real silence, then a tiny burp at exactly 2.2 s."""
    x = silence(2.65)
    g = silence(1.0)
    mix(g, thump(95, 30, 0.9, 0.32), 0.0, 1.2)
    mix(g, gulp_tone(240, 70, 0.6, rng, rough=0.2, scale=0.7), 0.0, 1.0)
    mix(g, rumble(rng, 0.9, 200, 0.3, attack=0.005), 0.0, 0.8)
    mix(g, grains(rng, 0.3, 14, 300, 1200, 0.01, 0.03), 0.0, 0.4)
    g = envelope(g, lambda t: 1.0 if t < 0.75 else max(0.0, 1 - (t - 0.75) / 0.25))
    mix(x, g, 0.0, 1.0)
    burp = voice(lambda t: 150 * (1 - 0.2 * t / 0.2), 0.2, glide("o", "a", 0.0, 0.2), rng=rng,
                 rough=0.6, scale=1.1, amp=ar(0.2, 0.01, 0.1))
    mix(x, burp, BURP_AT, 0.45)
    mix(x, struck(midi(96), 0.05, rng, BELL, click=0.02), BURP_AT + 0.18, 0.06)
    return x


def space_drift(rng):
    """Stage 7 ambience: an open C-G pad breathing slowly and a few far-off pings. 16 s loop."""
    sec = 16.0
    x = loop_tone(sec, 130.8, ((1, 0.5), (2, 0.18), (3, 0.06)), lfo=(1 / 8, 0.5))
    mix(x, loop_tone(sec, 196.0, ((1, 0.35), (2, 0.1)), lfo=(1 / 16, 0.7)), 0.0, 1.0, wrap=True)
    mix(x, loop_tone(sec, 293.7, ((1, 0.18),), lfo=(3 / 16, 0.8)), 0.0, 1.0, wrap=True)
    air = lfo_env(loop_noise(sec, rng, 1400, "band", 0.8), sec, 1 / 4, 0.7)
    mix(x, air, 0.0, 0.05, wrap=True)
    for k, n in enumerate((84, 91, 88, 93, 86)):
        ping = echo(struck(midi(n), 0.25, rng, BELL, click=0.02), 0.38, 0.4, 4)
        mix(x, ping, 1.3 + k * 3.1 + rng.uniform(0, 0.6), 0.18, wrap=True)
    return x


# ---------------------------------------------------------------- ring ambience beds (16 s loops)

def amb_dirt(rng):
    """Dirt: a close, warm hush and slow drips with a little cave echo."""
    sec = 16.0
    x = lfo_env(loop_noise(sec, rng, 260), sec, 1 / 8, 0.4)
    for _ in range(11):
        f = rng.uniform(900, 1500)
        drip = echo(chirp(f, f * 2.0, 0.035), 0.16, 0.35, 3)
        mix(x, drip, rng.uniform(0, sec), rng.uniform(0.25, 0.5), wrap=True)
    return x


def amb_topsoil(rng):
    """Topsoil: a breeze through the roots overhead and the odd far cricket."""
    sec = 16.0
    x = lfo_env(loop_noise(sec, rng, 520), sec, 1 / 4, 0.6)
    mix(x, lfo_env(loop_noise(sec, rng, 1100, "band", 1.2), sec, 3 / 16, 0.8, 1.3), 0.0, 0.35, wrap=True)
    for _ in range(5):
        at = rng.uniform(0, sec)
        for k in range(3):
            c = osc(0.05, 4300, ((1, 1.0, 0.0),), amp=lambda t: abs(math.sin(TAU * 60 * t)))
            mix(x, c, at + k * 0.09, 0.05, wrap=True)
    return x


def amb_deep_rock(rng):
    """Deep rock: humming crystals, slowly beating, with a rare glassy ping."""
    sec = 16.0
    x = loop_tone(sec, 523.3, ((1, 0.4), (2.0, 0.1)), lfo=(1 / 8, 0.6))
    mix(x, loop_tone(sec, 524.1, ((1, 0.3),)), 0.0, 1.0, wrap=True)           # beats with C5
    mix(x, loop_tone(sec, 784.0, ((1, 0.22),), lfo=(3 / 16, 0.8)), 0.0, 1.0, wrap=True)
    mix(x, loop_tone(sec, 1318.5, ((1, 0.08),), lfo=(5 / 16, 0.9)), 0.0, 1.0, wrap=True)
    mix(x, loop_noise(sec, rng, 200), 0.0, 0.25, wrap=True)
    for k in range(4):
        mix(x, echo(struck(midi(rng.choice(PENT_HI)), 0.2, rng, BELL, click=0.02), 0.3, 0.4, 4),
            k * 4.0 + rng.uniform(0.5, 3.0), 0.25, wrap=True)
    return x


def amb_core(rng):
    """Core: a warm low glow and lazy lava bubbles."""
    sec = 16.0
    x = lfo_env(loop_noise(sec, rng, 140), sec, 1 / 8, 0.5)
    mix(x, loop_tone(sec, 65.4, ((1, 0.5), (2, 0.15))), 0.0, 1.0, wrap=True)
    for _ in range(14):
        f = rng.uniform(110, 220)
        b = chirp(f, f * 2.2, rng.uniform(0.06, 0.12), ((1, 1.0, 0.0), (2, 0.2, 0.0)))
        mix(x, b, rng.uniform(0, sec), rng.uniform(0.3, 0.6), wrap=True)
    return x


def amb_surface(rng):
    """Surface: open-air wind in gusts and far-away birds."""
    sec = 16.0
    x = lfo_env(loop_noise(sec, rng, 800, "band", 0.6), sec, 1 / 8, 0.7)
    mix(x, lfo_env(loop_noise(sec, rng, 300), sec, 3 / 16, 0.5, 2.0), 0.0, 0.6, wrap=True)
    for _ in range(6):
        f = rng.uniform(2000, 2800)
        at = rng.uniform(0, sec)
        mix(x, whistle(f, f * 1.3, 0.07, rng, vib=0.0, breath=0.0), at, 0.07, wrap=True)
        mix(x, whistle(f * 1.25, f, 0.08, rng, vib=0.0, breath=0.0), at + 0.1, 0.06, wrap=True)
    return x


# ---------------------------------------------------------------- carrying, home, warping

def carry(rng):
    x = chirp(420, 720, 0.09, ((1, 1.0, 0.0), (2, 0.2, 0.0)))
    mix(x, struck(midi(79), 0.04, rng, WOOD), 0.0, 0.4)
    return at_len(x, 0.25)


def drop(rng):
    x = chirp(620, 340, 0.1, ((1, 1.0, 0.0), (2, 0.2, 0.0)))
    mix(x, thump(200, 90, 0.12, 0.05), 0.08, 0.6)
    mix(x, grains(rng, 0.08, 5, 500, 1500, 0.004, 0.01), 0.08, 0.3)
    return at_len(x, 0.32)


def sleep(rng):
    """Into bed: a lullaby fall (E D C) and two soft sleepy breaths."""
    x = notes_seq([(76, 0.0), (74, 0.2), (72, 0.4)], rng, MARIMBA, 0.25, 0.6)
    for k in range(2):
        b = svf(noise(0.5, rng), 600, 1.0, "band")
        mix(x, envelope(b, lambda t: math.sin(math.pi * t / 0.5) ** 2), 0.75 + k * 0.6, 0.25)
    return at_len(x, 2.0)


def warp(rng):
    """Wormhole: a swirl that rises and a sparkle where the worm pops out."""
    x = silence(0.9)
    mix(x, whistle(300, 1800, 0.42, rng, vib=0.06, breath=0.1), 0.0, 0.7)
    sw = svf(noise(0.5, rng), lambda t: 400 + 3000 * t / 0.5 + 400 * math.sin(TAU * 14 * t), 2.0, "band")
    mix(x, envelope(sw, lambda t: math.sin(math.pi * t / 0.5)), 0.0, 0.5)
    mix(x, pop(rng, 900), 0.42, 0.6)
    mix(x, sparkle(rng, 4, 0.45, 0.65, 0.5, PENT_HI), 0.0, 0.6)
    return x


def warp_charge(rng):
    x = osc(0.5, lambda t: 220 * (2.0 ** (t / 0.5)), ((1, 1.0, 0.0), (2, 0.3, 0.0), (3, 0.1, 0.0)),
            amp=lambda t: (0.3 + 0.7 * t / 0.5) * (0.7 + 0.3 * math.sin(TAU * 18 * t)))
    return fades(x, 0.01, 0.06)


def segment_pop(rng):
    x = pop(rng, 720)
    mix(x, struck(midi(rng.choice((84, 88, 91))), 0.05, rng, XYLO, click=0.1), 0.02, 0.35)
    return x


def hatch(rng):
    """Drop-in: the shell cracks, the body unfolds with a pop, a tiny 'hi!'."""
    x = silence(1.0)
    for t in (0.0, 0.1):
        mix(x, burst(rng, 0.04, 2400, 1.3, 0.008), t, 0.7)
        mix(x, struck(midi(84), 0.02, rng, WOOD, click=0.3), t, 0.3)
    mix(x, grains(rng, 0.15, 8, 1500, 4000, 0.003, 0.008), 0.18, 0.5)
    mix(x, chirp(300, 900, 0.16, ((1, 1.0, 0.0), (2, 0.3, 0.0))), 0.22, 0.6)
    mix(x, pop(rng, 700), 0.36, 0.6)
    mix(x, worm_chirp(900, 1300, 0.14, rng), 0.5, 0.7)
    return x


def egg_crack(rng):
    x = silence(0.4)
    for t, f in ((0.0, 2600), (0.13, 2200)):
        mix(x, burst(rng, 0.04, f, 1.4, 0.007), t, 0.8)
        mix(x, struck(midi(86), 0.02, rng, WOOD, click=0.3), t, 0.3)
    return x


def bonk(rng, f0=520.0):
    """Cartoon bonk with stars: hollow wood knock, a spring and twinkles. Funny, never hurt."""
    x = silence(0.9)
    mix(x, struck(f0, 0.07, rng, WOOD, click=0.4), 0.0, 1.0)
    mix(x, osc(0.3, lambda t: f0 * 1.5 * (1 + 0.2 * math.sin(TAU * 18 * t)), decay=0.1), 0.03, 0.35)
    for k, n in enumerate((88, 91, 88, 91)):
        mix(x, struck(midi(n), 0.05, rng, BELL, click=0.05), 0.14 + k * 0.08, 0.25)
    return x


def boop(rng):
    """Two worms pass through each other: a soft round boop-boop and a heart's ting."""
    x = silence(0.55)
    mix(x, chirp(520, 470, 0.1, ((1, 1.0, 0.0), (2, 0.1, 0.0))), 0.0, 0.8)
    mix(x, chirp(660, 700, 0.12, ((1, 1.0, 0.0), (2, 0.1, 0.0))), 0.11, 0.8)
    mix(x, struck(midi(96), 0.1, rng, BELL, click=0.02), 0.22, 0.25)
    return x


def home_trophy(rng):
    x = notes_seq([(72, 0.0), (76, 0.1), (79, 0.2)], rng, MARIMBA, 0.15, 0.6)
    mix(x, chord((84, 88), 0.3, rng, BELL), 0.3, 0.6)
    mix(x, sparkle(rng, 3, 0.35, 0.6, 0.4, PENT_HI), 0.0, 0.5)
    return at_len(x, 1.4)


def home_seed(rng):
    x = silence(0.8)
    mix(x, thump(220, 110, 0.1, 0.04), 0.0, 0.4)
    mix(x, grains(rng, 0.08, 6, 500, 1400, 0.004, 0.01), 0.0, 0.3)
    mix(x, notes_seq([(79, 0.08), (84, 0.2)], rng, XYLO, 0.12), 0.0, 0.6)
    return x


def burrow_grow(rng):
    """The burrow gets roomier: a soft dig-out rumble and a rising marimba run."""
    x = silence(1.3)
    mix(x, rumble(rng, 0.6, 300, 0.25, attack=0.05), 0.0, 0.5)
    mix(x, grains(rng, 0.5, 20, 300, 1500, 0.006, 0.02), 0.0, 0.5)
    mix(x, notes_seq([(67, 0.25), (69, 0.33), (72, 0.41), (74, 0.49), (76, 0.57)], rng, MARIMBA, 0.12), 0.0, 0.55)
    return x


def solo_focus(rng):
    x = silence(0.6)
    sw = svf(noise(0.25, rng), lambda t: 2500 - 1500 * t / 0.25, 1.5, "band")
    mix(x, envelope(sw, lambda t: math.sin(math.pi * t / 0.25)), 0.0, 0.3)
    mix(x, struck(midi(84), 0.12, rng, XYLO), 0.15, 0.6)
    return x


def wall_slide(rng, up=True):
    seq = (72, 74, 76, 79, 81) if up else (81, 79, 76, 74, 72)
    x = notes_seq([(n, k * 0.045) for k, n in enumerate(seq)], rng, XYLO, 0.07, 0.5)
    mix(x, paper(rng, 0.22, 1800, up), 0.0, 0.3)
    return at_len(x, 0.7)


def trait_swap(rng):
    x = silence(0.4)
    mix(x, paper(rng, 0.09, 2600, True), 0.0, 0.5)
    mix(x, paper(rng, 0.09, 2600, False), 0.1, 0.5)
    mix(x, struck(midi(79), 0.04, rng, WOOD, click=0.4), 0.2, 0.5)
    return x


def tackle_box_latch(rng):
    """The worm opens the tackle box: a latch clack and a rattle of lures."""
    x = silence(0.6)
    mix(x, struck(900, 0.02, rng, METAL, click=0.6), 0.0, 0.6)
    mix(x, struck(700, 0.03, rng, WOOD, click=0.4), 0.06, 0.6)
    for _ in range(7):
        mix(x, struck(rng.uniform(1800, 3200), 0.02, rng, METAL, click=0.2), rng.uniform(0.1, 0.3), 0.18)
    mix(x, struck(midi(84), 0.1, rng, BELL, click=0.02), 0.3, 0.3)
    return x


# ---------------------------------------------------------------- traits (each ends on the earned bell)

def trait_drill_head(rng):
    x = silence(0.9)
    src = saw(lambda t: 140 * (1.6 ** (t / 0.45)), 0.45)
    mix(x, envelope(svf(src, 1400, 1.4), ar(0.45, 0.03, 0.1)), 0.0, 0.5)
    mix(x, envelope(svf(noise(0.45, rng), 3000, 2.0, "band"), lambda t: 0.6 + 0.4 * math.sin(TAU * 25 * t)), 0.0, 0.2)
    mix(x, earned(rng), 0.45, 1.0)
    return x


def trait_glow(rng):
    x = silence(1.0)
    mix(x, chord((76, 79, 84), 0.3, rng, BELL), 0.0, 0.5)
    mix(x, osc(0.6, 1046.5, ((1, 1.0, 0.0), (1.005, 0.8, 0.0)), amp=lambda t: math.sin(math.pi * t / 0.6)), 0.0, 0.15)
    mix(x, sparkle(rng, 5, 0.05, 0.4, 0.6, PENT_HI), 0.0, 0.6)
    mix(x, earned(rng), 0.45, 1.0)
    return x


def trait_green_thumb(rng):
    x = silence(0.9)
    mix(x, envelope(svf(noise(0.25, rng), 2500, 0.8, "band"), lambda t: math.sin(math.pi * t / 0.25)), 0.0, 0.3)
    mix(x, chirp(300, 900, 0.18, ((1, 1.0, 0.0), (2, 0.25, 0.0))), 0.05, 0.6)     # sprout
    mix(x, struck(midi(79), 0.08, rng, MARIMBA), 0.2, 0.4)
    mix(x, earned(rng), 0.4, 1.0)
    return x


def trait_magnet(rng):
    x = silence(0.9)
    mix(x, osc(0.4, lambda t: 180 + 60 * t / 0.4, ((1, 1.0, 0.0), (2, 0.4, 0.0), (3, 0.2, 0.0)),
               amp=lambda t: math.sin(math.pi * t / 0.4) * (0.6 + 0.4 * math.sin(TAU * 12 * t))), 0.0, 0.5)
    mix(x, struck(2200, 0.03, rng, METAL, click=0.3), 0.36, 0.4)                   # clink
    mix(x, earned(rng), 0.45, 1.0)
    return x


def trait_slick(rng):
    x = silence(0.9)
    mix(x, whistle(700, 1600, 0.18, rng, curve=0.7, vib=0.0, breath=0.03), 0.0, 0.5)
    for k in range(3):
        f = 500 + 150 * k
        mix(x, chirp(f, f * 1.8, 0.05), 0.15 + k * 0.06, 0.35)                      # bubbles
    mix(x, earned(rng), 0.42, 1.0)
    return x


def trait_stone_head(rng):
    x = silence(0.9)
    mix(x, struck(180, 0.07, rng, WOOD, click=0.6), 0.0, 0.9)
    mix(x, struck(260, 0.05, rng, METAL, click=0.2), 0.0, 0.3)
    mix(x, grains(rng, 0.12, 6, 800, 2000, 0.004, 0.01), 0.02, 0.3)
    mix(x, earned(rng), 0.35, 1.0)
    return x


def trait_wriggle(rng):
    x = silence(1.0)
    mix(x, kazoo(330, 0.35, vib_rate=11.0, vib_depth=0.05), 0.0, 0.25)
    mix(x, worm_chirp(800, 1100, 0.12, rng), 0.25, 0.5)
    mix(x, shaker(rng, (0.0, 0.08, 0.16, 0.24), 0.3), 0.0, 1.0)
    mix(x, earned(rng), 0.45, 1.0)
    return x


# ---------------------------------------------------------------- pets (ladybirds)

def pet_home(rng):
    x = silence(0.9)
    mix(x, buzz(160, 0.35, rng), 0.0, 0.5)
    mix(x, notes_seq([(79, 0.35), (84, 0.47)], rng, XYLO, 0.12), 0.0, 0.6)
    return x


def pet_away(rng):
    x = silence(0.8)
    b = buzz(190, 0.6, rng)
    b = envelope(b, lambda t: (1 - t / 0.6) ** 1.5)
    mix(x, b, 0.0, 0.6)
    mix(x, chirp(900, 600, 0.12), 0.05, 0.25)
    return x


def pet_fetch(rng):
    x = silence(1.0)
    mix(x, buzz(170, 0.4, rng), 0.0, 0.5)
    mix(x, pop(rng, 800), 0.38, 0.5)
    mix(x, notes_seq([(84, 0.45), (88, 0.53), (91, 0.61)], rng, BELL, 0.1), 0.0, 0.5)
    return x


# ---------------------------------------------------------------- creatures (one bark each, all friendly)

def bird_gulp(rng):
    x = gulp_tone(700, 300, 0.2, rng, scale=1.3)
    mix(x, burst(rng, 0.03, 2000, 1.3, 0.006), 0.0, 0.4)
    return at_len(x, 0.4)


def boing(rng):
    x = osc(0.55, lambda t: 220 * (1 + 0.35 * math.exp(-t / 0.2) * math.sin(TAU * 9 * t)) * (1 + 0.3 * t),
            ((1, 1.0, 1.0), (2, 0.3, 1.5)), decay=0.25)
    return x


def bird_offended(rng):
    """The bird's offended squawk: a huffy 'hmph-AWK', more grumpy-cute than loud."""
    x = silence(0.6)
    mix(x, voice(lambda t: 520 * (1 - 0.15 * t / 0.12), 0.12, "u", rng=rng, rough=0.2, scale=1.4), 0.0, 0.5)
    mix(x, voice(lambda t: 900 * (1 - 0.3 * t / 0.2), 0.2, glide("a", "e", 0.0, 0.2), rng=rng,
                 rough=0.4, scale=1.5), 0.15, 0.8)
    return x


def bird_peck(rng):
    x = silence(0.35)
    for t in (0.0, 0.11):
        mix(x, struck(1600, 0.015, rng, WOOD, click=0.7), t, 0.8)
    return x


def bird_tweet(rng):
    x = silence(0.4)
    mix(x, whistle(2200, 3000, 0.07, rng, vib=0.0, breath=0.02), 0.0, 0.7)
    mix(x, whistle(2900, 2300, 0.08, rng, vib=0.0, breath=0.02), 0.1, 0.6)
    return x


def creature_munch(rng):
    x = silence(0.35)
    for t in (0.0, 0.12):
        mix(x, crunch(rng, 0.06, 6, 600, 1800, (180, 90), 0.05, 0.8), t, 1.0)
    return x


def ant_hup(rng):
    return at_len(voice(lambda t: 520 * (1 + 0.3 * t / 0.1), 0.1, glide("u", "a", 0.0, 0.1), rng=rng,
                        scale=1.6, amp=ar(0.1, 0.005, 0.05)), 0.2)


def beetle_blink(rng):
    x = struck(midi(93), 0.04, rng, BELL, click=0.1)
    mix(x, struck(midi(98), 0.04, rng, BELL, click=0.1), 0.07, 0.6)
    return at_len(x, 0.35)


def boot_rumble(rng):
    """A boot stomps by overhead: two soft, far thuds. Big, not scary."""
    x = silence(1.1)
    for t in (0.0, 0.45):
        mix(x, thump(80, 40, 0.4, 0.15), t, 0.9)
        mix(x, rumble(rng, 0.4, 220, 0.12), t, 0.5)
        mix(x, grains(rng, 0.2, 6, 400, 1000, 0.008, 0.02), t + 0.02, 0.25)
    return x


def grub_squeak(rng):
    return at_len(voice(lambda t: 900 * (1 + 0.35 * math.sin(math.pi * t / 0.12)), 0.12, "i", rng=rng,
                        scale=1.6, amp=ar(0.12, 0.01, 0.06)), 0.22)


def lava_blob_blorp(rng):
    x = chirp(140, 380, 0.14, ((1, 1.0, 0.0), (2, 0.3, 0.0)))
    mix(x, gulp_tone(200, 300, 0.12, rng, scale=0.8), 0.06, 0.5)
    return at_len(x, 0.35)


def lava_blob_swell(rng):
    x = silence(1.0)
    mix(x, osc(0.8, lambda t: 110 * (1 + t), ((1, 1.0, 0.0), (2, 0.25, 0.0)),
               amp=lambda t: (0.2 + 0.8 * t / 0.8) * (0.7 + 0.3 * math.sin(TAU * 7 * t))), 0.0, 0.5)
    for k in range(5):
        f = 150 + 40 * k
        mix(x, chirp(f, f * 2, 0.07), 0.1 + k * 0.14, 0.3)
    return x


def rock_beetle_clack(rng):
    x = silence(0.35)
    for t, f in ((0.0, 420), (0.09, 470)):
        mix(x, struck(f, 0.03, rng, WOOD, click=0.7), t, 0.8)
        mix(x, grains(rng, 0.04, 3, 1000, 2500, 0.003, 0.006), t, 0.3)
    return x


def rock_beetle_windup(rng):
    x = ratchet(rng, 0.85, 12, 220, 520, WOOD, 1.8)
    mix(x, rumble(rng, 0.85, 300, 0.6, attack=0.4), 0.0, 0.25)
    return x


def beetle_windup(rng):
    """The beetle winds up a charge: cartoon ratchet and a rising slide whistle (a warning, a laugh)."""
    x = ratchet(rng, 0.85, 10, 400, 900, WOOD, 1.7)
    mix(x, whistle(260, 640, 0.85, rng, curve=1.0, vib=0.01, breath=0.03), 0.0, 0.35)
    return x


def beetle_lunge(rng):
    x = silence(0.5)
    sw = svf(noise(0.25, rng), lambda t: 3000 - 2200 * t / 0.25, 1.2, "band")
    mix(x, envelope(sw, lambda t: math.sin(math.pi * t / 0.25)), 0.0, 0.6)
    mix(x, struck(330, 0.04, rng, WOOD, click=0.6), 0.2, 0.7)
    return x


# ---------------------------------------------------------------- world, garden, secrets, mole

def garden_plant(rng):
    x = silence(0.7)
    for t in (0.0, 0.1):
        mix(x, thump(200, 100, 0.1, 0.04), t, 0.4)
        mix(x, grains(rng, 0.06, 4, 500, 1400, 0.004, 0.01), t, 0.25)
    mix(x, chirp(400, 1000, 0.14, ((1, 1.0, 0.0), (2, 0.2, 0.0))), 0.22, 0.5)
    return x


def secret_found(rng):
    """A secret: a glissando of sparkles, an 'ooh' bell chord and the worm's wow-chirp."""
    x = silence(1.8)
    mix(x, notes_seq([(n, k * 0.05) for k, n in enumerate((72, 74, 76, 79, 81, 84, 86, 88, 91))],
                     rng, BELL, 0.1, 0.4), 0.0, 1.0)
    mix(x, chord((76, 79, 84, 88), 0.4, rng, BELL), 0.5, 0.8)
    mix(x, sparkle(rng, 6, 0.55, 1.2, 0.6, PENT_HI), 0.0, 0.5)
    mix(x, worm_chirp(700, 1200, 0.2, rng, ("o", "i")), 0.75, 0.6)
    return x


def mole_hide(rng):
    x = silence(0.5)
    mix(x, chirp(700, 260, 0.16, ((1, 1.0, 0.0), (2, 0.2, 0.0))), 0.0, 0.6)
    mix(x, grains(rng, 0.2, 10, 400, 1500, 0.006, 0.015), 0.05, 0.5)
    mix(x, thump(160, 80, 0.1, 0.05), 0.16, 0.4)
    return x


def mole_pop(rng):
    x = silence(0.5)
    mix(x, grains(rng, 0.15, 10, 400, 1600, 0.005, 0.015), 0.0, 0.5)
    mix(x, pop(rng, 500), 0.08, 0.8)
    mix(x, chirp(400, 800, 0.1), 0.1, 0.3)
    return x


def mole_sorry(rng):
    """The Mole's apology without words: a sheepish 'oh-dear' hum, falling a gentle step."""
    x = silence(0.8)
    mix(x, voice(lambda t: 220 * (1 + 0.04 * math.sin(TAU * 5 * t)), 0.22, glide("o", "u", 0.0, 0.22),
                 rng=rng, scale=0.95, amp=ar(0.22, 0.03, 0.1)), 0.0, 0.7)
    mix(x, voice(lambda t: 196 * (1 - 0.05 * t / 0.35), 0.35, glide("e", "a", 0.0, 0.35), rng=rng,
                 scale=0.95, amp=ar(0.35, 0.03, 0.2)), 0.24, 0.7)
    return x


def swap(rng):
    """Swap shop trade: a wooden counter knock and a cheerful two-bell 'ta-ding'."""
    x = silence(0.8)
    mix(x, struck(500, 0.04, rng, WOOD, click=0.5), 0.0, 0.6)
    mix(x, struck(midi(84), 0.15, rng, BELL, click=0.05), 0.1, 0.6)
    mix(x, struck(midi(88), 0.2, rng, BELL, click=0.05), 0.2, 0.6)
    mix(x, sparkle(rng, 2, 0.25, 0.4, 0.4, PENT_HI), 0.0, 0.5)
    return x


# ---------------------------------------------------------------- tackle box and book

def box_open(rng):
    x = silence(0.6)
    mix(x, struck(800, 0.02, rng, METAL, click=0.5), 0.0, 0.5)
    mix(x, chirp(300, 600, 0.16, ((1, 1.0, 0.0), (2, 0.3, 0.0))), 0.04, 0.35)       # lid up
    for _ in range(5):
        mix(x, struck(rng.uniform(2000, 3200), 0.02, rng, METAL, click=0.2), rng.uniform(0.15, 0.3), 0.15)
    return x


def box_close(rng):
    x = silence(0.4)
    mix(x, chirp(600, 300, 0.12, ((1, 1.0, 0.0), (2, 0.3, 0.0))), 0.0, 0.35)
    mix(x, struck(500, 0.03, rng, WOOD, click=0.5), 0.12, 0.7)
    mix(x, struck(900, 0.02, rng, METAL, click=0.5), 0.15, 0.4)
    return x


def page_flip(rng, fc=3200.0):
    x = paper(rng, 0.16, fc, True)
    mix(x, burst(rng, 0.03, fc * 0.7, 1.0, 0.01), 0.13, 0.3)
    return at_len(x, 0.3)


def tick(rng, n=84, partials=XYLO):
    return at_len(struck(midi(n), 0.04, rng, partials, click=0.25), 0.25)


def box_play(rng):
    """Play a cutscene again: a projector click-clack and a rising 'here we go' chime."""
    x = silence(0.9)
    for k in range(4):
        mix(x, struck(1400, 0.012, rng, WOOD, click=0.7), k * 0.06, 0.4)
    mix(x, notes_seq([(72, 0.25), (76, 0.33), (79, 0.41)], rng, BELL, 0.12), 0.0, 0.5)
    return x


def lure_pin(rng):
    x = struck(2600, 0.06, rng, METAL, click=0.3)
    mix(x, struck(midi(91), 0.08, rng, BELL, click=0.05), 0.05, 0.4)
    return at_len(x, 0.5)


def page_new(rng):
    """A new page in the log: a page flips in and a small 'ooh, new!' ding-ding."""
    x = silence(1.0)
    mix(x, page_flip(rng), 0.0, 0.6)
    mix(x, notes_seq([(84, 0.2), (91, 0.3)], rng, BELL, 0.15), 0.0, 0.6)
    mix(x, sparkle(rng, 3, 0.3, 0.5, 0.4, PENT_HI), 0.0, 0.5)
    return x


def book(rng, up=True):
    x = silence(0.5)
    mix(x, paper(rng, 0.2, 2200, up), 0.0, 0.5)
    mix(x, thump(180 if up else 140, 90, 0.12, 0.05), 0.18 if up else 0.12, 0.5)
    return x


def book_look(rng):
    x = silence(0.6)
    mix(x, chirp(500, 760, 0.12, ((1, 1.0, 0.0), (2, 0.2, 0.0))), 0.0, 0.5)
    mix(x, struck(midi(88), 0.1, rng, BELL, click=0.05), 0.08, 0.45)
    return x


# ---------------------------------------------------------------- template cues

def jump(rng):
    return at_len(chirp(330, 660, 0.14, ((1, 1.0, 0.0), (2, 0.2, 0.0))), 0.22)


def action(rng):
    x = struck(midi(79), 0.05, rng, WOOD, click=0.4)
    mix(x, chirp(600, 900, 0.06), 0.0, 0.3)
    return at_len(x, 0.3)


def round_start(rng):
    return at_len(notes_seq([(72, 0.0), (76, 0.12), (79, 0.24), (84, 0.36)], rng, MARIMBA, 0.15), 1.2)


def round_end(rng):
    return at_len(notes_seq([(84, 0.0), (79, 0.12), (76, 0.24), (72, 0.36)], rng, MARIMBA, 0.18), 1.3)


def pause_cue(rng):
    return at_len(notes_seq([(79, 0.0), (72, 0.08)], rng, XYLO, 0.08), 0.5)


# ---------------------------------------------------------------- planet chomp, space, polar world

def chomp_bite(rng):          # one bite of the long planet chomp (played many times, pitched)
    x = silence(0.5)
    mix(x, thump(140, 55, 0.3, 0.12), 0.0, 1.0)
    mix(x, grains(rng, 0.3, 28, 400, 3200, 0.005, 0.02, spread=0.7), 0.0, 0.9)
    mix(x, rumble(rng, 0.3, 500, 0.1), 0.0, 0.4)
    return x


def confirm_hold(rng):
    """A held A on the point of no return: a short, curious rising hum. Short on purpose: once
    this is a file, Audio.play plays it and ProtoSfx.stop() can no longer cut it."""
    x = osc(0.55, lambda t: 262 * (1.5 ** (t / 0.55)), ((1, 1.0, 0.0), (2, 0.25, 0.0)),
            amp=lambda t: 0.4 + 0.6 * t / 0.55)
    return fades(x, 0.02, 0.15)


def confirm_cancel(rng):
    return at_len(chirp(520, 330, 0.16, ((1, 1.0, 0.0), (2, 0.15, 0.0))), 0.3)


def confirm_yes(rng):
    return at_len(notes_seq([(72, 0.0), (79, 0.1)], rng, BELL, 0.2, 0.7), 1.0)


def jar_clink(rng):
    x = struck(1800, 0.15, rng, ((1, 1.0, 1.0), (2.32, 0.5, 1.5), (4.25, 0.25, 2.2)), click=0.2)
    mix(x, struck(2700, 0.1, rng, ((1, 1.0, 1.0), (2.1, 0.3, 1.5)), click=0.1), 0.03, 0.4)
    return at_len(x, 0.9)


def space_bite(rng):
    x = chomp_munch(rng, 0.9)
    mix(x, sparkle(rng, 2, 0.1, 0.25, 0.4, PENT_HI), 0.0, 0.6)
    return at_len(x, 0.7)


def space_bump(rng):
    x = osc(0.4, lambda t: 300 * (1 + 0.3 * math.exp(-t / 0.15) * math.sin(TAU * 10 * t)),
            ((1, 1.0, 1.0), (2, 0.2, 1.5)), decay=0.2)
    mix(x, thump(180, 90, 0.1, 0.04), 0.0, 0.4)
    return x


def world_blocked(rng):
    x = struck(260, 0.04, rng, WOOD, click=0.5)
    mix(x, chirp(400, 300, 0.08), 0.03, 0.3)
    return at_len(x, 0.3)


def world_munch(rng):         # every few frames while a worm eats the polar world: tiny and dry
    return at_len(crunch(rng, 0.05, 5, 900, 2600, (240, 140), 0.03, 0.8), 0.12)


def world_seed(rng):
    return at_len(notes_seq([(79, 0.0)], rng, XYLO, 0.08), 0.35)


def world_regrow(rng):
    x = envelope(svf(noise(0.3, rng), lambda t: 1200 + 2000 * t / 0.3, 1.0, "band"),
                 lambda t: math.sin(math.pi * t / 0.3))
    mix(x, struck(midi(88), 0.05, rng, MARIMBA), 0.2, 0.3)
    return at_len(x, 0.5)


def world_sprout(rng):
    return at_len(chirp(500, 1100, 0.1, ((1, 1.0, 0.0), (2, 0.2, 0.0))), 0.2)


# ---------------------------------------------------------------- the file table

def v(fn, *a):
    return lambda rng: fn(rng, *a)


FILES = {}


def add(stem, make, kind="sfx", trim=0.0, why=""):
    FILES[stem] = (make, kind, trim, why)


# The chomp: three variants each for the frequent sizes (Audio picks one at random).
for i, p in enumerate((1.0, 0.92, 1.08), 1):
    add("chomp_1_%d" % i, v(chomp_crunch, p), trim=-4.0)
    add("chomp_2_%d" % i, v(chomp_munch, p), trim=-3.0)
    add("chomp_3_%d" % i, v(chomp_big_crunch, p), trim=-2.0)
add("chomp_4", chomp_gulp, trim=-1.0)
add("chomp_5", chomp_boom, trim=-0.5)
add("tunnel", tunnel_loop, "loop", -9.0)
add("burst", burst_zip, trim=-2.0)
add("wiggle", wiggle, trim=-2.0)
add("stage_up", stage_up, trim=1.0)
add("threat_near", threat_near, trim=-3.0)
add("eaten", eaten, trim=-1.0)
add("now_i_eat_you", now_i_eat_you, trim=0.0)
add("breakthrough", breakthrough, trim=-0.5)
add("planet_gone", planet_gone, trim=-0.5)
add("space_drift", space_drift, "loop", -12.0)
for ring in ("dirt", "topsoil", "deep_rock", "core", "surface"):
    add("amb_" + ring, globals()["amb_" + ring], "loop", -16.0)

add("carry", carry, trim=-3.0)
add("drop", drop, trim=-3.0)
add("sleep", sleep, trim=-4.0)
add("warp", warp, trim=-2.0)
add("warp_charge", warp_charge, trim=-5.0)
add("segment_pop", segment_pop, trim=-4.0)
add("hatch", hatch, trim=-1.0)
add("egg_crack", egg_crack, trim=-3.0)
add("bonk", bonk, trim=-3.0)
add("boop", boop, trim=-3.0)
add("home_trophy", home_trophy, trim=-2.0)
add("home_seed", home_seed, trim=-3.0)
add("burrow_grow", burrow_grow, trim=-2.0)
add("solo_focus", solo_focus, trim=-4.0)
add("wall_open", v(wall_slide, True), trim=-3.0)
add("wall_close", v(wall_slide, False), trim=-3.0)
add("trait_swap", trait_swap, trim=-3.0)
add("tackle_box", tackle_box_latch, trim=-3.0)
for t in ("drill_head", "glow", "green_thumb", "magnet", "slick", "stone_head", "wriggle"):
    add("trait_" + t, globals()["trait_" + t], trim=-2.0)
add("pet_home", pet_home, trim=-3.0)
add("pet_away", pet_away, trim=-4.0)
add("pet_fetch", pet_fetch, trim=-3.0)

add("bird_gulp", bird_gulp, trim=-2.0)
add("boing", boing, trim=-2.0)
add("bird_offended", bird_offended, trim=-3.0)
add("bird_peck", bird_peck, trim=-3.0)
add("bird_tweet", bird_tweet, trim=-4.0)
add("creature_munch", creature_munch, trim=-5.0)
add("ant_hup", ant_hup, trim=-5.0)
add("beetle_blink", beetle_blink, trim=-5.0)
add("boot_rumble", boot_rumble, trim=-3.0)
add("grub_squeak", grub_squeak, trim=-5.0)
add("lava_blob_blorp", lava_blob_blorp, trim=-4.0)
add("lava_blob_swell", lava_blob_swell, trim=-3.0)
add("rock_beetle_clack", rock_beetle_clack, trim=-4.0)
add("rock_beetle_windup", rock_beetle_windup, trim=-3.0)
add("beetle_windup", beetle_windup, trim=-3.0)
add("beetle_lunge", beetle_lunge, trim=-2.0)

add("garden_plant", garden_plant, trim=-3.0)
add("secret_found", secret_found, trim=-0.5)
add("mole_hide", mole_hide, trim=-4.0)
add("mole_pop", mole_pop, trim=-3.0)
add("mole_sorry", mole_sorry, trim=-3.0)
add("swap", swap, trim=-2.0)

add("box_open", box_open, trim=-3.0)
add("box_close", box_close, trim=-3.0)
add("box_flip", page_flip, trim=-5.0)
add("box_tick", v(tick, 84), trim=-5.0)
add("box_play", box_play, trim=-3.0)
add("lure_pin", lure_pin, trim=-3.0)
add("page_new", page_new, trim=-2.0)
add("book_open", v(book, True), trim=-3.0)
add("book_close", v(book, False), trim=-3.0)
add("book_flip", v(page_flip, 2600.0), trim=-5.0)
add("book_look", book_look, trim=-4.0)
add("book_tick", v(tick, 79), trim=-5.0)

# ui_move, ui_confirm, player_join (and the rest of the menu kit) stay with UiSound's designed
# synth, shared by every Open Jar game: GreyBeep hands those to UiSound instead of beeping.
add("jump", jump, trim=-4.0)
add("action", action, trim=-3.0)
add("round_start", round_start, trim=-2.0)
add("round_end", round_end, trim=-2.0)
add("pause", pause_cue, trim=-3.0)
add("solo_on", v(lambda rng: notes_seq([(72, 0.0), (84, 0.1)], rng, XYLO, 0.08)), trim=-3.0)
add("solo_off", v(lambda rng: notes_seq([(84, 0.0), (72, 0.1)], rng, XYLO, 0.08)), trim=-3.0)

add("chomp_bite", chomp_bite, trim=-2.0)
add("confirm_hold", confirm_hold, trim=-4.0)
add("confirm_cancel", confirm_cancel, trim=-3.0)
add("confirm_yes", confirm_yes, trim=-2.0)
add("jar_clink", jar_clink, trim=-3.0)
add("space_bite", space_bite, trim=-2.0)
add("space_bump", space_bump, trim=-3.0)
add("world_blocked", world_blocked, trim=-5.0)
add("world_munch", world_munch, trim=-7.0)
add("world_seed", world_seed, trim=-5.0)
add("world_regrow", world_regrow, trim=-8.0)
add("world_sprout", world_sprout, trim=-7.0)

# The order of the stitched preview: the cue table first, then the rest in play order.
PREVIEW = ["chomp_1_1", "chomp_2_1", "chomp_3_1", "chomp_4", "chomp_5", "tunnel", "burst", "wiggle",
           "stage_up", "threat_near", "eaten", "now_i_eat_you", "breakthrough", "planet_gone",
           "space_drift", "amb_dirt", "amb_topsoil", "amb_deep_rock", "amb_core", "amb_surface"]
PREVIEW += [s for s in FILES if s not in PREVIEW and not re.match(r"chomp_[123]_[23]$", s)]
LOOP_PREVIEW_SEC = 3.0


def pop(rng, f0=600.0):
    x = chirp(f0, f0 * 2.2, 0.06)
    mix(x, burst(rng, 0.03, 2000, 1.5, 0.004), 0.0, 0.4)
    return at_len(x, 0.25)


# ---------------------------------------------------------------- ffmpeg

def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(3)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<i", int(round(max(-1.0, min(1.0, v)) * 8388607)))[:3]
                               for v in x))


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True)


def run_bytes(cmd):
    return subprocess.run(cmd, capture_output=True, check=True).stdout


def measure(path, tile=1):
    """(integrated LUFS, true peak dBTP) via ebur128. tile > 1 loops the input first."""
    cmd = ["ffmpeg", "-hide_banner", "-nostats"]
    if tile > 1:
        cmd += ["-stream_loop", str(tile - 1)]
    cmd += ["-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"]
    err = run(cmd).stderr
    summary = err[err.rfind("Summary:"):]
    num = r"(-?inf|-?\d+(?:\.\d+)?)"
    lufs = float(re.search(r"I:\s+" + num + r" LUFS", summary).group(1))
    peak = float(re.search(r"True peak:\s+Peak:\s+" + num, summary).group(1))
    return lufs, peak


def duration(path):
    out = run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
               "stream=duration", "-of", "default=nw=1", path]).stdout
    return float(re.search(r"duration=([\d.]+)", out).group(1))


def decoded_samples(path):
    raw = run_bytes(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-"])
    return struct.unpack("<%df" % (len(raw) // 4), raw)


def encode(wav, ogg, gain_db):
    run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", wav, "-af", "volume=%.2fdB" % gain_db,
         "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "5", "-map_metadata", "-1",
         "-fflags", "+bitexact", "-flags:a", "+bitexact", ogg])


def out_path(stem):
    return os.path.join(AUDIO_DIR, "sfx", stem + ".ogg")


def build_loop(stem, tmp, x, trim):
    """Seamless loop: circular low-pass and DC block, loudness by plain gain, then a seam check."""
    x = dc_block(soft(x, 9500.0, circular=True), circular=True)
    x = peak_normalise(x, 0.5)
    wav = os.path.join(tmp, stem + ".wav")
    write_wav(wav, x)
    target = SFX_TARGET + trim
    lufs, peak = measure(wav, 3)
    gain = min(target - lufs, TP_CEILING - 0.5 - peak)
    ogg = out_path(stem)
    for _ in range(4):
        encode(wav, ogg, gain)
        lufs, peak = measure(ogg, 3)
        if peak <= TP_CEILING:
            break
        gain -= peak - TP_CEILING + 0.1
    y = decoded_samples(ogg)
    steps = sorted(abs(y[i + 1] - y[i]) for i in range(len(y) - 1))
    return {"stem": stem, "kind": "loop", "seconds": len(y) / SR, "lufs": lufs, "active_lufs": None,
            "true_peak": peak, "target": target,
            "seam": {"decoded": len(y), "rendered": len(x), "seam_step": abs(y[0] - y[-1]),
                     "p99_step": steps[int(len(steps) * 0.99)]}}


def build(stem, tmp):
    make, kind, trim, _ = FILES[stem]
    rng = random.Random(SEED + stem)
    x = make(rng)
    if kind == "loop":
        return build_loop(stem, tmp, x, trim)
    x = fades(dc_block(soft(x, 9500.0)), 0.001, 0.005)
    x = peak_normalise(x, 0.5)
    wav = os.path.join(tmp, stem + ".wav")
    write_wav(wav, x)
    secs = len(x) / SR
    tile = 10 if secs < SHORT_CUE else 1
    target = SFX_TARGET + trim
    lufs, peak = measure(wav, tile)
    short_by = (target - lufs) - (TP_CEILING - 0.3 - peak)
    for _ in range(2):
        if short_by <= 0.5:
            break
        # Peak-bound, not loudness-bound: limit the transients (at most 10 dB) and re-measure.
        x = peak_normalise(limit(x, 0.5 * 10.0 ** (-min(short_by, 10.0) / 20.0)), 0.5)
        write_wav(wav, x)
        lufs, peak = measure(wav, tile)
        short_by = (target - lufs) - (TP_CEILING - 0.3 - peak)
    gain = min(target - lufs, TP_CEILING - 0.3 - peak)
    ogg = out_path(stem)
    for _ in range(4):   # Vorbis can push peaks up a little; back off until under the ceiling
        encode(wav, ogg, gain)
        lufs, peak = measure(ogg, tile)
        if peak <= TP_CEILING:
            break
        gain -= peak - TP_CEILING + 0.1
    file_lufs = measure(ogg)[0] if tile > 1 else lufs
    return {"stem": stem, "kind": kind, "seconds": duration(ogg), "lufs": file_lufs,
            "active_lufs": lufs if tile > 1 else None, "true_peak": peak, "target": target}


def _job(args):
    return build(*args)


def loudness(r):
    """The number the kid rule compares: active loudness for short cues, whole-file otherwise."""
    return r["active_lufs"] if r["active_lufs"] is not None else r["lufs"]


def preview(path, tmp):
    """Stitch PREVIEW with 0.3 s gaps; loops play LOOP_PREVIEW_SEC with a fade."""
    parts = []
    gap = os.path.join(tmp, "gap.wav")
    write_wav(gap, silence(0.3))
    for stem in PREVIEW:
        src = out_path(stem)
        if FILES[stem][1] == "loop":
            cut = os.path.join(tmp, stem + "_preview.wav")
            run(["ffmpeg", "-y", "-v", "error", "-stream_loop", "3", "-i", src, "-t", str(LOOP_PREVIEW_SEC),
                 "-ar", str(SR), "-ac", "1", "-af",
                 "afade=t=in:d=0.2,afade=t=out:st=%.2f:d=0.4" % (LOOP_PREVIEW_SEC - 0.4), cut])
            src = cut
        parts += [src, gap]
    lst = os.path.join(tmp, "preview_list.txt")
    with open(lst, "w") as f:
        for p in parts:
            wav = p if p.endswith(".wav") else os.path.join(tmp, os.path.basename(p) + ".pv.wav")
            if wav != p:
                run(["ffmpeg", "-y", "-v", "error", "-i", p, "-ar", str(SR), "-ac", "1", wav])
            f.write("file '%s'\n" % wav)
    run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-f", "concat", "-safe", "0", "-i", lst,
         "-c:a", "libvorbis", "-q:a", "5", path])
    return duration(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("only", nargs="*", help="file stems to build (default: all)")
    ap.add_argument("--keep-wav", default=os.path.join(REPO, ".scratch", "cue-wav"),
                    help="WAV sources go here (default .scratch/cue-wav)")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--preview", help="write the stitched preview .ogg here (after building)")
    ap.add_argument("--no-build", action="store_true", help="with --preview: just stitch")
    ap.add_argument("--table", help="write the measured loudness table (markdown) here")
    args = ap.parse_args()
    if args.list:
        for s, (_, kind, trim, _w) in FILES.items():
            print("%-24s %-5s %+.1f" % (s, kind, trim))
        return
    stems = args.only or list(FILES)
    unknown = [s for s in stems if s not in FILES]
    if unknown:
        sys.exit("unknown stem(s): %s" % ", ".join(unknown))
    tmp = args.keep_wav
    os.makedirs(tmp, exist_ok=True)
    os.makedirs(os.path.join(AUDIO_DIR, "sfx"), exist_ok=True)
    bad = []
    if not args.no_build:
        print("%-24s %-5s %7s %7s %7s %6s" % ("file", "kind", "sec", "LUFS", "active", "TP"))
        results = {}
        order = sorted(stems, key=lambda s: FILES[s][1] != "loop")   # longest first
        with Pool(args.jobs) as pool:
            for r in pool.imap_unordered(_job, [(s, tmp) for s in order]):
                results[r["stem"]] = r
                act = "%7.1f" % r["active_lufs"] if r["active_lufs"] is not None else "%7s" % "-"
                print("%-24s %-5s %7.3f %7.1f %s %6.1f" % (r["stem"], r["kind"], r["seconds"], r["lufs"],
                                                         act, r["true_peak"]), flush=True)
                if "seam" in r:
                    s = r["seam"]
                    print("  loop: decoded %d / rendered %d, seam step %.4f (p99 %.4f)" % (
                        s["decoded"], s["rendered"], s["seam_step"], s["p99_step"]), flush=True)
                    if s["decoded"] != s["rendered"] or s["seam_step"] > 2.0 * s["p99_step"] + 0.01:
                        bad.append("%s: loop seam (%r)" % (r["stem"], s))
                if r["true_peak"] > TP_CEILING + 0.05:
                    bad.append("%s: true peak %.2f dBTP" % (r["stem"], r["true_peak"]))
        if "stage_up" in results:
            top = loudness(results["stage_up"])
            for s, r in results.items():
                if s != "stage_up" and loudness(r) > top + 0.05:
                    bad.append("%s: %.1f LUFS is louder than stage_up (%.1f)" % (s, loudness(r), top))
        if args.table:
            with open(args.table, "w") as f:
                f.write("| file | kind | seconds | LUFS (active) | true peak dBTP |\n| --- | --- | --- | --- | --- |\n")
                for s in FILES:
                    if s in results:
                        r = results[s]
                        f.write("| %s.ogg | %s | %.2f | %.1f | %.1f |\n" % (s, r["kind"], r["seconds"],
                                                                         loudness(r), r["true_peak"]))
    if args.preview:
        print("preview: %s (%.1f s)" % (args.preview, preview(args.preview, tmp)))
    if bad:
        print("\nFAILED kid / loudness / loop checks:\n  " + "\n  ".join(bad))
        sys.exit(1)


if __name__ == "__main__":
    main()
