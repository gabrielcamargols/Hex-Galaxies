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


def racha():
    """rachadura no chão (decalque): linhas ramificadas; miolo da linha = intensidade alta (vira brilho magenta)"""
    S = N * 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    rr = random.Random(13)

    def ramo(x, y, a, L, w, prof):
        pts = [(x, y)]
        n = int(6 + L / 8)
        for i in range(n):
            a += rr.uniform(-0.5, 0.5)
            x += math.cos(a) * L / n
            y += math.sin(a) * L / n
            pts.append((x, y))
            if prof < 2 and rr.random() < 0.18:
                ramo(x, y, a + rr.choice([-1, 1]) * rr.uniform(0.5, 1.1), L * 0.45, w * 0.6, prof + 1)
        for i in range(len(pts) - 1):
            ww = max(1, int(w * (1 - i / len(pts))))
            d.line([pts[i], pts[i + 1]], fill=255, width=ww)
    for k in range(7):
        a = k / 7 * 2 * math.pi + rr.uniform(-0.3, 0.3)
        ramo(S / 2, S / 2, a, S * rr.uniform(0.28, 0.45), 9, 0)
    d.ellipse([S / 2 - 16, S / 2 - 16, S / 2 + 16, S / 2 + 16], fill=255)
    m = np.asarray(im).astype(np.float32) / 255
    core = ndi.gaussian_filter(m, 1.2)
    halo = ndi.gaussian_filter(m, 4.0) * 0.6
    v = np.clip(np.maximum(core, halo * 0.45), 0, 1)
    v = np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255
    v = np.clip((v - 0.14) / 0.86, 0, 1)      # fundo zerado: só as linhas e um halo curto
    x, y = grid()
    return v * np.clip((1.0 - np.hypot(x, y)) * 4, 0, 1)


