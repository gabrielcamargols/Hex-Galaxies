"""Hex Galaxies - FERRAMENTA DE ASSETS DE CENÁRIO (models/cen_<planeta>_<peça>_<n>.glb)

Estilo das referências do jogo: formas robustas e arredondadas, proporção "de brinquedo",
cores quentes e saturadas, aros e rebites, sombreado pintado em 3 tons e contorno preto grosso
(o contorno e o sombreado são feitos pelo shader "pintado" do jogo, scripts/board.gd).

Cada peça é uma função que recebe um gerador aleatório (variações) e devolve uma Mesh.
Para criar uma peça nova: escreva a função, coloque em ASSETS no planeta certo e rode a ferramenta.

  Tarhut (deserto dos 5 sóis)
    rocha       rocha de arenito arredondada, em camadas
    ossada      esqueleto de fera: crânio com presas, coluna, costelas e ossos soltos
    cacto_bola  cacto redondo de gomos com flor rosa
    cacto       cacto de braços sobre um monte de areia
    buraco      cratera de areia com borda rachada (buracos do verme)
    cristal     aglomerado de cristais roxos
  Valak (oceano, posto de mineração)
    barril      barril laranja com aros e rebites
    domo        domo de mineração: painéis, porta, antena parabólica, tanque, guindaste com cesto
    pinheiro    pinheiro de camadas caídas e onduladas
    rocha       rocha cinza arredondada com musgo
    caixa       caixa de carga de madeira com cantoneiras
    vagonete    vagonete de minério sobre trilhos

Uso: python tools/cenario.py [pasta_saida] [planeta]
"""
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glbkit import Mesh, Scene

VARIANTS = 3


def J(rng, a):
    return float(rng.uniform(-a, a))


def rivets(m, r, y, n, col, size=0.05, phase=0.0):
    for i in range(n):
        a = phase + 2 * math.pi * i / n
        m.sphere(size, 6, 4, col, at=(math.cos(a) * r, y, math.sin(a) * r))


def band(m, r, y, h, col, seg=24, out=0.04):
    m.lathe([(r + out * 0.6, y - h / 2), (r + out, y - h / 2 + 0.01), (r + out, y + h / 2 - 0.01), (r + out * 0.6, y + h / 2)], seg, col, cap_top=False, cap_bot=False)


# ======================= TARHUT =======================
def t_rocha(rng):
    m = Mesh()
    cols = ["#a8604a", "#c08060", "#d0a07a", "#985040"]
    y = 0.0
    r = 0.8 + J(rng, 0.1)
    n = int(rng.integers(3, 5))
    for i in range(n):
        h = 0.32 + J(rng, 0.06)
        prof = [(r * 0.96, y), (r, y + 0.04), (r * 1.02, y + h * 0.5), (r * 0.94, y + h - 0.03), (r * 0.85, y + h)]
        m.lathe(prof, 18, cols[i % 4], rmod=lambda a, k, s=rng.uniform(0, 6): 1 + 0.07 * math.sin(3 * a + s) + 0.04 * math.sin(5 * a), at=(J(rng, 0.06), 0, J(rng, 0.06)))
        y += h
        r *= 0.86 + J(rng, 0.04)
    m.blob(r * 1.05, "#d8b48a", seg=14, rings=7, bump=0.12, seed=int(rng.integers(1e6)), at=(0, y, 0), scale=(1, 0.45, 1))
    return m


