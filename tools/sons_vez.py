"""Sons de aviso de vez: vez_sua.wav (sobe, brilhante) e vez_rival.wav (desce, discreto)."""
import numpy as np, wave, os
SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "sounds")

def tone(f, d, a=0.005, k=5.0, harm=(1.0, 0.35, 0.12)):
    t = np.arange(int(SR * d)) / SR
    x = sum(h * np.sin(2 * np.pi * f * (i + 1) * t) for i, h in enumerate(harm))
    e = np.minimum(1.0, t / a) * np.exp(-k * t)
    return x * e

def at(buf, x, t0):
    i = int(t0 * SR)
    buf[i:i + len(x)] += x[:len(buf) - i]

def save(name, x, peak=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    # eco curto para dar espaço
    d = int(0.11 * SR)
    y = x.copy()
    y[d:] += 0.28 * x[:-d]
    y = y / (np.max(np.abs(y)) + 1e-9) * peak
    s = (y * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(s.tobytes())

# sua vez: arpejo ascendente (Mi, Sol#, Si, Mi) com brilho
b = np.zeros(int(SR * 1.1))
for i, f in enumerate([659.3, 830.6, 987.8, 1318.5]):
    at(b, tone(f, 0.7, k=4.0 + i), i * 0.075)
at(b, 0.25 * tone(2637.0, 0.5, k=6.0, harm=(1.0,)), 0.24)
save("vez_sua.wav", b)

# vez do adversário: duas notas graves descendo, mais suaves
b = np.zeros(int(SR * 0.9))
for i, f in enumerate([392.0, 293.7]):
    at(b, tone(f, 0.6, k=6.0, harm=(1.0, 0.2)), i * 0.12)
save("vez_rival.wav", b, peak=0.55)
print("ok")