def arpao():
    """arpão de lado (ponta à direita), 256x64: haste, farpas e ponta; intensidade alta no fio da lâmina"""
    W, H = 256, 64
    im = Image.new("L", (W * 2, H * 2), 0)
    d = ImageDraw.Draw(im)
    s = 2
    d.rectangle([0, 28 * s, 190 * s, 36 * s], fill=215)                         # haste
    d.polygon([(178 * s, 14 * s), (256 * s, 32 * s), (178 * s, 50 * s), (192 * s, 32 * s)], fill=255)   # ponta
    d.polygon([(150 * s, 32 * s), (176 * s, 10 * s), (168 * s, 32 * s)], fill=230)                   # farpa de cima
    d.polygon([(150 * s, 32 * s), (176 * s, 54 * s), (168 * s, 32 * s)], fill=230)                   # farpa de baixo
    for k in range(4):                                                                               # amarras
        x = 20 + k * 14
        d.rectangle([x * s, 25 * s, (x + 5) * s, 39 * s], fill=120)
    v = np.asarray(im.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255
    return v


def raio():
    """raio em tira repetível (256x64): zigue-zague com ramos; miolo branco (alto), halo baixo"""
    W, H = 256, 64
    rr = random.Random(17)
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    pts = [(0, H / 2)]
    for i in range(1, 9):
        pts.append((i * W / 9, H / 2 + rr.uniform(-20, 20)))
    pts.append((W, H / 2))
    d.line(pts, fill=255, width=5)
    for i in range(2, 8, 2):
        x, y = pts[i]
        d.line([(x, y), (x + rr.uniform(10, 26), y + rr.choice([-1, 1]) * rr.uniform(12, 22))], fill=200, width=3)
    m = np.asarray(im).astype(np.float32) / 255
    core = ndi.gaussian_filter(m, 0.8)
    core = np.clip(core / core.max() * 1.3, 0, 1)      # miolo do raio chega no topo da rampa (cor do núcleo)
    halo = ndi.gaussian_filter(m, 5.0) * 2.2
    return np.clip(np.maximum(core, np.clip(halo, 0, 0.45)), 0, 1)


def _poly_mask(pts, S):
    im = Image.new("L", (S, S), 0)
    ImageDraw.Draw(im).polygon(pts, fill=255)
    return np.asarray(im).astype(np.float32) / 255


def pinca_a():
    """dedo de cima da pinça de caranguejo: nasce no CENTRO (pivô), arqueia para a direita e desce até a ponta;
    dentes serrilhados na borda de dentro. Intensidade alta no miolo, baixa na borda."""
    S = N * 2
    c = S / 2
    R = S * 0.46
    P0, P1, P2 = np.array([c, c - 4.0]), np.array([c + 0.55 * R, c - 0.75 * R]), np.array([c + 0.98 * R, c + 0.05 * R])
    outer, inner = [], []
    n = 40
    for i in range(n + 1):
        t = i / n
        p = (1 - t) ** 2 * P0 + 2 * (1 - t) * t * P1 + t * t * P2
        dp = 2 * (1 - t) * (P1 - P0) + 2 * t * (P2 - P1)
        nv = np.array([dp[1], -dp[0]]) / (np.linalg.norm(dp) + 1e-6)     # normal para fora (cima)
        w = S * 0.075 * (1 - t) ** 0.8 + 1.0
        outer.append(tuple(p + nv * w))
        dente = (S * 0.045 if (i % 4) in (1, 2) and 0.08 < t < 0.8 else 0.0)
        inner.append(tuple(p - nv * (w * 0.55 + dente)))
    pts = outer + inner[::-1]
    m = _poly_mask(pts, S)
    d = ndi.distance_transform_edt(m)
    v = np.clip(d / 16.0, 0, 1) * 0.8 + m * 0.2
    v = np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255
    return v


def punho():
    """punho de HQ fechado, nós dos dedos para cima; borda escura (contorno) por intensidade baixa"""
    S = N * 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([S * 0.30, S * 0.62, S * 0.70, S * 0.92], radius=int(S * 0.06), fill=255)          # pulso
    d.ellipse([S * 0.16, S * 0.26, S * 0.84, S * 0.80], fill=255)                                            # mão
    for k in range(4):
        cx = S * (0.27 + k * 0.155)
        d.ellipse([cx - S * 0.085, S * 0.14, cx + S * 0.085, S * 0.40], fill=255)                            # nós
    d.ellipse([S * 0.10, S * 0.42, S * 0.46, S * 0.66], fill=255)                                            # polegar
    m = np.asarray(im).astype(np.float32) / 255 > 0.5
    dist = ndi.distance_transform_edt(m)
    v = np.clip(dist / 10.0, 0, 1) * 0.85 + m * 0.15
    ln = Image.new("L", (S, S), 0)
    dl = ImageDraw.Draw(ln)
    for k in range(3):
        x = S * (0.345 + k * 0.155)
        dl.line([(x, S * 0.22), (x, S * 0.44)], fill=255, width=7)
    dl.arc([S * 0.10, S * 0.42, S * 0.46, S * 0.66], 200, 340, fill=255, width=6)
    lnm = np.asarray(ln).astype(np.float32) / 255
    v = np.where(lnm > 0.5, 0.18, v)
    hi = np.clip(1 - np.hypot((np.arange(S)[None, :] - S * 0.42) / (S * 0.18), (np.arange(S)[:, None] - S * 0.3) / (S * 0.09)), 0, 1)
    v = np.clip(v + hi * 0.25 * m, 0, 1)
    v = np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255
    return v


def onda():
    """crista de onda (maré): arco grosso com espuma recortada no topo"""
    x, y = grid()
    r = np.hypot(x, y + 0.6)
    band = np.clip(1 - np.abs(r - 0.95) / 0.22, 0, 1) * (y < 0.3)
    n = fbm(41, esc=10)
    espuma = np.clip(1 - np.abs(r - 1.12) / (0.05 + 0.08 * n), 0, 1) * (n > 0.45) * (y < 0.2)
    return np.clip(np.maximum(band * (0.5 + 0.5 * np.clip(1.15 - r, 0, 1) * 2), espuma), 0, 1)


def garras_chao():
    """três sulcos de garra no chão"""
    S = N * 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    for k in range(3):
        off = (k - 1) * S * 0.16
        pts = []
        for i in range(12):
            t = i / 11
            pts.append((S * 0.18 + t * S * 0.64 + off * 0.3, S * 0.25 + off + t * S * 0.42 + math.sin(t * 3) * 8))
        for i in range(len(pts) - 1):
            w = int(4 + 22 * math.sin(math.pi * i / (len(pts) - 1)))
            d.line([pts[i], pts[i + 1]], fill=255, width=w)
    m = np.asarray(im).astype(np.float32) / 255
    core = ndi.gaussian_filter(m, 1.5)
    v = np.asarray(Image.fromarray((np.clip(core, 0, 1) * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255
    return v


def moeda():
    x, y = grid()
    r = np.hypot(x * 1.0, y * 1.0)
    face = np.clip((0.82 - r) * 12, 0, 1)
    aro = np.clip(1 - np.abs(r - 0.66) / 0.06, 0, 1)
    return np.clip(face * 0.7 + aro * 0.3 + np.clip(0.4 - np.hypot(x + 0.3, y + 0.3), 0, 1), 0, 1)


def espinhos():
    """bola de espinhos (baiacu): corpo redondo + espinhos triangulares; miolo alto, borda baixa (contorno)"""
    S = N * 2
    c = S / 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    rr = random.Random(3)
    for k in range(14):
        a = k / 14 * 2 * math.pi + rr.uniform(-0.1, 0.1)
        L = S * rr.uniform(0.40, 0.47)
        w = 0.16
        d.polygon([(c + math.cos(a - w) * S * 0.26, c + math.sin(a - w) * S * 0.26), (c + math.cos(a) * L, c + math.sin(a) * L),
                   (c + math.cos(a + w) * S * 0.26, c + math.sin(a + w) * S * 0.26)], fill=255)
    d.ellipse([c - S * 0.29, c - S * 0.29, c + S * 0.29, c + S * 0.29], fill=255)
    m = np.asarray(im).astype(np.float32) / 255 > 0.5
    v = np.clip(ndi.distance_transform_edt(m) / 22.0, 0, 1) * 0.85 + m * 0.15
    y, x = np.mgrid[0:S, 0:S]
    v = np.clip(v + np.clip(1 - np.hypot(x - c * 0.82, y - c * 0.8) / (S * 0.1), 0, 1) * 0.3 * m, 0, 1)
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255


def agulha():
    """espinho de baiacu de lado (ponta à direita), 256x64: base grossa afinando até a ponta; borda baixa (contorno), miolo alto"""
    W, H = 256, 64
    s = 4
    im = Image.new("L", (W * s, H * s), 0)
    d = ImageDraw.Draw(im)
    d.polygon([(8 * s, 18 * s), (40 * s, 21 * s), (250 * s, 32 * s), (40 * s, 43 * s), (8 * s, 46 * s)], fill=255)
    m = np.asarray(im).astype(np.float32) / 255 > 0.5
    dist = ndi.distance_transform_edt(m) / (s * 9.0)
    v = np.clip(dist, 0, 1) * 0.8 + m * 0.2
    y, x = np.mgrid[0:H * s, 0:W * s]
    v = np.clip(v + np.clip(1 - np.abs(y - 32 * s) / (2.2 * s), 0, 1) * m * 0.35, 0, 1)   # fio claro no centro
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)).astype(np.float32) / 255


def _soft(m, k=9.0, hi=0.2, S=1):
    """máscara booleana -> intensidade: borda baixa (contorno), miolo alto"""
    d = ndi.distance_transform_edt(m) / (S * k)
    return np.clip(d, 0, 1) * (1 - hi) + m * hi


def chifre():
    """chifre de narval de lado (ponta à direita), 256x64: cone com espiral e base grossa"""
    W, H, s = 256, 64, 4
    im = Image.new("L", (W * s, H * s), 0)
    d = ImageDraw.Draw(im)
    d.polygon([(6 * s, 10 * s), (60 * s, 17 * s), (252 * s, 32 * s), (60 * s, 47 * s), (6 * s, 54 * s)], fill=255)
    m = np.asarray(im).astype(np.float32) / 255 > 0.5
    v = _soft(m, 10.0, 0.25, s)
    y, x = np.mgrid[0:H * s, 0:W * s]
    larg = np.clip((x / s - 6) / 246, 0, 1)
    ban = np.sin((x / s * 0.55) + (y / s - 32) * 0.28)                 # faixas diagonais = espiral do chifre
    v = np.where(m, np.clip(v - (ban > 0.55) * 0.32 * (1 - larg * 0.6), 0, 1), v)
    v = np.clip(v + np.clip(1 - np.abs(y - 26 * s) / (2.0 * s), 0, 1) * m * 0.3, 0, 1)
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)).astype(np.float32) / 255


