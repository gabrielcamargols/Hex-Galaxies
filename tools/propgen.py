"""Hex Galaxies - gerador de cenário 3D por planeta (models/<planeta>_<peça>_<n>.glb).

Estilo do jogo: low-poly facetado, cores chapadas da paleta de cada planeta, contorno escuro (aplicado no jogo).
Cada peça tem variações (semente diferente) para o cenário não se repetir.

  Tarhut (deserto dos 5 sóis):
    arenito   pilares de arenito em camadas (laranja/vermelho), tortos
    cristal   aglomerado de cristais roxos brilhantes
    cacto     cacto alienígena de gomos com flores
    ossos     costelas e crânio de criatura gigante meio enterrados
    destroco  pedaço de nave caída, enferrujado, com aleta
  Valak (oceano, posto de mineração abandonado):
    torre     torre de perfuração enferrujada com treliça
    tanque    tanque cilíndrico com escada e faixa de aviso
    pinheiro  pinheiro de ilha (copa em camadas)
    rocha     rocha cinza com musgo
    guindaste guindaste de carga quebrado

Uso: python tools/propgen.py [pasta_saida]       (gera todas as peças)
     python tools/propgen.py models tarhut          (só um planeta)
O jogo usa automaticamente os arquivos que existirem (scripts/board.gd, _build_scenery/_build_far).
"""
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glbkit import Mesh, Scene

VARIANTS = 3


def jit(rng, a):
    return float(rng.uniform(-a, a))


# ---------------- Tarhut ----------------
def arenito(rng):
    m = Mesh()
    cols = ["#c0583a", "#d8744a", "#e8a060", "#b04a30", "#f0c080"]
    y = 0.0
    r = 0.9 + jit(rng, 0.15)
    layers = int(rng.integers(4, 7))
    x = z = 0.0
    for i in range(layers):
        h = 0.35 + jit(rng, 0.08)
        r2 = r * (0.86 + jit(rng, 0.08))
        m.cylinder(r, r2, h, 7, cols[i % len(cols)], at=(x, y, z), rot=(jit(rng, 0.05), rng.uniform(0, 6.28), jit(rng, 0.05)), jitter=0.03, seed=int(rng.integers(1e6)))
        y += h
        x += jit(rng, 0.08)
        z += jit(rng, 0.08)
        r = r2 * (1.08 if i == layers - 2 else 1.0)
    # chapéu mais largo (rocha erodida pela base)
    m.cylinder(r * 1.25, r * 0.9, 0.3, 7, "#e8a060", at=(x, y, z), jitter=0.04, seed=int(rng.integers(1e6)))
    return m


def cristal(rng):
    m = Mesh()
    cols = ["#a35cf0", "#c98aff", "#7a3ad0"]
    n = int(rng.integers(4, 8))
    for i in range(n):
        a = rng.uniform(0, 6.28)
        d = 0.0 if i == 0 else rng.uniform(0.15, 0.5)
        h = (1.6 if i == 0 else rng.uniform(0.5, 1.1))
        m.crystal(0.14 + h * 0.06, h, cols[i % 3], sides=6, at=(math.cos(a) * d, 0, math.sin(a) * d),
                  rot=(jit(rng, 0.5) if i else 0, a, jit(rng, 0.5) if i else 0))
    m.cylinder(0.65, 0.4, 0.2, 7, "#9a6440", jitter=0.03, seed=3)
    return m


def cacto(rng):
    m = Mesh()
    g = ["#5f9a4a", "#4a7e3a"]
    h = 1.4 + jit(rng, 0.3)
    m.cylinder(0.22, 0.2, h, 8, g[0])
    m.sphere(0.2, 8, 4, g[0], at=(0, h, 0))
    for side in (-1, 1):
        if rng.random() < 0.8:
            y0 = h * rng.uniform(0.35, 0.6)
            m.cylinder(0.12, 0.12, 0.35, 6, g[1], at=(0, y0, 0), rot=(0, 0, side * 1.57))
            m.cylinder(0.12, 0.11, 0.5, 6, g[1], at=(side * 0.35, y0, 0))
            m.sphere(0.11, 6, 3, "#ff6a9a", at=(side * 0.35, y0 + 0.55, 0))
    m.sphere(0.12, 6, 3, "#ff6a9a", at=(0, h + 0.2, 0))
    return m


