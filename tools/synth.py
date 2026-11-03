"""Gera os efeitos sonoros do Hex Galaxies por síntese (WAV 22050 Hz, mono, 16 bits)."""
import numpy as np, wave, os, sys

SR = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else "sounds"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.2, curve=3.0):
    """ataque linear curto, decaimento exponencial"""
    x = np.ones(n)
    na = max(1, int(a * SR))
    x[:na] = np.linspace(0, 1, na)
    k = np.arange(n - na) / SR
    x[na:] = np.exp(-k / max(r, 1e-4) * curve / 3.0)
    return x


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, cut):
    a = np.exp(-2 * np.pi * cut / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def lowpass_var(x, cuts):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        a = np.exp(-2 * np.pi * cuts[i] / SR)
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cut):
    return x - lowpass(x, cut)


def sweep(f0, f1, d, shape="sin"):
    tt = t(d)
    f = f0 * (f1 / f0) ** (tt / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if shape == "sq":
        return np.sign(np.sin(ph))
    return np.sin(ph)


def tone(f, d):
    return np.sin(2 * np.pi * f * t(d))


def pad(x, d):
    n = int(SR * d)
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n] if len(x) < n else x


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def delay(x, at):
    return np.concatenate([np.zeros(int(at * SR)), x])


def save(name, x, peak=0.85):
    x = np.asarray(x, float)
    x = x - np.mean(x)
    m = np.max(np.abs(x)) or 1
    x = x / m * peak
    fade = min(len(x) // 4, int(0.01 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def loopable(x, xf=0.6):
    """crossfade do fim no começo para tocar em loop sem emenda"""
    n = int(xf * SR)
    head, tail = x[:n].copy(), x[-n:].copy()
    ramp = np.linspace(0, 1, n)
    body = x[n:-n] if len(x) > 2 * n else x[n:]
    start = tail * (1 - ramp) + head * ramp
    return np.concatenate([start, body])


# ---------------- golpes e tiros ----------------
d = 0.28
n = int(SR * d)
cuts = np.linspace(6000, 900, n)
save("golpe", lowpass_var(noise(n), cuts) * env(n, 0.01, 0.12) * np.sin(np.linspace(0, np.pi, n)) ** 0.5)

d = 0.42
n = int(SR * d)
thump = sweep(140, 45, d) * env(n, 0.002, 0.12)
crack = highpass(noise(n), 1500) * env(n, 0.001, 0.03)
save("impacto", mix(thump * 1.0, crack * 0.6))

d = 0.35
n = int(SR * d)
save("tiro_laser", mix(sweep(1800, 300, d) * env(n, 0.002, 0.18), sweep(3600, 600, d) * 0.3 * env(n, 0.002, 0.12)))

d = 0.6
n = int(SR * d)
partials = [1, 2.76, 5.4, 8.93]
chime = sum(np.sin(2 * np.pi * 880 * p * t(d)) * env(n, 0.001, 0.5 / (i + 1)) / (i + 1) for i, p in enumerate(partials))
save("tiro_cristal", mix(chime, sweep(2400, 900, 0.18) * 0.5 * env(int(SR * 0.18), 0.001, 0.08)))

d = 0.3
n = int(SR * d)
save("tiro_energia", mix(sweep(600, 1400, d, "saw") * env(n, 0.002, 0.15) * 0.4, lowpass(noise(n), 3000) * env(n, 0.001, 0.08) * 0.6))

d = 0.25
n = int(SR * d)
save("projetil", lowpass_var(noise(n), np.linspace(800, 5000, n)) * np.sin(np.linspace(0, np.pi, n)))

# ---------------- cura, escudo, poder ----------------
d = 0.9
notes = [523, 659, 784, 1046]
x = np.zeros(int(SR * d))
for i, f in enumerate(notes):
    s = np.sin(2 * np.pi * f * t(0.5)) * env(int(SR * 0.5), 0.01, 0.35)
    x = mix(x, delay(s * 0.6, i * 0.09))
save("cura", x)

d = 0.7
n = int(SR * d)
shim = sum(np.sin(2 * np.pi * f * t(d) + 3 * np.sin(2 * np.pi * 6 * t(d))) for f in (660, 990, 1320)) / 3
save("escudo", mix(shim * env(n, 0.02, 0.45), lowpass(noise(n), 2500) * env(n, 0.001, 0.05) * 0.3))

d = 0.6
n = int(SR * d)
save("poder", mix(sweep(180, 720, d, "saw") * env(n, 0.05, 0.4) * 0.35, sweep(360, 1440, d) * env(n, 0.05, 0.4) * 0.5))

d = 0.7
n = int(SR * d)
wob = np.sin(2 * np.pi * 90 * t(d) + 6 * np.sin(2 * np.pi * 7 * t(d)))
save("maldicao", wob * env(n, 0.02, 0.5))

d = 1.2
n = int(SR * d)
fire = lowpass_var(noise(n), np.linspace(1200, 5000, n)) * env(n, 0.3, 0.8)
save("fenix", mix(fire * 0.6, sweep(300, 1200, d) * env(n, 0.1, 0.8) * 0.4))

d = 0.5
n = int(SR * d)
save("armadilha", mix(sq := (np.sign(np.sin(2 * np.pi * 220 * t(0.08))) * env(int(SR * 0.08), 0.001, 0.05) * 0.4), delay(highpass(noise(int(SR * 0.3)), 800) * env(int(SR * 0.3), 0.001, 0.08), 0.06)))

# ---------------- entrar, cair, passos ----------------
d = 0.8
n = int(SR * d)
save("invocar", mix(lowpass_var(noise(n), np.linspace(300, 6000, n)) * env(n, 0.3, 0.4) * 0.6, sweep(200, 900, d) * env(n, 0.2, 0.5) * 0.5))

d = 0.9
n = int(SR * d)
save("derrota", mix(sweep(300, 50, d, "saw") * env(n, 0.005, 0.5) * 0.4, lowpass(noise(n), 900) * env(n, 0.002, 0.4)))

d = 0.12
n = int(SR * d)
save("passo", lowpass(noise(n), 1400) * env(n, 0.003, 0.05))

d = 1.0
n = int(SR * d)
boom = mix(sweep(90, 30, d) * env(n, 0.002, 0.5), lowpass(noise(n), 1800) * env(n, 0.001, 0.35))
save("explosao", boom)

# ---------------- vermes ----------------
d = 3.0
n = int(SR * d)
brown = np.cumsum(noise(n))
brown = highpass(brown / np.max(np.abs(brown)), 20)
rumble = lowpass(brown, 180) * (0.6 + 0.4 * np.sin(2 * np.pi * 1.3 * t(d))) + np.sin(2 * np.pi * 38 * t(d)) * 0.4
fadeio = np.minimum(1, np.minimum(t(d) / 0.6, (d - t(d)) / 0.8))
save("verme_rumor", rumble * fadeio)

d = 2.2
n = int(SR * d)
crunch = highpass(noise(n), 400) * env(n, 0.001, 0.25)
roar = lowpass(sweep(90, 60, d, "saw") * (1 + 0.3 * np.sin(2 * np.pi * 9 * t(d))), 900) * env(n, 0.05, 1.4)
save("verme_ataque", mix(crunch * 0.7, roar * 0.8, lowpass(brown[:n], 160) * env(n, 0.001, 1.2) * 1.2))

d = 2.5
n = int(SR * d)
save("dunas", lowpass_var(noise(n), 900 + 700 * np.sin(np.linspace(0, np.pi, n))) * np.sin(np.linspace(0, np.pi, n)) ** 0.6)

# ---------------- ambiente ----------------
d = 10.0
n = int(SR * d)
gust = 0.55 + 0.45 * np.sin(2 * np.pi * 0.11 * t(d)) * np.sin(2 * np.pi * 0.07 * t(d) + 1)
wind = lowpass_var(noise(n), 500 + 500 * gust) * gust
save("vento_loop", loopable(wind), 0.5)

d = 8.0
n = int(SR * d)
gust2 = 0.7 + 0.3 * np.sin(2 * np.pi * 0.25 * t(d))
storm = mix(lowpass_var(noise(n), 1200 + 1500 * gust2) * gust2, highpass(noise(n), 3000) * 0.25 * gust2)
save("tempestade_loop", loopable(storm), 0.65)

d = 10.0
n = int(SR * d)
waves = lowpass(noise(n), 600) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.18 * t(d)) ** 2)
birds = np.zeros(n)
for at in (1.3, 1.5, 5.2, 5.35, 7.9):
    b = sweep(2600, 3400, 0.09) * env(int(SR * 0.09), 0.005, 0.05) * 0.25
    s0 = int(at * SR)
    birds[s0 : s0 + len(b)] += b
save("ilha_loop", loopable(mix(waves, birds, lowpass(noise(n), 300) * 0.3)), 0.45)

# ---------------- interface ----------------
d = 1.6
n = int(SR * d)
gong = sum(np.sin(2 * np.pi * f * t(d)) * env(n, 0.002, 1.2 / (i + 1)) / (i + 1) for i, f in enumerate((220, 331, 440, 587)))
save("round", gong)

d = 0.12
n = int(SR * d)
save("clique", tone(1200, d) * env(n, 0.001, 0.03) * 0.5)

d = 0.35
n = int(SR * d)
save("confirmar", mix(tone(660, 0.12) * env(int(SR * 0.12), 0.002, 0.06), delay(tone(990, 0.2) * env(int(SR * 0.2), 0.002, 0.12), 0.09)))

d = 0.5
n = int(SR * d)
save("carta", lowpass_var(noise(n), np.linspace(4000, 1500, n)) * env(n, 0.005, 0.15) * 0.6)

print("ok", sorted(os.listdir(OUT)))