def espeto():
    """espeto vertical (ponta em cima), 128: base larga, afinando; para rajadas radiais com velocidade"""
    S = N * 4
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    d.polygon([(S * 0.30, S * 0.98), (S * 0.5, S * 0.02), (S * 0.70, S * 0.98)], fill=255)
    m = np.asarray(im).astype(np.float32) / 255 > 0.5
    v = _soft(m, 9.0, 0.25, 4)
    y, x = np.mgrid[0:S, 0:S]
    v = np.clip(v + np.clip(1 - np.abs(x - S * 0.46) / (S * 0.02), 0, 1) * m * 0.3, 0, 1)
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255


def mandibula():
    """mandíbula de cima: gengiva em arco largo e achatado com presas penduradas; a de baixo é a mesma girada 180 graus"""
    S = N * 4
    c = S / 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    cy = S * 0.3
    d.ellipse([c - S * 0.48, cy - S * 0.2, c + S * 0.48, cy + S * 0.2], fill=255)
    d.rectangle([0, cy, S, S], fill=0)                      # só o topo do arco (gengiva)
    d.rectangle([c - S * 0.47, cy - S * 0.01, c + S * 0.47, cy + S * 0.07], fill=255)
    rr = random.Random(11)
    n = 6
    for k in range(n):
        u = (k + 0.5) / n * 2 - 1                          # -1..1 ao longo da boca
        px = c + u * S * 0.40
        py = cy + S * 0.03
        L = S * (0.46 - 0.12 * abs(u)) * (1.0 + rr.uniform(-0.05, 0.08))
        tip = (px - u * S * 0.05, py + L)                  # as pontas se fecham um pouco para dentro
        w = S * 0.065
        d.polygon([(px - w, py), tip, (px + w, py)], fill=255)
    m = np.asarray(im).astype(np.float32) / 255 > 0.5
    v = _soft(m, 6.0, 0.3, 4)
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255


