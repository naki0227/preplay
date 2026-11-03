"""Writes the background music and tap sounds for the promotion video.

    python3 tool/make_bgm.py SECONDS OUT.wav [TAP_SECONDS ...]

Everything is synthesized here (no samples, nothing to license): a bright
120 BPM loop in C major (C - G - Am - F) with a marimba-like pluck, bass,
kick, clap and hi-hat. The first bar is pluck only, then the beat drops.
A short "pop" plays at each tap time. Fades out over the last second.
"""
import sys
import wave

import numpy as np

RATE = 48000
BPM = 120
BEAT = 60 / BPM
CHORDS = [  # (bass root, chord tones) as MIDI notes, one bar each
    (36, [60, 64, 67, 72]),  # C
    (43, [59, 62, 67, 71]),  # G
    (45, [60, 64, 69, 72]),  # Am
    (41, [60, 65, 69, 72]),  # F
]


def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def env(n, attack, decay):
    t = np.arange(n) / RATE
    return np.minimum(t / attack, 1.0) * np.exp(-t / decay)


def add(buf, start, sig, gain=1.0, pan=0.0):
    i = int(start * RATE)
    if i >= buf.shape[0]:
        return
    sig = sig[: buf.shape[0] - i] * gain
    buf[i:i + len(sig), 0] += sig * (1 - max(pan, 0))
    buf[i:i + len(sig), 1] += sig * (1 + min(pan, 0))


def pluck(note, length=0.35):
    n = int(length * RATE)
    t = np.arange(n) / RATE
    f = hz(note)
    tone = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 4 * f * t) * np.exp(-t / 0.03)
    return tone * env(n, 0.002, 0.12)


def bass(note, length):
    n = int(length * RATE)
    t = np.arange(n) / RATE
    f = hz(note)
    tone = sum(np.sin(2 * np.pi * k * f * t) / k for k in range(1, 5))
    return np.tanh(1.5 * tone) * env(n, 0.005, 0.18)


def kick():
    n = int(0.25 * RATE)
    t = np.arange(n) / RATE
    freq = 50 + 90 * np.exp(-t / 0.03)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE) * env(n, 0.001, 0.09)


def noise(length, decay, rng, highpass=True):
    n = int(length * RATE)
    x = rng.standard_normal(n)
    if highpass:
        x = np.diff(x, prepend=0.0)
    return x * env(n, 0.001, decay)


def pop():
    n = int(0.09 * RATE)
    t = np.arange(n) / RATE
    freq = 1300 * np.exp(-t / 0.05) + 500
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE) * env(n, 0.001, 0.03)


def render(seconds, taps=(), seed=7):
    rng = np.random.default_rng(seed)
    buf = np.zeros((int(seconds * RATE) + RATE, 2))
    bar_len = 4 * BEAT
    for bar in range(int(seconds / bar_len) + 1):
        root, tones = CHORDS[bar % len(CHORDS)]
        t0 = bar * bar_len
        pattern = [0, 2, 1, 3, 2, 1, 3, 2]  # arpeggio over the chord, in 16ths
        for k in range(16):
            note = tones[pattern[k % 8]] + (12 if k in (6, 14) else 0)
            add(buf, t0 + k * BEAT / 4, pluck(note), 0.22, pan=0.25 if k % 2 else -0.25)
        if bar == 0:
            continue  # intro: pluck only, then the beat comes in
        for b in range(4):
            add(buf, t0 + b * BEAT, kick(), 0.9)
            if b in (1, 3):
                add(buf, t0 + b * BEAT, noise(0.18, 0.05, rng), 0.22)
            for h in (0.5,):
                add(buf, t0 + (b + h) * BEAT, noise(0.05, 0.012, rng), 0.08, pan=0.3)
            for e in (0, 0.5):
                add(buf, t0 + (b + e) * BEAT, bass(root + (12 if e else 0), BEAT / 2), 0.28)
    for t in taps:
        add(buf, t, pop(), 0.35)
    buf = buf[: int(seconds * RATE)]
    fade = int(min(1.0, seconds / 4) * RATE)
    buf[-fade:] *= np.linspace(1, 0, fade)[:, None]
    buf = np.tanh(buf * 1.2)
    return buf / max(1e-9, np.abs(buf).max()) * 0.89


def write(path, buf):
    data = (buf * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


if __name__ == '__main__':
    seconds, out, *taps = sys.argv[1:]
    write(out, render(float(seconds), [float(t) for t in taps]))
