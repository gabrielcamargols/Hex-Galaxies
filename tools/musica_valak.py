"""Hex Galaxies - trilha de batalha de Valak, 'Ferrugem e Maré' (sintetizada, loop sem emenda).

Clima: planeta oceano, posto de mineração abandonado. Ondas, sirene de neblina, metal
enferrujado como percussão, gotas, marimba misteriosa e uma melodia de flauta melancólica
que vira tensão de batalha. Mi menor, 84 BPM, 32 compassos.
  1-8   mar e neblina: ondas, sirene grave, gotas, marimba sozinha
  9-16  a mina acorda: percussão de metal, bumbo abafado, baixo
  17-24 batalha: flauta com o tema, cordas tensas, bigornas
  25-32 maré baixa: tudo recua, só marimba, ondas e a sirene
Uso: python tools/musica_valak.py [saida.ogg]   (precisa de ffmpeg)
"""
import os, sys, wave, subprocess
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt

SR = 32000
BPM = 84
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 32
LEN = BARS * BAR
TAIL = 5.0
N = int((LEN + TAIL) * SR)
rng = np.random.default_rng(77)
L = np.zeros(N)
R = np.zeros(N)
SEND = np.zeros(N)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def filt(x, kind, f, order=2):
    if kind == "band":
        sos = butter(order, f, "band", fs=SR, output="sos")
    else:
        sos = butter(order, min(f, SR / 2 * 0.95), kind, fs=SR, output="sos")
    return sosfilt(sos, x)


def add(sig, t0, gain=1.0, pan=0.0, rev=0.3):
    i = int(t0 * SR)
    if i >= N:
        return
    j = min(N, i + len(sig))
    s = sig[:j - i] * gain
    L[i:j] += s * np.sqrt(0.5 * (1 - pan))
    R[i:j] += s * np.sqrt(0.5 * (1 + pan))
    SEND[i:j] += s * rev


def env(n, a, r):
    t = np.arange(n) / SR
    d = n / SR
    return np.clip(t / max(a, 1e-4), 0, 1) * np.clip((d - t) / max(r, 1e-4), 0, 1)


def saw(freq, n, det=0.0):
    t = np.arange(n) / SR
    out = np.zeros(n)
    for d in ([-det, 0, det] if det else [0]):
        f = freq * 2 ** (d / 12)
        ph = 2 * np.pi * f * t + rng.random() * 6.28
        k = 1
        while k * f < SR / 2.2 and k < 36:
            out += np.sin(ph * k) / k
            k += 1
    return out / (3 if det else 1)


# Mi m - Dó - Ré - Si m (2 compassos cada)
PROG = [(40, [64, 67, 71]), (36, [64, 67, 72]), (38, [62, 66, 69]), (35, [62, 66, 71])]


