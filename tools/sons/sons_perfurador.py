"""Sons da broca do Perfurador, sintetizados (motor a combustão + broca, impacto em inimigo, cristal, pedra, cavar)."""
import numpy as np, wave, subprocess, sys
from scipy.signal import butter, sosfilt
SR = 44100
rng = np.random.default_rng(7)
OUT = sys.argv[1]


def t_(d): return np.arange(int(SR * d)) / SR
def bp(x, lo, hi, o=2): return sosfilt(butter(o, [lo / (SR / 2), hi / (SR / 2)], 'band', output='sos'), x)
def lp(x, f, o=2): return sosfilt(butter(o, f / (SR / 2), 'low', output='sos'), x)
def hp(x, f, o=2): return sosfilt(butter(o, f / (SR / 2), 'high', output='sos'), x)
def env(t, pts): return np.interp(t, [p[0] for p in pts], [p[1] for p in pts])
def sat(x, k=2.5): return np.tanh(x * k) / np.tanh(k)


def motor(d, rpm_pts, amp_pts):
    """motor de dois tempos: trem de pulsos (explosões) na rotação + ronco filtrado + engrenagem/broca chiando."""
    t = t_(d)
    f = env(t, rpm_pts)                      # explosões por segundo
    ph = np.cumsum(f) / SR
    pulso = np.exp(-((ph % 1.0)) * 9.0)       # cada explosão decai rápido
    pulso += 0.15 * rng.normal(size=len(t)) * pulso
    ronco = lp(sat(pulso * 1.6), 900) * 1.2
    escape = bp(rng.normal(size=len(t)), 300, 1400) * pulso * 0.35
    # engrenagem e broca: uivo agudo proporcional à rotação, com harmônicos e um pouco de aspereza
    phw = 2 * np.pi * np.cumsum(f * 26.0) / SR
    uivo = (np.sin(phw) + 0.45 * np.sin(2 * phw + 0.3) + 0.25 * np.sin(3.01 * phw)) * 0.12
    uivo *= 0.8 + 0.2 * np.sin(2 * np.pi * 7 * t)
    chiado = hp(rng.normal(size=len(t)), 3500) * 0.05 * (f / max(f.max(), 1))
    y = (ronco + escape + uivo + chiado) * env(t, amp_pts)
    return y


def metal_ring(t, freqs, dec, amp):
    y = np.zeros_like(t)
    for f, a in zip(freqs, amp):
        y += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t * dec)
    return y


def grao(n_total, d, t0s, comp, lo, hi, dec):
    """grãos curtos de ruído filtrado (estalos de pedra, cascalho)"""
    y = np.zeros(n_total)
    for t0 in t0s:
        n = int(SR * comp * rng.uniform(0.5, 1.5))
        g = bp(rng.normal(size=n), lo * rng.uniform(0.7, 1.3), hi * rng.uniform(0.7, 1.3)) * np.exp(-np.arange(n) / SR * dec)
        i = int(t0 * SR)
        if i + n < n_total:
            y[i:i + n] += g * rng.uniform(0.4, 1.0)
    return y


