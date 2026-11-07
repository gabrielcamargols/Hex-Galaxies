"""Hex Galaxies - trilha de tensão (toca por cima da música do mapa quando um comandante
fica com metade da Vida ou menos). Tambores graves, pulso de baixo e um alarme distante.

Uso: python tools/musica_tensao.py [pasta_sounds]
"""
import os, sys, subprocess
import numpy as np

SR = 44100
BPM = 112
BEAT = 60.0 / BPM
BARS = 4
N = int(SR * BEAT * 4 * BARS)
t = np.arange(N) / SR
out = np.zeros(N)
rng = np.random.default_rng(7)


def add(x, start):
    i = int(start * SR)
    j = min(N, i + len(x))
    out[i:j] += x[: j - i]


def taiko(f0=55.0, d=0.6, amp=1.0):
    n = int(SR * d)
    tt = np.arange(n) / SR
    f = f0 * (1.0 + 1.5 * np.exp(-tt * 30))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 6)
    hit = rng.normal(0, 1, n) * np.exp(-tt * 60) * 0.35
    return (body + hit) * amp


def tick(d=0.08, amp=0.25):
    n = int(SR * d)
    tt = np.arange(n) / SR
    return rng.normal(0, 1, n) * np.exp(-tt * 70) * amp


for bar in range(BARS):
    b0 = bar * 4 * BEAT
    for k, (pos, f, a) in enumerate([(0, 50, 1.0), (1.5, 62, 0.6), (2, 50, 0.9), (3, 70, 0.55), (3.5, 62, 0.7)]):
        add(taiko(f, 0.7, a), b0 + pos * BEAT)
    for s8 in range(8):
        add(tick(amp=0.18 if s8 % 2 else 0.3), b0 + s8 * BEAT / 2)
# pulso de baixo em colcheias, subindo de intensidade ao longo do loop
bass_f = 41.2
env = np.zeros(N)
for e in range(BARS * 8):
    i = int(e * BEAT / 2 * SR)
    seg = np.arange(min(N - i, int(BEAT / 2 * SR))) / SR
    env[i:i + len(seg)] = np.exp(-seg * 7)
out += np.tanh(2.2 * np.sin(2 * np.pi * bass_f * t)) * env * 0.35 * (0.7 + 0.3 * t / t[-1])
# alarme distante (duas notas, bem baixo)
alarm = (np.sin(2 * np.pi * 440 * t) * (np.floor(t / (BEAT * 2)) % 2 == 0) + np.sin(2 * np.pi * 415 * t) * (np.floor(t / (BEAT * 2)) % 2 == 1))
alarm *= 0.05 * (0.5 + 0.5 * np.sin(2 * np.pi * t / (BEAT * 2))) ** 2
out += alarm
out /= np.max(np.abs(out)) * 1.15
dst = sys.argv[1] if len(sys.argv) > 1 else "sounds"
wav = os.path.join(dst, "_tensao.wav")
import wave
with wave.open(wav, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((out * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", os.path.join(dst, "tensao_loop.ogg")], check=True)
os.remove(wav)
print("tensao_loop.ogg", round(N / SR, 2), "s")
