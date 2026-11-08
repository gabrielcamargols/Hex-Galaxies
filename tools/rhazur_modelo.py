"""Hex Galaxies - modelo low poly animado de Rhazur (Abyssais, comandante).
python3 tools/rhazur_modelo.py   ->  models/rhazur.glb

Orca-tubarão de pé, de frente para +Z. Braço esquerdo da arte (-X na cena) é a garra gigante de caranguejo;
o direito (+X) tem a manopla dourada de garras. Trapos roxo/azuis, correntes e medalhões hexagonais dourados.
Cada junta é um nó com nome (pelvis, torso, head, jaw, arm_L, claw_L, pincer_L...), e as animações vão
embutidas no .glb: idle_loop, andar_loop, ataque, dano.
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from glbkit import Mesh, Scene

PI = math.pi
SKIN = "#2b3070"
SKIN2 = "#3c4590"
BELLY = "#f4f1ff"
BELLY2 = "#cfc9ee"
PURPLE = "#7b35c9"
PURPLE_D = "#5a2aa8"
BLUE = "#3a40b8"
BLUE_D = "#2a2f86"
GOLD = "#f2b91e"
GOLD_D = "#b97c12"
CRAB = "#b8398c"
CRAB_L = "#e366a6"
CRAB_D = "#7d2068"
CRAB_IN = "#f4d9e8"
TEETH = "#f7f5ee"
EYE = "#74f0ff"

sc = Scene()
ID = {}


def N(name, mesh=None, at=(0, 0, 0), rot=(0, 0, 0), parent=None, smooth=False):
    ID[name] = sc.add(name, mesh, at=at, rot=rot, parent=None if parent is None else ID[parent], smooth=smooth)
    return ID[name]


def limb(r0, r1, h, col, seg=7, at=(0, 0, 0)):
    """membro pendurado: de y=-h (ponta) até y=0 (junta)"""
    m = Mesh()
    m.cylinder(r1, r0, h, seg, col, at=(at[0], at[1] - h, at[2]))
    return m


# ---------------- raiz e quadril ----------------
N("root")
m = Mesh()
m.box(0.5, 0.26, 0.34, SKIN, at=(0, 0, 0))
m.cylinder(0.075, 0.075, 0.03, 6, GOLD, at=(0, 0.02, 0.17), rot=(PI / 2, 0, 0))
N("pelvis", m, at=(0, 1.05, 0), parent="root", smooth=True)

# ---------------- tronco ----------------
m = Mesh()
m.sphere(0.3, 9, 6, SKIN, at=(0, 0.33, 0), scale=(1.45, 1.05, 0.85))
m.sphere(0.27, 9, 6, BELLY, at=(0, 0.3, 0.13), scale=(1.05, 0.98, 0.62))
m.sphere(0.12, 7, 5, SKIN, at=(0, 0.04, 0), scale=(1.7, 1.0, 1.1))
for i, y in enumerate([0.16, 0.08, 0.0]):
    m.box(0.07 if i < 2 else 0.05, 0.04, 0.03, BELLY2, at=(-0.055, y, 0.19))
    m.box(0.07 if i < 2 else 0.05, 0.04, 0.03, BELLY2, at=(0.055, y, 0.19))
N("torso", m, at=(0, 0.14, 0), parent="pelvis", smooth=True)

# faixa de pano rasgado + correntes + medalhão do peito (peças duras, sem suavizar)
m = Mesh()
m.box(0.17, 0.72, 0.035, BLUE, at=(0.02, 0.33, 0.255), rot=(0, 0, -0.55))
m.box(0.1, 0.18, 0.03, PURPLE, at=(-0.25, 0.62, 0.2), rot=(0.1, 0, -0.5))
m.box(0.09, 0.14, 0.03, PURPLE_D, at=(0.22, 0.12, 0.27), rot=(0.1, 0, -0.5))
m.cylinder(0.075, 0.075, 0.03, 6, GOLD, at=(0.0, 0.33, 0.29), rot=(PI / 2, 0, 0))
for i in range(9):
    t = i / 8.0
    x = -0.27 + 0.52 * t
    y = 0.6 - 0.45 * t
    m.torus(0.04, 0.013, 8, 5, PURPLE if i % 2 == 0 else PURPLE_D, at=(x, y, 0.28 - 0.02 * math.sin(t * PI)), rot=(0, (0 if i % 2 == 0 else PI / 2), -0.6))
N("trapos_peito", m, at=(0, 0, 0), parent="torso")

# ---------------- cabeça de orca-tubarão ----------------
m = Mesh()
m.sphere(0.23, 9, 6, SKIN, at=(0, 0.02, 0.1), scale=(0.98, 0.88, 1.6))
m.sphere(0.09, 7, 5, BELLY, at=(0.12, 0.05, 0.21), scale=(0.5, 0.6, 1.1))
m.sphere(0.09, 7, 5, BELLY, at=(-0.12, 0.05, 0.21), scale=(0.5, 0.6, 1.1))
m.sphere(0.03, 6, 4, EYE, at=(0.13, 0.07, 0.17), scale=(0.6, 0.9, 1.0))
m.sphere(0.03, 6, 4, EYE, at=(-0.13, 0.07, 0.17), scale=(0.6, 0.9, 1.0))
m.sphere(0.05, 6, 4, SKIN2, at=(0, 0.02, 0.4), scale=(1.1, 0.7, 0.9))
for sx in (-1, 1):
    for k in range(4):
        m.cylinder(0.012, 0.0, 0.05, 4, TEETH, at=(sx * (0.045 + 0.012 * k), -0.07, 0.17 + 0.065 * k), rot=(PI, 0, 0))
N("head", m, at=(0, 0.7, 0.05), parent="torso", smooth=True)

m = Mesh()
m.box(0.24, 0.06, 0.34, BELLY, at=(0, -0.03, 0.16))
for sx in (-1, 1):
    for k in range(4):
        m.cylinder(0.012, 0.0, 0.05, 4, TEETH, at=(sx * (0.07 + 0.01 * k), 0.0, 0.07 + 0.065 * k))
N("jaw", m, at=(0, -0.09, 0.06), parent="head", smooth=False)

m = Mesh()
m.cylinder(0.2, 0.01, 0.3, 3, SKIN, at=(0, 0, 0), scale=(0.3, 1.0, 1.25))
m.cylinder(0.2, 0.01, 0.3, 3, PURPLE_D, at=(0, 0.0, -0.012), scale=(0.34, 0.96, 1.1))
N("nadadeira", m, at=(0, 0.14, -0.08), rot=(-1.0, 0, 0), parent="head")
for sx in (-1, 1):
    m = Mesh()
    m.cylinder(0.09, 0.01, 0.2, 3, SKIN, at=(0, 0, 0), scale=(0.3, 1.0, 0.8))
    N("barbatana_%s" % ("L" if sx < 0 else "R"), m, at=(sx * 0.17, -0.02, -0.02), rot=(0, 0, sx * -1.1), parent="head")

# ---------------- braço direito (+X): manopla dourada ----------------
m = Mesh()
m.sphere(0.14, 8, 5, SKIN, at=(0, 0, 0))
m.box(0.2, 0.05, 0.3, PURPLE_D, at=(0.02, 0.1, 0.0), rot=(0, 0, 0.25))
N("ombro_R", m, at=(0.4, 0.5, 0), parent="torso", smooth=True)
N("arm_R", limb(0.1, 0.085, 0.3, SKIN), parent="ombro_R", rot=(0, 0, -0.08), smooth=True)
m = Mesh()
m.box(0.2, 0.28, 0.2, GOLD, at=(0, -0.15, 0))
m.cylinder(0.125, 0.125, 0.04, 6, GOLD_D, at=(0, -0.03, 0))
m.cylinder(0.12, 0.12, 0.04, 6, GOLD_D, at=(0, -0.26, 0))
N("forearm_R", m, at=(0, -0.3, 0), parent="arm_R")
m = Mesh()
m.box(0.15, 0.1, 0.17, GOLD, at=(0, -0.05, 0.02))
for k in range(4):
    x = -0.054 + 0.036 * k
    m.cylinder(0.028, 0.0, 0.2, 5, GOLD, at=(x, -0.09, 0.09), rot=(-1.15 - 0.05 * k, 0, 0))
    m.cylinder(0.014, 0.0, 0.08, 4, GOLD_D, at=(x, -0.2, 0.2), rot=(-1.9, 0, 0))
m.cylinder(0.03, 0.0, 0.14, 5, GOLD, at=(0.085, -0.05, 0.05), rot=(-0.6, 0, -1.0))
N("hand_R", m, at=(0, -0.3, 0), parent="forearm_R")

# ---------------- braço esquerdo (-X): garra de caranguejo ----------------
m = Mesh()
m.sphere(0.17, 8, 5, CRAB, at=(0, 0, 0))
for k in range(4):
    m.sphere(0.035, 5, 3, CRAB_L, at=(-0.1 - 0.02 * k, 0.1 - 0.06 * k, 0.1), scale=(1, 1, 0.8))
N("ombro_L", m, at=(-0.42, 0.5, 0), parent="torso", smooth=True)
m = Mesh()
m.cylinder(0.14, 0.18, 0.3, 8, CRAB, at=(0, -0.3, 0))
for k in range(5):
    a = k * 1.3
    m.sphere(0.035, 5, 3, CRAB_L, at=(math.cos(a) * 0.15, -0.08 - 0.05 * k, math.sin(a) * 0.15))
N("arm_L", m, parent="ombro_L", rot=(-0.22, 0, 0.3), smooth=True)
m = Mesh()
m.sphere(0.25, 9, 6, CRAB, at=(0, -0.2, 0.08), scale=(1.15, 1.0, 1.35))
m.sphere(0.11, 6, 4, CRAB_D, at=(0, -0.05, 0.12), scale=(1.4, 0.8, 1.0))
for k in range(6):
    a = k * 1.05
    m.sphere(0.032, 5, 3, CRAB_L, at=(math.cos(a) * 0.22, -0.2 + math.sin(a) * 0.18, 0.05 + 0.1 * math.sin(k)), scale=(1, 1, 0.8))
# pinça de cima (fixa): lâmina curva com dentes na face de dentro
m.box(0.21, 0.14, 0.4, CRAB, at=(0, -0.1, 0.5), rot=(0.12, 0, 0))
m.cylinder(0.105, 0.0, 0.32, 5, CRAB_L, at=(0, -0.12, 0.7), rot=(PI / 2 + 0.35, 0, 0))
for k in range(4):
    m.cylinder(0.025, 0.0, 0.08, 4, CRAB_IN, at=(0, -0.16, 0.34 + 0.08 * k), rot=(PI, 0, 0))
N("claw_L", m, at=(0, -0.3, 0), parent="arm_L", smooth=True)
m = Mesh()
m.box(0.2, 0.12, 0.38, CRAB_D, at=(0, -0.04, 0.22), rot=(-0.1, 0, 0))
m.cylinder(0.1, 0.0, 0.32, 5, CRAB, at=(0, -0.07, 0.46), rot=(PI / 2 - 0.45, 0, 0))
for k in range(4):
    m.cylinder(0.022, 0.0, 0.07, 4, CRAB_IN, at=(0, 0.01, 0.12 + 0.07 * k))
N("pincer_L", m, at=(0, -0.3, 0.3), parent="claw_L", smooth=True)

# ---------------- pernas ----------------
for sx, S in ((-1, "L"), (1, "R")):
    m = Mesh()
    m.sphere(0.13, 7, 5, SKIN, at=(0, -0.02, 0))
    m.cylinder(0.115, 0.15, 0.42, 7, SKIN, at=(0, -0.44, 0))
    m.box(0.05, 0.3, 0.03, BELLY2, at=(sx * 0.0, -0.22, 0.12))
    N("thigh_" + S, m, at=(sx * 0.18, -0.08, 0), parent="pelvis", smooth=True)
    m = Mesh()
    m.sphere(0.1, 7, 5, SKIN2, at=(0, 0, 0))
    m.cylinder(0.095, 0.115, 0.4, 7, SKIN, at=(0, -0.4, 0))
    N("shin_" + S, m, at=(0, -0.44, 0), parent="thigh_" + S, smooth=True)
    m = Mesh()
    m.box(0.22, 0.1, 0.34, SKIN, at=(0, -0.05, 0.08))
    for k in range(3):
        m.cylinder(0.03, 0.0, 0.1, 4, BELLY, at=((k - 1) * 0.065, -0.05, 0.22), rot=(PI / 2, 0, 0))
    N("foot_" + S, m, at=(0, -0.4, 0), parent="shin_" + S, smooth=False)

# ---------------- saia / trapos ----------------
panels = [("f0", -0.2, 0.19, 0.38, BLUE), ("f1", 0.0, 0.21, 0.5, PURPLE), ("f2", 0.2, 0.19, 0.36, BLUE_D),
          ("l0", -0.29, 0.0, 0.3, PURPLE_D), ("l1", 0.29, 0.0, 0.3, BLUE),
          ("b0", -0.14, -0.19, 0.34, BLUE_D), ("b1", 0.14, -0.19, 0.4, PURPLE_D)]
for nm, x, z, ln, col in panels:
    m = Mesh()
    m.box(0.17, ln, 0.03, col, at=(0, -ln / 2, 0))
    m.box(0.07, 0.12, 0.03, col, at=(-0.03, -ln - 0.05, 0))
    m.box(0.05, 0.08, 0.03, col, at=(0.05, -ln - 0.03, 0))
    rot = (0, math.atan2(x, z) if (abs(x) > 0.2 and abs(z) < 0.05) else 0.0, 0)
    if abs(z) < 0.05:
        rot = (0, PI / 2, 0)
    if z < -0.1:
        rot = (0, PI, 0)
    N("saia_" + nm, m, at=(x, -0.1, z), rot=rot, parent="pelvis")

# ---------------- cauda ----------------
m = Mesh()
m.cylinder(0.17, 0.12, 0.32, 7, SKIN, at=(0, 0, 0), rot=(-PI / 2, 0, 0))
N("tail1", m, at=(0, -0.02, -0.16), rot=(0.25, 0, 0), parent="pelvis", smooth=True)
m = Mesh()
m.cylinder(0.12, 0.08, 0.3, 7, SKIN, at=(0, 0, 0), rot=(-PI / 2, 0, 0))
m.box(0.05, 0.03, 0.2, BELLY, at=(0, -0.06, -0.15))
N("tail2", m, at=(0, 0, -0.3), parent="tail1", smooth=True)
m = Mesh()
m.cylinder(0.08, 0.05, 0.28, 7, SKIN, at=(0, 0, 0), rot=(-PI / 2, 0, 0))
N("tail3", m, at=(0, 0, -0.29), parent="tail2", smooth=True)
for sx, S in ((-1, "L"), (1, "R")):
    m = Mesh()
    m.cylinder(0.3, 0.3, 0.03, 3, SKIN, at=(0, 0, 0), scale=(1.1, 1.0, 1.0))
    m.cylinder(0.2, 0.2, 0.035, 3, BELLY, at=(0, 0.0, 0.0), scale=(1.0, 1.0, 0.9))
    N("fluke_" + S, m, at=(sx * 0.1, 0, -0.26), rot=(0, (PI / 2 if sx > 0 else -PI / 2) + (0.0), 0), parent="tail3")

# ======================================================================
#                              ANIMAÇÕES
# ======================================================================
FPS = 30


def S(t, k=1.0, ph=0.0):
    return math.sin(2 * PI * (t * k + ph))


def C(t, k=1.0, ph=0.0):
    return math.cos(2 * PI * (t * k + ph))


def sample(dur, fn, loop=True):
    """fn(tn) -> valor; devolve [(t, valor)] a 30 fps (o último repete o primeiro nos loops)"""
    n = max(2, int(round(dur * FPS)))
    out = []
    for i in range(n + 1):
        tn = i / n
        out.append((dur * tn, fn(0.0 if (loop and i == n) else tn)))
    return out


def keyed(dur, keys):
    """keys: [(tn, valor)] com suavização (ease) entre eles"""
    def f(tn):
        for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
            if t0 <= tn <= t1:
                u = 0 if t1 == t0 else (tn - t0) / (t1 - t0)
                u = u * u * (3 - 2 * u)
                return tuple(a + (b - a) * u for a, b in zip(v0, v1))
        return keys[-1][1]
    return sample(dur, f, loop=False)


def add3(*vs):
    return tuple(sum(c) for c in zip(*vs))


REST_Y = 1.05
RGB = {"arm_L": (-0.35, 0, 0.12), "arm_R": (0, 0, -0.08)}


# ---------- idle (respira, rabo e garra balançam) ----------
def idle():
    d = 2.4
    T = {}
    T["pelvis"] = {"pos": sample(d, lambda t: (0, REST_Y + 0.014 * S(t), 0))}
    T["torso"] = {"rot": sample(d, lambda t: (0.025 * S(t, 1, 0.1), 0.05 * S(t, 1, 0.3), 0.01 * S(t)))}
    T["head"] = {"rot": sample(d, lambda t: (0.03 * S(t, 1, 0.3), 0.14 * S(t, 1, 0.55), 0))}
    T["jaw"] = {"rot": sample(d, lambda t: (0.07 + 0.05 * S(t, 2, 0.2), 0, 0))}
    T["nadadeira"] = {"rot": sample(d, lambda t: (-1.0 + 0.05 * S(t, 1, 0.2), 0, 0.03 * S(t, 1, 0.6)))}
    T["arm_R"] = {"rot": sample(d, lambda t: (0.06 * S(t, 1, 0.2), 0, -0.1 + 0.03 * S(t, 1, 0.1)))}
    T["forearm_R"] = {"rot": sample(d, lambda t: (-0.35 + 0.06 * S(t, 1, 0.3), 0, 0))}
    T["hand_R"] = {"rot": sample(d, lambda t: (-0.15 + 0.12 * S(t, 2, 0.1), 0, 0))}
    T["arm_L"] = {"rot": sample(d, lambda t: (-0.22 + 0.05 * S(t, 1, 0.25), 0, 0.3 + 0.03 * S(t)))}
    T["claw_L"] = {"rot": sample(d, lambda t: (0.12 * S(t, 1, 0.5), 0, 0))}
    T["pincer_L"] = {"rot": sample(d, lambda t: (0.14 + 0.2 * max(0.0, S(t, 2, 0.0)) ** 2, 0, 0))}
    T["tail1"] = {"rot": sample(d, lambda t: (0.25, 0.16 * S(t, 1, 0.0), 0))}
    T["tail2"] = {"rot": sample(d, lambda t: (0, 0.24 * S(t, 1, -0.12), 0))}
    T["tail3"] = {"rot": sample(d, lambda t: (0, 0.32 * S(t, 1, -0.25), 0))}
    for s_ in ("L", "R"):
        k = 1 if s_ == "L" else -1
        T["fluke_" + s_] = {"rot": sample(d, lambda t, k=k, s_=s_: (0.18 * S(t, 1, -0.4), (PI / 2 if s_ == "R" else -PI / 2), 0))}
    for nm, *_ in panels:
        T["saia_" + nm] = {"rot": sample(d, lambda t, nm=nm: add3(_skirt_rest(nm), (0.05 * S(t, 1, 0.12 * len(nm) + 0.03 * ord(nm[0])), 0, 0.02 * S(t, 1, 0.3))))}
    return d, T


def _skirt_rest(nm):
    for n_, x, z, ln, col in panels:
        if n_ == nm:
            if abs(z) < 0.05:
                return (0, PI / 2, 0)
            if z < -0.1:
                return (0, PI, 0)
            return (0, 0, 0)
    return (0, 0, 0)


# ---------- andar ----------
def andar():
    d = 0.9
    T = {}
    T["pelvis"] = {"pos": sample(d, lambda t: (0, REST_Y - 0.035 * C(t, 2), 0)),
                   "rot": sample(d, lambda t: (0.03, 0.09 * S(t), 0.03 * C(t)))}
    T["torso"] = {"rot": sample(d, lambda t: (0.06, -0.12 * S(t), -0.03 * C(t)))}
    T["head"] = {"rot": sample(d, lambda t: (-0.04, 0.06 * S(t), 0))}
    T["jaw"] = {"rot": sample(d, lambda t: (0.08, 0, 0))}
    T["thigh_L"] = {"rot": sample(d, lambda t: (-0.6 * S(t), 0, 0))}
    T["thigh_R"] = {"rot": sample(d, lambda t: (-0.6 * S(t, 1, 0.5), 0, 0))}
    T["shin_L"] = {"rot": sample(d, lambda t: (0.15 + 0.85 * max(0.0, C(t)), 0, 0))}
    T["shin_R"] = {"rot": sample(d, lambda t: (0.15 + 0.85 * max(0.0, C(t, 1, 0.5)), 0, 0))}
    T["foot_L"] = {"rot": sample(d, lambda t: (0.25 * S(t, 1, 0.15) - 0.1, 0, 0))}
    T["foot_R"] = {"rot": sample(d, lambda t: (0.25 * S(t, 1, 0.65) - 0.1, 0, 0))}
    T["arm_R"] = {"rot": sample(d, lambda t: (-0.5 * S(t), 0, -0.1))}
    T["forearm_R"] = {"rot": sample(d, lambda t: (-0.45 - 0.25 * S(t), 0, 0))}
    T["hand_R"] = {"rot": sample(d, lambda t: (-0.25, 0, 0))}
    T["arm_L"] = {"rot": sample(d, lambda t: (-0.25 + 0.3 * S(t, 1, 0.5), 0, 0.3))}
    T["claw_L"] = {"rot": sample(d, lambda t: (0.1 * C(t, 2), 0, 0))}
    T["pincer_L"] = {"rot": sample(d, lambda t: (0.16 + 0.1 * S(t, 2), 0, 0))}
    T["tail1"] = {"rot": sample(d, lambda t: (0.25, 0.3 * S(t, 1, 0.25), 0))}
    T["tail2"] = {"rot": sample(d, lambda t: (0, 0.38 * S(t, 1, 0.1), 0))}
    T["tail3"] = {"rot": sample(d, lambda t: (0, 0.46 * S(t, 1, -0.05), 0))}
    for s_ in ("L", "R"):
        T["fluke_" + s_] = {"rot": sample(d, lambda t, s_=s_: (0.25 * S(t, 1, -0.2), (PI / 2 if s_ == "R" else -PI / 2), 0))}
    for nm, *_ in panels:
        T["saia_" + nm] = {"rot": sample(d, lambda t, nm=nm: add3(_skirt_rest(nm), (0.16 * S(t, 2, 0.1 * len(nm)) + 0.1, 0, 0.05 * S(t))))}
    return d, T


# ---------- ataque: a garra sobe, desce esmagando e a pinça fecha ----------
def ataque():
    d = 1.1
    K = lambda *ks: keyed(d, list(ks))
    T = {}
    T["pelvis"] = {"pos": K((0, (0, REST_Y, 0)), (0.3, (0, REST_Y - 0.06, -0.06)), (0.5, (0, REST_Y - 0.1, 0.2)), (0.62, (0, REST_Y - 0.08, 0.22)), (1.0, (0, REST_Y, 0)))}
    T["torso"] = {"rot": K((0, (0, 0, 0)), (0.3, (-0.28, -0.2, 0)), (0.5, (0.42, 0.18, 0)), (0.62, (0.4, 0.15, 0)), (1.0, (0, 0, 0)))}
    T["head"] = {"rot": K((0, (0, 0, 0)), (0.3, (-0.1, -0.15, 0)), (0.5, (0.2, 0.1, 0)), (0.62, (0.25, 0.1, 0)), (1.0, (0, 0, 0)))}
    T["jaw"] = {"rot": K((0, (0.07, 0, 0)), (0.3, (0.5, 0, 0)), (0.5, (0.6, 0, 0)), (0.7, (0.1, 0, 0)), (1.0, (0.07, 0, 0)))}
    T["arm_L"] = {"rot": K((0, (-0.22, 0, 0.3)), (0.3, (-2.5, 0, 0.25)), (0.5, (-0.1, 0, 0.05)), (0.62, (0.05, 0, 0.05)), (1.0, (-0.22, 0, 0.3)))}
    T["claw_L"] = {"rot": K((0, (0, 0, 0)), (0.3, (-0.3, 0, 0)), (0.5, (0.35, 0, 0)), (1.0, (0, 0, 0)))}
    T["pincer_L"] = {"rot": K((0, (0.14, 0, 0)), (0.3, (1.0, 0, 0)), (0.48, (1.0, 0, 0)), (0.56, (-0.12, 0, 0)), (0.8, (0.05, 0, 0)), (1.0, (0.14, 0, 0)))}
    T["arm_R"] = {"rot": K((0, (0, 0, -0.1)), (0.3, (0.5, 0, -0.5)), (0.5, (-0.7, 0, -0.2)), (1.0, (0, 0, -0.1)))}
    T["forearm_R"] = {"rot": K((0, (-0.35, 0, 0)), (0.3, (-0.2, 0, 0)), (0.5, (-0.9, 0, 0)), (1.0, (-0.35, 0, 0)))}
    T["thigh_L"] = {"rot": K((0, (0, 0, 0)), (0.3, (0.25, 0, 0)), (0.5, (-0.4, 0, 0)), (1.0, (0, 0, 0)))}
    T["thigh_R"] = {"rot": K((0, (0, 0, 0)), (0.3, (0.35, 0, 0)), (0.5, (0.3, 0, 0)), (1.0, (0, 0, 0)))}
    T["shin_L"] = {"rot": K((0, (0, 0, 0)), (0.3, (0.3, 0, 0)), (0.5, (0.6, 0, 0)), (1.0, (0, 0, 0)))}
    T["shin_R"] = {"rot": K((0, (0, 0, 0)), (0.3, (0.3, 0, 0)), (0.5, (0.3, 0, 0)), (1.0, (0, 0, 0)))}
    T["tail1"] = {"rot": K((0, (0.25, 0, 0)), (0.3, (0.45, -0.2, 0)), (0.5, (0.1, 0.3, 0)), (1.0, (0.25, 0, 0)))}
    T["tail2"] = {"rot": K((0, (0, 0, 0)), (0.3, (0, -0.3, 0)), (0.55, (0, 0.5, 0)), (1.0, (0, 0, 0)))}
    T["tail3"] = {"rot": K((0, (0, 0, 0)), (0.3, (0, -0.4, 0)), (0.6, (0, 0.6, 0)), (1.0, (0, 0, 0)))}
    for nm, *_ in panels:
        r0 = _skirt_rest(nm)
        T["saia_" + nm] = {"rot": K((0, r0), (0.3, add3(r0, (-0.3, 0, 0))), (0.5, add3(r0, (0.5, 0, 0))), (1.0, r0))}
    return d, T


# ---------- dano ----------
def dano():
    d = 0.5
    K = lambda *ks: keyed(d, list(ks))
    T = {}
    T["pelvis"] = {"pos": K((0, (0, REST_Y, 0)), (0.18, (0, REST_Y - 0.03, -0.12)), (1.0, (0, REST_Y, 0)))}
    T["torso"] = {"rot": K((0, (0, 0, 0)), (0.18, (-0.38, 0.1, 0.06)), (1.0, (0, 0, 0)))}
    T["head"] = {"rot": K((0, (0, 0, 0)), (0.18, (-0.5, 0.25, 0)), (1.0, (0, 0, 0)))}
    T["jaw"] = {"rot": K((0, (0.07, 0, 0)), (0.18, (0.7, 0, 0)), (0.6, (0.2, 0, 0)), (1.0, (0.07, 0, 0)))}
    T["arm_R"] = {"rot": K((0, (0, 0, -0.1)), (0.18, (0.3, 0, -0.9)), (1.0, (0, 0, -0.1)))}
    T["arm_L"] = {"rot": K((0, (-0.22, 0, 0.3)), (0.18, (-0.7, 0, 0.5)), (1.0, (-0.22, 0, 0.3)))}
    T["pincer_L"] = {"rot": K((0, (0.14, 0, 0)), (0.18, (0.8, 0, 0)), (1.0, (0.14, 0, 0)))}
    T["tail1"] = {"rot": K((0, (0.25, 0, 0)), (0.18, (0.6, 0.3, 0)), (1.0, (0.25, 0, 0)))}
    T["tail2"] = {"rot": K((0, (0, 0, 0)), (0.2, (0, -0.5, 0)), (1.0, (0, 0, 0)))}
    T["tail3"] = {"rot": K((0, (0, 0, 0)), (0.22, (0, 0.6, 0)), (1.0, (0, 0, 0)))}
    T["thigh_L"] = {"rot": K((0, (0, 0, 0)), (0.18, (0.2, 0, 0)), (1.0, (0, 0, 0)))}
    T["thigh_R"] = {"rot": K((0, (0, 0, 0)), (0.18, (0.2, 0, 0)), (1.0, (0, 0, 0)))}
    T["shin_L"] = {"rot": K((0, (0, 0, 0)), (0.18, (0.3, 0, 0)), (1.0, (0, 0, 0)))}
    T["shin_R"] = {"rot": K((0, (0, 0, 0)), (0.18, (0.3, 0, 0)), (1.0, (0, 0, 0)))}
    return d, T


for name, fn in (("idle_loop", idle), ("andar_loop", andar), ("ataque", ataque), ("dano", dano)):
    d, T = fn()
    sc.animate(name, d, T)

out = os.path.join(os.path.dirname(__file__), "..", "models", "rhazur.glb")
sc.save(out)
print("ok", out, len(sc.nodes), "nós,", len(sc.anims), "animações")
