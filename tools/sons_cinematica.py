"""Ambientes em loop da cinemática dos comandantes: heli_loop.wav e abismo_loop.wav."""
import numpy as np, wave, os
SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "sounds")
rng = np.random.default_rng(3)

def save(name, x, peak=0.7):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    s = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(s.tobytes())

def lowpass(x, a):
    # passa-baixa de 1 polo, aplicado ida e volta (sem defasagem) e circular para o loop
    y = np.concatenate([x, x])
    out = np.zeros_like(y); acc = 0.0
    for i in range(len(y)):
        acc += a * (y[i] - acc); out[i] = acc
    return out[len(x):]

# helicóptero: pás batendo 6 vezes por segundo + turbina; 2 s fecham o ciclo
d = 2.0; n = int(SR * d); t = np.arange(n) / SR
nz = lowpass(rng.standard_normal(n), 0.06)
blade = np.zeros(n)
for k in range(12):
    tt = (t - k / 6.0) % d
    blade += np.exp(-tt * 38.0) * (tt < 0.12)
thump = nz * (0.25 + 1.6 * blade) + 0.6 * np.sin(2 * np.pi * 42 * t) * blade
turb = 0.12 * np.sin(2 * np.pi * 410 * t + 0.3 * np.sin(2 * np.pi * 3 * t)) + 0.05 * np.sin(2 * np.pi * 820 * t)
save("heli_loop.wav", thump + turb, 0.65)

# abismo: zumbido grave que respira + correnteza + bolhas
d = 4.0; n = int(SR * d); t = np.arange(n) / SR
drone = (np.sin(2 * np.pi * 55 * t) + 0.5 * np.sin(2 * np.pi * 82.5 * t + 1.0) + 0.3 * np.sin(2 * np.pi * 110.5 * t)) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.5 * t))
cur = lowpass(rng.standard_normal(n), 0.015) * 3.0 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.25 * t + 2))
bub = np.zeros(n)
for _ in range(14):
    t0 = rng.uniform(0, d - 0.1); f0 = rng.uniform(500, 1400); i0 = int(t0 * SR); m = int(0.06 * SR)
    tt = np.arange(m) / SR
    bub[i0:i0 + m] += 0.35 * np.sin(2 * np.pi * (f0 * tt + 4000 * tt * tt)) * np.exp(-tt * 70)
save("abismo_loop.wav", 0.5 * drone + cur + bub, 0.6)
print("ok")