def ossos(rng):
    m = Mesh()
    bone = ["#e8dcc0", "#d0c09c"]
    n = int(rng.integers(4, 7))
    for i in range(n):
        x = (i - n / 2) * 0.45
        h = 1.4 - abs(i - n / 2) * 0.18 + jit(rng, 0.1)
        # costela curva: 3 pedaços inclinados
        for k in range(3):
            a = 0.35 * k
            m.cylinder(0.09 - k * 0.015, 0.075 - k * 0.015, h * 0.4, 6, bone[k % 2],
                       at=(x, h * 0.36 * k, -math.sin(a) * h * 0.4 * k * 0.6), rot=(-a - 0.15, 0, 0))
    # coluna e crânio meio enterrado
    m.cylinder(0.12, 0.12, n * 0.48, 6, bone[1], at=(-(n / 2) * 0.48, 0.06, 0), rot=(0, 0, -1.57))
    m.sphere(0.45, 7, 4, bone[0], at=((n / 2) * 0.48 + 0.4, 0.15, 0), scale=(1.3, 0.8, 1.0))
    m.sphere(0.1, 5, 3, "#3a2a20", at=((n / 2) * 0.48 + 0.65, 0.32, 0.22))
    m.sphere(0.1, 5, 3, "#3a2a20", at=((n / 2) * 0.48 + 0.65, 0.32, -0.22))
    return m


def destroco(rng):
    m = Mesh()
    rust = ["#8a5a3c", "#6e7a84", "#b07040"]
    m.box(1.8, 0.6, 0.9, rust[1], at=(0, 0.25, 0), rot=(0.12, 0.3, 0.25), jitter=0.05, seed=int(rng.integers(1e6)))
    m.box(0.9, 0.08, 0.7, rust[2], at=(-0.6, 0.8, 0.1), rot=(0.4, 0.3, 0.9))
    m.cylinder(0.25, 0.32, 0.6, 8, rust[0], at=(0.85, 0.3, 0), rot=(0, 0, -1.4))
    m.cylinder(0.2, 0.0, 0.01, 8, "#2a1a10", at=(1.45, 0.33, 0), rot=(0, 0, -1.4))
    m.box(0.12, 0.7, 0.5, "#c84a30", at=(-0.2, 0.8, -0.25), rot=(0.2, 0.3, 0.3))
    return m


# ---------------- Valak ----------------
def torre(rng):
    m = Mesh()
    rust = "#a0582e"
    h = 3.2 + jit(rng, 0.4)
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.cylinder(0.07, 0.06, h, 5, rust, at=(sx * 0.5, 0, sz * 0.5), rot=(sz * 0.08, 0, -sx * 0.08))
    for k in range(5):
        y = h * (0.15 + 0.18 * k)
        w = 1.0 - 0.15 * k
        m.box(w, 0.06, 0.06, "#7a4020", at=(0, y, w / 2))
        m.box(w, 0.06, 0.06, "#7a4020", at=(0, y, -w / 2))
        m.box(0.06, 0.06, w, "#7a4020", at=(w / 2, y, 0))
        m.box(0.06, 0.06, w, "#7a4020", at=(-w / 2, y, 0))
    m.box(0.7, 0.25, 0.7, "#d8b040", at=(0, h, 0))
    m.cylinder(0.1, 0.1, 0.8, 6, "#5a6670", at=(0, h - 0.6, 0))
    if rng.random() < 0.6:
        m.box(0.6, 0.04, 0.3, "#d8b040", at=(0.4, h * 0.55, 0.2), rot=(0, 0.4, 0.7))   # placa caindo
    return m


