"""Trilha original 'Areias de Tarhut' (deserto, clima épico espacial), sintetizada.
Gera WAV estéreo 32 kHz que depois vira OGG. Loop sem emenda de 32 compassos."""
import numpy as np, wave, sys
from scipy.signal import fftconvolve, butter, sosfilt

SR = 32000
BPM = 72
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 32
LEN = BARS * BAR
TAIL = 4.0
N = int((LEN + TAIL) * SR)
rng = np.random.default_rng(11)
L = np.zeros(N)
R = np.zeros(N)


def f(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def lp(x, cut, order=2):
    sos = butter(order, min(cut, SR / 2 * 0.95), "low", fs=SR, output="sos")
    return sosfilt(sos, x)


def hp(x, cut, order=2):
    sos = butter(order, cut, "high", fs=SR, output="sos")
    return sosfilt(sos, x)


def bp(x, lo, hi):
    sos = butter(2, [lo, hi], "band", fs=SR, output="sos")
    return sosfilt(sos, x)


def add(sig, t0, gain=1.0, pan=0.0):
    i = int(t0 * SR)
    j = min(N, i + len(sig))
    if j <= i:
        return
    gl = gain * np.cos((pan + 1) * np.pi / 4)
    gr = gain * np.sin((pan + 1) * np.pi / 4)
    L[i:j] += sig[: j - i] * gl
    R[i:j] += sig[: j - i] * gr


def adsr(n, a, d, s, r):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na)
    nd = min(nd, n - na)
    e[na:na + nd] = np.linspace(1, s, nd)
    nr = min(nr, n)
    if nr > 0:
        e[n - nr:] *= np.linspace(1, 0, nr)
    return e


def saw(freq, n, detune=0.0, phase=None):
    t = np.arange(n) / SR
    ph = rng.random() if phase is None else phase
    return 2 * ((freq * (1 + detune) * t + ph) % 1) - 1


# ---------------- harmonia ----------------
CH = {
    "D5": [38, 45, 50, 57, 62],
    "Gm": [43, 50, 55, 58, 62],
    "D": [38, 50, 54, 57, 62],
    "Bb": [46, 50, 53, 58, 62],
    "Eb": [39, 51, 55, 58, 63],
    "A": [45, 52, 57, 61, 64],
}
PROG = ["D5", "Gm", "D", "D5", "Bb", "Gm", "Eb", "A"]


def strings(chord, t0, dur, gain, bright):
    n = int((dur + 1.2) * SR)
    out = np.zeros(n)
    for m in CH[chord][1:]:
        v = np.zeros(n)
        for dt in (-0.006, -0.002, 0.003, 0.007):
            v += saw(f(m), n, dt)
        out += v
    out = lp(out, bright)
    env = adsr(n, 0.9, 0.3, 0.85, 1.4)
    trem = 1 + 0.05 * np.sin(2 * np.pi * 4.6 * np.arange(n) / SR)
    sig = out * env * trem / 14
    add(sig, t0, gain, -0.35)
    add(np.roll(sig, int(0.011 * SR)), t0, gain, 0.35)


def bass(chord, t0, dur, gain):
    n = int((dur + 0.8) * SR)
    m = CH[chord][0]
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f(m) * t) + 0.5 * lp(saw(f(m), n), 300)
    x += 0.4 * np.sin(2 * np.pi * f(m - 12) * t)
    add(x * adsr(n, 0.6, 0.2, 0.9, 0.9) * 0.35, t0, gain, 0)


def oboe(m, t0, dur, gain, pan=0.15):
    n = int((dur + 0.25) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.3 * t) * np.clip(t / 0.35, 0, 1)
    ph = np.cumsum(f(m) * vib) / SR
    x = 2 * (ph % 1) - 1
    x = np.sign(x) * np.abs(x) ** 0.7
    x = bp(x, 700, 1700) * 1.4 + lp(x, 2600) * 0.4
    add(x * adsr(n, 0.07, 0.15, 0.8, 0.22) * 0.33, t0, gain, pan)


def horn(m, t0, dur, gain, pan=-0.2):
    n = int((dur + 0.4) * SR)
    t = np.arange(n) / SR
    x = sum(saw(f(m), n, d) for d in (-0.003, 0.0, 0.004))
    swell = np.clip(t / 0.25, 0, 1)
    x = lp(x * 0.5, 450 + 1300 * swell[-1]) * 0.6 + lp(x * 0.5, 900) * 0.4
    add(x * adsr(n, 0.18, 0.25, 0.75, 0.35) * 0.3, t0, gain, pan)
    add(x * adsr(n, 0.18, 0.25, 0.75, 0.35) * 0.18, t0, gain * 0.8, pan + 0.4)


def harp(m, t0, gain, pan):
    n = int(2.2 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in range(1, 9):
        x += np.sin(2 * np.pi * f(m) * k * t) * np.exp(-t * (1.4 + k * 0.9)) / k ** 1.2
    x *= np.clip(t / 0.003, 0, 1)
    add(x * 0.22, t0, gain, pan)


def drum(t0, gain, pitch=70):
    n = int(1.3 * SR)
    t = np.arange(n) / SR
    fr = pitch * (1 + 0.6 * np.exp(-t * 18))
    x = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t * 4.0)
    x += lp(rng.uniform(-1, 1, n), 900) * np.exp(-t * 22) * 0.6
    add(x * 0.6, t0, gain, 0)