def jato():
    """jato de maré de lado (frente à direita), 256x64: massa de água com crista curvada na frente, topo com espuma"""
    W, H, s = 256, 64, 4
    rr = random.Random(23)
    im = Image.new("L", (W * s, H * s), 0)
    d = ImageDraw.Draw(im)
    top = []
    for i in range(0, 41):
        x = 6 + i * 5.2
        f = i / 40
        h = 8 + 34 * (f ** 0.8) + rr.uniform(-3, 3) * f      # cresce para a frente
        top.append((x * s, (60 - h) * s))
    d.polygon([(6 * s, 60 * s)] + top + [(220 * s, 14 * s), (244 * s, 20 * s), (252 * s, 36 * s), (240 * s, 50 * s), (214 * s, 60 * s)], fill=255)
    for k in range(7):                                     # bolhas de espuma na crista
        cx, cy = rr.uniform(150, 235), rr.uniform(10, 26)
        d.ellipse([(cx - 7) * s, (cy - 7) * s, (cx + 7) * s, (cy + 7) * s], fill=255)
    m = np.asarray(im).astype(np.float32) / 255 > 0.5
    v = _soft(m, 9.0, 0.3, s)
    y, x = np.mgrid[0:H * s, 0:W * s]
    ond = np.sin(x / s * 0.45 + y / s * 0.2) > 0.6                                   # linhas de correnteza
    v = np.where(m, np.clip(v - ond * 0.08, 0, 1), v)
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)).astype(np.float32) / 255


