"""Impacto-assinatura de cada facção (Manual de VFX e Sombras v0.1), em flipbook HQ:
tinta de contorno, cores chapadas (base/sombra/acento), retícula e fragmentos do material.
python3 tools/vfx_faccoes.py [--preview arq.png]  ->  vfx/imp_<fac>.png (12 quadros de 256)"""
import json, math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = os.path.join(os.path.dirname(__file__), "..")
PAL = json.load(open(os.path.join(ROOT, "data", "vfx_paletas.json")))
F = 12
R = 256
SS = 2
Z = 1.75            # tela de desenho maior que o quadro: o efeito cabe com folga
S = int(R * SS * Z)
C = (S // 2, int(S * 0.53))


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


class Frame:
    def __init__(self):
        self.im = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    def shape(self, draw_fn, col, ink=None, inkw=5, alpha=255):
        m = Image.new("L", (S, S), 0)
        draw_fn(ImageDraw.Draw(m))
        a = np.asarray(m) > 0
        if not a.any():
            return a
        if ink is not None:
            k = ndi.binary_dilation(a, iterations=inkw * SS)
            self._fill(k, ink + (alpha,))
        self._fill(a, col + (alpha,))
        return a

    def _fill(self, mask, col):
        arr = np.zeros((S, S, 4), np.uint8)
        arr[mask] = col
        self.im.alpha_composite(Image.fromarray(arr, "RGBA"))

    def dots(self, mask, col, step=9, rmax=3.0, region=None):
        lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        st = int(step * SS)
        for y in range(0, S, st):
            for x in range(0, S, st):
                xx = x + (st // 2 if (y // st) % 2 else 0)
                if xx >= S or not mask[y, min(xx, S - 1)]:
                    continue
                t = 1.0 if region is None else region(xx, y)
                if t <= 0.05:
                    continue
                r = rmax * SS * min(1.0, t)
                d.ellipse([xx - r, y - r, xx + r, y + r], fill=col + (255,))
        self.im.alpha_composite(lay)

    def out(self):
        return self.im.resize((R, R), Image.LANCZOS)


def star(cx, cy, n, r1, r2, rot=0.0, jit=None, seed=0):
    rnd = random.Random(seed)
    pts = []
    for i in range(n * 2):
        a = rot + i * math.pi / n
        r = r1 if i % 2 == 0 else r2
        if jit:
            r *= 1 + rnd.uniform(-jit, jit)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def blob(cx, cy, r, n=14, jit=0.3, seed=0):
    rnd = random.Random(seed)
    return [(cx + r * (1 + rnd.uniform(-jit, jit)) * math.cos(i * 2 * math.pi / n), cy + r * (1 + rnd.uniform(-jit, jit)) * math.sin(i * 2 * math.pi / n)) for i in range(n)]


def pop(t, a=0.42, b=0.85):
    """cresce rápido e encolhe na saída (o desenho nunca some de uma vez)"""
    g = ease(min(1.0, t * 1.7))
    if t <= a:
        return g
    k = min(1.0, (t - a) / (b - a))
    return g * (1 - k * k)


def ease(t):
    return 1 - (1 - t) ** 3


def fade(t, a=0.55):
    return 1.0 if t < a else max(0.0, 1 - (t - a) / (1 - a))


def frags(fr, t, n, col, ink, kind, seed, dist=200, size=16):
    rnd = random.Random(seed)
    for i in range(n):
        a = rnd.uniform(0, 2 * math.pi)
        dd = (40 + dist * ease(t) * rnd.uniform(0.6, 1.1)) * SS
        x, y = C[0] + dd * math.cos(a), C[1] + dd * math.sin(a) - 40 * SS * t + 60 * SS * t * t
        s = size * SS * (1 - t * 0.7) * rnd.uniform(0.6, 1.2)
        if s < 2:
            continue
        rot = rnd.uniform(0, 6.28) + t * 4
        if kind == "quad":
            pts = [(x + s * math.cos(rot + k * math.pi / 2), y + s * math.sin(rot + k * math.pi / 2)) for k in range(4)]
        elif kind == "tri":
            pts = [(x + s * math.cos(rot + k * 2.09), y + s * math.sin(rot + k * 2.09)) for k in range(3)]
        elif kind == "pix":
            pts = [(x - s * 0.6, y - s * 0.6), (x + s * 0.6, y - s * 0.6), (x + s * 0.6, y + s * 0.6), (x - s * 0.6, y + s * 0.6)]
        else:
            pts = blob(x, y, s * 0.7, 7, 0.4, seed + i)
        fr.shape(lambda d, p=pts: d.polygon(p, fill=255), col, ink, 2)


def KRI(t, P):
    fr = Frame()
    b, o, g, sh, gr = rgb(P["primary"]), rgb(P["secondary"]), rgb(P["extra"]), rgb(P["shadow"]), rgb(P["outline"])
    e = ease(min(1, t * 1.6))
    r = (40 + 150 * pop(t)) * SS
    if pop(t) > 0.03:
        fr.shape(lambda d: d.polygon(star(C[0], C[1], 8, r, r * 0.42, 0.2, 0.25, 3), fill=255), b, sh, 6)
        r2 = r * (0.62 if t < 0.35 else 0.62 * fade(t, 0.3))
        if r2 > 4:
            m = fr.shape(lambda d: d.polygon(star(C[0], C[1], 6, r2, r2 * 0.5, 0.5, 0.2, 5), fill=255), o, sh, 3)
            fr.shape(lambda d: d.polygon(star(C[0], C[1], 6, r2 * 0.45, r2 * 0.25, 0.5), fill=255), rgb(P["highlight"]))
    # hachuras grafite (diagonais duras)
    if t > 0.25:
        d0 = Image.new("L", (S, S), 0)
        dd = ImageDraw.Draw(d0)
        for i in range(-6, 7):
            x = C[0] + i * 24 * SS
            L = (60 + 120 * ease(t)) * SS
            dd.line([(x - L * 0.5, C[1] + L * 0.5), (x + L * 0.5, C[1] - L * 0.5)], fill=255, width=3 * SS)
        hm = np.asarray(d0) > 0
        yy, xx = np.mgrid[0:S, 0:S]
        ring = np.hypot(xx - C[0], yy - C[1])
        hm &= (ring > r * 0.7) & (ring < r * 1.15)
        a = np.zeros((S, S, 4), np.uint8)
        a[hm] = gr + (int(230 * fade(t, 0.5)),)
        fr.im.alpha_composite(Image.fromarray(a, "RGBA"))
    frags(fr, t, 9, g, sh, "quad", 11, 210, 15)
    return fr


def WAC(t, P):
    fr = Frame()
    gold, pat, sh, ol, bone = rgb(P["primary"]), rgb(P["secondary"]), rgb(P["shadow"]), rgb(P["outline"]), rgb(P["highlight"])
    e = ease(min(1, t * 1.5))
    r = (36 + 140 * pop(t)) * SS * min(1, pop(t) * 4)
    if pop(t) > 0.03:
        # sombra de entalhe: a mesma forma deslocada em verde-pedra
        fr.shape(lambda d: d.polygon([(x + 10 * SS, y + 10 * SS) for x, y in star(C[0], C[1], 5, r, r * 0.55, 0.0, 0.3, 7)], fill=255), ol)
        fr.shape(lambda d: d.polygon(star(C[0], C[1], 5, r, r * 0.55, 0.0, 0.3, 7), fill=255), gold, sh, 5)
        fr.shape(lambda d: d.polygon(star(C[0], C[1], 5, r * 0.4, r * 0.25, 0.3), fill=255), bone)
    # fibras de hachura que se abrem radialmente
    d0 = Image.new("L", (S, S), 0)
    dd = ImageDraw.Draw(d0)
    for i in range(16):
        a = i * math.pi / 8 + 0.1
        r0 = r * 0.9
        r1 = r0 + 70 * SS * ease(t)
        dd.line([(C[0] + r0 * math.cos(a), C[1] + r0 * math.sin(a)), (C[0] + r1 * math.cos(a), C[1] + r1 * math.sin(a))], fill=255, width=4 * SS)
    a = np.zeros((S, S, 4), np.uint8)
    a[np.asarray(d0) > 0] = gold + (int(255 * fade(t, 0.45)),)
    fr.im.alpha_composite(Image.fromarray(a, "RGBA"))
    frags(fr, t, 8, pat, sh, "tri", 21, 190, 16)
    return fr


def ZUK(t, P):
    fr = Frame()
    cy, bl, ind, ol, wh = rgb(P["primary"]), rgb(P["secondary"]), rgb(P["shadow"]), rgb(P["outline"]), rgb(P["highlight"])
    # 1) linha branca -> 2) contorno ciano -> 3) quebra em pixels azuis
    if t < 0.3:
        L = 200 * SS * ease(t / 0.3)
        fr.shape(lambda d: (d.line([(C[0] - L, C[1]), (C[0] + L, C[1])], fill=255, width=7 * SS), d.line([(C[0], C[1] - L * 0.6), (C[0], C[1] + L * 0.6)], fill=255, width=5 * SS)), wh, ind, 2)
    if 0.12 < t < 0.8:
        k = ease(min(1, (t - 0.12) / 0.4))
        r = (40 + 120 * k) * SS * (1 - max(0, (t - 0.55) / 0.25) * 0.6)
        hexp = [(C[0] + r * math.cos(i * math.pi / 3), C[1] + r * 0.85 * math.sin(i * math.pi / 3)) for i in range(6)]
        m = Image.new("L", (S, S), 0)
        ImageDraw.Draw(m).polygon(hexp, outline=255, width=int(10 * SS * (1 - k * 0.5)))
        mm = np.asarray(m) > 0
        fr._fill(ndi.binary_dilation(mm, iterations=3 * SS), ind + (255,))
        fr._fill(mm, cy + (255,))
        fr.shape(lambda d: d.polygon([(C[0] + 0.35 * (x - C[0]), C[1] + 0.35 * (y - C[1])) for x, y in hexp], fill=255), wh if t < 0.35 else cy, ind, 3)
    if t > 0.3:
        frags(fr, (t - 0.3) / 0.7, 16, bl, ol, "pix", 31, 170, 13)
    return fr


def ABY(t, P):
    fr = Frame()
    mg, pu, dk, ol, pk = rgb(P["primary"]), rgb(P["secondary"]), rgb(P["shadow"]), rgb(P["outline"]), rgb(P["highlight"])
    e = ease(min(1, t * 1.5))
    r = (40 + 140 * e) * SS
    if pop(t, 0.45, 0.9) > 0.03:
        sc = pop(t, 0.45, 0.9) / max(0.01, e)
        out = blob(C[0], C[1], r * sc, 16, 0.35, 41)
        m = fr.shape(lambda d: d.polygon(out, fill=255), pu, ol, 7)
        inner = blob(C[0] + 6 * SS, C[1] - 6 * SS, r * 0.62 * sc, 12, 0.3, 42)
        m2 = fr.shape(lambda d: d.polygon(inner, fill=255), pk)
        # retícula deslocada (impressão fora de registro)
        sh = np.roll(np.roll(m, 9 * SS, 0), 7 * SS, 1) & m
        fr.dots(sh & ~m2, mg, 10, 3.6)
        fr.shape(lambda d: d.polygon(blob(C[0] + 8 * SS, C[1] - 10 * SS, r * 0.22 * sc, 9, 0.3, 43), fill=255), (255, 235, 250))
    # respingos densos e grânulos magenta
    rnd = random.Random(44)
    for i in range(18):
        a = rnd.uniform(0, 6.28)
        dd = r * (1.05 + 0.6 * ease(t) * rnd.uniform(0.4, 1.0))
        s = rnd.uniform(5, 13) * SS * (1 - t * 0.6)
        x, y = C[0] + dd * math.cos(a), C[1] + dd * math.sin(a)
        fr.shape(lambda d, x=x, y=y, s=s: d.ellipse([x - s, y - s, x + s, y + s], fill=255), mg if i % 3 else pu, ol, 2)
    return fr


def TER(t, P):
    fr = Frame()
    am, tq, br, ol, sand = rgb(P["primary"]), rgb(P["secondary"]), rgb(P["shadow"]), rgb(P["outline"]), rgb(P["extra"])
    e = ease(t)
    # anel de poeira com recortes
    r = (50 + 150 * e) * SS
    w = (40 * (1 - e) + 10) * SS
    yy, xx = np.mgrid[0:S, 0:S]
    ang = np.arctan2(yy - C[1], xx - C[0])
    dist = np.hypot(xx - C[0], (yy - C[1]) * 1.6)
    cuts = np.sin(ang * 7 + 1.3) > -0.55
    ring = (dist > r - w) & (dist < r + w * 0.4) & cuts
    if fade(t, 0.5) > 0.05:
        fr._fill(ndi.binary_dilation(ring, iterations=4 * SS), ol + (int(255 * fade(t, 0.5)),))
        fr._fill(ring, sand + (int(255 * fade(t, 0.5)),))
        fr.dots(ring, br, 8, 2.4)
    if pop(t, 0.3, 0.6) > 0.03:
        rr = (30 + 70 * pop(t, 0.3, 0.6)) * SS
        fr.shape(lambda d: d.polygon(star(C[0], C[1], 7, rr, rr * 0.5, 0.3, 0.3, 51), fill=255), am, br, 5)
        fr.shape(lambda d: d.ellipse([C[0] - rr * 0.3, C[1] - rr * 0.3, C[0] + rr * 0.3, C[1] + rr * 0.3], fill=255), (255, 240, 200))
        # espiral curta (marca de broca)
        pts = [(C[0] + (8 + k * 2.2) * SS * math.cos(k * 0.45 + t * 9), C[1] + (8 + k * 2.2) * SS * math.sin(k * 0.45 + t * 9)) for k in range(30)]
        fr.shape(lambda d: d.line(pts, fill=255, width=4 * SS), tq)
    frags(fr, t, 10, (90, 90, 100), ol, "tri", 52, 200, 14)
    return fr


def LIT(t, P):
    fr = Frame()
    tq, vi, mn, ol, wh = rgb(P["primary"]), rgb(P["secondary"]), rgb(P["shadow"]), rgb(P["outline"]), rgb(P["highlight"])
    e = ease(min(1, t * 1.4))
    rnd = random.Random(61)
    if pop(t) > 0.03:
        # facetas cristalinas (3-4) que explodem
        for k in range(4):
            a = k * math.pi / 2 + 0.4
            L = (60 + 110 * pop(t)) * SS
            cx, cy = C[0] + math.cos(a) * L * 0.35, C[1] + math.sin(a) * L * 0.35
            pts = [(C[0], C[1]), (cx + math.cos(a + 0.5) * L * 0.4, cy + math.sin(a + 0.5) * L * 0.4), (C[0] + math.cos(a) * L, C[1] + math.sin(a) * L), (cx + math.cos(a - 0.5) * L * 0.3, cy + math.sin(a - 0.5) * L * 0.3)]
            fr.shape(lambda d, p=pts: d.polygon(p, fill=255), tq if k % 2 else vi, ol, 4)
            half = [pts[0], pts[1], pts[2]]
            fr.shape(lambda d, p=half: d.polygon(p, fill=255), mn)
    # rachaduras finas brancas que se propagam
    d0 = Image.new("L", (S, S), 0)
    dd = ImageDraw.Draw(d0)
    for k in range(9):
        a = rnd.uniform(0, 6.28)
        x, y = C
        Lk = 200 * SS * ease(min(1, t * 1.8))
        segs = 5
        for j in range(segs):
            a += rnd.uniform(-0.5, 0.5)
            nx, ny = x + math.cos(a) * Lk / segs, y + math.sin(a) * Lk / segs
            dd.line([(x, y), (nx, ny)], fill=255, width=3 * SS)
            x, y = nx, ny
    a = np.zeros((S, S, 4), np.uint8)
    a[np.asarray(d0) > 0] = wh + (int(255 * fade(t, 0.5)),)
    fr.im.alpha_composite(Image.fromarray(a, "RGBA"))
    frags(fr, t, 12, tq, ol, "tri", 62, 200, 13)
    return fr


def FAU(t, P):
    fr = Frame()
    org, lime, pet, ol, yel = rgb(P["primary"]), rgb(P["secondary"]), rgb(P["shadow"]), rgb(P["outline"]), rgb(P["highlight"])
    # animação em degraus (timing cartunesco)
    ts = math.floor(t * 6) / 6
    e = ease(min(1, ts * 1.4))
    r = (40 + 160 * pop(ts, 0.45, 0.95)) * SS
    if pop(ts, 0.45, 0.95) > 0.03:
        m = fr.shape(lambda d: d.polygon(star(C[0], C[1], 10, r, r * 0.62, 0.0, 0.18, 71), fill=255), yel, pet, 8)
        fr.dots(m, org, 11, 4.2)
        # listras lima
        d0 = Image.new("L", (S, S), 0)
        dd = ImageDraw.Draw(d0)
        for k in range(10):
            a = k * math.pi / 5 + 0.3
            dd.polygon([(C[0] + r * 0.4 * math.cos(a - 0.08), C[1] + r * 0.4 * math.sin(a - 0.08)), (C[0] + r * 0.95 * math.cos(a), C[1] + r * 0.95 * math.sin(a)), (C[0] + r * 0.4 * math.cos(a + 0.08), C[1] + r * 0.4 * math.sin(a + 0.08))], fill=255)
        lm = (np.asarray(d0) > 0) & m
        fr._fill(lm, lime + (255,))
        rr = r * 0.42
        fr.shape(lambda d: d.polygon(star(C[0], C[1], 8, rr, rr * 0.6, 0.2, 0.15, 72), fill=255), org, pet, 4)
    # linhas de velocidade
    d0 = Image.new("L", (S, S), 0)
    dd = ImageDraw.Draw(d0)
    for k in range(12):
        a = k * math.pi / 6
        r0 = r * 1.05
        r1 = r0 + 60 * SS * e
        dd.line([(C[0] + r0 * math.cos(a), C[1] + r0 * math.sin(a)), (C[0] + r1 * math.cos(a), C[1] + r1 * math.sin(a))], fill=255, width=5 * SS)
    a = np.zeros((S, S, 4), np.uint8)
    a[np.asarray(d0) > 0] = pet + (int(255 * fade(t, 0.5)),)
    fr.im.alpha_composite(Image.fromarray(a, "RGBA"))
    frags(fr, ts, 8, rgb(P["extra"]), ol, "blob", 73, 190, 12)
    return fr


FX = {"KRI": KRI, "WAC": WAC, "ZUK": ZUK, "ABY": ABY, "TER": TER, "LIT": LIT, "FAU": FAU}

if __name__ == "__main__":
    rows = []
    for fac, fn in FX.items():
        strip = Image.new("RGBA", (R * F, R), (0, 0, 0, 0))
        for i in range(F):
            strip.alpha_composite(fn(i / (F - 1), PAL[fac]).out(), (i * R, 0))
        strip.save(os.path.join(ROOT, "vfx", "imp_%s.png" % fac.lower()), optimize=True)
        rows.append(strip)
        print(fac)
    if "--preview" in sys.argv:
        out = sys.argv[sys.argv.index("--preview") + 1]
        pv = Image.new("RGBA", (R * 6 // 2, R // 2 * len(rows) * 2), (0, 0, 0, 255))
        sel = [1, 3, 5, 7, 9, 11]
        for ri, st in enumerate(rows):
            for k, fi in enumerate(sel):
                q = st.crop((fi * R, 0, fi * R + R, R)).resize((R // 2, R // 2))
                for bi, bg in enumerate([(225, 190, 130, 255), (40, 30, 70, 255)]):
                    cell = Image.new("RGBA", q.size, bg)
                    cell.alpha_composite(q)
                    pv.paste(cell, (k * R // 2, (ri * 2 + bi) * R // 2))
        pv.save(out)