def chord_at(bar):
    return PROG[(bar // 2) % 4]


def T(bar, beat=0.0):
    return bar * BAR + beat * BEAT


# ---------------- instrumentos ----------------
def waves():
    """mar: ruído filtrado que sobe e desce como ondas, em loop perfeito"""
    t = np.arange(N) / SR
    x = rng.normal(size=N)
    low = filt(x, "low", 500)
    hi = filt(x, "band", [900, 3500])
    sw = 0.5 + 0.5 * np.sin(2 * np.pi * t / (BAR * 2) - 1.2)
    sw2 = 0.5 + 0.5 * np.sin(2 * np.pi * t / (BAR * 2) * 1.0 + 0.6)
    yl = low * (0.35 + 0.65 * sw ** 2) + hi * sw ** 4 * 0.35
    yr = low * (0.35 + 0.65 * sw2 ** 2) + hi * sw2 ** 4 * 0.35
    L[:] += yl * 0.07
    R[:] += yr * 0.07
    SEND[:] += (yl + yr) * 0.01


def foghorn(t0, m, gain):
    n = int(3.2 * SR)
    tt = np.arange(n) / SR
    y = saw(hz(m), n, 0.05) + saw(hz(m + 7), n, 0.04) * 0.4
    y = filt(y, "low", 520) * (1 + 0.08 * np.sin(2 * np.pi * 3.5 * tt))
    add(np.tanh(y * 1.5) * env(n, 0.5, 1.4), t0, gain, rng.uniform(-0.5, 0.5), 1.0)


def drip(t0, gain, pan):
    n = int(0.25 * SR)
    tt = np.arange(n) / SR
    f = 1400 + 1800 * np.exp(-tt * 40) + rng.uniform(-200, 300)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 28)
    add(y, t0, gain, pan, 0.9)


def marimba(m, t0, gain, pan):
    n = int(1.4 * SR)
    tt = np.arange(n) / SR
    f = hz(m)
    y = np.sin(2 * np.pi * f * tt) * np.exp(-tt * 3.2) + 0.35 * np.sin(2 * np.pi * f * 3.93 * tt) * np.exp(-tt * 12) \
        + 0.15 * np.sin(2 * np.pi * f * 9.2 * tt) * np.exp(-tt * 30)
    y *= 1 + 0.15 * np.sin(2 * np.pi * 5.5 * tt)
    add(y, t0, gain, pan, 0.55)
    add(y * 0.3, t0 + BEAT * 0.75, gain, -pan, 0.7)


def anvil(t0, gain, pitch=1.0):
    """metal enferrujado: parciais inarmônicos"""
    n = int(1.2 * SR)
    tt = np.arange(n) / SR
    y = np.zeros(n)
    for p, d, a in ((1.0, 5, 1.0), (2.76, 8, 0.6), (5.4, 13, 0.4), (8.93, 20, 0.25), (13.3, 30, 0.15)):
        y += np.sin(2 * np.pi * 420 * pitch * p * tt + rng.random() * 6) * np.exp(-tt * d) * a
    y += filt(rng.normal(size=n), "band", [2000, 8000]) * np.exp(-tt * 60) * 0.5
    add(y, t0, gain, rng.uniform(-0.4, 0.4), 0.5)


def pipe(t0, gain, pan):
    n = int(0.35 * SR)
    tt = np.arange(n) / SR
    y = (np.sin(2 * np.pi * 760 * tt) + np.sin(2 * np.pi * 1130 * tt) * 0.7) * np.exp(-tt * 22)
    y += filt(rng.normal(size=n), "band", [3000, 9000]) * np.exp(-tt * 80) * 0.6
    add(y, t0, gain, pan, 0.3)


def kick(t0, gain):
    n = int(0.6 * SR)
    tt = np.arange(n) / SR
    f = 45 + 70 * np.exp(-tt * 25)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 7)
    add(filt(y, "low", 300), t0, gain, 0, 0.15)


def chain(t0, gain):
    """corrente / sucata arrastada"""
    n = int(0.5 * SR)
    tt = np.arange(n) / SR
    y = np.zeros(n)
    for k in range(9):
        s = int(rng.uniform(0, 0.42) * SR)
        m = int(0.02 * SR)
        y[s:s + m] += filt(rng.normal(size=m), "band", [2500, 7000]) * np.exp(-np.arange(m) / SR * 150)
    add(y, t0, gain, rng.uniform(-0.5, 0.5), 0.4)


def bass(m, t0, dur, gain):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    y = filt(saw(hz(m), n), "low", 350) * 0.8 + np.sin(2 * np.pi * hz(m) * tt) * 0.6
    add(y * env(n, 0.01, 0.1) * np.exp(-tt * 1.6), t0, gain, 0, 0.05)


def strings(notes, t0, dur, gain):
    n = int((dur + 1.2) * SR)
    tt = np.arange(n) / SR
    y = np.zeros(n)
    for m in notes:
        y += saw(hz(m), n, 0.1)
    y = filt(y, "low", 1600) * (0.7 + 0.3 * np.sin(2 * np.pi * tt / (BEAT * 2)))   # tremor tenso
    add(y * env(n, 0.9, 1.1), t0, gain, rng.uniform(-0.3, 0.3), 0.7)


def flute(notes, t0, gain):
    """flauta/assobio melancólico com sopro"""
    total = sum(d for _, d in notes)
    n = int((total * BEAT + 1.0) * SR)
    f = np.zeros(n)
    amp = np.zeros(n)
    pos = 0
    prev = hz(notes[0][0])
    for m, d in notes:
        k = int(d * BEAT * SR)
        if m is None:
            amp[pos:pos + k] = 0
        else:
            tgt = hz(m)
            g = np.minimum(1, np.arange(k) / (0.05 * SR))
            f[pos:pos + k] = prev + (tgt - prev) * g
            a = np.minimum(1, np.arange(k) / (0.06 * SR)) * np.clip((k - np.arange(k)) / (0.08 * SR), 0, 1)
            amp[pos:pos + k] = a
            prev = tgt
        pos += k
    f[pos:] = prev
    tt = np.arange(n) / SR
    vib = 1 + 0.008 * np.sin(2 * np.pi * 5.0 * tt)
    ph = 2 * np.pi * np.cumsum(np.maximum(f, 20) * vib) / SR
    y = np.sin(ph) + 0.12 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)
    breath = filt(rng.normal(size=n), "band", [1500, 5000]) * 0.12
    add((y + breath) * amp, t0, gain, 0.2, 0.8)


