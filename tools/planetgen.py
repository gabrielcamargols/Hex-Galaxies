"""Hex Galaxies - texturas dos planetas da galáxia do menu (estilo toon, cores chapadas).

Gera em planets/ (equiretangular 1024x512, sem emenda porque o ruído é calculado na esfera):
  valak.png    oceano com ilhas e cicatrizes de mineração enferrujadas (mapa "posto")
  tarhut.png   deserto de dunas laranja e cânions (mapa "tarhut")
  gigante.png  gigante gasoso em faixas
  gelo.png     planeta de gelo
  lava.png     planeta vulcânico
  anel.png     faixa do anel do gigante gasoso (1024x64)
  estrela.png  brilho radial (sprite da estrela / sóis)
  ../sky/espaco.jpg  céu escuro de estrelas e nebulosas do menu (4096x2048)

Uso: python tools/planetgen.py [pasta_saida]
"""
import os, sys
import numpy as np
from PIL import Image

W, H = 1024, 512


def sphere_dirs():
    lon = (np.arange(W) + 0.5) / W * 2 * np.pi - np.pi
    lat = np.pi / 2 - (np.arange(H) + 0.5) / H * np.pi
    lo, la = np.meshgrid(lon, lat)
    # Godot: u=0 em -X... qualquer orientação serve, é uma esfera girando
    return np.stack([np.cos(la) * np.cos(lo), np.sin(la), np.cos(la) * np.sin(lo)], -1), la


def fbm(P, seed, octaves=5, base=2.0, waves=24):
    rng = np.random.default_rng(seed)
    out = np.zeros(P.shape[:2])
    amp = 1.0
    tot = 0.0
    f = base
    for o in range(octaves):
        acc = np.zeros(P.shape[:2])
        for k in range(waves):
            d = rng.normal(size=3)
            d /= np.linalg.norm(d)
            acc += np.sin((P @ d) * f + rng.random() * 6.283)
        out += acc / np.sqrt(waves) * amp
        tot += amp
        amp *= 0.5
        f *= 2.05
    out /= tot
    return (out - out.min()) / (out.max() - out.min())


def ramp(v, stops):
    """posteriza: stops = [(limiar, cor_hex), ...] crescente"""
    img = np.zeros(v.shape + (3,))
    for th, c in stops:
        rgb = np.array([int(c[i:i + 2], 16) for i in (1, 3, 5)]) / 255.0
        img[v >= th] = rgb
    return img


def save(img, path, alpha=None):
    a = np.clip(img * 255, 0, 255).astype(np.uint8)
    if alpha is not None:
        a = np.dstack([a, np.clip(alpha * 255, 0, 255).astype(np.uint8)])
    Image.fromarray(a).save(path)


def valak(out):
    P, la = sphere_dirs()
    n = fbm(P, 11, 5, 1.6)
    img = ramp(n, [(0, "#0b3a63"), (0.3, "#11507e"), (0.4, "#1d7aa6"), (0.46, "#2aa6c8"), (0.5, "#e8d29a"),
                   (0.53, "#7fb54a"), (0.64, "#5a8f34"), (0.76, "#3e6a2a")])
    # cicatrizes de mineração: crateras enferrujadas nas ilhas
    m = fbm(P, 37, 3, 6.0)
    land = n >= 0.53
    scar = land & (m > 0.6)
    img[scar] = np.array([0xb0, 0x5a, 0x2c]) / 255
    img[land & (m > 0.7)] = np.array([0x6e, 0x34, 0x1c]) / 255
    # calotas polares
    ice = np.abs(la) > np.radians(74) + (fbm(P, 5, 2, 4.0) - 0.5) * 0.15
    img[ice] = np.array([0xe6, 0xf4, 0xff]) / 255
    save(img, os.path.join(out, "valak.png"))
    # luzes das minas (só nas cicatrizes, pontilhadas)
    rng = np.random.default_rng(3)
    lights = (scar & (rng.random(scar.shape) > 0.86)).astype(float)
    glow = np.zeros_like(lights)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            glow = np.maximum(glow, np.roll(np.roll(lights, dy, 0), dx, 1) * (1.0 if dx == 0 and dy == 0 else 0.5))
    li = np.dstack([glow * 1.0, glow * 0.62, glow * 0.25])
    save(li, os.path.join(out, "valak_luz.png"))


