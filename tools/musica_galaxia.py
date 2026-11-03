"""Hex Galaxies - trilha do menu 'Guerra entre Galáxias' (sintetizada, loop sem emenda).

Clima: espaço profundo, aliens e guerra galáctica. Ré menor, 96 BPM, 32 compassos (80 s).
  1-8   abertura: coro distante, drone grave, lead alienígena (teremim) e pulsos
  9-16  arpejo de sintetizador, tambores de guerra (taiko) e baixo em ostinato
  17-24 tema heroico nos metais, caixa marcial, coro cheio e explosões distantes
  25-32 o alien volta, tambores mais leves, subida que fecha o loop
Uso: python tools/musica_galaxia.py [saida.ogg]   (precisa de ffmpeg)
"""
import os, sys, wave, subprocess
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt

SR = 32000
BPM = 96
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 32
LEN = BARS * BAR
TAIL = 5.0
N = int((LEN + TAIL) * SR)
rng = np.random.default_rng(42)
L = np.zeros(N)
R = np.zeros(N)
SEND = np.zeros(N)   # envio para a reverberação


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


def env(n, a, r, hold=None):
    t = np.arange(n) / SR
    e = np.clip(t / max(a, 1e-4), 0, 1)
    d = n / SR
    return e * np.clip((d - t) / max(r, 1e-4), 0, 1)


def saw(freq, n, det=0.0):
    t = np.arange(n) / SR
    out = np.zeros(n)
    for d in ([-det, 0, det] if det else [0]):
        f = freq * 2 ** (d / 12)
        ph = 2 * np.pi * f * t + rng.random() * 6.28
        k = 1
        while k * f < SR / 2.2 and k < 40:
            out += np.sin(ph * k) / k
            k += 1
    return out / (3 if det else 1)


# progressão: Ré m - Si♭ - Sol m - Lá (2 compassos cada)
PROG = [(50, [62, 65, 69]), (46, [62, 65, 70]), (43, [62, 67, 70]), (45, [61, 64, 69])]


def chord_at(bar):
    return PROG[(bar // 2) % 4]


# ---------------- instrumentos ----------------
def choir(notes, t0, dur, gain):
    n = int((dur + 1.5) * SR)
    t = np.arange(n) / SR
    voice = np.zeros(n)
    for m in notes:
        f = hz(m) * (1 + 0.004 * np.sin(2 * np.pi * 5.2 * t + rng.random() * 6))
        ph = 2 * np.pi * np.cumsum(f) / SR
        src = np.zeros(n)
        for k in range(1, 18):
            src += np.sin(ph * k) / k
        voice += src
    y = filt(voice, "band", [600, 900]) * 1.0 + filt(voice, "band", [1050, 1400]) * 0.6 + filt(voice, "band", [2400, 2900]) * 0.25
    add(y * env(n, 1.2, 1.5), t0, gain, rng.uniform(-0.3, 0.3), 0.8)


def drone(m, t0, dur, gain):
    n = int((dur + 1) * SR)
    t = np.arange(n) / SR
    y = saw(hz(m), n, 0.08)
    cut = 250 + 180 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 7.0))
    y = filt(y, "low", 380) * 0.7 + np.sin(2 * np.pi * hz(m - 12) * t) * 0.5
    add(y * env(n, 2.0, 1.0), t0, gain, 0, 0.4)


def arp_note(m, t0, gain, pan):
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    y = saw(hz(m), n, 0.06)
    y = filt(y, "low", 2600) * np.exp(-t * 9) + filt(y, "low", 900) * np.exp(-t * 3) * 0.4
    add(y, t0, gain, pan, 0.35)
    add(y * 0.35, t0 + BEAT * 0.75, gain, -pan, 0.5)   # eco


def bass_note(m, t0, dur, gain):
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = filt(saw(hz(m), n), "low", 420) + np.sin(2 * np.pi * hz(m - 12) * t) * 0.8
    add(y * env(n, 0.005, 0.06) * np.exp(-t * 2.5), t0, gain, 0, 0.05)


