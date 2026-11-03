"""Hex Galaxies - música ambiente espacial do menu (loop sem emenda de 48 s).

Pads suaves com acordes lentos, baixo grave, sininhos de estrelas com eco e reverberação.
Uso: python tools/musica_espaco.py [saida.ogg]   (precisa de ffmpeg para gerar o .ogg)
"""
import os, sys, subprocess, wave
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt

SR = 32000
L = 48.0
TAIL = 7.0
rng = np.random.default_rng(7)
N = int(SR * (L + TAIL))
t = np.arange(N) / SR


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def lp(x, f):
    return sosfilt(butter(2, f, "low", fs=SR, output="sos"), x)


CHORDS = [  # (tempo inicial, notas MIDI)
    (0, [45, 57, 60, 64, 71]),    # Lá menor (add9)
    (12, [41, 57, 60, 64, 69]),   # Fá maj7
    (24, [48, 55, 59, 64, 67]),   # Dó maj7
    (36, [40, 55, 59, 62, 66]),   # Mi menor 7 (9)
]


def pad_note(f, start, dur):
    n0 = int(start * SR)
    n = int((dur + 5.0) * SR)
    tt = np.arange(n) / SR
    y = np.zeros(n)
    for det in (-0.12, 0.0, 0.11):
        ff = f * 2 ** (det / 12)
        ph = 2 * np.pi * ff * tt + rng.random() * 6.28
        for k in range(1, 10):
            y += np.sin(ph * k) / k * (0.85 ** k)
    a = np.clip(tt / 3.5, 0, 1)
    r = np.clip((dur + 4.5 - tt) / 4.5, 0, 1)
    y *= a * r * (0.75 + 0.25 * np.sin(2 * np.pi * 0.11 * tt + rng.random() * 6))
    out = np.zeros(N)
    end = min(N, n0 + n)
    out[n0:end] += y[:end - n0]
    return out


pad = np.zeros(N)
bass = np.zeros(N)
for st, notes in CHORDS:
    for m in notes[1:]:
        pad += pad_note(hz(m), st, 12.0) * 0.16
    f = hz(notes[0] - 12)
    n0 = int(st * SR)
    n = int(16 * SR)
    tt = np.arange(n) / SR
    b = np.sin(2 * np.pi * f * tt) * np.clip(tt / 2.0, 0, 1) * np.clip((16 - tt) / 4.0, 0, 1)
    end = min(N, n0 + n)
    bass[n0:end] += b[:end - n0] * 0.35
pad = lp(pad, 1400)

# sininhos de estrelas: notas agudas do acorde atual, com eco
bells = np.zeros(N)
for i in range(70):
    st = rng.random() * L
    notes = [c for c in CHORDS if c[0] <= st][-1][1]
    m = notes[1 + int(rng.random() * 4)] + 24
    f = hz(m)
    n = int(2.5 * SR)
    tt = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * f * 2.76 * tt) * np.exp(-tt * 6)) * np.exp(-tt * 2.2)
    n0 = int(st * SR)
    for e, g in ((0, 1.0), (0.375, 0.45), (0.75, 0.2)):
        a = n0 + int(e * SR)
        end = min(N, a + n)
        if a < N:
            bells[a:end] += y[:end - a] * 0.07 * g * (0.5 + rng.random() * 0.5)

air = lp(rng.normal(size=N), 600) * 0.02 * (0.6 + 0.4 * np.sin(2 * np.pi * t / 16))
mix = pad + bass + bells + air

# reverberação longa
ir_n = int(3.5 * SR)
irt = np.arange(ir_n) / SR
ir = rng.normal(size=ir_n) * np.exp(-irt * 1.6)
ir = lp(ir, 3500)
ir /= np.sqrt(np.sum(ir ** 2))
wetL = fftconvolve(mix, ir)[:N]
wetR = fftconvolve(mix, np.roll(ir, 97))[:N]
L_ch = mix * 0.6 + wetL * 0.55
R_ch = mix * 0.6 + wetR * 0.55

# fecha o loop: a cauda volta para o começo
n_loop = int(L * SR)
out = []
for ch in (L_ch, R_ch):
    y = ch[:n_loop].copy()
    tail = ch[n_loop:]
    y[:len(tail)] += tail
    out.append(y)
st = np.stack(out, -1)
st = st / np.max(np.abs(st)) * 0.8

dst = sys.argv[1] if len(sys.argv) > 1 else "sounds/musica_espaco.ogg"
tmp = dst + ".tmp.wav"
with wave.open(tmp, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((st * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
os.remove(tmp)
print("ok", dst)
