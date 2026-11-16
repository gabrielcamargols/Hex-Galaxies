"""FORJA — texturas dos ZUKUNFT (tecnologia, hologramas, hexágonos e pixels).
Mesmo padrão da forja_tex.py: intensidade no R e no alfa; borda baixa (contorno) e miolo alto (brilho).
python3 tools/forja_tex_zuk.py  ->  vfx/tex/{hex_oco,pixel,hex_grade,glitch,mira_hex,pena,lamina}.png"""
import math, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
import sys
sys.path.insert(0, os.path.dirname(__file__))
from forja_tex import save, grid, N

S = 512   # desenha grande e reduz (bordas limpas)


def _down(v, n=N):
    return np.asarray(Image.fromarray((np.clip(v, 0, 1) * 255).astype(np.uint8)).resize((n, n), Image.LANCZOS)).astype(np.float32) / 255


def _hex_pts(cx, cy, r, rot=0.0):
    return [(cx + r * math.cos(math.radians(60 * i + rot)), cy + r * math.sin(math.radians(60 * i + rot))) for i in range(6)]


def _mask(draw_fn, s=S):
    im = Image.new("L", (s, s), 0)
    draw_fn(ImageDraw.Draw(im))
    return np.asarray(im).astype(np.float32) / 255 > 0.5


def _edge_soft(m, k=10.0, hi=0.25):
    d = ndi.distance_transform_edt(m) / k
    return np.clip(d, 0, 1) * (1 - hi) + m * hi


def hex_oco():
    """hexágono vazado: aro grosso (miolo do aro brilha) + aro fino de dentro; para escudos, portais, ondas"""
    out = _mask(lambda d: d.polygon(_hex_pts(S / 2, S / 2, S * 0.47, 30), fill=255))
    inn = _mask(lambda d: d.polygon(_hex_pts(S / 2, S / 2, S * 0.37, 30), fill=255))
    aro = out & ~inn
    v = _edge_soft(aro, 14, 0.2)
    fino_o = _mask(lambda d: d.polygon(_hex_pts(S / 2, S / 2, S * 0.32, 30), fill=255))
    fino_i = _mask(lambda d: d.polygon(_hex_pts(S / 2, S / 2, S * 0.295, 30), fill=255))
    v = np.maximum(v, (fino_o & ~fino_i) * 0.55)
    return _down(v)


def pixel():
    """bloco de pixel: quadrado de canto vivo, contorno baixo e miolo alto (desintegração digital)"""
    m = _mask(lambda d: d.rectangle([S * 0.16, S * 0.16, S * 0.84, S * 0.84], fill=255))
    v = _edge_soft(m, 40, 0.3)
    # brilho de canto (reflexo de tela)
    hl = _mask(lambda d: d.rectangle([S * 0.26, S * 0.26, S * 0.46, S * 0.46], fill=255))
    v = np.where(hl, 1.0, v)
    return _down(v)


def hex_grade():
    """colmeia de energia: grade de hexágonos finos que some para a borda (matriz de escudo)"""
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    r = S * 0.11
    w = r * math.sqrt(3)
    for row in range(-1, 8):
        for col in range(-1, 7):
            cx = col * w + (w / 2 if row % 2 else 0)
            cy = row * r * 1.5
            d.polygon(_hex_pts(cx, cy, r * 0.93, 30), outline=255, width=int(S * 0.018))
    v = np.asarray(im).astype(np.float32) / 255
    x, y = np.mgrid[0:S, 0:S].astype(np.float32) / S * 2 - 1
    fall = np.clip(1.15 - np.hypot(x, y), 0, 1) ** 0.8
    v = ndi.gaussian_filter(v, 1.2) * 1.3
    return _down(np.clip(v, 0, 1) * fall)