def taiko(t0, gain, big=False):
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    f = 52 + 90 * np.exp(-t * 18)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * (4 if big else 6.5))
    skin = filt(rng.normal(size=n), "band", [200, 1800]) * np.exp(-t * 40) * 0.5
    add((body + skin) * (1.4 if big else 1.0), t0, gain, rng.uniform(-0.15, 0.15), 0.5)


def snare(t0, gain):
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    y = filt(rng.normal(size=n), "band", [1500, 7000]) * np.exp(-t * 18) + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * 0.6
    add(y, t0, gain, 0.1, 0.4)


def brass(m, t0, dur, gain):
    n = int((dur + 0.4) * SR)
    t = np.arange(n) / SR
    y = saw(hz(m), n, 0.09) + saw(hz(m - 12), n, 0.05) * 0.5
    op = np.clip(t / 0.12, 0, 1)
    y = filt(y, "low", 900) * (1 - op * 0.6) + filt(y, "low", 3200) * op * 0.8
    add(np.tanh(y * 1.3) * env(n, 0.05, 0.35), t0, gain, rng.uniform(-0.2, 0.2), 0.45)


def alien(notes, t0, gain):
    """lead tipo teremim: senoide com glissando entre notas e vibrato que cresce"""
    total = sum(d for _, d in notes)
    n = int((total * BEAT + 1.2) * SR)
    f = np.zeros(n)
    pos = 0
    prev = hz(notes[0][0])
    for m, d in notes:
        k = int(d * BEAT * SR)
        tgt = hz(m)
        g = np.minimum(1, np.arange(k) / (0.12 * SR))
        f[pos:pos + k] = prev + (tgt - prev) * g
        prev = tgt
        pos += k
    f[pos:] = prev
    t = np.arange(n) / SR
    vib = 1 + 0.012 * np.sin(2 * np.pi * 6.0 * t) * np.clip(t % (BEAT * 2) / 0.8, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    y = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    y *= 1 + 0.25 * np.sin(2 * np.pi * 0.7 * t)
    add(y * env(n, 0.3, 1.0), t0, gain, -0.25, 0.9)


def laser(t0, gain, pan):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 2400 * np.exp(-t * 9) + 180
    y = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * np.exp(-t * 10)
    add(filt(y, "low", 4000) * 0.5, t0, gain, pan, 0.7)


def boom(t0, gain):
    n = int(2.2 * SR)
    t = np.arange(n) / SR
    y = filt(rng.normal(size=n), "low", 220) * np.exp(-t * 2.2) * 2.0 + np.sin(2 * np.pi * 38 * t) * np.exp(-t * 3)
    add(y, t0, gain, rng.uniform(-0.6, 0.6), 0.9)


def riser(t0, dur, gain):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = rng.normal(size=n)
    y = np.zeros(n)
    for i in range(8):
        a, b = i * n // 8, (i + 1) * n // 8
        c = 400 + 5000 * (i / 8) ** 2
        y[a:b] = filt(x, "band", [c, c * 1.6])[a:b]
    add(y * (t / dur) ** 2, t0, gain, 0, 0.8)


# ---------------- arranjo ----------------
def T(bar, beat=0.0):
    return bar * BAR + beat * BEAT


for bar in range(BARS):
    root, ch = chord_at(bar)
    sec = bar // 8           # 0 abertura, 1 arpejo, 2 tema, 3 retorno
    if bar % 2 == 0:
        choir([n - 12 for n in ch] + [ch[0]], T(bar), BAR * 2, 0.055 if sec in (0, 3) else 0.08)
        drone(root - 12, T(bar), BAR * 2, 0.18 if sec != 2 else 0.12)
    # pulsos graves na abertura
    if sec == 0:
        for b in (0, 2.5):
            bass_note(root - 12, T(bar, b), BEAT * 1.2, 0.18)
        if bar % 4 == 3:
            taiko(T(bar, 3), 0.35)
    # arpejo de 16 avos
    if sec in (1, 2, 3):
        notes = [ch[0], ch[1], ch[2], ch[0] + 12, ch[2], ch[1] + 12, ch[2] + 12, ch[1] + 12]
        for i in range(16):
            arp_note(notes[i % 8], T(bar, i * 0.25), 0.05 if sec != 3 else 0.035, -0.5 if i % 2 else 0.5)
        for i in range(8):   # baixo em colcheias
            bass_note(root - 12 if i % 4 else root - 24 + 12, T(bar, i * 0.5), BEAT * 0.45, 0.16)
    # tambores de guerra
    if sec in (1, 2):
        for b, big in ((0, True), (0.75, False), (1.5, False), (2, True), (3, False), (3.5, False)):
            taiko(T(bar, b), 0.32 if big else 0.22, big)
    if sec == 3:
        for b in (0, 2):
            taiko(T(bar, b), 0.22, True)
    if sec == 2:
        snare(T(bar, 1), 0.16)
        snare(T(bar, 3), 0.16)
        if bar % 4 == 3:
            for i in range(8):
                snare(T(bar, 2 + i * 0.25), 0.05 + i * 0.012)
        if bar % 4 == 1:
            boom(T(bar, 0.5), 0.12)
    # tiros de laser distantes (guerra lá fora)
    if sec >= 1 and rng.random() < 0.55:
        for k in range(rng.integers(1, 4)):
            laser(T(bar, rng.uniform(0, 4)), 0.035, rng.uniform(-0.8, 0.8))

# lead alienígena (abertura e retorno)
A1 = [(74, 3), (72, 1), (69, 4), (70, 2), (69, 2), (67, 4), (69, 3), (73, 1), (76, 4), (74, 8)]
alien(A1, T(0, 2), 0.09)
alien(A1, T(24, 2), 0.08)
# tema heroico nos metais (compassos 17-24)
THEME = [(62, 1.5), (69, 0.5), (69, 2), (70, 1), (69, 1), (67, 1), (65, 1),
         (62, 1.5), (65, 0.5), (67, 2), (69, 4),
         (70, 1.5), (69, 0.5), (67, 2), (65, 1), (64, 1), (62, 1), (64, 1),
         (65, 1.5), (64, 0.5), (61, 2), (62, 4)]
t = T(16)
for m, d in THEME:
    brass(m, t, d * BEAT * 0.95, 0.07)
    brass(m - 12, t, d * BEAT * 0.95, 0.04)
    t += d * BEAT
# transições
riser(T(7, 0), BAR, 0.05)
riser(T(15, 0), BAR, 0.06)
riser(T(31, 0), BAR, 0.05)
boom(T(16), 0.16)
boom(T(8), 0.1)

# ---------------- mixagem ----------------
ir_n = int(3.2 * SR)
irt = np.arange(ir_n) / SR
ir = rng.normal(size=ir_n) * np.exp(-irt * 1.8)
ir = filt(ir, "low", 5000)
ir /= np.sqrt(np.sum(ir ** 2))
wl = fftconvolve(SEND, ir)[:N]
wr = fftconvolve(SEND, np.roll(ir, 113))[:N]
outL = L + wl * 0.5
outR = R + wr * 0.5
n_loop = int(LEN * SR)
st = []
for ch in (outL, outR):
    y = ch[:n_loop].copy()
    tail = ch[n_loop:]
    y[:len(tail)] += tail
    st.append(y)
st = np.stack(st, -1)
st = np.tanh(st / np.max(np.abs(st)) * 1.4) * 0.85

dst = sys.argv[1] if len(sys.argv) > 1 else "sounds/musica_galaxia.ogg"
tmp = dst + ".tmp.wav"
with wave.open(tmp, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((st * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", dst], check=True)
os.remove(tmp)
print("ok", dst, round(LEN, 1), "s")