def grava(nome, y, pico=0.9):
    y = y / (np.abs(y).max() + 1e-9) * pico
    fade = int(SR * 0.01)
    y[-fade:] *= np.linspace(1, 0, fade)
    w = wave.open(f'{OUT}/{nome}.wav', 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((y * 32767).astype(np.int16).tobytes()); w.close()
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', f'{OUT}/{nome}.wav', '-c:a', 'libvorbis', '-q:a', '5', f'{OUT}/{nome}.ogg'], check=True)


# 1) motor no golpe: arranque (puxa a corda), acelera, gira forte, desacelera e apaga
d = 1.25
y = motor(d, [(0, 9), (0.12, 14), (0.25, 48), (0.85, 52), (1.05, 22), (1.25, 8)], [(0, 0), (0.03, 0.6), (0.25, 1.0), (0.85, 1.0), (1.2, 0.25), (1.25, 0)])
t = t_(d)
puxa = bp(rng.normal(size=len(t)), 600, 2500) * env(t, [(0, 0), (0.01, 0.6), (0.08, 0.0), (1.25, 0)])   # tranco da partida
grava('perfurador_motor', sat((y + puxa * 0.5) / (np.abs(y).max() + 1e-9) * 2.2, 1.6))

# 2) broca acertando o inimigo: rangido de metal na armadura, trepidação, pancada surda
d = 0.7; t = t_(d)
trepida = (0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 46 * t)))           # a ponta batendo em ciclos
raspa = bp(rng.normal(size=len(t)), 1200, 5200, 3) * trepida * env(t, [(0, 0), (0.01, 1), (0.45, 0.8), (0.7, 0)])
grito = metal_ring(t, [1320, 1980, 2870, 4110], 7.0, [0.35, 0.25, 0.2, 0.12]) * (0.6 + 0.4 * trepida)
baque = lp(rng.normal(size=len(t)), 180) * np.exp(-t * 18) * 3.0 + np.sin(2 * np.pi * 70 * t) * np.exp(-t * 14) * 0.8
grava('perfurador_acerta', sat(raspa * 1.1 + grito + baque, 1.8))

# 3) cristal estilhaçando: estalo seco, chuva de cacos agudos tilintando e brilho que soa e some
d = 1.4; t = t_(d)
estalo = hp(rng.normal(size=len(t)), 2500) * np.exp(-t * 60) * 1.5
cacos = np.zeros(len(t))
for t0 in np.sort(rng.exponential(0.18, 70)):
    if t0 > d - 0.3: continue
    n = int(SR * 0.25); tt = np.arange(n) / SR
    f = rng.uniform(2300, 8500)
    c = (np.sin(2 * np.pi * f * tt) + 0.5 * np.sin(2 * np.pi * f * 2.76 * tt)) * np.exp(-tt * rng.uniform(18, 40))
    i = int(t0 * SR); cacos[i:i + n] += c[:len(cacos) - i] * rng.uniform(0.15, 0.5) * np.exp(-t0 * 2.0)
brilho = metal_ring(t, [1567, 2349, 3135, 4699], 3.2, [0.18, 0.14, 0.1, 0.07])
grava('perfurador_cristal', sat(estalo * 0.35 + cacos * 2.5 + brilho * 1.5, 1.4))

# 4) pedra quebrando: baque grave, rachadura, pedaços caindo e cascalho escorrendo
d = 1.3; t = t_(d)
baque = lp(rng.normal(size=len(t)), 220, 3) * np.exp(-t * 9) * 4 + np.sin(2 * np.pi * 55 * t) * np.exp(-t * 10) * 0.9
racha = bp(rng.normal(size=len(t)), 500, 3200) * np.exp(-t * 25) * 1.2
pedacos = grao(len(t), d, np.sort(rng.uniform(0.05, 0.9, 26)), 0.05, 300, 1800, 45) * 1.2
cascalho = grao(len(t), d, np.sort(rng.uniform(0.15, 1.2, 140)), 0.012, 1500, 6000, 160) * 0.5 * env(t, [(0, 0), (0.2, 1), (1.3, 0.2)])
grava('perfurador_pedra', sat(baque + racha + pedacos + cascalho, 1.5))

# 5) cavar: motor forte + terra e pedra sendo moídas (Perfuração Subterrânea)
d = 1.8; t = t_(d)
y = motor(d, [(0, 10), (0.2, 50), (1.5, 50), (1.8, 15)], [(0, 0), (0.05, 0.7), (0.25, 1.0), (1.5, 1.0), (1.8, 0)])
moe = bp(rng.normal(size=len(t)), 150, 1200) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)) * env(t, [(0, 0), (0.3, 0), (0.45, 1), (1.5, 1), (1.8, 0)])
cas = grao(len(t), d, np.sort(rng.uniform(0.4, 1.7, 200)), 0.01, 1200, 5000, 150) * 0.35
yy = y / (np.abs(y).max() + 1e-9)
grava('perfurador_cavar', sat(yy * 1.8 + moe / (np.abs(moe).max() + 1e-9) * 0.7 + cas / (np.abs(cas).max() + 1e-9) * 0.4, 1.5))
print('ok')