def tanque(rng):
    m = Mesh()
    r = 0.8 + jit(rng, 0.1)
    h = 1.3 + jit(rng, 0.2)
    m.cylinder(r, r, h, 12, "#8e9aa4", at=(0, 0, 0))
    m.cylinder(r, r * 0.3, 0.35, 12, "#7a8690", at=(0, h, 0))
    m.cylinder(r * 1.01, r * 1.01, 0.18, 12, "#e0b020", at=(0, h * 0.55, 0), cap=False)
    m.cylinder(r * 1.012, r * 1.012, 0.1, 12, "#2a2a2a", at=(0, h * 0.55 + 0.04, 0), cap=False)
    for k in range(7):
        m.box(0.3, 0.04, 0.04, "#a0582e", at=(r + 0.06, 0.15 + k * h / 7, 0))
    m.sphere(0.25, 8, 4, "#a0582e", at=(r * 0.5, h * 0.3, r * 0.8), scale=(1.0, 0.5, 0.4))   # mancha de ferrugem
    return m


def pinheiro(rng):
    m = Mesh()
    h = 1.8 + jit(rng, 0.4)
    m.cylinder(0.12, 0.09, h * 0.35, 6, "#6a4528")
    greens = ["#3e7a3a", "#4f9444", "#2f6230"]
    for k in range(3):
        y = h * (0.25 + 0.22 * k)
        r = 0.75 - 0.18 * k
        m.cylinder(r, 0.0, h * 0.42, 7, greens[k % 3], at=(0, y, 0), rot=(0, rng.uniform(0, 1), 0))
    return m


def rocha(rng):
    m = Mesh()
    m.sphere(0.8, 7, 4, "#8e8a86", scale=(1.0 + jit(rng, 0.2), 0.7, 0.9), at=(0, 0.35, 0), jitter=0.08, seed=int(rng.integers(1e6)))
    m.sphere(0.5, 6, 3, "#a29e98", at=(0.5, 0.25, 0.3), jitter=0.06, seed=int(rng.integers(1e6)))
    m.sphere(0.55, 7, 3, "#5f9a4a", at=(-0.1, 0.72, 0), scale=(1.0, 0.25, 0.8))   # musgo
    return m


def guindaste(rng):
    m = Mesh()
    m.box(0.9, 0.3, 0.9, "#6e7a84", at=(0, 0.15, 0))
    m.box(0.25, 2.4, 0.25, "#d8b040", at=(0, 1.5, 0))
    ang = 0.35 + jit(rng, 0.25)
    L = 2.4
    m.box(L, 0.18, 0.18, "#d8b040", at=(math.cos(ang) * L / 2 - 0.1, 2.6 + math.sin(ang) * L / 2, 0), rot=(0, 0, ang))
    m.box(0.04, 1.2, 0.04, "#2a2a2a", at=(math.cos(ang) * L - 0.1, 2.6 + math.sin(ang) * L - 0.6, 0))
    m.box(0.35, 0.3, 0.35, "#a0582e", at=(math.cos(ang) * L - 0.1, 2.6 + math.sin(ang) * L - 1.3, 0), rot=(0.3, 0.4, 0))
    m.box(0.6, 0.5, 0.5, "#8e9aa4", at=(-0.35, 2.4, 0))
    return m


PLANETS = {
    "tarhut": {"arenito": arenito, "cristal": cristal, "cacto": cacto, "ossos": ossos, "destroco": destroco},
    "valak": {"torre": torre, "tanque": tanque, "pinheiro": pinheiro, "rocha": rocha, "guindaste": guindaste},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "models"
    only = sys.argv[2] if len(sys.argv) > 2 else None
    os.makedirs(out, exist_ok=True)
    n = 0
    for planet, kinds in PLANETS.items():
        if only and planet != only:
            continue
        for kind, fn in kinds.items():
            for v in range(VARIANTS):
                rng = np.random.default_rng(hash((planet, kind, v)) & 0xffffffff if False else (len(planet) * 1000 + len(kind) * 37 + v * 7919))
                sc = Scene()
                sc.add(kind, fn(rng))
                sc.save(os.path.join(out, "%s_%s_%d.glb" % (planet, kind, v)))
                n += 1
    print("modelos:", n)