def t_ossada(rng):
    m = Mesh()
    bone, dark = "#f2e8d2", "#b8a07a"
    L = 4 + int(rng.integers(0, 2))
    # coluna (vértebras arredondadas, caindo para a cauda)
    for i in range(L + 3):
        x = -0.3 + i * 0.32
        y = 0.18 + 0.12 * math.sin(i * 0.5) - 0.02 * i
        m.sphere(0.16 - i * 0.008, 10, 7, bone, at=(x, y, 0), scale=(1.1, 0.9, 1.0))
    # costelas (arcos)
    for i in range(L):
        x = 0.05 + i * 0.32
        for side in (-1, 1):
            for k in range(5):
                a = k / 4 * 1.4
                m.sphere(0.075, 8, 5, bone, at=(x, 0.22 - math.sin(a) * 0.22, side * (0.12 + math.sin(a) * 0.32 + k * 0.03)), scale=(0.9, 1.3, 1.0))
    # crânio com focinho, órbita e presas
    m.sphere(0.36, 14, 10, bone, at=(-0.62, 0.26, 0), scale=(1.15, 0.85, 0.9))
    m.sphere(0.2, 12, 8, bone, at=(-0.98, 0.16, 0), scale=(1.3, 0.75, 0.85))
    m.sphere(0.11, 10, 6, "#7a3a14", at=(-0.66, 0.32, 0.26), scale=(1.0, 0.9, 0.5))
    m.sphere(0.11, 10, 6, "#7a3a14", at=(-0.66, 0.32, -0.26), scale=(1.0, 0.9, 0.5))
    for side in (-1, 1):
        m.cylinder(0.05, 0, 0.22, 8, "#fff0c8", at=(-1.08, 0.12, side * 0.1), rot=(math.pi, 0, 0))
        m.cylinder(0.06, 0, 0.2, 8, bone, at=(-0.5, 0.52, side * 0.18), rot=(side * 0.4, 0, 0.3))   # chifres
    # ossos soltos e pedrinhas
    for k in range(2):
        x, z = 0.4 + J(rng, 0.6), (0.7 if k else -0.7) + J(rng, 0.1)
        a = rng.uniform(0, 3.14)
        m.cylinder(0.05, 0.05, 0.42, 8, bone, at=(x, 0.06, z), rot=(0, a, math.pi / 2))
        for e in (-0.21, 0.21):
            m.sphere(0.07, 8, 5, bone, at=(x + math.cos(a) * e, 0.06, z - math.sin(a) * e))
    for k in range(4):
        m.blob(0.07 + rng.random() * 0.05, dark, seg=8, rings=5, bump=0.2, seed=int(rng.integers(1e6)), at=(J(rng, 1.3), 0.03, J(rng, 0.9)))
    return m


def t_cacto_bola(rng):
    m = Mesh()
    r = 0.55 + J(rng, 0.08)
    ribs = int(rng.integers(8, 11))
    prof = [(r * math.sin(t), r * (1 - math.cos(t)) * 0.95) for t in np.linspace(0.15, math.pi * 0.98, 12)]
    prof = [(0.25 * r, 0.0)] + prof
    m.lathe(prof, 40, "#3f9a6a", rmod=lambda a, k: 1 + 0.06 * math.cos(ribs * a))
    for i in range(14):
        a = 2 * math.pi * (i % ribs) / ribs
        t = rng.uniform(0.6, 2.4)
        m.cylinder(0.03, 0, 0.12, 6, "#f4d48a", at=(math.cos(a) * math.sin(t) * r * 1.04, r * (1 - math.cos(t)) * 0.95, math.sin(a) * math.sin(t) * r * 1.04),
                   rot=(0, -a, -(math.pi / 2 - (t - math.pi / 2)) + 0.0))
    flower(m, (r * 0.35, r * 1.85, r * 0.25), 0.22)
    return m


def flower(m, at, s):
    x, y, z = at
    for i in range(7):
        a = 2 * math.pi * i / 7
        m.sphere(s * 0.45, 8, 4, "#ff6aa8", at=(x + math.cos(a) * s * 0.55, y, z + math.sin(a) * s * 0.55), scale=(1.0, 0.35, 0.6), rot=(0, -a, 0))
    m.sphere(s * 0.28, 8, 5, "#ffd23a", at=(x, y + s * 0.08, z))


def t_cacto(rng):
    m = Mesh()
    g = "#3a8a6a"
    h = 1.3 + J(rng, 0.2)
    m.blob(0.55, "#e8b468", seg=14, rings=6, bump=0.15, seed=int(rng.integers(1e6)), at=(0, 0, 0), scale=(1.2, 0.35, 1.0))
    body = [(0.3, 0.05), (0.34, 0.3), (0.35, h * 0.7), (0.3, h * 0.9), (0.18, h), (0.0, h + 0.04)]
    m.lathe(body, 28, g, rmod=lambda a, k: 1 + 0.07 * math.cos(8 * a))
    for side, yb, hl in ((-1, h * 0.35, 0.55), (1, h * 0.5, 0.45)):
        if rng.random() < 0.9:
            m.cylinder(0.14, 0.15, 0.32, 14, g, at=(side * 0.25, yb, 0), rot=(0, 0, side * -1.3))
            arm = [(0.16, 0), (0.17, hl * 0.7), (0.12, hl), (0.0, hl + 0.03)]
            m.lathe(arm, 20, g, rmod=lambda a, k: 1 + 0.07 * math.cos(6 * a), at=(side * 0.52, yb + 0.06, 0))
    for i in range(18):
        a = rng.uniform(0, 6.28)
        y = rng.uniform(0.2, h * 0.9)
        m.cylinder(0.025, 0, 0.09, 5, "#f4e0a8", at=(math.cos(a) * 0.36, y, math.sin(a) * 0.36), rot=(0, -a, -math.pi / 2))
    flower(m, (-0.52, h * 0.35 + 0.65, 0.05), 0.2)
    return m


