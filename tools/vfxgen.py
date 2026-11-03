"""Hex Galaxies - gerador de VFX 2.5D (flipbooks) no estilo anime/cartoon.

Cada efeito vira uma tira PNG com FRAMES quadros de 256x256 em res://vfx/<nome>.png.

Estilo (das referências): sem contorno preto; cada forma tem 3 tons chapados
- borda escura saturada, meio saturado e núcleo quase branco - calculados pela
distância até a borda; brilho (glow) em volta das partes claras; bordas
recortadas e irregulares, buracos (espaço negativo), respingos e faíscas soltas,
arcos finos de movimento.

Uso:  python tools/vfxgen.py [pasta_saida] [--preview arquivo.png] [--only nome1,nome2]
Para criar um efeito novo: escreva uma função fx_<nome>(t, R) que devolve camadas
(Layer) para o instante t (0..1); ela entra automaticamente na geração.
"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, distance_transform_edt, map_coordinates

FRAMES = 12
OUT = 256          # tamanho final de cada quadro
SS = 2             # supersample
S = OUT * SS
CX, CY = S // 2, int(S * 0.56)   # centro (um pouco abaixo do meio: o "chão" do efeito)

_noise_cache = {}


def noise_field(seed, sigma):
    key = (seed, sigma)
    if key not in _noise_cache:
        r = np.random.default_rng(seed)
        n = gaussian_filter(r.random((S, S)), sigma * SS)
        _noise_cache[key] = (n - n.min()) / (n.max() - n.min() + 1e-9)
    return _noise_cache[key]


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


class Layer:
    """uma forma pintada.  col = meio, light = núcleo, dark = borda.
    jag = irregularidade da borda, holes = buracos, flecks = respingos soltos, glow = brilho."""

    def __init__(self, col, light=None, dark=None, alpha=1.0, outline=False, glow=0.5, jag=0.5, holes=0.2, flecks=0, core=0.55):
        self.mask = Image.new("L", (S, S), 0)
        self.d = ImageDraw.Draw(self.mask)
        self.col = hexc(col)
        self.light = hexc(light) if light else np.minimum(255, self.col * 0.4 + 170)
        self.dark = hexc(dark) if dark else self.col * 0.55
        self.alpha = alpha
        self.glow = glow
        self.jag = jag
        self.holes = holes
        self.flecks = flecks
        self.core = core

    # primitivas (coordenadas relativas ao centro, em pixels de 256)
    def disc(self, x, y, r):
        x, y, r = CX + x * SS, CY + y * SS, max(0.5, r * SS)
        self.d.ellipse([x - r, y - r, x + r, y + r], fill=255)
        return self

    def ellipse(self, x, y, rx, ry):
        x, y, rx, ry = CX + x * SS, CY + y * SS, max(0.5, rx * SS), max(0.5, ry * SS)
        self.d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=255)
        return self

    def poly(self, pts):
        if len(pts) >= 3:
            self.d.polygon([(CX + px * SS, CY + py * SS) for px, py in pts], fill=255)
        return self

    def line(self, pts, w):
        p = [(CX + px * SS, CY + py * SS) for px, py in pts]
        self.d.line(p, fill=255, width=max(1, int(w * SS)), joint="curve")
        for px, py in p:
            r = w * SS / 2
            self.d.ellipse([px - r, py - r, px + r, py + r], fill=255)
        return self

    def taper(self, pts, w0, w1):
        """traço que afina (pincelada de movimento)"""
        n = len(pts)
        for i in range(n - 1):
            w = w0 + (w1 - w0) * i / max(1, n - 2)
            self.line([pts[i], pts[i + 1]], max(0.6, w))
        return self

    def ring(self, x, y, rx, ry, w):
        x, y, rx, ry = CX + x * SS, CY + y * SS, rx * SS, ry * SS
        self.d.ellipse([x - rx, y - ry, x + rx, y + ry], outline=255, width=max(1, int(w * SS)))
        return self

    def arc(self, x, y, rx, ry, a0, a1, w):
        """arco fino (rastro de movimento em volta do efeito)"""
        pts = []
        for i in range(24):
            a = a0 + (a1 - a0) * i / 23
            pts.append((x + math.cos(a) * rx, y + math.sin(a) * ry))
        ww = [w * math.sin(math.pi * i / 23) + 0.6 for i in range(24)]
        for i in range(23):
            self.line([pts[i], pts[i + 1]], ww[i])
        return self

    def spikes(self, x, y, n, r_in, r_out, rot0=0.0, jitter=0.35, rr=None):
        rr = rr or np.random.default_rng(1)
        pts = []
        for k in range(n * 2):
            a = rot0 + math.pi * k / n
            r = (r_out * (1 - jitter + 2 * jitter * rr.random())) if k % 2 == 0 else r_in
            pts.append((x + math.cos(a) * r, y + math.sin(a) * r))
        return self.poly(pts)

    def cut_disc(self, x, y, r):
        x, y, r = CX + x * SS, CY + y * SS, r * SS
        self.d.ellipse([x - r, y - r, x + r, y + r], fill=0)
        return self


def _over(dst, src):
    a = src[..., 3:4]
    da = dst[..., 3:4]
    out_a = a + da * (1 - a)
    rgb = (src[..., :3] * a + dst[..., :3] * da * (1 - a)) / np.maximum(out_a, 1e-6)
    dst[..., :3] = rgb
    dst[..., 3:4] = out_a


YY, XX = np.mgrid[0:S, 0:S].astype(float)


def render(layers, seed):
    canvas = np.zeros((S, S, 4), float)
    for i, L in enumerate(layers):
        m = np.asarray(L.mask, float) / 255.0
        if m.max() <= 0 or L.alpha <= 0.01:
            continue
        sd = seed * 37 + i * 11
        # borda irregular: desloca a forma com ruído (efeito de respingo / chama)
        if L.jag > 0:
            amp = L.jag * 9 * SS
            dx = (noise_field(sd, 5) - 0.5) * 2 * amp
            dy = (noise_field(sd + 1, 5) - 0.5) * 2 * amp
            m = map_coordinates(m, [YY + dy, XX + dx], order=1, mode="constant")
        inside = m > 0.5
        if not inside.any():
            continue
        depth = distance_transform_edt(inside)
        dn = depth / max(depth.max(), 1.0)
        # buracos (espaço negativo) na região de meio-tom
        if L.holes > 0:
            hn = noise_field(sd + 2, 3.2)
            band = inside & (dn > 0.05) & (dn < 0.55)
            thr = np.quantile(hn[band], 1 - L.holes * 0.55) if band.any() else 2.0
            cut = band & (hn > thr)
            inside = inside & ~cut
            depth = distance_transform_edt(inside)
            dn = depth / max(depth.max(), 1.0)
        # brilho atrás da forma
        if L.glow > 0:
            g = gaussian_filter((dn > 0.25).astype(float) + inside * 0.4, 11 * SS) * L.glow * 1.6
            gc = (L.col * 0.5 + L.light * 0.5)
            _over(canvas, np.dstack([np.broadcast_to(gc, (S, S, 3)), np.clip(g, 0, 0.75) * L.alpha]))
        # 3 tons chapados pela profundidade: borda escura / meio / núcleo claro
        lo, mid, hi = L.dark, L.col, L.light
        w1 = np.clip((dn - 0.16) / 0.04, 0, 1)[..., None]
        w2 = np.clip((dn - L.core) / 0.05, 0, 1)[..., None]
        rgb = lo * (1 - w1) + mid * w1
        rgb = rgb * (1 - w2) + hi * w2
        a = gaussian_filter(inside.astype(float), 0.7 * SS)
        _over(canvas, np.dstack([rgb, a * L.alpha]))
        # respingos soltos perto da borda
        if L.flecks > 0:
            rr = np.random.default_rng(sd + 5)
            ys, xs = np.nonzero(inside)
            cy, cx = ys.mean(), xs.mean()
            fl = Image.new("L", (S, S), 0)
            fd = ImageDraw.Draw(fl)
            for k in range(L.flecks):
                j = rr.integers(len(xs))
                px, py = xs[j], ys[j]
                vx, vy = px - cx, py - cy
                nrm = math.hypot(vx, vy) + 1e-6
                dist = (8 + rr.random() * 26) * SS
                qx, qy = px + vx / nrm * dist, py + vy / nrm * dist
                r = (1.2 + rr.random() * 3.2) * SS
                fd.ellipse([qx - r, qy - r * 0.7, qx + r, qy + r * 0.7], fill=255)
            fm = np.asarray(fl, float) / 255.0
            frgb = np.broadcast_to(mid * 0.5 + hi * 0.5, (S, S, 3))
            _over(canvas, np.dstack([frgb, fm * L.alpha]))
    canvas[..., 3] = np.clip(canvas[..., 3], 0, 1) * 255.0
    img = Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), "RGBA")
    return img.resize((OUT, OUT), Image.LANCZOS)


def ease(t):
    return 1 - (1 - t) ** 3


def fade(t, start=0.6):
    return 1.0 if t < start else max(0.0, 1 - (t - start) / (1 - start))


def rot(x, y, a):
    c, s = math.cos(a), math.sin(a)
    return x * c - y * s, x * s + y * c


# paletas prontas (borda, meio, núcleo)
WHITE = dict(col="#dfe4f2", light="#ffffff", dark="#8a93b8")      # tingível pelo jogo
FIRE = dict(col="#ff7a22", light="#ffe86a", dark="#c2301c")
BLUE = dict(col="#3a7cff", light="#d8f2ff", dark="#1a2a8a")
PINK = dict(col="#e040e8", light="#ffd8ff", dark="#6a1a9a")
GOLD = dict(col="#ffc832", light="#fffbd0", dark="#d0761a")
ICE = dict(col="#c8daf0", light="#ffffff", dark="#4a6a9e")
GREEN = dict(col="#5ae05a", light="#eaffc8", dark="#1f7a3a")
VOID = dict(col="#3a40d8", light="#ff9ae0", dark="#140c3a")
ROCK = dict(col="#8c8480", light="#c8beb6", dark="#4a4442")
SMOKE = dict(col="#8a8aa0", light="#c8c8d8", dark="#4a4a62")


# ===================== efeitos =====================
# t = 0..1; R = gerador aleatório fixo por efeito

def fx_slash(t, R):
    """golpe: meia-lua com rastro e faíscas (tingível)"""
    a0 = -1.6 + 2.4 * ease(min(1, t * 1.8))
    span = 2.3 * (1 - 0.5 * t)
    L = Layer(alpha=fade(t, 0.45), jag=0.25, holes=0.1, flecks=10, glow=0.5, core=0.5, **WHITE)
    pts_o, pts_i = [], []
    for k in range(24):
        a = a0 - span * k / 23
        w = math.sin(math.pi * k / 23) ** 0.8
        pts_o.append((math.cos(a) * 108, math.sin(a) * 108 * 0.7 - 25))
        pts_i.append((math.cos(a) * (108 - 50 * w), math.sin(a) * (108 - 50 * w) * 0.7 - 25))
    L.poly(pts_o + pts_i[::-1])
    tr = Layer(alpha=fade(t, 0.3) * 0.8, jag=0.1, holes=0, glow=0.2, **WHITE)
    tr.arc(0, -25, 122, 85, a0 - span * 1.1, a0 + 0.1, 3)
    return [tr, L]


def fx_hit(t, R):
    """impacto: estrela de pontas finas + aro + faíscas (referência 2)"""
    s = ease(min(1, t * 2.4)) * (1 - 0.25 * t)
    al = fade(t, 0.35)
    rr = np.random.default_rng(3)
    star = Layer(alpha=al, jag=0.15, holes=0.0, flecks=16, glow=0.9, core=0.35, **GOLD)
    star.spikes(0, -30, 7, 14 * s, 92 * s, t * 0.6, 0.45, rr)
    ring = Layer(alpha=al * 0.9, jag=0.2, holes=0.3, glow=0.4, **FIRE)
    ring.arc(0, -30, 62 * s + 4, 62 * s + 4, 0.3, 5.2, 4)
    return [ring, star]


def fx_boom(t, R):
    """explosão: fogo recortado com buracos + fumaça azulada (referência 1)"""
    rr = np.random.default_rng(5)
    smoke = Layer(alpha=fade(t, 0.45) * 0.95, jag=1.1, holes=0.5, flecks=10, glow=0.0, col="#5a5e7a", light="#9a9eb8", dark="#2a2c40")
    fire = Layer(alpha=fade(t, 0.35), jag=1.3, holes=0.55, flecks=26, glow=0.8, **FIRE)
    for k in range(10):
        a = rr.random() * math.tau
        d = 46 * ease(t) * (0.4 + rr.random())
        r = (28 + 24 * rr.random()) * (0.45 + ease(min(1, t * 2)))
        x, y = rot(d, 0, a)
        if t > 0.2:
            smoke.disc(x * 1.1, y * 0.8 - 30 - 55 * t, r * (0.9 + 0.4 * t))
        if t < 0.75:
            fire.disc(x * 0.8, y * 0.7 - 30 - 15 * t, r * 0.85 * (1 - t * 0.8))
    if t < 0.3:
        fire.disc(0, -30, 50 * (1 - t / 0.3) + 10)
    return [smoke, fire]


def fx_smoke(t, R):
    """puf de fumaça (derrota, poeira)"""
    L = Layer(alpha=fade(t, 0.35), jag=0.6, holes=0.3, flecks=8, glow=0.0, **SMOKE)
    rr = np.random.default_rng(9)
    for k in range(8):
        a = rr.random() * math.tau
        d = 18 + 48 * ease(t) * rr.random()
        x, y = rot(d, 0, a)
        L.disc(x, y * 0.5 - 10 - 60 * t * rr.random(), (16 + 18 * rr.random()) * (0.5 + ease(t)))
    return [L]


def fx_ring(t, R):
    """onda de choque no chão (vista de cima; tingível)"""
    r = 20 + 100 * ease(t)
    L = Layer(alpha=fade(t, 0.45), jag=0.5, holes=0.35, flecks=14, glow=0.5, core=0.6, **WHITE)
    L.ring(0, -10, r, r, 20 * (1 - 0.7 * t) + 3)
    return [L]


def fx_heal(t, R):
    """cura: espiral de folhas/luz verde subindo + cruzes brilhantes"""
    rr = np.random.default_rng(3)
    swirl = Layer(alpha=fade(t, 0.55), jag=0.3, holes=0.25, flecks=12, glow=0.8, **GREEN)
    for k in range(2):
        pts = []
        for i in range(16):
            u = i / 15
            a = k * math.pi + u * 5 + t * 6
            pts.append((math.cos(a) * (55 - 25 * u), 40 - u * 140 * ease(min(1, t * 1.5)) + math.sin(a) * 12))
        swirl.taper(pts, 9, 1)
    pl = Layer(alpha=fade(t, 0.6), jag=0.05, holes=0.0, glow=1.0, core=0.4, **GREEN)
    for k in range(5):
        x = (rr.random() - 0.5) * 110
        y = 40 - 150 * ((t + rr.random() * 0.6) % 1.0)
        s = 8 + 6 * rr.random()
        pl.poly([(x - s / 3, y - s), (x + s / 3, y - s), (x + s / 3, y - s / 3), (x + s, y - s / 3), (x + s, y + s / 3),
                 (x + s / 3, y + s / 3), (x + s / 3, y + s), (x - s / 3, y + s), (x - s / 3, y + s / 3), (x - s, y + s / 3),
                 (x - s, y - s / 3), (x - s / 3, y - s / 3)])
    return [swirl, pl]


def fx_shield(t, R):
    """escudo: orbe de energia com aro em volta (referência 1, orbe azul)"""
    s = ease(min(1, t * 2.5)) * (1 + 0.04 * math.sin(t * 20))
    al = fade(t, 0.55)
    orb = Layer(alpha=al * 0.85, jag=0.35, holes=0.45, flecks=8, glow=0.9, core=0.7, **WHITE)
    orb.disc(0, -40, 72 * s)
    orb.cut_disc(-14, -54, 40 * s)
    ring = Layer(alpha=al, jag=0.2, holes=0.2, glow=0.5, **WHITE)
    ring.arc(0, -40, 92 * s + 2, 30 * s + 1, -0.2 + t * 3, 4.6 + t * 3, 5)
    return [orb, ring]


def fx_aura(t, R):
    """aura de poder: labaredas recortadas subindo (tingível)"""
    L = Layer(alpha=fade(t, 0.55), jag=0.8, holes=0.35, flecks=14, glow=0.8, **WHITE)
    rr = np.random.default_rng(4)
    for k in range(8):
        x = -66 + 132 * k / 7 + (rr.random() - 0.5) * 10
        h = (60 + 55 * rr.random()) * math.sin(math.pi * min(1, t * 1.3 + rr.random() * 0.2))
        base = 50 - abs(x) * 0.25
        w = 11 + 6 * rr.random()
        L.poly([(x - w, base), (x + w, base), (x + w * 0.4, base - h * 0.6), (x + 6 * math.sin(t * 9 + k), base - h), (x - w * 0.4, base - h * 0.6)])
    return [L]


def fx_curse(t, R):
    """maldição: fiapos de fumaça mágica em espiral (referência 3)"""
    L = Layer(alpha=fade(t, 0.55), jag=0.7, holes=0.4, flecks=14, glow=0.7, **VOID)
    for k in range(3):
        pts = []
        for i in range(18):
            u = i / 17
            a = k * 2.1 + u * 4 + t * 5
            r = 25 + 75 * u * ease(min(1, t * 1.6))
            pts.append((math.cos(a) * r, math.sin(a) * r * 0.6 - 40 - u * 40))
        L.taper(pts, 22, 3)
    eye = Layer(alpha=fade(t, 0.4) if t > 0.15 else 0, jag=0.05, holes=0, glow=1.0, col="#f0ff6a", light="#ffffff", dark="#9ac030")
    eye.ellipse(-14, -50, 6, 3.5).ellipse(14, -50, 6, 3.5)
    return [L, eye]


def fx_crystal(t, R):
    """estilhaços de cristal saindo do centro (tingível)"""
    L = Layer(alpha=fade(t, 0.5), jag=0.1, holes=0.1, flecks=18, glow=0.7, core=0.45, **WHITE)
    rr = np.random.default_rng(6)
    for k in range(10):
        a = math.tau * k / 10 + rr.random() * 0.4
        d = 10 + 90 * ease(t) * (0.7 + 0.5 * rr.random())
        ln = 28 + 16 * rr.random()
        x, y = rot(d, 0, a)
        tx, ty = rot(d + ln, 0, a)
        nx, ny = rot(0, 8, a)
        L.poly([(x + nx, (y + ny) * 0.8 - 30), (tx, ty * 0.8 - 30), (x - nx, (y - ny) * 0.8 - 30), (x - (tx - x) * 0.25, (y - (ty - y) * 0.25) * 0.8 - 30)])
    return [L]


def fx_bolt(t, R):
    """raio em zigue-zague + estouro no chão (referência 1)"""
    rr = np.random.default_rng(int(t * FRAMES) + 11)
    al = fade(t, 0.5)
    L = Layer(alpha=al, jag=0.05, holes=0.0, glow=1.2, core=0.3, **GOLD)
    pts = [(-10, -125)]
    for k in range(1, 7):
        pts.append(((rr.random() - 0.5) * 60, -125 + k * 28))
    pts.append((0, 45))
    L.taper(pts, 7, 4)
    burst = Layer(alpha=al, jag=0.4, holes=0.2, flecks=18, glow=1.0, core=0.4, **GOLD)
    s = ease(min(1, t * 2.5))
    burst.spikes(0, 45, 6, 8 * s, 48 * s, -math.pi / 2, 0.5, rr)
    burst.ellipse(0, 46, 40 * s, 8 * s)
    return [burst, L]


def fx_poison(t, R):
    """veneno: poça e bolhas verdes"""
    rr = np.random.default_rng(7)
    drip = Layer(alpha=fade(t, 0.5), jag=0.6, holes=0.3, flecks=10, glow=0.5, col="#4ac03a", light="#c8ff8a", dark="#1a5a2a")
    drip.ellipse(0, 40, 54 * ease(min(1, t * 2)), 15 * ease(min(1, t * 2)))
    L = Layer(alpha=fade(t, 0.6), jag=0.15, holes=0.0, glow=0.7, core=0.45, col="#7ae05a", light="#eaffc0", dark="#2a7a2a")
    for k in range(9):
        x = (rr.random() - 0.5) * 100
        y = 30 - 130 * ((t * 0.9 + rr.random() * 0.5) % 1.0)
        L.disc(x, y, 5 + 9 * rr.random())
    return [drip, L]


def fx_fire(t, R):
    """chamas recortadas (fênix, incêndio)"""
    L = Layer(alpha=fade(t, 0.6), jag=1.2, holes=0.5, flecks=22, glow=0.9, **FIRE)
    rr = np.random.default_rng(8)
    for k in range(7):
        x = -62 + 124 * k / 6
        h = (85 + 60 * rr.random()) * math.sin(math.pi * min(1, t * 1.2 + 0.1)) * (1 + 0.15 * math.sin(t * 25 + k))
        w = 19
        L.poly([(x - w, 50), (x + w, 50), (x + w * 0.4, 50 - h * 0.6), (x + 6 * math.sin(t * 15 + k), 50 - h), (x - w * 0.4, 50 - h * 0.6)])
    return [L]


def fx_spikes(t, R):
    """armadilha/estacas: espinhos saindo do chão como respingo (referência 1, gelo)"""
    L = Layer(alpha=fade(t, 0.6), jag=0.3, holes=0.25, flecks=14, glow=0.3, **ICE)
    up = math.sin(math.pi * min(1, t * 1.5)) if t < 0.66 else max(0, 1 - (t - 0.66) * 3)
    rr = np.random.default_rng(10)
    for k in range(8):
        x = -76 + 152 * k / 7 + (rr.random() - 0.5) * 8
        h = (40 + 40 * rr.random()) * up
        L.poly([(x - 12, 50), (x + 12, 50), (x + (rr.random() - 0.5) * 10, 50 - h)])
    base = Layer(alpha=fade(t, 0.6), jag=0.5, holes=0.2, glow=0.0, col="#4a6a9e", light="#8aa8d0", dark="#2a3a5e")
    base.ellipse(0, 52, 90 * min(1, t * 3) + 1, 9)
    return [base, L]


def fx_vortex(t, R):
    """abismo: redemoinho de fiapos azul-escuros com núcleo rosa (referência 3)"""
    s = ease(min(1, t * 2))
    L = Layer(alpha=fade(t, 0.6), jag=0.6, holes=0.35, flecks=16, glow=0.8, **VOID)
    for arm in range(3):
        pts = []
        for k in range(16):
            a = arm * math.tau / 3 + k * 0.33 - t * 9
            r = 6 + k * 5.6 * s
            x, y = rot(r, 0, a)
            pts.append((x, y * 0.42 + 10))
        L.taper(pts, 4, 16)
    core = Layer(alpha=fade(t, 0.6), jag=0.2, holes=0, glow=1.2, core=0.3, col="#40c0ff", light="#e0ffff", dark="#2040c0")
    core.poly([(-8, 12), (8, 12), (2, -30 * s), (0, -44 * s), (-2, -30 * s)])
    return [L, core]


def fx_portal(t, R):
    """portal / teletransporte (tingível)"""
    s = ease(min(1, t * 2)) * (1 - max(0, t - 0.7) / 0.3)
    ring = Layer(alpha=1.0, jag=0.4, holes=0.3, flecks=12, glow=1.0, core=0.55, **WHITE)
    ring.ring(0, 30, 72 * s + 1, 24 * s + 1, 12)
    sp = Layer(alpha=fade(t, 0.5), jag=0.0, holes=0, glow=1.0, core=0.3, **WHITE)
    rr = np.random.default_rng(2)
    for k in range(8):
        x = (rr.random() - 0.5) * 120 * s
        y = 30 - 120 * ((t + rr.random()) % 1.0)
        sp.spikes(x, y, 4, 2, 9, 0, 0.1, rr)
    return [ring, sp]


def fx_mark(t, R):
    """mira travando no alvo"""
    s = 1.6 - 0.6 * ease(min(1, t * 2))
    L = Layer(alpha=fade(t, 0.7), jag=0.05, holes=0.0, glow=0.9, core=0.5, col="#ff4a3a", light="#ffd0c0", dark="#9a1a10")
    L.ring(0, -40, 46 * s, 46 * s, 7)
    for a in range(4):
        x1, y1 = rot(30 * s, 0, a * math.pi / 2 + t)
        x2, y2 = rot(64 * s, 0, a * math.pi / 2 + t)
        L.taper([(x2, y2 - 40), (x1, y1 - 40)], 9, 2)
    return [L]


def fx_glue(t, R):
    """espuma adesiva / raízes prendendo"""
    L = Layer(alpha=fade(t, 0.65), jag=0.7, holes=0.3, flecks=14, glow=0.3, col="#c8e050", light="#ffffd0", dark="#6a8a20")
    rr = np.random.default_rng(12)
    s = ease(min(1, t * 2.2))
    for k in range(8):
        a = math.tau * k / 8 + rr.random() * 0.5
        x, y = rot(35 * s * (0.6 + 0.6 * rr.random()), 0, a)
        L.disc(x, y * 0.45 + 40, (12 + 10 * rr.random()) * s)
    L.ellipse(0, 40, 44 * s, 14 * s)
    return [L]


def fx_rock(t, R):
    """pedras saindo do chão (barreira, terremoto) - blocos facetados sem contorno"""
    dust = Layer(alpha=fade(t, 0.4) * 0.9, jag=0.7, holes=0.35, flecks=14, glow=0.0, col="#c8a878", light="#efd8a8", dark="#8a6a44")
    rock = Layer(alpha=fade(t, 0.7), jag=0.1, holes=0.0, glow=0.0, core=0.45, **ROCK)
    rr = np.random.default_rng(13)
    up = ease(min(1, t * 2.5))
    for k in range(5):
        x = -52 + 104 * k / 4 + (rr.random() - 0.5) * 12
        h = (40 + 42 * rr.random()) * up
        w = 17 + 8 * rr.random()
        rock.poly([(x - w, 50), (x - w * 0.8, 50 - h * 0.8), (x - w * 0.2, 50 - h), (x + w * 0.6, 50 - h * 0.9), (x + w, 50)])
    for k in range(7):
        a = rr.random() * math.pi
        x, y = rot(30 + 62 * ease(t), 0, a + math.pi)
        dust.disc(x, 50 + y * 0.3, 16 * (1 - t * 0.5))
    return [dust, rock]


def fx_ink(t, R):
    """tinta / véu de sombra: manchas escuras com brilho roxo (referência 3)"""
    L = Layer(alpha=fade(t, 0.55), jag=0.8, holes=0.35, flecks=18, glow=0.4, col="#3a2a9a", light="#c080ff", dark="#120a30")
    rr = np.random.default_rng(14)
    for k in range(10):
        a = rr.random() * math.tau
        d = 15 + 80 * ease(t) * rr.random()
        x, y = rot(d, 0, a)
        L.disc(x, y * 0.7 - 20, (9 + 14 * rr.random()) * (1 - 0.4 * t))
    return [L]


def fx_sonic(t, R):
    """ondas sonoras em arco (tingível)"""
    layers = []
    for k in range(3):
        tt = (t * 1.4 - k * 0.18)
        if tt <= 0 or tt > 1:
            continue
        L = Layer(alpha=1 - tt, jag=0.3, holes=0.2, flecks=4, glow=0.7, **WHITE)
        r = 25 + 80 * tt
        L.arc(-40, -30, r, r, -0.8, 0.8, 9)
        layers.append(L)
    return layers


def fx_sparkle(t, R):
    """brilhos de estrela (buff, visão) (tingível)"""
    L = Layer(alpha=1.0, jag=0.0, holes=0, glow=1.0, core=0.3, **WHITE)
    rr = np.random.default_rng(15)
    for k in range(7):
        ph = (t * 1.3 + rr.random()) % 1.0
        s = math.sin(math.pi * ph) * (10 + 12 * rr.random())
        x = (rr.random() - 0.5) * 140
        y = -60 + (rr.random() - 0.5) * 100
        L.spikes(x, y, 4, s * 0.25, s * 1.7, 0, 0.05, rr)
    return [L]


def fx_prison(t, R):
    """prisão de cristal: colunas de gelo/cristal se fechando (referência 1, respingo)"""
    L = Layer(alpha=fade(t, 0.8), jag=0.2, holes=0.2, flecks=12, glow=0.6, core=0.45, **ICE)
    up = ease(min(1, t * 2.0))
    for k in range(7):
        a = math.tau * k / 7
        x, y = rot(46, 0, a)
        h = (88 + 24 * (k % 2)) * up
        lean = -x * 0.25 * up
        L.poly([(x - 13, y * 0.4 + 40), (x + 13, y * 0.4 + 40), (x + lean + 7, y * 0.4 + 40 - h), (x + lean, y * 0.4 + 40 - h - 20), (x + lean - 7, y * 0.4 + 40 - h)])
    return [L]


def fx_beam(t, R):
    """coluna de luz descendo (bombardeio, pouso orbital) (tingível)"""
    w = 42 * math.sin(math.pi * min(1, t * 1.4))
    L = Layer(alpha=fade(t, 0.5), jag=0.3, holes=0.15, flecks=16, glow=1.2, core=0.5, **WHITE)
    L.poly([(-w, -128), (w, -128), (w * 0.7, 50), (-w * 0.7, 50)])
    L.ellipse(0, 50, w * 1.7 + 2, w * 0.5 + 1)
    return [L]


def fx_dash(t, R):
    """linhas de velocidade (passo extra, investida)"""
    L = Layer(alpha=fade(t, 0.3), jag=0.05, holes=0.0, glow=0.4, core=0.4, **WHITE)
    rr = np.random.default_rng(16)
    for k in range(6):
        y = -70 + 22 * k + (rr.random() - 0.5) * 6
        x0 = -110 + 160 * ease(t) * (0.6 + 0.4 * rr.random())
        L.taper([(x0, y), (x0 + 55 + 30 * rr.random(), y)], 1, 7)
    return [L]


EFFECTS = {k[3:]: v for k, v in sorted(globals().items()) if k.startswith("fx_") and callable(v)}


def build(out_dir, only=None):
    os.makedirs(out_dir, exist_ok=True)
    made = []
    for i, (name, fn) in enumerate(EFFECTS.items()):
        if only and name not in only:
            continue
        R = np.random.default_rng(100 + i)
        sheet = Image.new("RGBA", (OUT * FRAMES, OUT), (0, 0, 0, 0))
        for f in range(FRAMES):
            t = f / (FRAMES - 1)
            img = render(fn(t, R), 100 + i)
            sheet.paste(img, (f * OUT, 0))
        sheet.save(os.path.join(out_dir, name + ".png"), optimize=True)
        made.append(name)
    return made


def preview(out_dir, path, names, bg=(36, 30, 40)):
    cols = 6
    th = 110
    img = Image.new("RGBA", (th * cols + 110, th * len(names)), bg + (255,))
    d = ImageDraw.Draw(img)
    for r, n in enumerate(names):
        sh = Image.open(os.path.join(out_dir, n + ".png"))
        d.text((6, r * th + th // 2 - 6), n, fill=(255, 230, 160, 255))
        for c in range(cols):
            f = int(c * (FRAMES - 1) / (cols - 1))
            fr = sh.crop((f * OUT, 0, (f + 1) * OUT, OUT)).resize((th, th), Image.LANCZOS)
            img.alpha_composite(fr, (110 + c * th, r * th))
    img.save(path)


if __name__ == "__main__":
    args = list(sys.argv[1:])
    out, prev, only = "vfx", None, None
    i = 0
    while i < len(args):
        if args[i] == "--preview":
            prev = args[i + 1]
            i += 2
        elif args[i] == "--only":
            only = set(args[i + 1].split(","))
            i += 2
        else:
            out = args[i]
            i += 1
    names = build(out, only)
    print("gerados:", ", ".join(names))
    if prev:
        preview(out, prev, names)
        print("prévia:", prev)
