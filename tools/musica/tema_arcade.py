"""Hex Galaxies — tema arcade: chiptune + rock, 150 BPM, Mi menor, loop de 32 compassos."""
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile
import sys

SR = 44100
BPM = 150.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
NBARS = 36
N = int(NBARS * BAR * SR)
rng = np.random.default_rng(7)

def mid(n):  # nota MIDI -> Hz
    return 440.0 * 2 ** ((n - 69) / 12.0)

def lp(x, f):
    return sosfilt(butter(2, f / (SR / 2), 'low', output='sos'), x)

def hp(x, f):
    return sosfilt(butter(2, f / (SR / 2), 'high', output='sos'), x)

def bp(x, lo, hi):
    return sosfilt(butter(2, [lo / (SR / 2), hi / (SR / 2)], 'band', output='sos'), x)

def env(n, a=0.004, d=0.08, s=0.6, r=0.04):
    t = np.arange(n) / SR
    e = np.ones(n) * s
    ai = int(a * SR); di = int(d * SR); ri = int(r * SR)
    e[:ai] = np.linspace(0, 1, ai) if ai else e[:ai]
    if di:
        e[ai:ai + di] = np.linspace(1, s, len(e[ai:ai + di]))
    if ri and n > ri:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e

def pulse(f, n, duty=0.25, vib=0.0, slide_from=None):
    t = np.arange(n) / SR
    ff = np.full(n, f)
    if slide_from is not None:
        k = min(n, int(0.04 * SR))
        ff[:k] = np.linspace(slide_from, f, k)
    if vib:
        ff = ff * (1 + vib * np.sin(2 * np.pi * 6.0 * t) * np.clip((t - 0.12) * 4, 0, 1))
    ph = np.cumsum(ff) / SR
    return np.where((ph % 1.0) < duty, 1.0, -1.0)

def tri(f, n):
    ph = (np.arange(n) * f / SR) % 1.0
    return 4 * np.abs(ph - 0.5) - 1

def saw(f, n, det=0.0):
    ph = (np.arange(n) * f * (1 + det) / SR) % 1.0
    return 2 * ph - 1

def put(buf, start_s, sig, gain=1.0):
    i = int(start_s * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[:j - i] * gain

def crush(x, bits=6):
    q = 2 ** bits
    return np.round(x * q) / q

# ------------------------------------------------------------ harmonia
# Em  C  D  B   (verso)   |  Em  C  G  D  (refrão)
VERSE = [40, 36, 38, 35]
CHORUS = [40, 36, 43, 38]
QUAL = {40: 'm', 36: 'M', 38: 'M', 35: 'M', 43: 'M'}

def chord_tones(root):
    third = 3 if QUAL[root] == 'm' else 4
    return [root, root + third, root + 7]

# seções (compassos): intro 4, verso 8, refrão 8, ponte 4, verso 4, refrão 8 = 36
SECS = [('intro', 4), ('verso', 8), ('refrao', 8), ('ponte', 4), ('verso2', 4), ('refrao2', 8)]
bar_sec = []
for nm, nb in SECS:
    bar_sec += [nm] * nb

def prog(bi):
    sec = bar_sec[bi]
    p = CHORUS if sec.startswith('refrao') else VERSE
    return p[bi % 4]

drums = np.zeros(N); bass = np.zeros(N); gtr = np.zeros(N); lead = np.zeros(N); arp = np.zeros(N); fx = np.zeros(N)

# ------------------------------------------------------------ bateria
def kick():
    n = int(0.28 * SR); t = np.arange(n) / SR
    f = 50 + 120 * np.exp(-t * 28)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    s += 0.5 * np.exp(-t * 120) * rng.uniform(-1, 1, n)
    return np.tanh(s * 2.2)

def snare(big=False):
    n = int((0.42 if big else 0.22) * SR); t = np.arange(n) / SR
    nz = bp(rng.uniform(-1, 1, n), 1200, 9000) * np.exp(-t * (9 if big else 18))
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30)
    s = nz * 1.6 + tone * 0.7
    if big:  # "gated reverb" anos 80
        g = np.ones(n); g[int(0.18 * SR):] = np.linspace(1, 0, n - int(0.18 * SR)) ** 3
        s = s * g
    return np.tanh(s * 1.5)

def hat(open_=False):
    n = int((0.16 if open_ else 0.045) * SR); t = np.arange(n) / SR
    return hp(rng.uniform(-1, 1, n), 7000) * np.exp(-t * (18 if open_ else 80))

def crash():
    n = int(1.6 * SR); t = np.arange(n) / SR
    return hp(rng.uniform(-1, 1, n), 4000) * np.exp(-t * 2.2)

K = kick(); S = snare(); SB = snare(True); H = hat(); HO = hat(True); CR = crash()