def shaker(t0, gain, pan):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    x = hp(rng.uniform(-1, 1, n), 5000) * np.exp(-t * 45)
    add(x * 0.12, t0, gain, pan)


def wind_bed():
    n = N
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    g = 0.6 + 0.4 * np.sin(2 * np.pi * 0.05 * t) * np.sin(2 * np.pi * 0.031 * t + 1)
    x = bp(noise, 250, 900) * g * 0.05
    add(x, 0, 1.0, -0.3)
    add(np.roll(x, 7000), 0, 1.0, 0.3)


# ---------------- arranjo ----------------
wind_bed()
for b in range(BARS):
    t0 = b * BAR
    ch = PROG[b % 8]
    sec = b // 8  # 0 intro, 1 oboé, 2 trompas, 3 clímax/volta
    sg = [0.55, 0.7, 0.85, 0.75][sec] * (0.7 if b >= 30 else 1.0)
    strings(ch, t0, BAR, sg, [900, 1300, 1900, 1500][sec])
    bass(ch, t0, BAR, [0.8, 0.9, 1.0, 0.9][sec])
    # tambores: 1 e 3 (mais na seção das trompas)
    if b >= 2:
        drum(t0, [0.35, 0.45, 0.7, 0.5][sec], 68)
        drum(t0 + 2 * BEAT, [0.25, 0.3, 0.5, 0.35][sec], 82)
        if sec == 2 and b % 2 == 1:
            for k in range(4):
                drum(t0 + 3 * BEAT + k * BEAT / 4, 0.18 + 0.06 * k, 95)
    if b >= 4:
        for k in range(8):
            shaker(t0 + k * BEAT / 2 + (0.03 if k % 2 else 0), 0.6 if k % 2 == 0 else 0.35, 0.5)
    # harpa: arpejo em colcheias
    if b >= 4:
        notes = CH[ch][1:] + [CH[ch][2] + 12]
        for k in range(8):
            m = notes[[0, 2, 1, 3, 4, 3, 2, 1][k]] + 12
            harp(m, t0 + k * BEAT / 2, 0.55 if sec != 2 else 0.4, -0.5 + 0.12 * k)

# melodia (oboé) - frase A e B, em batidas
PA = [(69, 2), (70, 1), (69, 1), (67, 1.5), (66, 0.5), (67, 1), (69, 1), (66, 2), (63, 1), (62, 1), (62, 4)]
PB = [(74, 2), (72, 1), (70, 1), (69, 1.5), (70, 0.5), (69, 1), (67, 1), (66, 1), (67, 1), (69, 1), (70, 1), (69, 4)]


def phrase(notes, t0, fn, transpose=0, gain=1.0):
    t = t0
    for m, d in notes:
        fn(m + transpose, t, d * BEAT * 0.97, gain)
        t += d * BEAT


phrase(PA, 8 * BAR, oboe)
phrase(PB, 12 * BAR, oboe)
# trompas: chamado heroico em quintas
HA = [(57, 3), (62, 1), (57, 2), (55, 1), (54, 1), (57, 1.5), (58, 0.5), (57, 1), (55, 1), (54, 3), (50, 1)]
HB = [(62, 3), (60, 1), (58, 2), (57, 1), (55, 1), (54, 1), (55, 1), (57, 1), (58, 1), (57, 4)]
phrase(HA, 16 * BAR, horn)
phrase(HA, 16 * BAR, horn, -5, 0.5)
phrase(HB, 20 * BAR, horn)
phrase(HB, 20 * BAR, horn, -12, 0.45)
# clímax: oboé uma oitava acima + trompa grave
phrase(PA, 24 * BAR, oboe, 12, 0.8)
phrase(PA, 24 * BAR, horn, -12, 0.35)
phrase(PB, 28 * BAR, oboe, 0, 0.9)

# ---------------- reverb e mixagem ----------------
irn = int(2.8 * SR)
ti = np.arange(irn) / SR
for ch in (0, 1):
    ir = rng.uniform(-1, 1, irn) * np.exp(-ti * 2.3)
    ir = lp(ir, 3500)
    ir[0] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    src = L if ch == 0 else R
    wet = fftconvolve(src, ir)[:N] * 0.38
    if ch == 0:
        L = src * 0.8 + wet
    else:
        R = src * 0.8 + wet

# loop sem emenda: a cauda volta para o início
nl = int(LEN * SR)
out = np.stack([L, R], axis=1)
loop = out[:nl].copy()
loop[: N - nl] += out[nl:]
loop = hp(loop.T, 30).T
loop /= np.max(np.abs(loop)) / 0.8

path = sys.argv[1] if len(sys.argv) > 1 else "musica_deserto.wav"
with wave.open(path, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((loop * 32767).astype(np.int16).tobytes())
print("ok", LEN, "s")