def estrela_mar():
    """estrela-do-mar vista de cima: 5 braços arredondados, miolo e pintinhas (para o chão)"""
    S = N * 4
    c = S / 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = S * (0.46 if k % 2 == 0 else 0.17)
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
    d.polygon(pts, fill=255)
    m = np.asarray(im.filter(ImageFilter.GaussianBlur(S * 0.012))).astype(np.float32) / 255 > 0.5
    v = _soft(m, 14.0, 0.25, 4)
    y, x = np.mgrid[0:S, 0:S]
    for k in range(5):
        a = -math.pi / 2 + k * 2 * math.pi / 5
        for t in (0.2, 0.3, 0.4):
            px, py = c + math.cos(a) * S * t * 0.95, c + math.sin(a) * S * t * 0.95
            v = np.where(np.hypot(x - px, y - py) < S * 0.012, np.clip(v + 0.35, 0, 1), v)
        v = np.clip(v - np.clip(1 - np.abs(np.cos(a) * (y - c) - np.sin(a) * (x - c)) / (S * 0.008), 0, 1) * m * 0.0, 0, 1)
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255


def arco_som():
    """onda sonora de lado, 256x64: arcos ")" concêntricos apontando para a direita (frente); usada esticada em faixa"""
    W, H, s = 256, 64, 4
    im = Image.new("L", (W * s, H * s), 0)
    d = ImageDraw.Draw(im)
    for k, (cx, rr, wd) in enumerate([(30, 100, 14), (95, 100, 11), (160, 90, 8)]):      # 3 arcos, o da frente mais fino
        box = [(cx - rr) * s, (32 - rr * 0.34) * s, (cx + rr) * s, (32 + rr * 0.34) * s]
        d.arc(box, -62, 62, fill=255, width=int(wd * s))
    m = np.asarray(im.filter(ImageFilter.GaussianBlur(s * 0.8))).astype(np.float32) / 255 > 0.45
    v = _soft(m, 4.5, 0.3, s)
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)).astype(np.float32) / 255


def engrenagem():
    """engrenagem de frente: aro com dentes e furo no meio"""
    S = N * 4
    c = S / 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    n = 10
    d.ellipse([c - S * 0.32, c - S * 0.32, c + S * 0.32, c + S * 0.32], fill=255)
    for k in range(n):
        a = 2 * math.pi * k / n
        px, py = c + math.cos(a) * S * 0.36, c + math.sin(a) * S * 0.36
        tx, ty = -math.sin(a), math.cos(a)
        w1, w2 = S * 0.075, S * 0.055
        ox, oy = math.cos(a) * S * 0.09, math.sin(a) * S * 0.09
        d.polygon([(px - tx * w1 - ox * 0.5, py - ty * w1 - oy * 0.5), (px + ox - tx * w2, py + oy - ty * w2), (px + ox + tx * w2, py + oy + ty * w2), (px + tx * w1 - ox * 0.5, py + ty * w1 - oy * 0.5)], fill=255)
    d.ellipse([c - S * 0.12, c - S * 0.12, c + S * 0.12, c + S * 0.12], fill=0)
    for k in range(4):                                       # furos de alívio
        a = math.pi / 4 + k * math.pi / 2
        px, py = c + math.cos(a) * S * 0.22, c + math.sin(a) * S * 0.22
        d.ellipse([px - S * 0.035, py - S * 0.035, px + S * 0.035, py + S * 0.035], fill=0)
    m = np.asarray(im).astype(np.float32) / 255 > 0.5
    v = _soft(m, 8.0, 0.3, 4)
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255


