"""FORJA DE VFX — Hex Galaxies
Desenha efeitos 2D quadro a quadro (flipbooks) no estilo HQ/grafite do jogo, para virarem VFX 3D no Godot.

Cada efeito é uma função que recebe t (0..1) e um Pincel, e pinta camadas:
  forma orgânica (contorno polar com ruído) -> preenchimento em faixas (cel) -> retícula -> contorno de tinta
  + respingos, rachaduras, estilhaços de tinta, dissolução por ruído.

Uso:
  python3 tools/forja_vfx.py aby                 # gera todos os efeitos da facção em vfx/aby/*.png
  python3 tools/forja_vfx.py aby garra impacto   # só alguns
  python3 tools/forja_vfx.py aby --folha f.png   # e uma folha de revisão com todos os quadros

Saída: tira horizontal de N quadros (N e tamanho de cada quadro no nome da receita em data/vfx_receitas.json).
"""
import json, math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = os.path.join(os.path.dirname(__file__), "..")
PAL = json.load(open(os.path.join(ROOT, "data", "vfx_paletas.json")))
SS = 2   # supersample


def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


# ---------------------------------------------------------------- ruído
class Ruido:
    def __init__(self, seed, size):
        self.rng = np.random.default_rng(seed)
        self.size = size
        self.cache = {}

    def campo(self, escala, oitavas=3, key=0):
        """fBm suave do tamanho do quadro, valores 0..1"""
        k = (escala, oitavas, key)
        if k in self.cache:
            return self.cache[k]
        H, W = self.size
        acc = np.zeros((H, W), np.float32)
        amp, tot = 1.0, 0.0
        g = max(2, int(escala))
        for _ in range(oitavas):
            base = self.rng.random((g + 1, g + 1)).astype(np.float32)
            up = ndi.zoom(base, (H / (g + 1) * 1.0001, W / (g + 1) * 1.0001), order=3)[:H, :W]
            acc += up * amp
            tot += amp
            amp *= 0.5
            g *= 2
        acc /= tot
        acc = (acc - acc.min()) / max(1e-6, acc.max() - acc.min())
        self.cache[k] = acc
        return acc

    def angular(self, n=64, key=0):
        """ruído periódico em ângulo (para contornos polares)"""
        r = np.random.default_rng(hash((key, n)) % (2 ** 32))
        v = r.random(n).astype(np.float32)
        v = np.concatenate([v, v[:4]])
        return v


def ang_interp(tab, th, freq=1.0):
    """amostra tabela periódica em ângulo th (rad) com interpolação cúbica simples"""
    n = len(tab) - 4
    x = (th / (2 * math.pi) * freq * n) % n
    i = np.floor(x).astype(int)
    f = x - i
    a, b = tab[i], tab[(i + 1) % n]
    f = f * f * (3 - 2 * f)
    return a * (1 - f) + b * f


