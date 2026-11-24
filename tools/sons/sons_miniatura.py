"""Sons de miniatura de tabuleiro, sintetizados: erguer a peça, pousar na mesa (toc) e tombar (derrota).
Peça de resina com base pesada sobre tabuleiro de madeira.
  python3 tools/sons/sons_miniatura.py sounds"""
import numpy as np, wave, subprocess, sys, os
from scipy.signal import butter, sosfilt
SR = 44100
rng = np.random.default_rng(11)
OUT = sys.argv[1]


def t_(d): return np.arange(int(SR * d)) / SR
def bp(x, lo, hi, o=2): return sosfilt(butter(o, [lo / (SR / 2), hi / (SR / 2)], 'band', output='sos'), x)
def lp(x, f, o=2): return sosfilt(butter(o, f / (SR / 2), 'low', output='sos'), x)
def hp(x, f, o=2): return sosfilt(butter(o, f / (SR / 2), 'high', output='sos'), x)


def batida(t, t0, forca=1.0, corpo=180.0, brilho=1.0):
    """um toque de base de resina na madeira: estalo curto + corpo grave da tábua + ressonância da peça"""
    y = np.zeros_like(t)
    m = t >= t0
    tt = t[m] - t0
    clique = hp(rng.normal(size=m.sum()), 2500) * np.exp(-tt * 260) * 0.5 * brilho
    madeira = (np.sin(2 * np.pi * corpo * tt) + 0.5 * np.sin(2 * np.pi * corpo * 2.37 * tt)) * np.exp(-tt * 38)
    resina = (0.25 * np.sin(2 * np.pi * 1230 * tt) + 0.15 * np.sin(2 * np.pi * 1870 * tt)) * np.exp(-tt * 70) * brilho
    ruido = bp(rng.normal(size=m.sum()), 400, 2200) * np.exp(-tt * 90) * 0.35
    y[m] = (clique + madeira * 0.8 + resina + ruido) * forca
    return y


def salva(nome, y):
    y = y / max(np.abs(y).max(), 1e-6) * 0.85
    fade = min(len(y), int(SR * 0.02))
    y[-fade:] *= np.linspace(1, 0, fade)
    w = os.path.join(OUT, nome + '.wav')
    with wave.open(w, 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR)
        f.writeframes((y * 32767).astype(np.int16).tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', w, '-c:a', 'libvorbis', '-q:a', '5', os.path.join(OUT, nome + '.ogg')])
    os.remove(w)


# erguer: a base desgruda da mesa (raspão curto) e um "fuu" leve da mão subindo
t = t_(0.42)
rasp = bp(rng.normal(size=len(t)), 900, 4000) * np.exp(-((t - 0.02) / 0.025) ** 2) * 0.5
desgruda = batida(t, 0.0, 0.35, corpo=240, brilho=0.6)
ar = bp(rng.normal(size=len(t)), 300, 1500) * np.sin(np.clip(t / 0.4, 0, 1) * np.pi) ** 2 * 0.18
salva('miniatura_ergue', rasp + desgruda + ar)

# pousar: toc firme e um segundo toque menor (a base assenta)
t = t_(0.5)
salva('miniatura_toc', batida(t, 0.0, 1.0) + batida(t, 0.055, 0.28, corpo=200, brilho=0.7))

# tombar: rangido da base inclinando, queda (toc forte), quique, rola e assenta
t = t_(1.3)
incl = bp(rng.normal(size=len(t)), 600, 2500) * np.clip((t - 0.0) / 0.3, 0, 1) * np.exp(-np.clip(t - 0.3, 0, None) * 30) * 0.12
y = incl + batida(t, 0.36, 1.0, corpo=150) + batida(t, 0.47, 0.45, corpo=170) + batida(t, 0.55, 0.22, corpo=190, brilho=0.8)
rola = bp(rng.normal(size=len(t)), 250, 1200) * np.exp(-np.clip(t - 0.58, 0, None) * 6) * (t > 0.58) * 0.15
rola *= 0.6 + 0.4 * np.sin(2 * np.pi * 14 * t)
salva('miniatura_tomba', y + rola + batida(t, 0.95, 0.12, corpo=210, brilho=0.5))
print('ok')