def chave():
    """chave inglesa na diagonal (cabeça em cima à direita), com boca aberta"""
    S = N * 4
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    c = S / 2
    d.rounded_rectangle([c - S * 0.06, S * 0.34, c + S * 0.06, S * 0.95], radius=int(S * 0.05), fill=255)        # cabo
    d.ellipse([c - S * 0.2, S * 0.08, c + S * 0.2, S * 0.48], fill=255)                                       # cabeça
    d.polygon([(c - S * 0.075, S * 0.06), (c + S * 0.075, S * 0.06), (c + S * 0.075, S * 0.27), (c - S * 0.075, S * 0.27)], fill=0)   # boca aberta
    im = im.rotate(-40, resample=Image.BICUBIC)
    m = np.asarray(im).astype(np.float32) / 255 > 0.5
    v = _soft(m, 7.0, 0.3, 4)
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255


def hexa():
    """placa hexagonal de reparo: moldura grossa, placa interna e 6 rebites"""
    S = N * 4
    c = S / 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    def hexp(r):
        return [(c + math.cos(math.radians(60 * k)) * r, c + math.sin(math.radians(60 * k)) * r) for k in range(6)]
    d.polygon(hexp(S * 0.47), fill=255)
    d.polygon(hexp(S * 0.37), fill=0)
    d.polygon(hexp(S * 0.31), fill=255)
    for k in range(6):
        a = math.radians(60 * k)
        px, py = c + math.cos(a) * S * 0.42, c + math.sin(a) * S * 0.42
        d.ellipse([px - S * 0.03, py - S * 0.03, px + S * 0.03, py + S * 0.03], fill=0)
    d.line([(c - S * 0.2, c), (c + S * 0.2, c)], fill=0, width=int(S * 0.02))      # junta da placa
    m = np.asarray(im).astype(np.float32) / 255 > 0.5
    v = _soft(m, 8.0, 0.3, 4)
    v = np.clip(v * 0.9 + np.where(m, 0.0, 0.0), 0, 1)
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255


def tentaculo():
    """tentáculo vertical que sobe e enrola a ponta para a direita, com ventosas"""
    S = N * 4
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    pts = []
    x, y = S * 0.36, S * 0.98
    th = -math.pi / 2
    n = 90
    for i in range(n):
        t = i / (n - 1)
        th += math.sin(t * 6.0) * 0.035 + (max(0.0, t - 0.55) ** 1.3) * 0.34       # ondula e enrola no fim
        x += math.cos(th) * S * 0.0105
        y += math.sin(th) * S * 0.0105
        pts.append((x, y, S * (0.085 * (1 - t) ** 0.9 + 0.014)))
    for x, y, r in pts:
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    m = np.asarray(im).astype(np.float32) / 255 > 0.5
    v = _soft(m, 6.0, 0.3, 4)
    for x, y, r in pts[8:80:6]:                           # ventosas
        yy, xx = np.mgrid[0:S, 0:S]
        v = np.where(np.hypot(xx - (x + r * 0.35), yy - y) < r * 0.28, np.clip(v - 0.3, 0, 1), v)
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255


def bolha():
    """bolha: anel fino + brilho no canto (intensidade alta no brilho)"""
    x, y = grid()
    r = np.hypot(x, y)
    aro = np.clip(1 - np.abs(r - 0.8) / 0.09, 0, 1) * 0.7
    dentro = np.clip(0.8 - r, 0, 1) * 0.25
    brilho = np.clip(1 - np.hypot(x + 0.35, y + 0.38) / 0.18, 0, 1)
    return np.clip(aro + dentro + brilho, 0, 1)