# ---------------------------------------------------------------- pincel
class Pincel:
    """tela de um quadro, em supersample; coordenadas 0..1 (x, y) com y para baixo"""

    def __init__(self, w, h, pal, seed=1):
        self.W, self.H = w * SS, h * SS
        self.w, self.h = w, h
        self.pal = pal
        self.rgb = np.zeros((self.H, self.W, 3), np.float32)
        self.a = np.zeros((self.H, self.W), np.float32)
        yy, xx = np.mgrid[0:self.H, 0:self.W].astype(np.float32)
        self.X = xx / self.W
        self.Y = yy / self.H * (self.H / self.W)  # mantém proporção: unidade = largura
        self.aspect = self.H / self.W
        self.ruido = Ruido(seed, (self.H, self.W))
        self.rng = random.Random(seed)

    # --- máscaras ---
    def polar(self, cx, cy, raio_fn):
        """máscara de forma polar: raio_fn(theta) -> raio (unid. de largura)"""
        dx, dy = self.X - cx, self.Y - cy
        th = np.arctan2(dy, dx) % (2 * math.pi)
        r = np.hypot(dx, dy)
        R = raio_fn(th)
        return r < R, r, th, R

    def explosao(self, cx, cy, raio, pontas, agud, seed, deform=0.25, rot=0.0):
        """estrela orgânica: pontas irregulares + deformação"""
        rr = random.Random(seed)
        n = pontas
        offs = [rr.uniform(-0.35, 0.35) for _ in range(n)]
        lens = [rr.uniform(0.55, 1.0) for _ in range(n)]
        tab = self.ruido.angular(48, key=seed)

        def fn(th):
            u = ((th + rot) / (2 * math.pi) * n) % n
            i = np.floor(u).astype(int)
            f = u - i
            o = np.array(offs)[i]
            L = np.array(lens)[i]
            ponta = np.clip(1 - np.abs(f - 0.5 - o * 0.5) * 2, 0, 1) ** agud
            return raio * (0.42 + 0.58 * ponta * L) * (1 + deform * (ang_interp(tab, th) - 0.5))
        return self.polar(cx, cy, fn)

    def blob(self, cx, cy, raio, seed, deform=0.35, freq=1.0):
        tab = self.ruido.angular(24, key=seed)
        return self.polar(cx, cy, lambda th: raio * (1 + deform * (ang_interp(tab, th, freq) - 0.5)))

    def disco(self, cx, cy, r):
        return np.hypot(self.X - cx, self.Y - cy) < r

    def dissolve(self, mask, t, escala=6, key=3, borda=0.0):
        """come a máscara com ruído: t=0 intacto, t=1 sumiu"""
        if t <= 0:
            return mask
        n = self.ruido.campo(escala, 3, key)
        return mask & (n > t * 1.02 + borda)

    # --- pintura ---
    def tinta(self, mask, larg=4.0, aspereza=0.6, key=7, cor=None):
        """contorno de tinta grosso e irregular em volta da máscara"""
        if not mask.any():
            return
        d = ndi.distance_transform_edt(~mask)
        n = self.ruido.campo(10, 2, key)
        w = larg * SS * (1 - aspereza * 0.5 + aspereza * n)
        k = (d > 0) & (d <= w)
        self.pinta(k, cor if cor is not None else rgb(self.pal["outline"]))

    def pinta(self, mask, cor, alpha=1.0):
        m = mask.astype(np.float32) * alpha if mask.dtype == bool else np.clip(mask, 0, 1) * alpha
        self.rgb = self.rgb * (1 - m[..., None]) + np.asarray(cor, np.float32)[None, None, :] * m[..., None]
        self.a = np.maximum(self.a, m) if alpha >= 1 else self.a + (1 - self.a) * m

    def cel(self, mask, luz, cores, cortes, reticula=None):
        """preenche a máscara em faixas de cor pelo campo 'luz' (0 escuro .. 1 claro).
        reticula: (faixa, tamanho_px, cor) põe pontos grandes de transição na faixa indicada"""
        idx = np.digitize(luz, cortes)
        for i, c in enumerate(cores):
            self.pinta(mask & (idx == i), c)
        if reticula is not None:
            faixa, passo, corp = reticula
            lo = cortes[faixa - 1] if faixa > 0 else 0.0
            hi = cortes[faixa] if faixa < len(cortes) else 1.0
            local = np.clip((luz - lo) / max(1e-6, hi - lo), 0, 1)
            self.retic(mask & (idx == faixa), 1 - local, passo, corp)

    def retic(self, mask, dens, passo, cor, ang=0.5):
        """retícula de pontos: dens 0..1 controla o raio dos pontos"""
        p = passo * SS
        c, s = math.cos(ang), math.sin(ang)
        u = (self.X * self.W * c - self.Y * self.W * s) / p
        v = (self.X * self.W * s + self.Y * self.W * c) / p
        fu, fv = u - np.round(u), v - np.round(v)
        r = np.hypot(fu, fv)
        dots = r < (0.08 + 0.55 * np.clip(dens, 0, 1))
        self.pinta(mask & dots, cor)

    def poligono(self, pts, cor=None, retorna=False):
        im = Image.new("L", (self.W, self.H), 0)
        ImageDraw.Draw(im).polygon([(x * self.W, y * self.W) for x, y in pts], fill=255)
        m = np.asarray(im) > 0
        if not retorna and cor is not None:
            self.pinta(m, cor)
        return m

    def linhas(self, segs, larg, cor=None):
        """segs: lista de polilinhas [(x,y),...] com largura (px no quadro final) que afina"""
        im = Image.new("L", (self.W, self.H), 0)
        d = ImageDraw.Draw(im)
        for pts, w in segs:
            n = len(pts)
            for i in range(n - 1):
                ww = max(1, int(w * SS * (1 - i / max(1, n - 1)) * 0.85 + SS))
                d.line([(pts[i][0] * self.W, pts[i][1] * self.W), (pts[i + 1][0] * self.W, pts[i + 1][1] * self.W)], fill=255, width=ww)
                d.ellipse([pts[i + 1][0] * self.W - ww / 2, pts[i + 1][1] * self.W - ww / 2,
                           pts[i + 1][0] * self.W + ww / 2, pts[i + 1][1] * self.W + ww / 2], fill=255)
        m = np.asarray(im) > 0
        if cor is not None:
            self.pinta(m, cor)
        return m

    def espinhos(self, cx, cy, n, r0, r1, larg, seed, cor, ang0=0, abertura=2 * math.pi):
        """traços pretos agressivos irradiando (marcador grosso)"""
        rr = random.Random(seed)
        im = Image.new("L", (self.W, self.H), 0)
        d = ImageDraw.Draw(im)
        for _ in range(n):
            a = ang0 + rr.uniform(-abertura / 2, abertura / 2)
            ra = rr.uniform(r0, r0 + (r1 - r0) * 0.4)
            rb = rr.uniform(r0 + (r1 - r0) * 0.55, r1)
            w = rr.uniform(0.4, 1.0) * larg / self.w
            ux, uy = math.cos(a), math.sin(a)
            px, py = -uy, ux
            pts = [(cx + ux * ra + px * w, cy + uy * ra + py * w), (cx + ux * rb, cy + uy * rb),
                   (cx + ux * ra - px * w, cy + uy * ra - py * w)]
            d.polygon([(x * self.W, y * self.W) for x, y in pts], fill=255)
        m = np.asarray(im) > 0
        self.pinta(m, cor)
        return m

    def gotas(self, gotas, cor_corpo, cor_tinta, brilho=None):
        """gotas: lista (x, y, r, vx, vy) — desenha gota com rabo na direção oposta ao movimento"""
        corpo = np.zeros((self.H, self.W), bool)
        for x, y, r, vx, vy in gotas:
            if r <= 0.001:
                continue
            sp = math.hypot(vx, vy)
            m = self.disco(x, y, r)
            if sp > 1e-4:
                ux, uy = vx / sp, vy / sp
                L = min(r * 4, sp * 0.6 + r)
                tail = [(x - uy * r, y + ux * r), (x - ux * L, y - uy * L), (x + uy * r, y - ux * r)]
                m |= self.poligono(tail, retorna=True)
            corpo |= m
        if not corpo.any():
            return
        self.tinta(corpo, 2.2, 0.3)
        self.pinta(corpo, cor_corpo)
        if brilho is not None:
            for x, y, r, vx, vy in gotas:
                if r > 0.012:
                    self.pinta(self.disco(x - r * 0.35, y - r * 0.35, r * 0.28), brilho)

    def rachaduras(self, cx, cy, seed, ramos=7, alcance=0.42, prog=1.0, larg=6):
        """gera polilinhas ramificadas a partir do centro; prog revela 0..1"""
        rr = random.Random(seed)
        segs = []

        def ramo(x, y, a, L, w, prof):
            pts = [(x, y)]
            passos = int(8 + L * 30)
            for i in range(passos):
                a += rr.uniform(-0.55, 0.55)
                st = L / passos
                x += math.cos(a) * st
                y += math.sin(a) * st
                pts.append((x, y))
                if prof < 2 and rr.random() < 0.13:
                    ramo(x, y, a + rr.choice([-1, 1]) * rr.uniform(0.5, 1.1), L * rr.uniform(0.3, 0.55), w * 0.6, prof + 1)
            segs.append((pts, w))
        for i in range(ramos):
            a = i / ramos * 2 * math.pi + rr.uniform(-0.3, 0.3)
            ramo(cx + math.cos(a) * 0.03, cy + math.sin(a) * 0.03, a, alcance * rr.uniform(0.6, 1.0), larg * rr.uniform(0.7, 1.2), 0)
        out = []
        for pts, w in segs:
            d0 = math.hypot(pts[0][0] - cx, pts[0][1] - cy)
            keep = [p for p in pts if math.hypot(p[0] - cx, p[1] - cy) <= d0 + alcance * prog * 1.1]
            if len(keep) > 1:
                out.append((keep, w))
        return out

    # --- saída ---
    def imagem(self):
        a = np.clip(self.a, 0, 1)
        im = np.dstack([np.clip(self.rgb, 0, 255), a * 255]).astype(np.uint8)
        img = Image.fromarray(im, "RGBA")
        # premultiplica para reduzir sem franja escura
        return img.resize((self.w, self.h), Image.LANCZOS)