def glitch():
    """faixas de glitch: barras horizontais de comprimentos e brilhos diferentes, com blocos soltos"""
    rng = np.random.default_rng(7)
    v = np.zeros((S, S), np.float32)
    y = int(S * 0.08)
    while y < S * 0.92:
        h = int(rng.integers(S * 0.02, S * 0.07))
        x0 = int(rng.integers(0, S * 0.35))
        x1 = int(rng.integers(S * 0.6, S))
        v[y:y + h, x0:x1] = rng.uniform(0.45, 1.0)
        if rng.random() < 0.6:
            bx = int(rng.integers(0, S - 40))
            v[y:y + h, bx:bx + int(rng.integers(12, 40))] = 1.0
        y += h + int(rng.integers(S * 0.015, S * 0.06))
    edge = ndi.binary_erosion(v > 0, iterations=4)
    v = np.where((v > 0) & ~edge, v * 0.35, v)
    return _down(v)


def mira_hex():
    """retículo hexagonal: aro fino, quatro marcas para dentro e ponto no centro"""
    out = _mask(lambda d: d.polygon(_hex_pts(S / 2, S / 2, S * 0.44, 0), fill=255))
    inn = _mask(lambda d: d.polygon(_hex_pts(S / 2, S / 2, S * 0.39, 0), fill=255))
    v = (out & ~inn).astype(np.float32) * 0.85

    def marcas(d):
        c = S / 2
        for a in (0, 90, 180, 270):
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            d.line([(c + ca * S * 0.17, c + sa * S * 0.17), (c + ca * S * 0.33, c + sa * S * 0.33)], fill=255, width=int(S * 0.035))
        d.ellipse([c - S * 0.035, c - S * 0.035, c + S * 0.035, c + S * 0.035], fill=255)
    v = np.maximum(v, _mask(marcas).astype(np.float32))
    v = np.maximum(v, ndi.gaussian_filter(v, 6) * 0.5)
    return _down(v)


def pena():
    """pena de chama (Fênix): gota alongada com ponta em cima e recortes de fogo nas laterais"""
    def f(d):
        c = S / 2
        pts = []
        for i in range(41):
            t = i / 40
            yy = S * (0.95 - 0.9 * t)
            wd = S * 0.24 * math.sin(math.pi * (t ** 0.75)) * (1 - 0.3 * t)
            wd *= 1 + 0.18 * math.sin(t * 22)
            pts.append((c + wd, yy))
        for i in range(40, -1, -1):
            t = i / 40
            yy = S * (0.95 - 0.9 * t)
            wd = S * 0.24 * math.sin(math.pi * (t ** 0.75)) * (1 - 0.3 * t)
            wd *= 1 + 0.18 * math.sin(t * 22 + 1.7)
            pts.append((c - wd, yy))
        d.polygon(pts, fill=255)
    m = _mask(f)
    v = _edge_soft(m, 30, 0.15)
    rib = _mask(lambda d: d.line([(S / 2, S * 0.9), (S / 2, S * 0.2)], fill=255, width=int(S * 0.02)))
    v = np.where(rib & m, 1.0, v)
    return _down(v)


def lamina():
    """lâmina de energia: meia-lua afiada (círculo menos círculo deslocado), fio de fora brilhando"""
    a = _mask(lambda d: d.ellipse([S * 0.06, S * 0.06, S * 0.94, S * 0.94], fill=255))
    b = _mask(lambda d: d.ellipse([S * 0.0, S * 0.16, S * 0.8, S * 0.96], fill=255))
    m = a & ~b
    dist_b = ndi.distance_transform_edt(~b) / 40.0          # longe do recorte = perto do fio de fora
    v = np.clip(dist_b, 0, 1) ** 0.8 * m
    v = np.maximum(v, _edge_soft(m, 6, 0.0) * 0.4)
    return _down(v)


if __name__ == "__main__":
    OUT = os.path.join(os.path.dirname(__file__), "..", "vfx", "tex")
    for nm, fn in [("hex_oco", hex_oco), ("pixel", pixel), ("hex_grade", hex_grade), ("glitch", glitch),
                   ("mira_hex", mira_hex), ("pena", pena), ("lamina", lamina)]:
        save(nm, fn())
        print("textura", nm)
