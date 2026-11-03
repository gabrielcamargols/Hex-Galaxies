"""Hex Galaxies - gera o Verme Gigante de Tarhut (models/verme_gigante.glb).

O verme é feito de partes separadas para o jogo animar (scripts/worm.gd):
  head            cabeça com a boca (garganta escura, anéis de dentes)
    petal_0..4    5 mandíbulas que abrem e fecham (dobradiça na borda da boca)
  seg_00..seg_17  segmentos do corpo, do pescoço até a cauda (cada um ao longo de +Y)
Tudo no estilo do jogo: cores chapadas, faces facetadas, placas de armadura e espinhos.

Uso: python tools/wormgen.py [saida.glb]
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glbkit import Mesh, Scene

SEGS = 18
ARMOR = ["#8a5a36", "#a06a40", "#7a4c2e"]
BELLY = "#d8a878"
DARK = "#3a2014"
FLESH = "#b0303a"
FLESH2 = "#6e1622"
TOOTH = "#f4ead0"


def seg_radius(i):
    # pescoço grosso, corpo enorme, cauda afinando
    t = i / (SEGS - 1)
    return 1.7 * (1.0 - 0.55 * t ** 1.6)


def segment(i):
    r = seg_radius(i)
    L = r * 0.95
    m = Mesh()
    col = ARMOR[i % 3]
    # corpo: anel facetado (um pouco mais largo no meio)
    m.cylinder(r * 0.86, r, L * 0.5, 10, col, cap=False, at=(0, -L * 0.5, 0))
    m.cylinder(r, r * 0.86, L * 0.5, 10, col, cap=False, at=(0, 0, 0))
    # placa de armadura em volta (borda escura)
    m.torus(r * 0.98, r * 0.12, 12, 5, DARK, at=(0, L * 0.42, 0))
    # barriga clara (lado de baixo)
    m.box(r * 1.1, L * 0.7, r * 0.25, BELLY, at=(0, 0, -r * 0.88))
    # espinhos nas costas
    for k, ang in enumerate((-0.5, 0.0, 0.5)):
        h = r * (0.55 if k == 1 else 0.35)
        m.cylinder(r * 0.16, 0, h, 5, "#e8d4a8" if k == 1 else DARK,
                   at=(math.sin(ang) * r * 0.9, 0, math.cos(ang) * r * 0.9), rot=(math.pi / 2 - 0.25, ang, 0))
    return m


def head():
    r = seg_radius(0) * 1.12
    m = Mesh()
    # pescoço da cabeça
    m.cylinder(r * 0.95, r, r * 0.8, 12, ARMOR[1], cap=False, at=(0, -r * 0.8, 0))
    # borda da boca
    m.torus(r * 0.92, r * 0.16, 14, 5, DARK, at=(0, 0, 0))
    # garganta (funil escuro para dentro)
    m.cylinder(r * 0.85, r * 0.15, r * 1.1, 12, FLESH2, cap=False, at=(0, -r * 1.05, 0))
    m.cylinder(r * 0.2, 0.0, 0.01, 8, "#120408", at=(0, -r * 1.06, 0))
    # anéis de dentes apontando para o centro (3 anéis, cada vez mais fundos)
    for ring, (rr, depth, n, sz) in enumerate(((0.82, 0.05, 16, 0.32), (0.6, -0.35, 12, 0.26), (0.4, -0.7, 9, 0.2))):
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * ring) / n
            x, z = math.cos(a) * r * rr, math.sin(a) * r * rr
            # cone deitado apontando para dentro e um pouco para cima
            m.cylinder(r * 0.07, 0, r * sz, 5, TOOTH, at=(x, depth * r, z), rot=(0, -a, math.pi / 2 - 0.3))
    return m


def petal():
    """mandíbula: placa curva com dentes na face interna; dobradiça na origem, cresce para +Y, face interna em -Z"""
    r = seg_radius(0) * 1.12
    m = Mesh()
    w = r * 0.95
    L = r * 1.6
    # placa externa (armadura) em 2 partes para dar curva
    m.box(w, L * 0.55, r * 0.18, ARMOR[0], at=(0, L * 0.27, r * 0.05))
    m.box(w * 0.75, L * 0.5, r * 0.16, ARMOR[2], at=(0, L * 0.7, r * 0.18), rot=(-0.35, 0, 0))
    m.cylinder(w * 0.18, 0, L * 0.35, 5, DARK, at=(0, L * 0.92, r * 0.3), rot=(-0.4, 0, 0))
    # carne por dentro
    m.box(w * 0.85, L * 0.8, r * 0.06, FLESH, at=(0, L * 0.42, -r * 0.06))
    # fileira de dentes grandes na face interna
    for k in range(4):
        y = L * (0.2 + 0.2 * k)
        for side in (-1, 1):
            m.cylinder(r * 0.07, 0, r * (0.3 + 0.05 * k), 5, TOOTH, at=(side * w * 0.25, y, -r * 0.08), rot=(-math.pi / 2, 0, 0))
    return m


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join("models", "verme_gigante.glb")
    sc = Scene()
    h = sc.add("head", head())
    r = seg_radius(0) * 1.12
    for k in range(5):
        a = 2 * math.pi * k / 5
        # dobradiça na borda da boca; a pétala aponta para cima e a face interna olha para o centro
        sc.add("petal_%d" % k, petal(), at=(math.cos(a) * r * 0.9, 0.0, math.sin(a) * r * 0.9),
               rot=(0, math.pi / 2 - a, 0), parent=h)
    for i in range(SEGS):
        sc.add("seg_%02d" % i, segment(i))
    sc.save(out)
    print("ok", out, "segmentos:", SEGS)