def ease_out(t, p=2.5):
    return 1 - (1 - t) ** p


def ease_in(t, p=2.0):
    return t ** p


def seg(t, a, b):
    """mapeia t para 0..1 dentro da janela [a,b]"""
    return min(1.0, max(0.0, (t - a) / max(1e-6, b - a)))


# ---------------------------------------------------------------- efeitos ABYSSAIS
def P(fac, k):
    return rgb(PAL[fac][k])


def aby_cores():
    return {
        "mag": rgb("#F438A9"), "rox": rgb("#A957EC"), "vio": rgb("#301342"),
        "tinta": rgb("#12061c"), "claro": rgb("#FF91D8"), "branco": rgb("#FFF1FA"), "lil": rgb("#d7a8ff"),
    }


def fx_impacto(t, p, C):
    """explosão orgânica estilo marcador: núcleo branco, faixas magenta/roxo, retícula grossa,
    traços pretos agressivos e respingos voando"""
    cx, cy = 0.5, 0.5
    g = ease_out(seg(t, 0.0, 0.35), 3)
    fim = seg(t, 0.45, 1.0)
    # traços pretos de velocidade (nascem rápido e somem)
    if t < 0.7:
        e = seg(t, 0.0, 0.25)
        p.espinhos(cx, cy, 16, 0.10 + 0.12 * e, 0.30 + 0.20 * e, 7 * (1 - seg(t, 0.35, 0.7)), 11, C["tinta"])
    R = 0.08 + 0.34 * g
    m, r, th, Rf = p.explosao(cx, cy, R, 9, 1.6, 21, deform=0.45, rot=t * 0.6)
    m = p.dissolve(m, ease_in(fim, 1.6), escala=7, key=5)
    if m.any():
        luz = 1 - np.clip(r / np.maximum(Rf, 1e-4), 0, 1)
        n = p.ruido.campo(9, 2, 8)
        luz = np.clip(luz + (n - 0.5) * 0.25, 0, 1)
        p.tinta(m, 5.5, 0.8, key=9)
        p.cel(m, luz, [C["vio"], C["rox"], C["mag"], C["claro"], C["branco"]], [0.18, 0.38, 0.62, 0.8],
              reticula=(1, 9, C["vio"]))
        p.retic(m & (luz > 0.38) & (luz < 0.62), 1 - (luz - 0.38) / 0.24, 7, C["rox"])
    # buracos escuros com faíscas (ref. corte roxo)
    if 0.25 < t < 0.85 and m.any():
        b, *_ = p.blob(0.42 + 0.1 * t, 0.56, 0.05 * (1 - fim), 31, 0.6)
        b &= m
        p.pinta(b, C["vio"])
    # respingos de tinta voando
    rr = random.Random(41)
    gts = []
    for i in range(14):
        a = rr.uniform(0, 2 * math.pi)
        v = rr.uniform(0.35, 0.75)
        tt = seg(t, 0.08, 1.0)
        d = 0.12 + v * ease_out(tt, 1.8) * 0.55
        x = cx + math.cos(a) * d
        y = cy + math.sin(a) * d + 0.25 * tt * tt
        r0 = rr.uniform(0.010, 0.028) * (1 - tt ** 1.5)
        gts.append((x, y, r0, math.cos(a) * v * (1 - tt), math.sin(a) * v * (1 - tt) + 0.4 * tt))
    if t > 0.06:
        p.gotas(gts, C["mag"], C["tinta"], C["claro"])


