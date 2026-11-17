"""Sons da HEX ENERGY (sintetizados, sem amostras de terceiros):
  sounds/hex_energy_loop.wav  — zumbido de energia neon que pulsa junto com o hexágono (loop de 3,2 s = 4 pulsos)
  sounds/hex_energy_surge.wav — a Hex Energy surge: subida + acorde brilhante + baque grave
  sounds/hex_energy_take.wav  — capturada: arpejo que sobe e estala
python3 tools/sons_hex_energy.py"""
import os, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "sounds")


def grava(nome, x, alvo=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * alvo
    st = np.stack([x, x], 1)
    with wave.open(os.path.join(OUT, nome), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((st * 32767).astype(np.int16).tobytes())
    print("som", nome, "%.2fs" % (len(x) / SR))


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def passa_baixa(x, corte):
    a = np.exp(-2 * np.pi * corte / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def saw(f, t, harm=12):
    return sum(np.sin(2 * np.pi * f * k * t) / k for k in range(1, harm + 1))


def loop():
    dur = 3.2
    t = t_(dur)
    pulso = 0.55 + 0.45 * (0.5 + 0.5 * np.cos(2 * np.pi * t / 0.8)) ** 3      # bate a cada 0,8 s
    grave = saw(55, t, 8) * 0.5 + np.sin(2 * np.pi * 110 * t) * 0.4
    grave = passa_baixa(grave, 420)
    # brilho neon: dois senos levemente desafinados (batimento) em quinta
    neon = (np.sin(2 * np.pi * 440 * t) + np.sin(2 * np.pi * 441.25 * t) + 0.6 * np.sin(2 * np.pi * 660 * t)) * 0.12
    # faísca: um "tic" agudo em cada pulso
    tic = np.zeros_like(t)
    for k in range(4):
        i0 = int(k * 0.8 * SR)
        n = int(0.09 * SR)
        e = np.exp(-np.arange(n) / (0.018 * SR))
        tic[i0:i0 + n] += np.sin(2 * np.pi * 1760 * np.arange(n) / SR) * e * 0.18
    x = grave * pulso + neon * pulso + tic
    # emenda sem clique: crossfade das pontas
    f = int(0.03 * SR)
    x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f)
    x = x[:-f]
    grava("hex_energy_loop.wav", x, 0.7)


def surge():
    dur = 2.2
    t = t_(dur)
    # subida: varredura de 140 Hz a 1100 Hz no primeiro segundo
    fs = 140 * (1100 / 140) ** np.clip(t / 1.0, 0, 1)
    fase = 2 * np.pi * np.cumsum(fs) / SR
    sobe = (np.sin(fase) + 0.4 * np.sin(fase * 2)) * np.clip(t / 1.0, 0, 1) ** 2 * (t < 1.05)
    # acorde de chegada (lá menor com nona: neon e misterioso) com cauda
    env = np.where(t >= 1.0, np.exp(-(t - 1.0) / 0.55), 0)
    acorde = sum(np.sin(2 * np.pi * f * t) for f in (440, 523.25, 659.25, 987.77, 1318.5)) * env * 0.35
    brilho = np.sin(2 * np.pi * 2637 * t) * np.where(t >= 1.0, np.exp(-(t - 1.0) / 0.2), 0) * 0.25
    # baque grave
    tb = np.clip(t - 1.0, 0, None)
    baque = np.sin(2 * np.pi * (90 * np.exp(-tb * 6) + 40) * tb) * np.exp(-tb / 0.25) * (t >= 1.0) * 0.9
    grava("hex_energy_surge.wav", sobe * 0.6 + acorde + brilho + baque, 0.85)


def take():
    dur = 1.3
    t = t_(dur)
    x = np.zeros_like(t)
    for k, f in enumerate((659.25, 880, 1046.5, 1318.5, 1760)):
        t0 = k * 0.06
        tt = np.clip(t - t0, 0, None)
        x += np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.35) * (t >= t0) * 0.4
    estalo = np.random.default_rng(3).normal(0, 1, len(t)) * np.exp(-t / 0.03) * 0.5
    sopro = passa_baixa(np.random.default_rng(4).normal(0, 1, len(t)), 2500) * np.exp(-((t - 0.25) / 0.15) ** 2) * 0.6
    grava("hex_energy_take.wav", x + estalo + sopro, 0.85)


if __name__ == "__main__":
    loop()
    surge()
    take()