def mina():
    """mina marinha: esfera com pinos; intensidade: borda baixa (contorno), miolo médio, brilho alto"""
    S = N * 2
    c = S / 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    for k in range(8):
        a = k / 8 * 2 * math.pi
        x1, y1 = c + math.cos(a) * S * 0.36, c + math.sin(a) * S * 0.36
        d.line([(c, c), (x1, y1)], fill=255, width=14)
        d.ellipse([x1 - 14, y1 - 14, x1 + 14, y1 + 14], fill=255)
    d.ellipse([c - S * 0.27, c - S * 0.27, c + S * 0.27, c + S * 0.27], fill=255)
    m = np.asarray(im).astype(np.float32) / 255 > 0.5
    v = np.clip(ndi.distance_transform_edt(m) / 14.0, 0, 1) * 0.6 + m * 0.12
    y, x = np.mgrid[0:S, 0:S]
    v = np.clip(v + np.clip(1 - np.hypot(x - c * 0.85, y - c * 0.82) / (S * 0.09), 0, 1) * 0.5 * m, 0, 1)
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255


def veu():
    """véu-fantasma encapuzado (guarda do Balu): capuz com rosto escuro e barra esfiapada"""
    S = N * 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    pts = [(S * 0.5, S * 0.06), (S * 0.8, S * 0.28), (S * 0.86, S * 0.7)]
    for k in range(7):
        x = S * (0.86 - k * 0.12)
        pts.append((x, S * (0.94 if k % 2 == 0 else 0.8)))
    pts += [(S * 0.14, S * 0.7), (S * 0.2, S * 0.28)]
    d.polygon(pts, fill=255)
    m = np.asarray(im).astype(np.float32) / 255 > 0.5
    v = np.clip(ndi.distance_transform_edt(m) / 26.0, 0, 1) * 0.8 + m * 0.2
    face = Image.new("L", (S, S), 0)
    ImageDraw.Draw(face).ellipse([S * 0.36, S * 0.24, S * 0.64, S * 0.5], fill=255)
    fm = np.asarray(face).astype(np.float32) / 255
    v = np.where(fm > 0.5, 0.08, v)
    for ex in (0.44, 0.56):
        ey = Image.new("L", (S, S), 0)
        ImageDraw.Draw(ey).ellipse([S * (ex - 0.025), S * 0.35, S * (ex + 0.025), S * 0.39], fill=255)
        v = np.where(np.asarray(ey) > 128, 1.0, v)
    return np.asarray(Image.fromarray((v * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)).astype(np.float32) / 255


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for nm, fn in [("brilho", brilho), ("anel", anel), ("estrela", estrela), ("faisca", faisca), ("fumaca", fumaca),
                   ("estilhaco", estilhaco), ("respingo", respingo), ("rasgo", rasgo), ("gota", gota), ("seta", seta), ("corrente", corrente), ("voronoi", voronoi), ("ponto", ponto), ("retalho", retalho), ("racha", racha), ("arpao", arpao), ("raio", raio), ("pinca_a", pinca_a), ("punho", punho), ("onda", onda), ("garras_chao", garras_chao), ("moeda", moeda), ("espinhos", espinhos), ("agulha", agulha), ("chifre", chifre), ("espeto", espeto), ("mandibula", mandibula), ("jato", jato), ("estrela_mar", estrela_mar), ("arco_som", arco_som), ("engrenagem", engrenagem), ("chave", chave), ("hexa", hexa), ("tentaculo", tentaculo), ("bolha", bolha), ("mina", mina), ("veu", veu)]:
        v = fn()
        if nm == "faisca":
            v = v[::-1]          # cabeça em cima: o topo da textura segue a velocidade
        save(nm, v)
        if nm == "pinca_a":
            save("pinca_b", v[::-1])     # dedo de baixo: espelho vertical
        print("textura", nm)