def fx_garra(t, p, C):
    """três garras em arco varrendo da esquerda para a direita; borda serrilhada, manchas escuras
    com estrelinhas, dissolve em gotas no final"""
    cx, cy = 0.5, 0.56
    sweep = ease_out(seg(t, 0.0, 0.4), 2.2)
    fim = seg(t, 0.42, 1.0)
    base_a = math.radians(200)
    span = math.radians(150)
    n = p.ruido.campo(12, 3, 4)
    tudo = np.zeros((p.H, p.W), bool)
    luz_t = np.zeros((p.H, p.W), np.float32)
    for k, (rr0, esp) in enumerate([(0.30, 0.050), (0.38, 0.062), (0.46, 0.048)]):
        dx, dy = p.X - cx, p.Y - cy
        th = (np.arctan2(dy, dx) - base_a) % (2 * math.pi)
        r = np.hypot(dx, dy)
        head = span * sweep
        tail = head - span * (0.65 + 0.35 * sweep) * (1 - 0.6 * fim)
        dentro = (th <= head) & (th >= max(0.0, tail))
        u = np.clip((th - tail) / max(1e-4, head - tail), 0, 1)   # 0 rabo .. 1 ponta
        w = esp * np.sin(np.pi * np.clip(u * 0.92 + 0.04, 0, 1)) ** 0.7 * (1 - 0.5 * fim)
        w = w * (0.75 + 0.5 * n)
        m = dentro & (np.abs(r - rr0 - 0.02 * k * sweep) < w)
        m = p.dissolve(m, ease_in(fim, 1.3), escala=9, key=10 + k)
        tudo |= m
        luz_t = np.where(m, np.clip(1 - np.abs(r - rr0) / np.maximum(w, 1e-4), 0, 1) * 0.6 + u * 0.4, luz_t)
    if tudo.any():
        # contorno com espinhos: dilata mais onde o ruído é alto
        p.tinta(tudo, 5.0, 1.0, key=12)
        p.cel(tudo, luz_t, [C["vio"], C["rox"], C["mag"], C["claro"], C["branco"]], [0.2, 0.4, 0.65, 0.85],
              reticula=(1, 8, C["vio"]))
        # manchas violeta com faíscas dentro
        sp = p.ruido.campo(16, 2, 13)
        manchas = tudo & (sp > 0.72) & (luz_t < 0.7)
        p.pinta(manchas, C["vio"])
        rr = random.Random(int(t * 10))
        for _ in range(6):
            ys, xs = np.nonzero(manchas[::8, ::8])
            if len(xs) == 0:
                break
            j = rr.randrange(len(xs))
            x, y = xs[j] * 8 / p.W, ys[j] * 8 / p.W
            p.pinta(p.disco(x, y, 0.006), C["branco"])
    # gotas pingando das pontas quando dissolve
    if fim > 0:
        rr = random.Random(77)
        gts = []
        for i in range(9):
            a = base_a + span * rr.uniform(0.2, 1.0)
            rad = rr.uniform(0.28, 0.5)
            x0, y0 = cx + math.cos(a) * rad, cy + math.sin(a) * rad
            gts.append((x0 + 0.04 * fim, y0 + 0.3 * fim * fim, 0.016 * (1 - fim), 0.0, 0.5 * fim))
        p.gotas(gts, C["mag"], C["tinta"], C["claro"])


