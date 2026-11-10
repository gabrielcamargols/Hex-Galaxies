"""FORJA — texturas de partícula dos VALAKIANOS (mineradores refugiados de Valak).
Linguagem das referências do diretor: formas pontudas e serrilhadas, estrela de impacto de 4 pontas,
recortes negativos (buracos) e cores CHAPADAS em faixas (contorno -> corpo -> miolo), como tinta de HQ.
A intensidade (canal R) escolhe a cor na rampa do shader: baixa = contorno, média = corpo, alta = miolo.
python3 tools/forja_tex_ter.py [folha.png]  ->  vfx/tex/*.png"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

sys.path.insert(0, os.path.dirname(__file__))
from forja_tex import OUT, fbm

SS = 4          # supersample do desenho
LO, MID, HI = 0.22, 0.58, 0.96


def tela(n=256, w=None):
    W = (w or n) * SS
    H = n * SS
    im = Image.new("L", (W, H), 0)
    return im, ImageDraw.Draw(im), W, H


def arr(im):
    return np.asarray(im).astype(np.float32) / 255


def baixa(v, n=256, w=None):
    im = Image.fromarray((np.clip(v, 0, 1) * 255).astype(np.uint8))
    return np.asarray(im.resize(((w or n), n), Image.LANCZOS)).astype(np.float32) / 255


def faixas(m, borda=0.022, corpo=0.075, lo=LO, mid=MID, hi=HI):
    """máscara -> 3 faixas chapadas pela distância até a borda (frações do lado menor)"""
    m = m > 0.5
    S = min(m.shape)
    d = ndi.distance_transform_edt(m) / S
    v = np.where(d < borda, lo, np.where(d < borda + corpo, mid, hi))
    v = v + 0.035 * np.clip(d / 0.2, 0, 1)        # leve subida para a erosão comer de fora para dentro
    return np.clip(v, 0, 1) * m


def acabamento(v, seed):
    """pincelada de HQ: borda irregular (não lisa), hachura diagonal no corpo e brilho riscado no miolo.
    Deixa a forma com detalhe pintado à mão, em vez de chapada e simples."""
    H, W = v.shape
    m = v > 0.05
    def ruido(sd, esc, oit):
        return fbm(sd, n=max(H, W), esc=esc, oit=oit)[:H, :W]
    ruido_b = ruido(seed, 22, 2)                      # borda que treme
    ruido_c = ruido(seed + 7, 9, 3)                   # manchas de tinta
    v = np.where(m & (ruido_b < 0.14), 0.0, v)        # bordas comidas em pequenos lascados
    yy, xx = np.mgrid[0:H, 0:W]
    hachura = ((xx + yy + (ruido_c * 12).astype(int)) // max(3, max(H, W) // 40)) % 2 == 0
    corpo = (v > LO + 0.05) & (v < MID + 0.05) & (ruido_c > 0.45)
    v = np.where(corpo & hachura, v * 0.78, v)        # hachura escura de tinta
    brilho = (v > HI - 0.04) & (ruido_c > 0.6)
    v = np.where(brilho & hachura, 0.99, v)           # riscos de luz no miolo
    return np.clip(v, 0, 1)


def salva(nome, v):
    v = acabamento(v, sum(map(ord, nome)))
    a = (np.clip(v, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(np.dstack([a, a, a, a]), "RGBA").save(os.path.join(OUT, nome + ".png"))
    return a


def pol(cx, cy, pts, W, H):
    return [((cx + x) * W, (cy + y) * H) for x, y in pts]


# ---------------------------------------------------------------- linguagem de impacto
def _estouro(seed, n=10, rin=(0.36, 0.46), rout=(0.6, 0.98)):
    """estouro serrilhado: pontas longas e curtas alternadas, algumas com sub-ponta (dente) ao lado"""
    im, d, W, H = tela()
    rr = random.Random(seed)
    pts = []
    off = rr.uniform(0, math.tau)
    for i in range(n):
        a0 = off + math.tau * i / n
        longa = (i % 2 == 0) or rr.random() < 0.25
        R = rr.uniform(rout[0] + 0.22, rout[1]) if longa else rr.uniform(rout[0], rout[0] + 0.2)
        da = math.tau / n
        ja = rr.uniform(-0.18, 0.18) * da
        r0 = rr.uniform(*rin)
        pts.append((a0 - da * 0.5, r0))
        if longa and rr.random() < 0.6:
            # sub-ponta: dente menor colado na base da ponta
            pts.append((a0 - da * 0.26, R * rr.uniform(0.5, 0.62)))
            pts.append((a0 - da * 0.2, r0 * 1.25))
        pts.append((a0 + ja, R))
    xy = [(0.5 * W + math.cos(a) * r * 0.5 * W, 0.5 * H + math.sin(a) * r * 0.5 * H) for a, r in pts]
    d.polygon(xy, fill=255)
    return baixa(faixas(arr(im), 0.013, 0.06))


def estouro():
    return _estouro(7)


def estouro_b():
    return _estouro(31, n=9, rin=(0.32, 0.42), rout=(0.56, 0.98))


def estrela4():
    """estrela de impacto de 4 pontas (vertical mais longa), lados côncavos e fio nítido"""
    im, d, W, H = tela()
    c = 0.5
    k = 0.085          # cintura
    pts = [(0, -0.49), (k, -k), (0.34, 0), (k, k), (0, 0.49), (-k, k), (-0.34, 0), (-k, -k)]
    d.polygon(pol(c, c, pts, W, H), fill=255)
    return baixa(faixas(arr(im), 0.014, 0.022, 0.25, 0.6, 1.0))


def lasca():
    """lasca de chama/pedra (ponta em cima): farpas nos lados e recorte negativo na base.
    A intensidade cai da ponta (miolo) para a cauda (contorno): a rampa pinta o degradê ao longo dela."""
    n = 128
    im, d, W, H = tela(n)
    pts = [(0.50, 0.02), (0.58, 0.30), (0.70, 0.22), (0.63, 0.50), (0.78, 0.44), (0.68, 0.72), (0.80, 0.70),
           (0.70, 0.97), (0.60, 0.84), (0.52, 0.95), (0.45, 0.80), (0.36, 0.93), (0.32, 0.70), (0.22, 0.74),
           (0.34, 0.48), (0.26, 0.46), (0.42, 0.26)]
    d.polygon([(x * W, y * H) for x, y in pts], fill=255)
    # recortes negativos (mordidas) na base
    d.ellipse([0.40 * W, 0.86 * H, 0.50 * W, 1.02 * H], fill=0)
    d.ellipse([0.55 * W, 0.88 * H, 0.63 * W, 1.02 * H], fill=0)
    m = arr(im) > 0.5
    y = np.mgrid[0:H, 0:W][0] / H
    dist = ndi.distance_transform_edt(m) / W
    v = np.clip(1.02 - y * 0.78, 0.2, 1.0)
    v = np.where(dist < 0.018, np.minimum(v, 0.3), v)
    return baixa(v * m, n)


def arco_golpe():
    """arco de golpe (bojo para a direita): crescente grosso com pontas rasgadas e buracos negativos"""
    im, d, W, H = tela()
    d.ellipse([0.10 * W, 0.05 * H, 0.98 * W, 0.95 * H], fill=255)
    d.ellipse([-0.20 * W, 0.0 * H, 0.70 * W, 1.0 * H], fill=0)
    # pontas rasgadas: triângulos negativos cortando as extremidades
    for sy in (-1, 1):
        cy = 0.5 + sy * 0.36
        d.polygon([(0.40 * W, (cy + sy * 0.02) * H), (0.62 * W, (cy - sy * 0.035) * H), (0.40 * W, (cy - sy * 0.06) * H)], fill=0)
        d.polygon([(0.52 * W, (cy + sy * 0.09) * H), (0.70 * W, (cy + sy * 0.045) * H), (0.50 * W, (cy + sy * 0.05) * H)], fill=0)
    # buracos negativos (gotas) no corpo
    for (x, y, rx, ry) in [(0.80, 0.42, 0.04, 0.075), (0.78, 0.64, 0.03, 0.055), (0.86, 0.55, 0.016, 0.025), (0.71, 0.26, 0.022, 0.036), (0.69, 0.77, 0.02, 0.032)]:
        d.ellipse([(x - rx) * W, (y - ry) * H, (x + rx) * W, (y + ry) * H], fill=0)
    m = arr(im) > 0.5
    # fio de ataque (borda de fora) mais claro
    yy, xx = np.mgrid[0:H, 0:W]
    r = np.hypot(xx / W - 0.54, (yy / H - 0.5) * (0.88 / 0.9)) / 0.44
    dist = ndi.distance_transform_edt(m) / W
    v = np.where(r > 0.9, HI, MID)
    v = np.where(dist < 0.014, LO, v)
    out = baixa(v * m)
    return np.roll(out, -int(256 * 0.18), axis=1)


def raio_oco():
    """faísca oca: contorno de raio em zigue-zague (só a linha), para piscar em volta do estouro"""
    n = 128
    im, d, W, H = tela(n)
    pts = [(0.50, 0.04), (0.66, 0.34), (0.54, 0.38), (0.74, 0.66), (0.58, 0.64), (0.62, 0.96),
           (0.36, 0.58), (0.50, 0.58), (0.30, 0.30), (0.46, 0.32)]
    xy = [(x * W, y * H) for x, y in pts]
    d.polygon(xy, fill=255)
    m = arr(im) > 0.5
    dist = ndi.distance_transform_edt(m) / W
    v = np.where((dist > 0) & (dist < 0.035), 1.0, 0.0)
    return baixa(v, n)


def poeira():
    """nuvem de poeira de HQ: bolotas com borda recortada, sombra em baixo e pontinhos soltos"""
    n = 128
    im, d, W, H = tela(n)
    rr = random.Random(4)
    for (x, y, r) in [(0.36, 0.56, 0.22), (0.56, 0.44, 0.26), (0.70, 0.60, 0.19), (0.48, 0.66, 0.2), (0.26, 0.68, 0.12), (0.80, 0.72, 0.1)]:
        d.ellipse([(x - r) * W, (y - r) * H, (x + r) * W, (y + r) * H], fill=255)
    m = arr(im) > 0.5
    yy, xx = np.mgrid[0:H, 0:W]
    dist = ndi.distance_transform_edt(m) / W
    luz = np.clip(1.0 - (yy / H - 0.3) * 1.6, 0, 1)
    v = np.where(luz > 0.62, 0.9, np.where(luz > 0.38, 0.62, 0.4))
    v = np.where(dist < 0.02, 0.2, v) * m
    for _ in range(7):
        a = rr.uniform(0, math.tau)
        dd = rr.uniform(0.34, 0.46)
        x, y, r = 0.5 + math.cos(a) * dd, 0.56 + math.sin(a) * dd * 0.8, rr.uniform(0.012, 0.028)
        dot = np.hypot(xx / W - x, yy / H - y) < r
        v = np.where(dot, 0.62, v)
    return baixa(v, n)


def anel_serra():
    """anel de choque serrilhado (chão): dentes para fora, vazio no meio"""
    im, d, W, H = tela()
    rr = random.Random(9)
    n = 22
    xy = []
    for i in range(n * 2):
        a = math.tau * i / (n * 2)
        R = (0.97 if i % 2 == 0 else rr.uniform(0.78, 0.86)) * 0.5
        xy.append((0.5 * W + math.cos(a) * R * W, 0.5 * H + math.sin(a) * R * H))
    d.polygon(xy, fill=255)
    d.ellipse([0.17 * W, 0.17 * H, 0.83 * W, 0.83 * H], fill=0)
    m = arr(im) > 0.5
    yy, xx = np.mgrid[0:H, 0:W]
    r = np.hypot(xx / W - 0.5, yy / H - 0.5) / 0.5
    v = np.where(r < 0.74, HI, MID)                 # fio de dentro claro, dentes no tom do corpo
    dist = ndi.distance_transform_edt(m) / W
    v = np.where(dist < 0.008, LO, v)
    return baixa(v * m)


# ---------------------------------------------------------------- objetos da facção
def pedra():
    """pedregulho facetado: topo claro, lado médio, base escura"""
    n = 128
    im, d, W, H = tela(n)
    base = [(0.22, 0.34), (0.50, 0.12), (0.80, 0.28), (0.90, 0.60), (0.70, 0.88), (0.34, 0.90), (0.12, 0.64)]
    d.polygon([(x * W, y * H) for x, y in base], fill=255)
    m = arr(im) > 0.5
    f = Image.new("L", (W, H), int(MID * 255))
    fd = ImageDraw.Draw(f)
    fd.polygon([(x * W, y * H) for x, y in [(0.22, 0.34), (0.50, 0.12), (0.80, 0.28), (0.56, 0.46)]], fill=int(HI * 255))
    fd.polygon([(x * W, y * H) for x, y in [(0.56, 0.46), (0.80, 0.28), (0.90, 0.60), (0.70, 0.88), (0.52, 0.70)]], fill=int(0.4 * 255))
    v = arr(f)
    dist = ndi.distance_transform_edt(m) / W
    v = np.where(dist < 0.03, LO, v)
    return baixa(v * m, n)


def _cristal_pts(cx, by, w, h, lean=0.0):
    """prisma de cristal: (contorno, faceta clara, faceta escura, brilho)"""
    top = (cx + lean, by - h)
    L, R = cx - w / 2, cx + w / 2
    sh = by - h * 0.72
    out = [(L + lean * 0.3, sh), top, (R + lean * 0.7, sh), (R, by), (L, by)]
    clara = [(L + lean * 0.3, sh), top, (cx + lean * 0.5, sh + h * 0.06), (cx, by), (L, by)]
    escura = [top, (R + lean * 0.7, sh), (R, by), (cx, by), (cx + lean * 0.5, sh + h * 0.06)]
    return out, clara, escura


def cristal_ter():
    """cacho de cristais de Valak (3 prismas): facetas chapadas, contorno e brilho"""
    im, d, W, H = tela()
    f = Image.new("L", (W, H), 0)
    fd = ImageDraw.Draw(f)
    for (cx, by, w, h, lean) in [(0.30, 0.95, 0.20, 0.52, -0.07), (0.70, 0.95, 0.19, 0.46, 0.08), (0.50, 0.97, 0.28, 0.92, 0.0)]:
        out, clara, escura = _cristal_pts(cx, by, w, h, lean)
        d.polygon([(x * W, y * H) for x, y in out], fill=255)
        fd.polygon([(x * W, y * H) for x, y in clara], fill=int(0.84 * 255))
        fd.polygon([(x * W, y * H) for x, y in escura], fill=int(0.5 * 255))
        # risco de brilho na faceta clara
        fd.line([((cx - w * 0.28) * W, (by - h * 0.62) * H), ((cx - w * 0.28) * W, (by - h * 0.2) * H)], fill=255, width=int(W * 0.012))
    m = arr(im) > 0.5
    v = arr(f)
    dist = ndi.distance_transform_edt(m) / W
    v = np.where(dist < 0.014, LO, v)
    return baixa(v * m)


def cristal_lanca():
    """lança de cristal de lado (ponta à direita), 256x64: prisma longo com faceta clara em cima"""
    n, w = 64, 256
    im, d, W, H = tela(n, w)
    out = [(0.04, 0.5), (0.16, 0.2), (0.74, 0.14), (0.98, 0.5), (0.74, 0.86), (0.16, 0.8)]
    d.polygon([(x * W, y * H) for x, y in out], fill=255)
    f = Image.new("L", (W, H), int(0.5 * 255))
    fd = ImageDraw.Draw(f)
    fd.polygon([(x * W, y * H) for x, y in [(0.04, 0.5), (0.16, 0.2), (0.74, 0.14), (0.98, 0.5)]], fill=int(0.86 * 255))
    fd.line([(0.2 * W, 0.36 * H), (0.7 * W, 0.32 * H)], fill=255, width=int(H * 0.07))
    m = arr(im) > 0.5
    v = arr(f)
    dist = ndi.distance_transform_edt(m) / H
    v = np.where(dist < 0.07, LO, v)
    return baixa(v * m, n, w)


def picareta():
    """picareta na diagonal: cabo de baixo-esquerda até cima-direita, cabeça curva de duas pontas"""
    im, d, W, H = tela()
    f = Image.new("L", (W, H), 0)
    fd = ImageDraw.Draw(f)
    for dr, fill in ((d, 255), (fd, int(0.5 * 255))):
        dr.line([(0.20 * W, 0.92 * H), (0.57 * W, 0.30 * H)], fill=fill, width=int(W * 0.07))
    # cabeça: arco grosso atravessado no topo do cabo
    cab = []
    for i in range(21):
        t = i / 20
        a = math.radians(196 + t * 104)
        cab.append((0.62 + math.cos(a) * 0.5, 0.76 + math.sin(a) * 0.5))
    for i in range(20, -1, -1):
        t = i / 20
        a = math.radians(196 + t * 104)
        esp = 0.105 * math.sin(t * math.pi) ** 0.6 + 0.004
        cab.append((0.62 + math.cos(a) * (0.5 - esp), 0.76 + math.sin(a) * (0.5 - esp)))
    for dr, fill in ((d, 255), (fd, int(0.9 * 255))):
        dr.polygon([(x * W, y * H) for x, y in cab], fill=fill)
    m = arr(im) > 0.5
    v = arr(f)
    dist = ndi.distance_transform_edt(m) / W
    v = np.where(dist < 0.013, LO, v)
    return baixa(v * m)


def broca():
    """broca de mineração de lado (ponta à direita): cone com sulcos em espiral e colar na base"""
    im, d, W, H = tela()
    cone = [(0.20, 0.20), (0.97, 0.50), (0.20, 0.80)]
    d.polygon([(x * W, y * H) for x, y in cone], fill=255)
    d.rectangle([0.06 * W, 0.26 * H, 0.22 * W, 0.74 * H], fill=255)
    m = arr(im) > 0.5
    yy, xx = np.mgrid[0:H, 0:W]
    u = xx / W
    vv = yy / H
    faixa = np.floor((u * 7.0 + (vv - 0.5) * 3.2)) % 2
    v = np.where(faixa > 0, 0.9, 0.55)
    v = np.where(u < 0.22, 0.42, v)
    v = np.where((u > 0.1) & (u < 0.13), 0.9, v)
    dist = ndi.distance_transform_edt(m) / W
    v = np.where(dist < 0.014, LO, v)
    return baixa(v * m)


def dinamite():
    """feixe de 3 bananas de dinamite na diagonal, cinta no meio e pavio com faísca"""
    im, d, W, H = tela()
    f = Image.new("L", (W, H), 0)
    fd = ImageDraw.Draw(f)
    ang = math.radians(-32)
    ca, sa = math.cos(ang), math.sin(ang)

    def rot(x, y):
        return ((0.46 + x * ca - y * sa) * W, (0.58 + x * sa + y * ca) * H)

    for k, oy in enumerate((-0.13, 0.0, 0.13)):
        box = [rot(-0.33, oy - 0.058), rot(0.33, oy - 0.058), rot(0.33, oy + 0.058), rot(-0.33, oy + 0.058)]
        d.polygon(box, fill=255)
        fd.polygon(box, fill=int((0.62 if k != 1 else 0.7) * 255))
        tampa = [rot(0.27, oy - 0.058), rot(0.33, oy - 0.058), rot(0.33, oy + 0.058), rot(0.27, oy + 0.058)]
        fd.polygon(tampa, fill=int(0.86 * 255))
        fd.line([rot(-0.3, oy - 0.03), rot(0.24, oy - 0.03)], fill=int(0.8 * 255), width=int(W * 0.012))
    cinta = [rot(-0.07, -0.2), rot(0.07, -0.2), rot(0.07, 0.2), rot(-0.07, 0.2)]
    d.polygon(cinta, fill=255)
    fd.polygon(cinta, fill=int(0.4 * 255))
    # pavio
    pav = [rot(0.33, 0.0), rot(0.42, -0.04), rot(0.47, -0.12), rot(0.52, -0.14)]
    for dr, fill in ((d, 255), (fd, int(0.45 * 255))):
        dr.line(pav, fill=fill, width=int(W * 0.022))
    # faísca do pavio: estrelinha
    sx, sy = rot(0.54, -0.15)
    for dr in (d, fd):
        for a in range(0, 360, 45):
            R = (0.085 if a % 90 == 0 else 0.05) * W
            dr.line([(sx, sy), (sx + math.cos(math.radians(a)) * R, sy + math.sin(math.radians(a)) * R)], fill=255, width=int(W * 0.014))
        dr.ellipse([sx - 0.03 * W, sy - 0.03 * H, sx + 0.03 * W, sy + 0.03 * H], fill=255)
    m = arr(im) > 0.5
    v = arr(f)
    dist = ndi.distance_transform_edt(m) / W
    v = np.where((dist < 0.011) & (v < 0.95), LO, v)
    return baixa(v * m)


def lanterna():
    """lanterna de mineiro: alça, tampa, vidro aceso (miolo) com grade e base"""
    im, d, W, H = tela()
    f = Image.new("L", (W, H), 0)
    fd = ImageDraw.Draw(f)
    # alça
    for dr, fill in ((d, 255), (fd, int(0.5 * 255))):
        dr.arc([0.34 * W, 0.03 * H, 0.66 * W, 0.34 * H], 180, 360, fill=fill, width=int(W * 0.028))
    partes = [
        ([(0.30, 0.24), (0.70, 0.24), (0.64, 0.34), (0.36, 0.34)], 0.5),      # tampa
        ([(0.33, 0.34), (0.67, 0.34), (0.72, 0.78), (0.28, 0.78)], 1.0),      # vidro aceso
        ([(0.24, 0.78), (0.76, 0.78), (0.70, 0.93), (0.30, 0.93)], 0.5),      # base
    ]
    for pts, lv in partes:
        xy = [(x * W, y * H) for x, y in pts]
        d.polygon(xy, fill=255)
        fd.polygon(xy, fill=int(lv * 255))
    for x0, x1 in ((0.42, 0.40), (0.58, 0.60)):
        fd.line([(x0 * W, 0.34 * H), (x1 * W, 0.78 * H)], fill=int(0.45 * 255), width=int(W * 0.016))
    fd.line([(0.305 * W, 0.56 * H), (0.695 * W, 0.56 * H)], fill=int(0.45 * 255), width=int(W * 0.016))
    m = arr(im) > 0.5
    v = arr(f)
    dist = ndi.distance_transform_edt(m) / W
    v = np.where(dist < 0.014, LO, v)
    return baixa(v * m)


def coluna():
    """colunas de basalto (prismas hexagonais) de alturas diferentes, pé na base do quadro"""
    im, d, W, H = tela()
    f = Image.new("L", (W, H), 0)
    fd = ImageDraw.Draw(f)
    for (cx, w, top) in [(0.24, 0.26, 0.42), (0.76, 0.25, 0.30), (0.50, 0.32, 0.07)]:
        L, R = cx - w / 2, cx + w / 2
        hh = w * 0.2
        corpo = [(L, top + hh), (cx, top + hh * 2), (R, top + hh), (R, 0.99), (L, 0.99)]
        topo = [(L, top + hh), (cx - w * 0.22, top), (cx + w * 0.22, top), (R, top + hh), (cx + w * 0.22, top + hh * 2), (cx - w * 0.22, top + hh * 2)]
        for pts in (corpo, topo):
            d.polygon([(x * W, y * H) for x, y in pts], fill=255)
        fd.polygon([(x * W, y * H) for x, y in [(L, top + hh), (cx - w * 0.22, top + hh * 2), (cx - w * 0.22, 0.99), (L, 0.99)]], fill=int(0.62 * 255))
        fd.polygon([(x * W, y * H) for x, y in [(cx - w * 0.22, top + hh * 2), (cx + w * 0.22, top + hh * 2), (cx + w * 0.22, 0.99), (cx - w * 0.22, 0.99)]], fill=int(0.5 * 255))
        fd.polygon([(x * W, y * H) for x, y in [(cx + w * 0.22, top + hh * 2), (R, top + hh), (R, 0.99), (cx + w * 0.22, 0.99)]], fill=int(0.38 * 255))
        fd.polygon([(x * W, y * H) for x, y in topo], fill=int(0.92 * 255))
        # veio de energia (miolo): risco quebrado na face da frente
        fd.line([(cx * W, (top + hh * 2.6) * H), ((cx - w * 0.1) * W, (top + hh * 4.2) * H), ((cx + w * 0.06) * W, (top + hh * 5.6) * H)], fill=255, width=int(W * 0.012))
    m = arr(im) > 0.5
    v = arr(f)
    dist = ndi.distance_transform_edt(m) / W
    v = np.where((dist < 0.012) & (v < 0.97), LO, v)
    return baixa(v * m)


def coroa():
    """coroa do Rei da Mina: aro com 3 pontas de cristal"""
    n = 128
    im, d, W, H = tela(n)
    pts = [(0.14, 0.78), (0.10, 0.36), (0.30, 0.56), (0.50, 0.14), (0.70, 0.56), (0.90, 0.36), (0.86, 0.78)]
    d.polygon([(x * W, y * H) for x, y in pts], fill=255)
    d.rectangle([0.14 * W, 0.74 * H, 0.86 * W, 0.88 * H], fill=255)
    f = Image.new("L", (W, H), int(0.62 * 255))
    fd = ImageDraw.Draw(f)
    fd.rectangle([0.14 * W, 0.74 * H, 0.86 * W, 0.88 * H], fill=int(0.45 * 255))
    for cx, cy in ((0.50, 0.50), (0.26, 0.66), (0.74, 0.66)):
        r = 0.07
        fd.polygon([((cx) * W, (cy - r * 1.3) * H), ((cx + r) * W, cy * H), (cx * W, (cy + r * 1.3) * H), ((cx - r) * W, cy * H)], fill=255)
    m = arr(im) > 0.5
    v = arr(f)
    dist = ndi.distance_transform_edt(m) / W
    v = np.where((dist < 0.03) & (v < 0.97), LO, v)
    return baixa(v * m, n)


TEXS = [("estouro", estouro), ("estouro_b", estouro_b), ("estrela4", estrela4), ("lasca", lasca), ("arco_golpe", arco_golpe),
        ("raio_oco", raio_oco), ("poeira", poeira), ("anel_serra", anel_serra), ("pedra", pedra), ("cristal_ter", cristal_ter),
        ("cristal_lanca", cristal_lanca), ("picareta", picareta), ("broca", broca), ("dinamite", dinamite), ("lanterna", lanterna),
        ("coluna", coluna), ("coroa", coroa)]


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    folha = []
    for nm, fn in TEXS:
        a = salva(nm, fn())
        folha.append((nm, a))
        print("textura", nm, a.shape)
    if len(sys.argv) > 1:
        # folha de revisão: cada textura pintada com a rampa da facção sobre cinza
        ramp = [(0x29, 0x2C, 0x35), (0x49, 0x3D, 0x3D), (0xFF, 0xAC, 0x45), (0xFF, 0xD9, 0x7A), (0xFF, 0xFF, 0xFF)]
        cols = 6
        rows = (len(folha) + cols - 1) // cols
        sh = Image.new("RGB", (cols * 200, rows * 200), (96, 98, 110))
        for i, (nm, a) in enumerate(folha):
            v = a.astype(np.float32) / 255
            idx = v * (len(ramp) - 1)
            i0 = np.clip(np.floor(idx).astype(int), 0, len(ramp) - 2)
            fr = (idx - i0)[..., None]
            rp = np.array(ramp, np.float32)
            rgbv = rp[i0] * (1 - fr) + rp[i0 + 1] * fr
            al = np.clip(v / 0.12, 0, 1)[..., None]
            t = Image.fromarray(np.dstack([rgbv, al * 255]).astype(np.uint8), "RGBA")
            t.thumbnail((190, 190))
            sh.paste(t, ((i % cols) * 200 + (200 - t.width) // 2, (i // cols) * 200 + (200 - t.height) // 2), t)
        sh.save(sys.argv[1])