def tarhut(out):
    P, la = sphere_dirs()
    base = fbm(P, 21, 4, 1.4)
    # dunas: faixas onduladas
    dunes = 0.5 + 0.5 * np.sin(P[..., 0] * 22 + P[..., 2] * 9 + base * 9)
    v = base * 0.65 + dunes * 0.35
    img = ramp(v, [(0, "#7a3e22"), (0.3, "#9a6440"), (0.42, "#c87440"), (0.55, "#e0925a"), (0.66, "#c9965e"),
                   (0.76, "#f2cf92")])
    can = fbm(P, 77, 4, 3.0)
    img[np.abs(can - 0.5) < 0.018] = np.array([0x4a, 0x22, 0x14]) / 255  # cânions
    cr = fbm(P, 91, 3, 7.0)
    img[(cr > 0.88) & (base > 0.45)] = np.array([0xa3, 0x5c, 0xf0]) / 255  # cristais roxos
    save(img, os.path.join(out, "tarhut.png"))


def gigante(out):
    P, la = sphere_dirs()
    turb = fbm(P, 5, 4, 3.0)
    v = 0.5 + 0.5 * np.sin(P[..., 1] * 13 + turb * 4.5)
    img = ramp(v, [(0, "#3a2a6e"), (0.25, "#5a3d9a"), (0.45, "#8a5ac8"), (0.6, "#4cb8d8"), (0.78, "#9fe0ee"), (0.9, "#e8d0ff")])
    # grande tempestade
    c = np.array([0.55, -0.3, 0.78])
    c /= np.linalg.norm(c)
    d = np.linalg.norm(P - c, axis=-1)
    img[d < 0.2] = np.array([0xff, 0x7a, 0x9a]) / 255
    img[d < 0.12] = np.array([0xff, 0xb0, 0xc0]) / 255
    save(img, os.path.join(out, "gigante.png"))


def gelo(out):
    P, la = sphere_dirs()
    v = fbm(P, 44, 5, 2.0)
    img = ramp(v, [(0, "#5a8ab8"), (0.35, "#8ab8dc"), (0.5, "#c8e6f6"), (0.68, "#f2fbff")])
    cr = fbm(P, 45, 3, 5.0)
    img[np.abs(cr - 0.5) < 0.012] = np.array([0x3a, 0x6a, 0xa0]) / 255
    save(img, os.path.join(out, "gelo.png"))


def lava(out):
    P, la = sphere_dirs()
    v = fbm(P, 66, 5, 2.2)
    img = ramp(v, [(0, "#1a0e0e"), (0.4, "#2e1814"), (0.58, "#4a2418")])
    cr = fbm(P, 67, 4, 3.5)
    hot = np.abs(cr - 0.5) < 0.03
    img[hot] = np.array([0xff, 0x6a, 0x1a]) / 255
    img[np.abs(cr - 0.5) < 0.012] = np.array([0xff, 0xd0, 0x5a]) / 255
    save(img, os.path.join(out, "lava.png"))
    save(np.dstack([hot * 1.0, hot * 0.4, hot * 0.05]), os.path.join(out, "lava_luz.png"))


def anel(out):
    x = np.linspace(0, 1, 1024)
    rng = np.random.default_rng(8)
    a = np.zeros(1024)
    for k in range(40):
        c = rng.random()
        wdt = 0.005 + rng.random() * 0.04
        a += np.exp(-((x - c) / wdt) ** 2) * rng.random()
    a = np.clip(a / a.max() * 1.3, 0, 1) * np.clip(x * 8, 0, 1) * np.clip((1 - x) * 8, 0, 1)
    a = np.round(a * 4) / 4
    col = np.stack([0.75 + 0.2 * x, 0.7 + 0.1 * x, 0.95 - 0.1 * x], -1)
    img = np.repeat(col[None], 64, 0)
    save(img, os.path.join(out, "anel.png"), np.repeat((a * 0.85)[None], 64, 0))


def estrela(out):
    s = 256
    y, x = np.mgrid[0:s, 0:s] / (s - 1) * 2 - 1
    r = np.sqrt(x * x + y * y)
    core = np.clip(1 - r / 0.22, 0, 1) ** 0.6
    halo = np.exp(-(r / 0.42) ** 2) * 0.7 + np.exp(-(r / 0.8) ** 2) * 0.25
    ang = np.arctan2(y, x)
    rays = (np.abs(np.cos(ang * 2)) ** 40 + np.abs(np.cos(ang * 2 + np.pi / 4)) ** 60 * 0.5) * np.exp(-r * 2.2) * 0.6
    a = np.clip(core + halo + rays, 0, 1) * np.clip((1 - r) * 3, 0, 1)
    img = np.ones((s, s, 3))
    save(img, os.path.join(out, "estrela.png"), a)