def fx_respingo(t, p, C):
    """mancha de tinta no chão (vista de cima) + rachaduras com brilho magenta"""
    cx, cy = 0.5, 0.5
    g = ease_out(seg(t, 0.0, 0.18), 3)
    fim = seg(t, 0.55, 1.0)
    # rachaduras crescem
    cr = p.rachaduras(cx, cy, 5, ramos=8, alcance=0.44, prog=ease_out(seg(t, 0.05, 0.45), 2), larg=7)
    if cr:
        fade = 1 - ease_in(fim, 1.5)
        mk = p.linhas(cr, 7)
        mk = p.dissolve(mk, ease_in(fim, 1.2), escala=10, key=14)
        p.tinta(mk, 2.0, 0.4)
        p.pinta(mk, C["vio"])
        mi = p.linhas([(pts, max(1, w * 0.35)) for pts, w in cr], 3)
        mi = p.dissolve(mi, ease_in(fim, 1.0), escala=10, key=14)
        p.pinta(mi, C["mag"] * 0.6 + C["claro"] * 0.4)
    # poça central com respingos em coroa
    R = 0.14 * g
    if R > 0.01:
        m, r, th, Rf = p.explosao(cx, cy, R * 1.3, 13, 0.9, 51, deform=0.6)
        m |= p.blob(cx, cy, R, 52, 0.5)[0]
        m = p.dissolve(m, ease_in(fim, 1.4), escala=8, key=15)
        if m.any():
            luz = 1 - np.clip(r / np.maximum(Rf, 1e-4), 0, 1)
            p.tinta(m, 4.0, 0.8, key=16)
            p.cel(m, luz, [C["vio"], C["rox"], C["mag"], C["claro"]], [0.25, 0.5, 0.82], reticula=(1, 8, C["vio"]))
    # gotinhas satélite
    rr = random.Random(61)
    gts = []
    for i in range(12):
        a = rr.uniform(0, 2 * math.pi)
        d = rr.uniform(0.17, 0.33) * g
        gts.append((cx + math.cos(a) * d, cy + math.sin(a) * d, rr.uniform(0.008, 0.02) * (1 - fim) * g, 0, 0))
    p.gotas(gts, C["mag"], C["tinta"], C["claro"])


