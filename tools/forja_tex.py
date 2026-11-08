"""FORJA — texturas de partícula (estilo "Hits & Impacts" em tempo real).
Cada textura é branca com a intensidade no canal R e no alfa; a cor vem da rampa no shader
e a erosão (dissolver com o tempo) corta pelos tons — por isso as bordas têm degradê e ruído.
python3 tools/forja_tex.py  ->  vfx/tex/*.png"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "vfx", "tex")
N = 128


def grid(n=N):
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    return (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1


def fbm(seed, n=N, esc=4, oit=4):
    rng = np.random.default_rng(seed)
    acc = np.zeros((n, n), np.float32)
    amp, tot, g = 1.0, 0.0, esc
    for _ in range(oit):
        b = rng.random((g + 1, g + 1)).astype(np.float32)
        acc += ndi.zoom(b, (n / (g + 1) * 1.0001, n / (g + 1) * 1.0001), order=3)[:n, :n] * amp
        tot += amp
        amp *= 0.5
        g *= 2
    acc /= tot
    return (acc - acc.min()) / (acc.max() - acc.min() + 1e-6)


def save(name, v, n=N):
    v = np.clip(v, 0, 1)
    a = (v * 255).astype(np.uint8)
    im = np.dstack([np.full_like(a, 255), np.full_like(a, 255), np.full_like(a, 255), a])
    # guarda a intensidade também no R (o shader lê .r para erosão/rampa; branco puro no alfa 0 evita franja)
    im[..., 0] = a
    im[..., 1] = a
    im[..., 2] = a
    Image.fromarray(im, "RGBA").save(os.path.join(OUT, name + ".png"))


def brilho():
    x, y = grid()
    r = np.hypot(x, y)
    return np.clip(np.exp(-r * r * 5.5) * 1.05 - 0.02, 0, 1) * (r < 1)


def anel():
    x, y = grid()
    r = np.hypot(x, y)
    n = fbm(3, esc=6)
    band = np.exp(-((r - 0.78) / 0.09) ** 2)
    inner = np.exp(-((r - 0.6) / 0.25) ** 2) * 0.25
    return np.clip((band + inner) * (0.55 + 0.6 * n), 0, 1)


def estrela():
    x, y = grid()
    r = np.hypot(x, y)
    a = np.arctan2(y, x)
    raios = np.exp(-np.abs(x) * 28) * np.exp(-np.abs(y) * 1.6) + np.exp(-np.abs(y) * 28) * np.exp(-np.abs(x) * 1.6)
    diag = (np.exp(-np.abs(x - y) * 30) + np.exp(-np.abs(x + y) * 30)) * np.exp(-r * 3.2) * 0.45
    core = np.exp(-r * r * 30)
    return np.clip(raios + diag + core, 0, 1)


def faisca():
    x, y = grid()
    # risco vertical afinando para baixo (cabeça em cima)
    w = 0.16 * np.clip((y + 1) / 2, 0, 1) ** 0.6
    v = np.clip(1 - np.abs(x) / np.maximum(w, 1e-3), 0, 1) * (np.abs(y) < 0.98)
    v *= np.clip(1.2 - (1 - (y + 1) / 2) * 0.9, 0, 1)
    return v ** 0.8


def fumaca():
    x, y = grid()
    r = np.hypot(x, y)
    n = fbm(11, esc=4)
    n2 = fbm(12, esc=8)
    v = np.clip(1 - r * (0.9 + 0.5 * n), 0, 1)
    return np.clip(v * 1.4 * (0.45 + 0.75 * n2), 0, 1)


def estilhaco():
    """caco de tinta preto agressivo (vertical, ponta em cima) com borda serrilhada"""
    im = Image.new("L", (N * 2, N * 2), 0)
    d = ImageDraw.Draw(im)
    rr = random.Random(5)
    S = N * 2
    pts = [(S * 0.5, S * 0.02)]
    for k in range(1, 7):
        t = k / 7
        pts.append((S * (0.5 + 0.22 * t + rr.uniform(-0.05, 0.05)), S * (0.02 + 0.92 * t)))
    pts.append((S * 0.5, S * 0.98))
    for k in range(6, 0, -1):
        t = k / 7
        pts.append((S * (0.5 - 0.2 * t + rr.uniform(-0.06, 0.04)), S * (0.02 + 0.92 * t)))
    d.polygon(pts, fill=255)
    m = np.asarray(im.resize((N, N), Image.LANCZOS)).astype(np.float32) / 255
    x, y = grid()
    # intensidade alta no centro do caco: a erosão come das bordas e da ponta de trás
    grad = np.clip(1.15 - np.abs(x) * 2.2 - np.clip(y, 0, 1) * 0.5, 0.15, 1)
    return m * grad


def respingo():
    x, y = grid()
    r = np.hypot(x, y)
    a = np.arctan2(y, x)
    rr = np.random.default_rng(21)
    k = 11
    lens = rr.uniform(0.55, 1.0, k)
    off = rr.uniform(0, 2 * np.pi)
    u = ((a + off) / (2 * np.pi) * k) % k
    i = np.floor(u).astype(int)
    f = u - i
    ponta = np.clip(1 - np.abs(f - 0.5) * 2, 0, 1) ** 3
    R = 0.42 + 0.5 * ponta * lens[i]
    n = fbm(22, esc=6)
    v = np.clip((R - r) * 6, 0, 1) * (0.5 + 0.6 * np.clip(1 - r / R, 0, 1) + 0.2 * n)
    # gotinhas soltas
    for j in range(9):
        aa = rr.uniform(0, 2 * np.pi)
        dd = rr.uniform(0.7, 0.95)
        v = np.maximum(v, np.clip((0.07 - np.hypot(x - np.cos(aa) * dd, y - np.sin(aa) * dd)) * 18, 0, 1))
    return np.clip(v, 0, 1)


def rasgo():
    """corte de garra: arco grosso afinando nas pontas; intensidade cresce para a ponta (frente)"""
    x, y = grid()
    cx, cy, R = 0.0, 0.85, 1.25
    r = np.hypot(x - cx, y - cy)
    a = np.arctan2(y - cy, x - cx)
    a0, a1 = math.radians(-160), math.radians(-20)
    u = np.clip((a - a0) / (a1 - a0), 0, 1)
    dentro = (a > a0) & (a < a1)
    w = 0.16 * np.clip(np.sin(np.pi * u), 0, 1) ** 0.8 + 0.01
    v = np.clip(1 - np.abs(r - R) / w, 0, 1) * dentro
    n = fbm(31, esc=10)
    return np.clip(v ** 0.7 * (0.35 + 0.75 * u) * (0.75 + 0.35 * n), 0, 1)


def gota():
    x, y = grid()
    r = np.hypot(x, y + 0.25)
    corpo = np.clip((0.55 - r) * 8, 0, 1)
    rabo = np.clip((0.55 * np.clip((0.3 - y) / 1.25, 0, 1) - np.abs(x)) * 10, 0, 1) * (y < -0.1)
    return np.clip(np.maximum(corpo, rabo), 0, 1)


def seta():
    """divisa (^) para efeitos de ajuda: sobe pelo corpo"""
    x, y = grid()
    d = np.abs(y + 0.15 + np.abs(x) * 0.9 - 0.25)
    v = np.clip(1 - d / 0.2, 0, 1) * (np.abs(x) < 0.75)
    return np.clip(v * (1.1 - np.abs(x) * 0.5), 0, 1)


def corrente():
    """elos de corrente em tira repetível (256x64): elo de frente (anel) e elo de lado (barra), alternados"""
    W, H = 256, 64
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    v = np.zeros((H, W), np.float32)
    cy = H / 2
    for i in range(4):
        cx = 32 + i * 64
        if i % 2 == 0:
            dx, dy = (x - cx) / 30, (y - cy) / 17
            r = np.hypot(dx, dy)
            v = np.maximum(v, np.clip(1 - np.abs(r - 0.78) / 0.24, 0, 1))
        else:
            dx, dy = (x - cx) / 46, (y - cy) / 7
            r = np.hypot(dx, dy)
            v = np.maximum(v, np.clip(1 - r, 0, 1) ** 0.5 * 0.9)
    # brilho de metal no topo de cada elo
    v = np.clip(v * (0.75 + 0.35 * np.clip((cy - y) / cy, -1, 1)), 0, 1)
    return v


def voronoi():
    """ruído celular repetível (para a esfera do projétil rolar)"""
    rng = np.random.default_rng(7)
    n = N
    pts = rng.random((14, 2)) * n
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    d1 = np.full((n, n), 1e9, np.float32)
    d2 = np.full((n, n), 1e9, np.float32)
    for px, py in pts:
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                d = np.hypot(x - px - ox, y - py - oy)
                d2 = np.where(d < d1, d1, np.minimum(d2, d))
                d1 = np.minimum(d1, d)
    v = (d2 - d1) / (n * 0.18)
    return np.clip(1 - v, 0, 1) ** 1.5


def ponto():
    """ponto de retícula: círculo chapado de borda nítida"""
    x, y = grid()
    r = np.hypot(x, y)
    return np.clip((0.9 - r) * 20, 0, 1)


def retalho():
    """pedaço de retícula: pontos que diminuem numa direção, dentro de um caco irregular"""
    x, y = grid()
    rr = random.Random(9)
    im = Image.new("L", (N, N), 0)
    pts = []
    for k in range(9):
        a = k / 9 * 2 * math.pi
        rad = rr.uniform(0.55, 0.95) * N / 2
        pts.append((N / 2 + math.cos(a) * rad, N / 2 + math.sin(a) * rad))
    ImageDraw.Draw(im).polygon(pts, fill=255)
    caco = np.asarray(im).astype(np.float32) / 255
    passo = 2 / 7.0
    u = (x + y) * 0.7071 / passo
    v = (x - y) * 0.7071 / passo
    d = np.hypot(u - np.round(u), v - np.round(v))
    raio = 0.12 + 0.36 * np.clip((1 - (x + 1) / 2) * 1.1, 0, 1)
    dots = np.clip((raio - d) * 14, 0, 1)
    return dots * caco


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for nm, fn in [("brilho", brilho), ("anel", anel), ("estrela", estrela), ("faisca", faisca), ("fumaca", fumaca),
                   ("estilhaco", estilhaco), ("respingo", respingo), ("rasgo", rasgo), ("gota", gota), ("seta", seta), ("corrente", corrente), ("voronoi", voronoi), ("ponto", ponto), ("retalho", retalho)]:
        v = fn()
        if nm == "faisca":
            v = v[::-1]          # cabeça em cima: o topo da textura segue a velocidade
        save(nm, v)
        print("textura", nm)