for bi in range(NBARS):
    sec = bar_sec[bi]; t0 = bi * BAR
    if sec == 'intro':
        if bi < 2:
            for b in range(4):
                put(drums, t0 + b * BEAT, K, 0.9)
        else:  # caixa acelerando para a entrada
            for k in range(8 if bi == 2 else 16):
                put(drums, t0 + k * BAR / (8 if bi == 2 else 16), S, 0.35 + 0.04 * k)
        continue
    if bar_sec[bi - 1] != sec or bi in (0,):
        put(drums, t0, CR, 0.55)
    if sec == 'ponte':
        # meio-tempo: bumbo no 1, caixa grande no 3
        put(drums, t0, K, 1.0); put(drums, t0 + 2 * BEAT, SB, 0.9)
        for e in range(4):
            put(drums, t0 + e * BEAT, HO, 0.25)
        continue
    big = sec.startswith('refrao')
    kp = [0, 1.5, 2.0, 2.5] if not big else [0, 0.75, 1.5, 2.0, 2.5, 3.25]
    for k in kp:
        put(drums, t0 + k * BEAT, K, 1.0)
    for sn in [1, 3]:
        put(drums, t0 + sn * BEAT, SB if big else S, 0.85)
    for e in range(8):
        put(drums, t0 + e * BEAT / 2, HO if (big and e % 2 == 1) else H, 0.35 if e % 2 == 0 else 0.22)
    if (bi + 1) < NBARS and bar_sec[bi + 1] != sec:  # virada
        for k in range(6):
            put(drums, t0 + 2.5 * BEAT + k * BEAT / 4, S, 0.5 + 0.08 * k)

# ------------------------------------------------------------ baixo (pulso 50%, colcheias, oitavas no refrão)
for bi in range(4, NBARS):
    r = prog(bi) - 12 + 12  # E2 = 40
    sec = bar_sec[bi]; t0 = bi * BAR
    for e in range(8):
        n = r + (12 if (sec.startswith('refrao') and e % 2 == 1) else 0)
        if sec == 'ponte':
            if e % 4: continue
            dur = BEAT * 2
        else:
            dur = BEAT / 2 * 0.92
        ns = int(dur * SR)
        s = pulse(mid(n), ns, 0.5) * env(ns, 0.002, 0.05, 0.75, 0.02)
        put(bass, t0 + e * BEAT / 2, s, 0.55)
bass = lp(bass, 1400)

# ------------------------------------------------------------ guitarra (power chord distorcida)
def power(root, dur, mute):
    ns = int(dur * SR)
    s = np.zeros(ns)
    for iv, g in [(0, 1.0), (7, 0.8), (12, 0.6)]:
        f = mid(root + iv)
        s += g * (saw(f, ns, -0.004) + saw(f, ns, 0.005))
    s = np.tanh(s * 3.5)
    e = env(ns, 0.002, 0.06 if mute else 0.25, 0.25 if mute else 0.75, 0.03)
    return lp(s * e, 2600 if mute else 4200)

for bi in range(4, NBARS):
    sec = bar_sec[bi]; t0 = bi * BAR; r = prog(bi)
    if sec == 'ponte':
        put(gtr, t0, power(r, BAR * 0.95, False), 0.42)
        continue
    if sec.startswith('refrao'):
        # acordes abertos nos tempos, chugs entre
        pat = [(0, 1.5, False), (1.5, 0.5, True), (2, 1.5, False), (3.5, 0.5, True)]
    else:
        # riff galopante: 8avas e 16avas abafadas
        pat = [(k * 0.5, 0.25, True) for k in range(8)] + [(k * 0.5 + 0.25, 0.25, True) for k in (1, 3, 5, 7)]
    for st, du, mu in pat:
        put(gtr, t0 + st * BEAT, power(r - 12 if mu else r, du * BEAT * 0.95, mu), 0.30 if mu else 0.40)
gtr = hp(gtr, 90)

