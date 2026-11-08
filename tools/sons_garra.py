"""Sons da Garra de Valak.
garra_ataque.wav : rugido grave da criatura + rocha rachando + pancada da mão batendo na borda
garra_puxa.wav   : arrasto: unhas raspando na pedra, chiado e um puxão (whoosh) para dentro do buraco
python3 tools/sons_garra.py"""
import os, wave
import numpy as np
from scipy.signal import butter, sosfilt

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "sounds")
rng = np.random.default_rng(31)


def filt(x, kind, f, order=2):
    sos = butter(order, f, kind if kind != "band" else "band", fs=SR, output="sos")
    return sosfilt(sos, x)


def save(name, y):
    y = y / (np.max(np.abs(y)) + 1e-9) * 0.9
    st = np.stack([y, np.roll(y, 37) * 0.96], -1)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((st * 32767).astype(np.int16).tobytes())
    print(name, round(len(y) / SR, 2), "s")


def place(dst, src, t0):
    i = int(t0 * SR)
    j = min(len(dst), i + len(src))
    dst[i:j] += src[:j - i]


def ataque():
    n = int(2.4 * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    # rugido: fundamental grave que cai + harmônicos sujos + ruído granulado (garganta)
    f = 70 * np.exp(-t * 0.5) + 18 * np.sin(2 * np.pi * 7 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    growl = np.sin(ph) + 0.6 * np.sin(2 * ph + 0.5) + 0.4 * np.sign(np.sin(3 * ph)) * 0.5
    grit = filt(rng.normal(size=n), "band", [150, 900]) * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t))
    env = np.minimum(1, t / 0.25) * np.exp(-np.maximum(0, t - 0.6) * 2.2)
    y += np.tanh((growl * 0.8 + grit * 1.5) * env * 2.0) * 0.9
    # rocha rachando (estalos secos)
    for k in range(9):
        tk = 0.55 + rng.uniform(0, 0.35)
        m = int(0.05 * SR)
        cr = rng.normal(size=m) * np.exp(-np.arange(m) / SR * 90)
        place(y, filt(cr, "band", [1500, 6000]) * 0.6, tk)
    # pancada: a mão bate na borda (subgrave + estrondo)
    m = int(1.2 * SR)
    tt = np.arange(m) / SR
    thump = np.sin(2 * np.pi * (55 * np.exp(-tt * 3) + 28) * tt) * np.exp(-tt * 4)
    boom = filt(rng.normal(size=m), "low", 400) * np.exp(-tt * 3)
    place(y, (thump * 1.6 + boom * 1.2), 0.8)
    return y


def puxa():
    n = int(1.3 * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    # unhas raspando: ruído com pulsos rápidos (dentes na pedra), agudo que desce
    scr = rng.normal(size=n)
    puls = (np.sin(2 * np.pi * (38 - 18 * t) * t) > 0.2).astype(float)
    scr = filt(scr * puls, "band", [1200, 5200]) * np.exp(-t * 1.5)
    y += scr * 0.8
    # whoosh do puxão (ruído filtrado que desce)
    wh = filt(rng.normal(size=n), "band", [200, 1400]) * np.sin(np.pi * np.clip(t / 0.9, 0, 1)) ** 2
    y += wh * 0.9
    # baque grave no fim
    m = int(0.5 * SR)
    tt = np.arange(m) / SR
    place(y, np.sin(2 * np.pi * (70 * np.exp(-tt * 5) + 30) * tt) * np.exp(-tt * 7) * 1.2, 0.75)
    return y


save("garra_ataque.wav", ataque())
save("garra_puxa.wav", puxa())