def fx_coluna(t, p, C):
    """coluna de mutação (quadro alto): tronco preto com núcleo magenta, labaredas serrilhadas,
    bolhas subindo, anéis na base"""
    ar = p.aspect  # altura/largura (2.0)
    base_y = ar * 0.9
    sobe = ease_out(seg(t, 0.0, 0.3), 2.5)
    fim = seg(t, 0.55, 1.0)
    n = p.ruido.campo(10, 3, 20)
    nv = p.ruido.campo(6, 3, 21)
    # tronco: largura ondula com a altura; topo serrilhado
    topo = base_y - (ar * 0.85) * sobe
    yy = p.Y
    rel = np.clip((base_y - yy) / max(1e-4, base_y - topo), 0, 1)
    larg = (0.20 + 0.06 * np.sin(yy * 9 + t * 8) + 0.08 * (nv - 0.5)) * (1 - 0.15 * rel) * (1 - 0.65 * ease_in(fim, 1.2))
    borda = (n - 0.5) * 0.10
    corpo = (np.abs(p.X - 0.5 + 0.03 * np.sin(yy * 5 + t * 5)) < larg + borda) & (yy < base_y) & (yy > topo - 0.08 * n)
    corpo = p.dissolve(corpo, ease_in(fim, 1.6) * 0.95, escala=7, key=22)
    if corpo.any():
        p.tinta(corpo, 3.0, 0.6, key=23, cor=C["mag"] * 0.5 + C["vio"] * 0.5)  # brilho de borda em vez de tinta
        p.pinta(corpo, C["tinta"])
        # chamas internas magenta subindo (ref. coluna rosa)
        dx = np.abs(p.X - 0.5) / np.maximum(larg, 1e-3)
        fl = p.ruido.campo(8, 3, 24)
        fl = np.roll(fl, int(-t * p.H * 0.5), axis=0)
        chama = corpo & (dx + (1 - rel) * 0.15 < 0.25 + 0.75 * fl * (1 - rel * 0.7))
        luz = np.clip(1 - dx * 0.9 - rel * 0.6 + (fl - 0.5) * 0.3, 0, 1)
        p.cel(chama, luz, [C["rox"], C["mag"], C["claro"], C["branco"]], [0.3, 0.55, 0.8], reticula=(0, 7, C["vio"]))
        # bolhas
        rr = random.Random(5)
        for i in range(6):
            bx = 0.5 + rr.uniform(-0.12, 0.12)
            by0 = base_y - rr.uniform(0.3, 1.5)
            by = by0 - t * rr.uniform(0.4, 0.9)
            br = rr.uniform(0.025, 0.05) * (1 - fim)
            if br > 0.004 and by > topo:
                b = p.disco(bx, by, br)
                p.tinta(b, 2.0, 0.3)
                p.pinta(b, C["mag"] * 0.8 + C["vio"] * 0.2)
                p.pinta(p.disco(bx - br * 0.3, by - br * 0.35, br * 0.3), C["claro"])
    # espinhos na base
    e = seg(t, 0.0, 0.25) * (1 - fim)
    if e > 0:
        p.espinhos(0.5, base_y, 14, 0.04, 0.10 + 0.18 * e, 9 * e, 25, C["tinta"], ang0=-math.pi / 2, abertura=math.pi * 0.95)
        p.espinhos(0.5, base_y, 8, 0.03, 0.08 + 0.12 * e, 6 * e, 26, C["mag"], ang0=-math.pi / 2, abertura=math.pi * 0.8)