# ------------------------------------------------------------ arpejo chiptune (16avas, triângulo + pulso)
for bi in range(NBARS):
    sec = bar_sec[bi]; t0 = bi * BAR
    if sec in ('verso', 'verso2') or sec == 'intro' or sec == 'ponte':
        tones = chord_tones(prog(bi) if bi >= 4 else VERSE[bi % 4])
        seq = [tones[0] + 24, tones[1] + 24, tones[2] + 24, tones[1] + 24]
        for k in range(16):
            n = seq[k % 4] + (12 if (k // 4) % 2 and sec == 'ponte' else 0)
            ns = int(BEAT / 4 * SR * 0.9)
            s = (0.6 * pulse(mid(n), ns, 0.125) + 0.4 * tri(mid(n), ns)) * env(ns, 0.001, 0.03, 0.4, 0.01)
            put(arp, t0 + k * BEAT / 4, s, 0.20 if sec != 'intro' else 0.17 + 0.02 * bi)

# ------------------------------------------------------------ melodia (pulso 25%, vibrato, glissando)
# (compasso relativo, tempo, duração em tempos, nota)
E4, Fs4, G4, A4, B4, C5, D5, E5, Fs5, G5, A5, B5 = 64, 66, 67, 69, 71, 72, 74, 76, 78, 79, 81, 83
VERSO_MEL = [
    (0, 0, 1, E5), (0, 1, .5, D5), (0, 1.5, .5, E5), (0, 2, 1.5, G5), (0, 3.5, .5, Fs5),
    (1, 0, 1, E5), (1, 1, 1, C5), (1, 2, 2, E5),
    (2, 0, 1, D5), (2, 1, .5, Fs5), (2, 1.5, .5, A5), (2, 2, 1.5, Fs5), (2, 3.5, .5, D5),
    (3, 0, 2, Fs5), (3, 2, 1, Ds5 := 75), (3, 3, 1, B4),
]
REFRAO_MEL = [
    (0, 0, .5, B5), (0, .5, .5, A5), (0, 1, 1.5, G5), (0, 2.5, .5, E5), (0, 3, 1, G5),
    (1, 0, 1.5, E5), (1, 1.5, .5, G5), (1, 2, 1, A5), (1, 3, 1, G5),
    (2, 0, 1, G5), (2, 1, 1, B5), (2, 2, 1.5, 86), (2, 3.5, .5, B5),
    (3, 0, 1.5, A5), (3, 1.5, .5, G5), (3, 2, 1, Fs5), (3, 3, 1, A5),
]
PONTE_MEL = [(0, 0, 4, E5), (1, 0, 4, C5 + 12), (2, 0, 4, D5 + 12), (3, 0, 2, Fs5), (3, 2, 2, B5)]

def play_mel(start_bar, mel, reps, oct_=0, gain=0.22, duty=0.25):
    prev = None
    for rp in range(reps):
        for (b, bt, du, n) in mel:
            t = (start_bar + rp * 4 + b) * BAR + bt * BEAT
            ns = int(du * BEAT * SR * 0.94)
            f = mid(n + oct_)
            s = pulse(f, ns, duty, vib=0.012 if du >= 1 else 0.0, slide_from=prev) * env(ns, 0.003, 0.1, 0.7, 0.03)
            put(lead, t, s, gain)
            prev = f if du < 1 else None

pos = 0
for nm, nb in SECS:
    if nm in ('verso', 'verso2'):
        play_mel(pos, VERSO_MEL, nb // 4)
    elif nm.startswith('refrao'):
        play_mel(pos, REFRAO_MEL, nb // 4, gain=0.24)
        play_mel(pos, REFRAO_MEL, nb // 4, oct_=-12, gain=0.10, duty=0.5)  # dobra uma oitava abaixo
    elif nm == 'ponte':
        play_mel(pos, PONTE_MEL, 1, gain=0.20, duty=0.125)
    pos += nb

# ------------------------------------------------------------ efeitos de fliperama: "moeda" na entrada e zap nas trocas
def coin():
    out = []
    for f, d in [(mid(83), 0.07), (mid(88), 0.28)]:
        ns = int(d * SR)
        out.append(pulse(f, ns, 0.5) * env(ns, 0.001, 0.05, 0.5, 0.05))
    return np.concatenate(out)

def zap(d=0.35):
    ns = int(d * SR); t = np.arange(ns) / SR
    f = 1800 * np.exp(-t * 9) + 120
    ph = np.cumsum(f) / SR
    return np.where(ph % 1 < 0.5, 1.0, -1.0) * np.exp(-t * 5)

put(fx, 0.0, coin(), 0.22)
for i, (nm, nb) in enumerate(SECS):
    pass
acc = 0
for nm, nb in SECS:
    if acc > 0 and nm != 'intro':
        put(fx, acc * BAR - 0.35, zap(), 0.12)
    acc += nb

# ------------------------------------------------------------ mixagem
chip = crush(lead + arp + fx, 7)
mixL = drums * 0.62 + bass * 0.9 + gtr * 0.95 + chip * 0.85
mixR = mixL.copy()
# leve abertura estéreo: guitarra dobrada atrasada à direita, arpejo puxado à esquerda
d = int(0.012 * SR)
g2 = np.concatenate([np.zeros(d), gtr[:-d]])
mixL += -gtr * 0.25 + arp * 0.10
mixR += g2 * 0.25 - arp * 0.10
st = np.stack([mixL, mixR], axis=1)
st = np.tanh(st * 1.15)
st /= np.max(np.abs(st)) * 1.05
# emenda do loop: fade curtíssimo nas bordas
f = int(0.004 * SR)
st[:f] *= np.linspace(0, 1, f)[:, None]
st[-f:] *= np.linspace(1, 0, f)[:, None]
wavfile.write(sys.argv[1], SR, (st * 32767).astype(np.int16))
print('ok', N / SR, 's')