def espaco(path):
    """céu do menu: fundo escuro azul/roxo, nebulosas suaves, estrelas e galáxias distantes"""
    global W, H
    W0, H0 = W, H
    W, H = 512, 256
    P, la = sphere_dirs()
    n1 = fbm(P, 101, 5, 1.5)
    n2 = fbm(P, 202, 4, 2.5)
    W, H = W0, H0
    def up(a):
        return np.array(Image.fromarray((a * 255).astype(np.uint8)).resize((4096, 2048), Image.BICUBIC)) / 255.0
    n1, n2 = up(n1), up(n2)
    base = np.array([0.02, 0.025, 0.07])
    neb_a = np.clip((n1 - 0.55) * 2.6, 0, 1) ** 1.5
    neb_b = np.clip((n2 - 0.6) * 3.0, 0, 1) ** 1.5
    img = base + neb_a[..., None] * np.array([0.3, 0.11, 0.44]) + neb_b[..., None] * np.array([0.05, 0.22, 0.36])
    # posteriza de leve (estilo chapado)
    img = np.round(img * 40) / 40
    rng = np.random.default_rng(9)
    h, w = img.shape[:2]
    # estrelas: pontos redondos e suaves (não ficam quadrados com o zoom)
    for k in range(9000):
        x, y = int(rng.integers(3, w - 3)), int(rng.integers(3, h - 3))
        b = rng.random() ** 3
        c = np.array([1.0, 0.95, 0.9]) if rng.random() < 0.7 else (np.array([0.7, 0.85, 1.0]) if rng.random() < 0.5 else np.array([1.0, 0.8, 0.6]))
        sg = 0.55 + b * 0.9
        yy, xx = np.mgrid[-2:3, -2:3]
        a = np.exp(-(xx ** 2 + yy ** 2) / (2 * sg * sg))[..., None] * (0.35 + 0.65 * b)
        sl = img[y - 2:y + 3, x - 2:x + 3]
        img[y - 2:y + 3, x - 2:x + 3] = np.maximum(sl, c * a)
    # estrelas grandes com cruz
    for k in range(60):
        x, y = rng.integers(12, w - 12), rng.integers(12, h - 12)
        c = np.array([1.0, 0.95, 0.85])
        L = rng.integers(6, 14)
        img[y, x - L:x + L + 1] = np.maximum(img[y, x - L:x + L + 1], c * 0.8)
        img[y - L:y + L + 1, x] = np.maximum(img[y - L:y + L + 1, x], c * 0.8)
        img[y - 1:y + 2, x - 1:x + 2] = c
    # galáxias espirais distantes
    for k in range(7):
        cx, cy = rng.integers(120, w - 120), rng.integers(300, h - 300)
        sz = rng.integers(30, 70)
        col = [np.array([0.85, 0.7, 1.0]), np.array([0.6, 0.85, 1.0]), np.array([1.0, 0.8, 0.6])][k % 3]
        tilt = 0.35 + rng.random() * 0.5
        rot = rng.random() * 6.28
        yy, xx = np.mgrid[-sz:sz + 1, -sz:sz + 1].astype(float)
        xr = xx * np.cos(rot) + yy * np.sin(rot)
        yr = (-xx * np.sin(rot) + yy * np.cos(rot)) / tilt
        r = np.sqrt(xr ** 2 + yr ** 2) / sz
        ang = np.arctan2(yr, xr)
        arm = 0.5 + 0.5 * np.cos(2 * ang - r * 9)
        a = np.clip((1 - r), 0, 1) * (0.25 + 0.75 * arm) * 0.8 + np.clip(1 - r * 4, 0, 1)
        a = np.round(np.clip(a, 0, 1) * 4) / 4
        sl = img[cy - sz:cy + sz + 1, cx - sz:cx + sz + 1]
        img[cy - sz:cy + sz + 1, cx - sz:cx + sz + 1] = sl * (1 - a[..., None] * 0.8) + col * a[..., None] * 0.8
    Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8)).save(path, quality=88)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "planets"
    os.makedirs(out, exist_ok=True)
    for f in (valak, tarhut, gigante, gelo, lava, anel, estrela):
        f(out)
        print(f.__name__, "ok")
    espaco(os.path.join(os.path.dirname(os.path.abspath(out)), "sky", "espaco.jpg"))
    print("espaco ok")