def fx_projetil(t, p, C):
    """bolota de mutação girando (laço): núcleo violeta, borda magenta pulsante, gotas presas"""
    cx, cy = 0.5, 0.5
    ph = t * 2 * math.pi
    R = 0.25 + 0.025 * math.sin(ph * 2)
    tab_seed = 70 + int(t * 8) % 8  # formas trocando (fervura)
    m, r, th, Rf = p.blob(cx, cy, R, tab_seed, 0.45, freq=1.0)
    p.espinhos(cx, cy, 10, R * 0.8, R * 1.55, 6, 71 + int(t * 8) % 8, C["tinta"])
    luz = 1 - np.clip(r / np.maximum(Rf, 1e-4), 0, 1)
    # luz deslocada para cima-esquerda (volume)
    luz = np.clip(luz * 0.7 + (0.5 - (p.X - cx) - (p.Y - cy)) * 0.6 - 0.15, 0, 1)
    p.tinta(m, 5.0, 0.9, key=72)
    p.cel(m, luz, [C["vio"], C["rox"], C["mag"], C["claro"]], [0.25, 0.48, 0.75], reticula=(0, 8, C["rox"]))
    # olho/núcleo
    p.pinta(p.blob(cx + 0.03, cy + 0.03, 0.07, 73 + int(t * 8) % 8, 0.5)[0], C["tinta"])
    p.pinta(p.disco(cx + 0.05, cy + 0.01, 0.018), C["branco"])
    p.pinta(p.disco(cx - 0.1, cy - 0.12, 0.035), C["branco"])