def t_buraco(rng):
    m = Mesh()
    ring = [(1.0, 0.0), (1.08, 0.12), (1.0, 0.32), (0.86, 0.38), (0.72, 0.3), (0.62, 0.12), (0.5, -0.2), (0.36, -0.5)]
    m.lathe(ring, 32, "#f0a848", rmod=lambda a, k, s=rng.uniform(0, 6): 1 + (0.08 * math.sin(3 * a + s) + 0.04 * math.sin(7 * a) if k < 5 else 0.0),
            ymod=lambda a, k, s=rng.uniform(0, 6): (0.08 * math.sin(4 * a + s) if 1 <= k <= 3 else 0.0), cap_top=False, cap_bot=False)
    m.lathe([(0.36, -0.5), (0.0, -0.52)], 24, "#2a0c06", cap_top=False, cap_bot=False)    # fundo escuro
    m.lathe([(0.62, 0.12), (0.5, -0.2), (0.36, -0.5)], 32, "#8a3a18", cap_top=False, cap_bot=False, scale=(0.995, 1, 0.995))
    for k in range(8):
        a = rng.uniform(0, 6.28)
        d = rng.uniform(1.1, 1.35)
        m.blob(0.06 + rng.random() * 0.07, "#e89a40", seg=8, rings=5, bump=0.2, seed=int(rng.integers(1e6)), at=(math.cos(a) * d, 0.03, math.sin(a) * d))
    return m


def t_cristal(rng):
    m = Mesh()
    cols = ["#a35cf0", "#c98aff", "#7a3ad0"]
    n = int(rng.integers(4, 7))
    for i in range(n):
        a = rng.uniform(0, 6.28)
        d = 0.0 if i == 0 else rng.uniform(0.15, 0.4)
        h = 1.4 if i == 0 else rng.uniform(0.45, 0.95)
        m.crystal(0.13 + h * 0.06, h, cols[i % 3], sides=6, at=(math.cos(a) * d, 0, math.sin(a) * d), rot=(J(rng, 0.45) if i else 0, a, J(rng, 0.45) if i else 0))
    m.blob(0.5, "#b4703e", seg=12, rings=6, bump=0.15, seed=int(rng.integers(1e6)), scale=(1.1, 0.35, 1.0))
    return m


# ======================= VALAK =======================
def v_barril(rng):
    m = Mesh()
    h = 1.3
    r = 0.5
    prof = [(r * 0.92, 0.0), (r, 0.06), (r * 1.05, h * 0.5), (r, h - 0.06), (r * 0.92, h)]
    body = "#f07a1a" if rng.random() < 0.7 else "#d84a2a"
    m.lathe(prof, 28, body, cap_top=False)
    m.lathe([(r * 0.82, h - 0.02), (0.0, h - 0.04)], 28, "#e86a14", cap_top=False, cap_bot=False)   # tampa
    rim = "#d8a070"
    m.torus(r * 0.9, 0.06, 28, 8, rim, at=(0, h, 0))
    m.torus(r * 0.9, 0.06, 28, 8, rim, at=(0, 0.02, 0))
    for y in (h * 0.3, h * 0.68):
        band(m, r * 1.03, y, 0.13, rim, 28, out=0.035)
        rivets(m, r * 1.1, y, 8, "#f0c890", 0.04, phase=rng.uniform(0, 1))
    # tampa com bocal
    m.cylinder(0.11, 0.11, 0.08, 8, rim, at=(r * 0.45, h, -r * 0.2))
    m.cylinder(0.06, 0.06, 0.09, 8, "#5a3018", at=(r * 0.45, h + 0.005, -r * 0.2))
    return m