# ---------------- arranjo ----------------
waves()
for bar in range(BARS):
    root, ch = chord_at(bar)
    sec = bar // 8
    # marimba sempre: arpejo misterioso em colcheias
    pat = [ch[0], ch[2], ch[1] + 12, ch[2], ch[0] + 12, ch[2], ch[1] + 12, ch[2] + 12]
    for i in range(8):
        if sec == 0 and i % 2 == 1:
            continue
        marimba(pat[i] - 12 if sec == 3 else pat[i], T(bar, i * 0.5), 0.07 if sec != 2 else 0.06, -0.4 if i % 2 else 0.4)
    # gotas aleatórias
    for k in range(rng.integers(1, 4)):
        drip(T(bar, rng.uniform(0, 4)), 0.05, rng.uniform(-0.8, 0.8))
    # sirene de neblina
    if bar % 8 == 0:
        foghorn(T(bar, 0.5), 28 if sec != 2 else 31, 0.14)
    if sec in (1, 2):
        kick(T(bar, 0), 0.5)
        kick(T(bar, 2.5), 0.4)
        if sec == 2:
            kick(T(bar, 1.5), 0.3)
        for b in (1, 3):
            anvil(T(bar, b), 0.07 if sec == 1 else 0.1, 1.0 if b == 1 else 1.19)
        for i in range(8):
            if rng.random() < 0.7:
                pipe(T(bar, i * 0.5 + 0.25), 0.025 + (0.015 if i % 2 else 0), -0.6 if i % 2 else 0.6)
        if bar % 2 == 1:
            chain(T(bar, 3.5), 0.06)
        for b, d in ((0, 1.5), (1.5, 1.0), (2.5, 1.5)):
            bass(root, T(bar, b), BEAT * d, 0.22)
    if sec == 2 and bar % 2 == 0:
        strings([ch[0] - 12, ch[1] - 12, ch[2] - 12], T(bar), BAR * 2, 0.045)
    if sec == 3 and bar % 2 == 0:
        bass(root, T(bar, 0), BEAT * 3, 0.15)

# tema da flauta (batalha) e eco no fim
THEME = [(71, 1.5), (72, 0.5), (71, 1), (67, 1), (64, 3), (None, 1),
         (67, 1.5), (69, 0.5), (67, 1), (64, 1), (62, 3), (None, 1),
         (64, 1), (66, 1), (67, 1), (69, 1), (71, 2), (74, 2),
         (73, 1.5), (71, 0.5), (69, 1), (66, 1), (71, 4)]
flute(THEME, T(16), 0.11)
flute(THEME[:12], T(24), 0.07)
flute([(64, 3), (67, 1), (66, 4), (None, 4), (64, 3), (62, 1), (59, 4)], T(4), 0.06)

# ---------------- mixagem ----------------
ir_n = int(3.6 * SR)
irt = np.arange(ir_n) / SR
ir = rng.normal(size=ir_n) * np.exp(-irt * 1.5)
ir = filt(ir, "low", 4500)
ir /= np.sqrt(np.sum(ir ** 2))
wl = fftconvolve(SEND, ir)[:N]
wr = fftconvolve(SEND, np.roll(ir, 131))[:N]
outL = L + wl * 0.55
outR = R + wr * 0.55
n_loop = int(LEN * SR)
st = []
for chn in (outL, outR):
    y = chn[:n_loop].copy()
    tail = chn[n_loop:]
    y[:len(tail)] += tail
    st.append(y)
st = np.stack(st, -1)
st = np.tanh(st / np.max(np.abs(st)) * 1.3) * 0.85

dst = sys.argv[1] if len(sys.argv) > 1 else "sounds/musica_valak.ogg"
tmp = dst + ".tmp.wav"
with wave.open(tmp, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((st * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", dst], check=True)
os.remove(tmp)
print("ok", dst, round(LEN, 1), "s")