def fx_gota(t, p, C):
    """gota solta (para partículas): pequena, com brilho; anima esticando"""
    st = 1 + 0.6 * math.sin(t * math.pi)
    m = p.disco(0.5, 0.5, 0.26)
    m |= p.poligono([(0.5 - 0.24, 0.5), (0.5, 0.5 - 0.26 * st * 1.6), (0.5 + 0.24, 0.5)], retorna=True)
    p.tinta(m, 6, 0.4)
    p.cel(m, np.clip(1 - p.Y * 1.1 + 0.2, 0, 1), [C["rox"], C["mag"]], [0.5])
    p.pinta(p.disco(0.42, 0.42, 0.07), C["claro"])


# receita da forja: id -> (função, quadros, largura, altura)
ABY = {
    "impacto": (fx_impacto, 16, 256, 256),
    "garra": (fx_garra, 16, 256, 256),
    "respingo": (fx_respingo, 16, 256, 256),
    "coluna": (fx_coluna, 16, 192, 384),
    "projetil": (fx_projetil, 8, 160, 160),
    "gota": (fx_gota, 8, 64, 64),
}
FACS = {"aby": (ABY, aby_cores, "ABY")}


def forjar(fac, nome, out_dir):
    tab, cores, F = FACS[fac]
    fn, N, w, h = tab[nome]
    C = cores()
    tira = Image.new("RGBA", (w * N, h), (0, 0, 0, 0))
    quadros = []
    for i in range(N):
        t = i / (N - 1) if N > 1 and nome not in ("projetil", "gota") else i / N
        p = Pincel(w, h, PAL[F], seed=hash((fac, nome)) % 10000 + 1)
        fn(t, p, C)
        q = p.imagem()
        tira.paste(q, (i * w, 0))
        quadros.append(q)
    os.makedirs(out_dir, exist_ok=True)
    tira.save(os.path.join(out_dir, nome + ".png"))
    return quadros


def folha(fac, nomes, quadros_por_nome, destino):
    """folha de revisão: uma linha por efeito, fundo xadrez escuro"""
    tab = FACS[fac][0]
    cw = 120
    linhas = []
    for nm in nomes:
        qs = quadros_por_nome[nm]
        w, h = qs[0].size
        sc = cw / max(w, h)
        linhas.append([q.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS) for q in qs])
    W = max(len(l) for l in linhas) * (cw + 6) + 110
    H = sum(max(q.size[1] for q in l) + 14 for l in linhas) + 10
    bg = Image.new("RGBA", (W, H), (58, 52, 70, 255))
    d = ImageDraw.Draw(bg)
    for x in range(0, W, 16):
        for y in range(0, H, 16):
            if (x // 16 + y // 16) % 2:
                d.rectangle([x, y, x + 15, y + 15], fill=(70, 64, 84, 255))
    y = 6
    for nm, l in zip(nomes, linhas):
        d.text((8, y + 6), nm, fill=(255, 255, 255, 255))
        x = 110
        for q in l:
            bg.alpha_composite(q, (x, y))
            x += cw + 6
        y += max(q.size[1] for q in l) + 14
    bg.convert("RGB").save(destino)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dest = None
    if "--folha" in sys.argv:
        dest = sys.argv[sys.argv.index("--folha") + 1]
        if dest in args:
            args.remove(dest)
    fac = args[0] if args else "aby"
    nomes = args[1:] or list(FACS[fac][0].keys())
    out = os.path.join(ROOT, "vfx", fac)
    qs = {}
    for nm in nomes:
        qs[nm] = forjar(fac, nm, out)
        print("forjado", fac, nm)
    if dest:
        folha(fac, nomes, qs, dest)