def v_domo(rng):
    m = Mesh()
    yel, cop, stone = "#f0b830", "#c0602a", "#b8a890"
    # base de pedra
    m.lathe([(1.25, 0), (1.3, 0.12), (1.22, 0.22), (1.12, 0.24)], 10, stone)
    # domo de painéis
    prof = [(1.1 * math.cos(t), 0.22 + 1.0 * math.sin(t)) for t in np.linspace(0, math.pi / 2 * 0.92, 10)]
    m.lathe(prof, 24, yel, cap_top=True, cap_bot=False)
    for i in range(8):                      # nervuras com rebites
        a = 2 * math.pi * i / 8
        for t in np.linspace(0.15, 1.2, 5):
            m.sphere(0.035, 6, 4, "#d8b890", at=(math.cos(a) * 1.11 * math.cos(t), 0.22 + 1.01 * math.sin(t), math.sin(a) * 1.11 * math.cos(t)))
    m.cylinder(0.32, 0.26, 0.22, 14, cop, at=(0, 1.15, 0))
    rivets(m, 0.31, 1.25, 8, "#e0b890", 0.03)
    # antena parabólica
    m.cylinder(0.04, 0.04, 0.3, 8, "#7a5a40", at=(0, 1.35, 0))
    m.lathe([(0.0, 0.0), (0.12, 0.02), (0.22, 0.09), (0.26, 0.16)], 16, "#e8d8b8", at=(0, 1.62, 0), rot=(0.6, 0.4, 0), cap_top=False, cap_bot=False)
    m.sphere(0.05, 8, 5, "#ffb020", at=(0.06, 1.85, 0.12))
    # porta com moldura e rampa
    m.box(0.55, 0.62, 0.3, cop, at=(0, 0.52, 1.0))
    m.box(0.36, 0.48, 0.32, "#3a1a0c", at=(0, 0.47, 1.02))
    m.box(0.5, 0.06, 0.6, "#a85a30", at=(0, 0.12, 1.4), rot=(-0.25, 0, 0))
    # janelas acesas
    for a in (0.8, -0.8, 2.5):
        m.box(0.32, 0.18, 0.06, "#ffd84a", at=(math.sin(a) * 1.03, 0.55, math.cos(a) * 1.03), rot=(0, a, 0))
    # tanque ao lado com cano
    tx = 1.35 if rng.random() < 0.5 else -1.35
    m.lathe([(0.32, 0), (0.34, 0.9), (0.28, 1.05), (0.0, 1.12)], 16, yel, at=(tx, 0.35, -0.4))
    for k in range(3):
        m.cylinder(0.035, 0.035, 0.4, 6, cop, at=(tx + (-0.2 + 0.2 * k), 0.0, -0.4 + (0.2 if k == 1 else -0.15)))
    band(m, 0.34, 0.75, 0.1, cop, 16)
    m.torus(0.25, 0.07, 12, 6, cop, at=((tx * 0.6), 1.0, -0.3), rot=(math.pi / 2, 0, 0.0), scale=(1, 1, 1))
    # guindaste com cesto de minério
    gx = -tx * 0.95
    m.box(0.14, 1.5, 0.14, cop, at=(gx, 0.75, -0.6), rot=(0, 0, 0.12 * (1 if gx > 0 else -1)))
    m.box(0.9, 0.12, 0.12, cop, at=(gx + (0.35 if gx > 0 else -0.35), 1.48, -0.6))
    m.cylinder(0.14, 0.14, 0.08, 12, "#7a4020", at=(gx, 1.5, -0.55), rot=(math.pi / 2, 0, 0))
    cx = gx + (0.75 if gx > 0 else -0.75)
    m.box(0.02, 0.5, 0.02, "#4a3020", at=(cx, 1.2, -0.6))
    m.box(0.36, 0.22, 0.3, "#c09a70", at=(cx, 0.85, -0.6))
    for k in range(4):
        m.blob(0.07, "#ffb030", seg=8, rings=5, bump=0.15, seed=k, at=(cx + (k % 2 - 0.5) * 0.14, 0.98, -0.6 + (k // 2 - 0.5) * 0.12))
    return m


def v_pinheiro(rng):
    m = Mesh()
    h = 1.9 + J(rng, 0.3)
    m.lathe([(0.2, 0), (0.15, 0.25), (0.13, h * 0.4)], 12, "#a85a28")
    tiers = 4
    for k in range(tiers):
        y0 = h * (0.18 + 0.2 * k)
        r = 0.85 - 0.17 * k
        th = h * 0.3
        lobes = 7 - k // 2
        prof = [(r, y0), (r * 0.8, y0 + th * 0.18), (r * 0.45, y0 + th * 0.65), (0.0, y0 + th)]
        g = ["#3e9a4a", "#4fae4a", "#62bf48", "#7acc48"][k]
        m.lathe(prof, 28, g, rmod=lambda a, kk, L=lobes, s=k * 0.7: 1 + (0.13 * math.cos(L * a + s) if kk == 0 else 0.05 * math.cos(L * a + s)),
                ymod=lambda a, kk, L=lobes, s=k * 0.7: (-0.1 * max(0.0, math.cos(L * a + s)) if kk == 0 else 0.0), cap_bot=True)
    return m


def v_rocha(rng):
    m = Mesh()
    m.blob(0.75, "#9aa0a8", seg=16, rings=10, bump=0.2, seed=int(rng.integers(1e6)), at=(0, 0.3, 0), scale=(1.1, 0.75, 0.95))
    if rng.random() < 0.8:
        m.blob(0.42, "#868c96", seg=12, rings=8, bump=0.2, seed=int(rng.integers(1e6)), at=(0.62, 0.15, 0.3), scale=(1, 0.8, 1))
    for k in range(3):   # musgo em manchas
        a = rng.uniform(0, 6.28)
        m.blob(0.26 + rng.random() * 0.1, "#4f9a3e", seg=10, rings=5, bump=0.25, seed=int(rng.integers(1e6)), at=(math.cos(a) * 0.3, 0.74 - k * 0.04, math.sin(a) * 0.25), scale=(1.2, 0.35, 1.0))
    return m


def v_caixa(rng):
    m = Mesh()
    s = 0.8
    m.box(s, s, s, "#c8803c", at=(0, s / 2, 0))
    for y in (0.08, s - 0.08):
        for z in (-s / 2 - 0.01, s / 2 + 0.01):
            m.box(s * 1.02, 0.1, 0.04, "#a05a28", at=(0, y, z))
        for x in (-s / 2 - 0.01, s / 2 + 0.01):
            m.box(0.04, 0.1, s * 1.02, "#a05a28", at=(x, y, 0))
    for x in (-1, 1):
        for z in (-1, 1):
            m.box(0.12, s * 1.02, 0.12, "#8a8f96", at=(x * s / 2, s / 2, z * s / 2))
    m.box(s * 1.2, 0.08, 0.08, "#a05a28", at=(0, s / 2, s / 2 + 0.02), rot=(0, 0, 0.78))
    if rng.random() < 0.6:
        m.box(0.6, 0.6, 0.6, "#d89048", at=(J(rng, 0.1), s + 0.3, J(rng, 0.1)), rot=(0, rng.uniform(0, 1), 0))
    return m


def v_vagonete(rng):
    m = Mesh()
    for z in (-0.35, 0.35):
        m.box(1.8, 0.06, 0.08, "#8a8f96", at=(0, 0.04, z))
    for x in np.linspace(-0.8, 0.8, 5):
        m.box(0.14, 0.05, 0.95, "#8a5a30", at=(x, 0.0, 0))
    m.lathe([(0.45, 0.25), (0.62, 0.75), (0.6, 0.8)], 4, "#c0602a", rot=(0, math.pi / 4, 0), cap_top=False, scale=(1.1, 1, 0.8))
    for x in (-0.38, 0.38):
        for z in (-0.38, 0.38):
            m.cylinder(0.14, 0.14, 0.08, 12, "#5a5e66", at=(x, 0.18, z + (0.04 if z > 0 else -0.04)), rot=(math.pi / 2, 0, 0))
    for k in range(7):
        m.blob(0.12, "#ffb030" if k % 3 else "#a35cf0", seg=8, rings=5, bump=0.2, seed=k + int(rng.integers(100)), at=(J(rng, 0.35), 0.8, J(rng, 0.25)))
    return m


ASSETS = {
    "tarhut": {"rocha": t_rocha, "ossada": t_ossada, "cacto_bola": t_cacto_bola, "cacto": t_cacto, "buraco": t_buraco, "cristal": t_cristal},
    "valak": {"barril": v_barril, "domo": v_domo, "pinheiro": v_pinheiro, "rocha": v_rocha, "caixa": v_caixa, "vagonete": v_vagonete},
}

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "models"
    only = sys.argv[2] if len(sys.argv) > 2 else None
    os.makedirs(out, exist_ok=True)
    n = 0
    for planet, kinds in ASSETS.items():
        if only and planet != only:
            continue
        for kind, fn in kinds.items():
            for v in range(VARIANTS):
                rng = np.random.default_rng(len(planet) * 1009 + len(kind) * 97 + v * 7919 + sum(map(ord, kind)))
                sc = Scene()
                sc.add(kind, fn(rng), smooth=True, paint=True)
                sc.save(os.path.join(out, "cen_%s_%s_%d.glb" % (planet, kind, v)))
                n += 1
    print("assets:", n)
