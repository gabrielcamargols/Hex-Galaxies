"""Hex Galaxies - ícones das táticas no estilo adesivo pop/HQ.
Corpo creme + 1 cor de destaque (2 tons), estilhaços pontudos, rastros de movimento,
contorno preto grosso em volta de tudo.
python3 tools/icones_taticas.py [id ...]  ->  ui/cartas/ic/<id>.png (128x128)
Precisa de rsvg-convert."""
import math, os, random, subprocess, sys, tempfile

OUT = os.path.join(os.path.dirname(__file__), "..", "ui", "cartas", "ic")
INK = "#140a1e"
CREAM = "#fff1da"
CREAM2 = "#f2cfa8"   # sombra do creme
OW = 15              # contorno externo
IW = 4.5             # linhas internas

# destaque: (cor, tom claro, tom escuro)
PINK = ("#f438a9", "#ff8fd0", "#b8217c")
PURP = ("#a957ec", "#d3a6ff", "#6f2fb8")
CYAN = ("#27ddf4", "#a8f6ff", "#138fb8")
YELL = ("#ffd12e", "#fff08a", "#e59a12")
RED = ("#ff4b3e", "#ff9a6e", "#c21f3a")
ORNG = ("#ff742b", "#ffb36b", "#c9461a")
GREN = ("#4fe06a", "#b4ff9a", "#1f9e4a")


class Ic:
    def __init__(self, rot=0):
        self.els = []
        self.rot = rot

    def add(self, tag, outline=True, **a):
        a = {k.replace("_", "-"): v for k, v in a.items()}
        self.els.append((tag, a, outline))

    # formas
    def poly(self, pts, fill, outline=True, sw=IW):
        d = " ".join("%.1f,%.1f" % p for p in pts)
        self.add("polygon", outline, points=d, fill=fill, stroke=INK, stroke_width=sw, stroke_linejoin="round")

    def path(self, d, fill, outline=True, sw=IW, stroke=INK, cap="round"):
        self.add("path", outline, d=d, fill=fill, stroke=stroke, stroke_width=sw, stroke_linejoin="round", stroke_linecap=cap)

    def circ(self, cx, cy, r, fill, outline=True, sw=IW):
        self.add("circle", outline, cx=cx, cy=cy, r=r, fill=fill, stroke=INK, stroke_width=sw)

    def line(self, d, color, w, outline=False):
        """traço sem preenchimento (brilho, risco)"""
        self.add("path", outline, d=d, fill="none", stroke=color, stroke_width=w, stroke_linecap="round", stroke_linejoin="round")

    def svg(self, size=256):
        back, front = [], []
        for tag, a, outline in self.els:
            attrs = " ".join('%s="%s"' % (k, v) for k, v in a.items())
            front.append("<%s %s/>" % (tag, attrs))
            if outline:
                b = dict(a)
                if b.get("fill", "none") != "none":
                    b["fill"] = INK
                b["stroke"] = INK
                b["stroke-width"] = float(a.get("stroke-width", 0)) + OW
                back.append("<%s %s/>" % (tag, " ".join('%s="%s"' % (k, v) for k, v in b.items())))
        g = '<g transform="translate(100 100) scale(0.84) rotate(%s) translate(-100 -100)">%s%s</g>' % (self.rot, "".join(back), "".join(front))
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="-6 -6 212 212">%s</svg>'
                % (size, size, g))


# ---------- geometria ----------
def burst(cx, cy, n, ro, ri, rot=0, seed=1, jit=0.3):
    rng = random.Random(seed)
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180.0 / n + rng.uniform(-8, 8))
        r = (ro if i % 2 == 0 else ri) * (1 + rng.uniform(-jit, jit * 0.6))
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def arrow(x1, y1, x2, y2, w, hw, hl, tail=1.0):
    dx, dy = x2 - x1, y2 - y1
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    px, py = -uy, ux
    bx, by = x2 - ux * hl, y2 - uy * hl
    t = w * tail / 2
    return [(x1 + px * t, y1 + py * t), (bx + px * w / 2, by + py * w / 2), (bx + px * hw / 2, by + py * hw / 2),
            (x2, y2), (bx - px * hw / 2, by - py * hw / 2), (bx - px * w / 2, by - py * w / 2), (x1 - px * t, y1 - py * t)]


def arc_arrow(cx, cy, r, a0, a1, w, hw, hl, steps=24):
    """faixa em arco de a0 até a1 (graus) com ponta de flecha no fim"""
    sgn = 1 if a1 > a0 else -1
    hla = math.degrees(hl / r) * sgn
    end = a1 - hla
    outer, inner = [], []
    for i in range(steps + 1):
        a = math.radians(a0 + (end - a0) * i / steps)
        k = 0.35 + 0.65 * i / steps   # afina no começo, como pincelada
        outer.append((cx + math.cos(a) * (r + w / 2 * k), cy + math.sin(a) * (r + w / 2 * k)))
        inner.append((cx + math.cos(a) * (r - w / 2 * k), cy + math.sin(a) * (r - w / 2 * k)))
    ae = math.radians(end)
    tip = math.radians(a1)
    head = [(cx + math.cos(ae) * (r + hw / 2), cy + math.sin(ae) * (r + hw / 2)),
            (cx + math.cos(tip) * r, cy + math.sin(tip) * r),
            (cx + math.cos(ae) * (r - hw / 2), cy + math.sin(ae) * (r - hw / 2))]
    return outer + head + inner[::-1]


def streak(x, y, ang, length, w):
    """rastro de movimento: triângulo fino"""
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    px, py = -uy, ux
    return [(x + px * w / 2, y + py * w / 2), (x + ux * length, y + uy * length), (x - px * w / 2, y - py * w / 2)]


def hexa(cx, cy, r, rot=30):
    return [(cx + math.cos(math.radians(rot + 60 * i)) * r, cy + math.sin(math.radians(rot + 60 * i)) * r) for i in range(6)]


def shield_path(cx, cy, s):
    return ("M{0},{1} L{2},{3} L{2},{4} C{2},{5} {6},{7} {0},{8} C{9},{7} {10},{5} {10},{4} L{10},{3} Z"
            .format(cx, cy - 50 * s, cx + 42 * s, cy - 36 * s, cy + 2 * s, cy + 30 * s, cx + 20 * s, cy + 46 * s,
                    cy + 56 * s, cx - 20 * s, cx - 42 * s))


def heart_path(cx, cy, s):
    return ("M{0},{1} C{0},{2} {3},{4} {5},{6} C{7},{8} {9},{10} {0},{11} "
            "C{12},{10} {13},{8} {14},{6} C{15},{4} {0},{2} {0},{1} Z").format(
        cx, cy - 22 * s, cy - 52 * s, cx + 52 * s, cy - 52 * s, cx + 52 * s, cy - 16 * s,
        cx + 52 * s, cy + 14 * s, cx + 18 * s, cy + 34 * s, cy + 52 * s,
        cx - 18 * s, cx - 52 * s, cx - 52 * s, cx - 52 * s)


def sparkle(ic, x, y, s, col=CREAM):
    ic.poly([(x, y - s), (x + s * 0.28, y - s * 0.28), (x + s, y), (x + s * 0.28, y + s * 0.28),
             (x, y + s), (x - s * 0.28, y + s * 0.28), (x - s, y), (x - s * 0.28, y - s * 0.28)], col, sw=3)


def plus(ic, x, y, s, col=CREAM):
    t = s * 0.36
    ic.poly([(x - t, y - s), (x + t, y - s), (x + t, y - t), (x + s, y - t), (x + s, y + t), (x + t, y + t),
             (x + t, y + s), (x - t, y + s), (x - t, y + t), (x - s, y + t), (x - s, y - t), (x - t, y - t)], col, sw=3.5)


def zap(ic, pts, col):
    ic.poly(pts, col[0])


# ---------- ícones ----------
def i_flanquear():
    ic = Ic(-6)
    for k, (yy, ln) in enumerate([(72, 60), (100, 76), (128, 54)]):
        ic.poly(streak(112, yy, 180, ln, 12), YELL[k % 2], sw=3)
    ic.poly(hexa(132, 100, 34), CYAN[0])
    ic.poly(hexa(132, 100, 20), CYAN[1], outline=False, sw=0)
    ic.poly(arc_arrow(100, 118, 70, 200, 330, 26, 52, 30), YELL[0])
    ic.line("M48,92 Q70,60 110,52", YELL[1], 6)
    return ic


def i_retirada():
    ic = Ic(4)
    ic.poly(burst(130, 74, 9, 56, 24, seed=3), RED[0])
    ic.poly(burst(130, 74, 9, 32, 14, seed=4), RED[1], outline=False, sw=0)
    ic.poly(arrow(140, 132, 36, 150, 30, 64, 40), CYAN[0])
    ic.line("M120,128 L76,136", CYAN[1], 6)
    for yy in (116, 160):
        ic.poly(streak(160, yy, 0, 30, 10), CREAM, sw=3)
    return ic


def i_troca():
    ic = Ic(-4)
    ic.poly(burst(100, 100, 8, 34, 16, seed=7), YELL[0])
    ic.poly(arc_arrow(100, 100, 60, 200, 340, 28, 56, 32), PINK[0])
    ic.poly(arc_arrow(100, 100, 60, 20, 160, 28, 56, 32), CYAN[0])
    ic.line("M50,74 Q72,46 110,42", PINK[1], 6)
    ic.line("M150,126 Q128,154 90,158", CYAN[1], 6)
    return ic


def i_avanco():
    ic = Ic(-8)
    for x, col in ((40, YELL), (92, ORNG)):
        ic.poly([(x, 46), (x + 34, 46), (x + 78, 100), (x + 34, 154), (x, 154), (x + 44, 100)], col[0])
        ic.poly([(x + 10, 54), (x + 30, 54), (x + 66, 100), (x + 52, 100)], col[1], outline=False, sw=0)
    for yy in (60, 140):
        ic.poly(streak(40, yy, 180, 30, 9), CREAM, sw=3)
    return ic


def i_cobertura():
    ic = Ic(-6)
    ic.poly(burst(150, 64, 8, 40, 16, seed=11), YELL[0])
    ic.path(shield_path(92, 104, 1.12), CYAN[0])
    ic.path(shield_path(92, 104, 0.72), CYAN[1])
    ic.path("M92,54 L92,164", "none", sw=IW)
    ic.poly([(150, 34), (176, 50), (164, 58), (146, 46)], CREAM, sw=4)   # projétil
    ic.poly(streak(150, 40, -150, 46, 8), CREAM, outline=False, sw=0)
    return ic


def i_escudo():
    ic = Ic(5)
    ic.poly(burst(146, 70, 9, 52, 20, seed=13), RED[0])
    ic.path(shield_path(86, 108, 1.12), PURP[0])
    ic.path(shield_path(86, 108, 0.72), PURP[1])
    ic.poly([(118, 76), (176, 18), (186, 28), (128, 86)], CREAM)          # lâmina
    ic.poly([(112, 70), (134, 92), (126, 98), (106, 78)], PURP[2])
    sparkle(ic, 120, 120, 14)
    return ic


def i_dispersao():
    ic = Ic(0)
    ic.poly(burst(100, 104, 10, 44, 20, seed=17), PURP[0])
    ic.circ(100, 104, 18, CREAM)
    for ang, col in ((-90, CYAN), (30, YELL), (150, PINK)):
        a = math.radians(ang)
        ic.poly(arrow(100 + math.cos(a) * 30, 104 + math.sin(a) * 30, 100 + math.cos(a) * 92, 104 + math.sin(a) * 92, 18, 40, 26), col[0])
    return ic


def i_propulsor():
    ic = Ic(-14)
    ic.poly([(88, 128), (112, 128), (124, 186), (100, 160), (78, 188)], ORNG[0])
    ic.poly([(92, 132), (108, 132), (110, 166), (100, 152), (90, 166)], YELL[0], outline=False, sw=0)
    ic.path("M100,14 C130,40 132,80 124,130 L76,130 C68,80 70,40 100,14 Z", CREAM)
    ic.path("M100,22 C118,42 120,76 116,124 L104,124 C108,80 108,46 100,22 Z", CREAM2, outline=False, sw=0)
    ic.circ(100, 70, 15, CYAN[0])
    ic.poly([(76, 96), (52, 132), (78, 128)], PINK[0])
    ic.poly([(124, 96), (148, 132), (122, 128)], PINK[0])
    for x in (60, 140):
        ic.poly(streak(x, 150, 90, 34, 8), YELL[1], sw=3)
    return ic


def i_placas():
    ic = Ic(4)
    ic.path("M50,46 L86,34 Q100,48 114,34 L150,46 L160,96 Q152,150 100,172 Q48,150 40,96 Z", PURP[0])
    ic.path("M62,58 L86,50 Q100,62 114,50 L138,58 L144,96 Q138,136 100,154 Q62,136 56,96 Z", PURP[1])
    ic.path("M100,62 L100,154", "none")
    ic.path("M60,98 L140,98", "none")
    for x, y in ((74, 74), (126, 74), (74, 122), (126, 122)):
        ic.circ(x, y, 6, CREAM, outline=False, sw=3)
    ic.line("M58,64 L64,92", CREAM, 6)
    return ic


def i_lente():
    ic = Ic(-6)
    ic.poly(burst(150, 46, 6, 34, 12, seed=21), CYAN[0])
    ic.poly([(118, 128), (134, 112), (184, 162), (168, 178)], CREAM)
    ic.circ(88, 92, 58, CREAM)
    ic.circ(88, 92, 44, CYAN[0])
    ic.circ(88, 92, 30, CYAN[1], sw=4)
    ic.circ(88, 92, 14, CYAN[2], sw=4)
    ic.line("M60,70 Q70,56 88,52", CREAM, 7)
    return ic


def i_reparo():
    ic = Ic(-10)
    ic.path("M60,36 A30,30 0 1 0 90,92 L150,152 A14,14 0 0 0 170,132 L110,72 A30,30 0 0 0 82,30 L84,54 L72,66 L48,58 A30,30 0 0 0 60,36 Z", CREAM)
    ic.line("M120,90 L160,130", CREAM2, 7)
    plus(ic, 148, 58, 30, GREN[0])
    plus(ic, 148, 58, 14, GREN[1])
    sparkle(ic, 48, 150, 13, YELL[0])
    return ic


def i_dados():
    ic = Ic(-12)
    ic.poly(burst(100, 100, 10, 86, 58, seed=25), PINK[0])
    ic.path("M56,54 Q56,46 64,46 L136,46 Q144,46 144,54 L144,146 Q144,154 136,154 L64,154 Q56,154 56,146 Z", CREAM)
    ic.path("M128,46 L136,46 Q144,46 144,54 L144,146 Q144,154 136,154 L128,154 Z", CREAM2, outline=False, sw=0)
    for x, y in ((78, 70), (100, 100), (122, 130), (122, 70), (78, 130)):
        ic.circ(x, y, 9, INK, outline=False, sw=0)
    return ic


def i_fogo():
    ic = Ic(4)
    ic.path("M100,14 C112,48 156,62 150,118 C146,158 124,184 100,184 C72,184 48,160 50,124 C52,96 66,86 72,64 "
            "C82,82 84,94 90,96 C94,70 88,40 100,14 Z", RED[0])
    ic.path("M104,70 C114,96 140,110 134,140 C130,162 116,172 100,172 C82,172 68,158 70,138 C72,120 82,114 86,100 "
            "C92,112 94,118 98,118 C102,102 98,86 104,70 Z", ORNG[0], outline=False, sw=IW)
    ic.path("M100,120 C110,134 118,142 116,154 C114,166 106,170 100,170 C92,170 84,164 84,154 C84,142 94,136 100,120 Z",
            YELL[0], outline=False, sw=IW)
    return ic


def i_reforco():
    ic = Ic(-4)
    ic.poly(arrow(66, 10, 66, 70, 22, 44, 26), CYAN[0])
    ic.circ(96, 84, 26, CREAM)
    ic.path("M48,176 Q48,120 96,118 Q144,120 144,176 Z", CREAM)
    ic.path("M120,126 Q144,136 144,176 L126,176 Q126,144 112,124 Z", CREAM2, outline=False, sw=0)
    plus(ic, 150, 70, 26, CYAN[0])
    plus(ic, 150, 70, 12, CYAN[1])
    return ic


def i_pulso():
    ic = Ic(0)
    ic.circ(100, 100, 78, "none", sw=IW)
    ic.line("M100,22 A78,78 0 0 1 178,100", PURP[0], 10)
    ic.line("M100,178 A78,78 0 0 1 22,100", PURP[0], 10)
    ic.circ(100, 100, 52, PURP[0])
    ic.circ(100, 100, 52, "none", outline=False)
    ic.poly([(108, 50), (78, 106), (98, 106), (88, 152), (124, 92), (104, 92), (116, 50)], YELL[0])
    ic.line("M66,80 Q72,62 88,56", PURP[1], 6)
    return ic


def i_granada():
    ic = Ic(-10)
    ic.poly(burst(146, 38, 7, 26, 10, seed=31), PINK[0])
    ic.line("M120,62 Q130,44 144,40", "#8a5a3a", 8, outline=True)
    ic.path("M96,58 L126,58 L130,78 L92,78 Z", CREAM2)
    ic.circ(100, 124, 60, CREAM)
    ic.line("M68,130 Q76,164 112,170", PINK[0], 12)
    ic.line("M64,104 Q70,82 88,74", "#ffffff", 7)
    return ic


def i_sinalizador():
    ic = Ic(-4)
    ic.circ(96, 104, 64, RED[0])
    ic.circ(96, 104, 44, CREAM)
    ic.circ(96, 104, 24, RED[0])
    ic.circ(96, 104, 8, CREAM, sw=3)
    for d in ("M96,20 L96,52", "M96,156 L96,188", "M12,104 L44,104", "M148,104 L180,104"):
        ic.path(d, "none", sw=10)
    ic.poly(arrow(178, 24, 108, 92, 14, 34, 26), YELL[0])
    return ic


def i_adrenalina():
    ic = Ic(-36)
    ic.poly(burst(100, 100, 8, 88, 60, rot=10, seed=35), GREN[0])
    ic.path("M84,40 L116,40 L116,140 L84,140 Z", CREAM)
    ic.path("M88,80 L112,80 L112,136 L88,136 Z", GREN[1], outline=False, sw=3)
    ic.path("M76,40 L124,40 L124,30 L76,30 Z", PURP[0])
    ic.path("M96,24 L104,24 L104,10 L96,10 Z", PURP[0])
    ic.path("M76,10 L124,10 L124,2 L76,2 Z", PURP[0])
    ic.poly([(96, 140), (104, 140), (100, 186)], CREAM)
    for y in (60, 80, 100, 120):
        ic.path("M84,%d L98,%d" % (y, y), "none", sw=3.5)
    return ic


def i_barreira():
    ic = Ic(-4)
    ic.poly(burst(100, 96, 10, 92, 62, seed=39), YELL[0])
    rows = [(40, 0), (78, 22), (116, 0)]
    for y, off in rows:
        for x in range(28 + off - (44 if off else 0), 172, 46):
            x0, x1 = max(28, x), min(172, x + 42)
            if x1 - x0 > 12:
                ic.path("M%d,%d L%d,%d L%d,%d L%d,%d Z" % (x0, y, x1, y, x1, y + 34, x0, y + 34), ORNG[0])
                ic.line("M%d,%d L%d,%d" % (x0 + 6, y + 8, x1 - 8, y + 8), ORNG[1], 5)
    ic.path("M28,150 L172,150 L172,166 L28,166 Z", ORNG[2])
    return ic


def i_gancho():
    ic = Ic(-20)
    ic.path("M46,30 L82,30 L82,104 A18,18 0 0 0 118,104 L118,30 L154,30 L154,104 A54,54 0 0 1 46,104 Z", RED[0])
    ic.path("M46,30 L82,30 L82,58 L46,58 Z", CREAM)
    ic.path("M118,30 L154,30 L154,58 L118,58 Z", CREAM)
    ic.line("M60,70 L60,104 Q60,130 80,144", RED[1], 7)
    ic.poly([(64, 4), (78, 20), (70, 22), (86, 38), (60, 18), (68, 16)], CYAN[0], sw=3)
    ic.poly([(136, 4), (122, 20), (130, 22), (114, 38), (140, 18), (132, 16)], CYAN[0], sw=3)
    return ic


def i_camuflagem():
    ic = Ic(-6)
    ic.path("M14,100 Q100,20 186,100 Q100,180 14,100 Z", CREAM)
    ic.circ(100, 100, 38, PURP[0])
    ic.circ(100, 100, 18, INK, outline=False, sw=0)
    ic.circ(88, 88, 7, "#ffffff", outline=False, sw=0)
    ic.poly([(150, 18), (172, 34), (52, 184), (30, 168)], PURP[1])
    ic.line("M156,30 L50,166", PURP[0], 5)
    return ic


def i_onda():
    ic = Ic(0)
    ic.poly(burst(100, 100, 12, 94, 74, seed=43), YELL[0])
    ic.circ(100, 100, 62, "none", outline=False, sw=10)
    ic.add("circle", False, cx=100, cy=100, r=62, fill="none", stroke=ORNG[0], stroke_width=10)
    ic.add("circle", False, cx=100, cy=100, r=42, fill="none", stroke=ORNG[0], stroke_width=8)
    ic.circ(100, 100, 24, CREAM)
    for ang in range(20, 360, 72):
        a = math.radians(ang)
        ic.poly(arrow(100 + math.cos(a) * 28, 100 + math.sin(a) * 28, 100 + math.cos(a) * 58, 100 + math.sin(a) * 58, 8, 20, 14),
                CREAM, outline=False, sw=3)
    return ic


def i_orbital():
    ic = Ic(8)
    ic.poly(burst(100, 150, 11, 64, 26, seed=47), RED[0])
    ic.poly(burst(100, 150, 11, 38, 16, seed=48), YELL[0], outline=False, sw=IW)
    ic.poly([(78, 4), (122, 4), (112, 132), (88, 132)], YELL[1])
    ic.poly([(92, 4), (108, 4), (102, 132), (98, 132)], "#ffffff", outline=False, sw=0)
    ic.circ(152, 34, 18, CREAM)
    ic.add("ellipse", True, cx=152, cy=34, rx=30, ry=8, fill="none", stroke=PURP[0], stroke_width=6)
    return ic


def i_kit():
    ic = Ic(-6)
    ic.path("M76,40 L76,28 Q76,20 84,20 L116,20 Q124,20 124,28 L124,40", "none", sw=10)
    ic.path("M30,52 Q30,40 42,40 L158,40 Q170,40 170,52 L170,150 Q170,162 158,162 L42,162 Q30,162 30,150 Z", CREAM)
    ic.path("M150,40 L158,40 Q170,40 170,52 L170,150 Q170,162 158,162 L150,162 Z", CREAM2, outline=False, sw=0)
    plus(ic, 100, 102, 40, GREN[0])
    plus(ic, 100, 102, 22, GREN[1])
    sparkle(ic, 172, 22, 14, GREN[1])
    return ic


def i_ultimo():
    ic = Ic(6)
    ic.path(heart_path(100, 102, 1.55), RED[0])
    ic.path("M70,70 Q60,80 62,96", "none", outline=False)
    ic.line("M48,76 Q52,56 72,50", RED[1], 8)
    ic.poly([(104, 36), (84, 92), (108, 100), (92, 168), (120, 92), (98, 86), (114, 38)], CREAM)
    ic.poly(burst(160, 40, 6, 22, 9, seed=51), YELL[0])
    return ic


def i_revide():
    ic = Ic(-10)
    ic.poly(burst(132, 70, 9, 68, 30, seed=55), RED[0])
    ic.poly(burst(132, 70, 9, 40, 18, seed=56), YELL[0], outline=False, sw=IW)
    ic.path("M40,110 Q38,74 66,70 L120,70 Q138,72 138,90 Q138,104 124,106 L120,106 Q126,132 108,150 L60,160 Q40,150 40,110 Z", CREAM)
    for x in (66, 84, 102):
        ic.path("M%d,70 L%d,100" % (x, x), "none", sw=IW)
    ic.path("M46,126 Q80,128 100,112", "none", sw=IW)
    ic.path("M52,160 L110,150 L116,190 L58,196 Z", ORNG[0])
    return ic


def i_resgate():
    ic = Ic(0)
    for cx, col in ((58, PINK), (142, CYAN)):
        ic.add("ellipse", True, cx=cx, cy=150, rx=40, ry=14, fill=col[0], stroke=INK, stroke_width=IW)
        ic.add("ellipse", False, cx=cx, cy=150, rx=24, ry=7, fill=col[1], stroke="none", stroke_width=0)
        ic.poly([(cx - 30, 148), (cx - 18, 40), (cx + 18, 40), (cx + 30, 148)], col[1], outline=False, sw=0)
    ic.poly(arc_arrow(100, 104, 52, 200, 330, 20, 42, 26), YELL[0])
    sparkle(ic, 58, 90, 16)
    sparkle(ic, 142, 96, 12)
    return ic


def i_quantica():
    ic = Ic(-16)
    ic.add("ellipse", True, cx=100, cy=100, rx=86, ry=30, fill="none", stroke=PURP[0], stroke_width=10)
    ic.add("ellipse", True, cx=100, cy=100, rx=30, ry=86, fill="none", stroke=PURP[0], stroke_width=10)
    ic.circ(100, 100, 26, CREAM)
    ic.circ(100, 100, 12, PINK[0], sw=3)
    ic.circ(186, 100, 13, CYAN[0])
    ic.circ(100, 14, 13, YELL[0])
    return ic


def i_interceptar():
    ic = Ic(10)
    ic.path("M62,30 L138,30 Q148,30 148,40 L148,150 Q148,160 138,160 L62,160 Q52,160 52,150 L52,40 Q52,30 62,30 Z", CREAM)
    ic.path("M66,44 L134,44 L134,146 L66,146 Z", YELL[0], sw=3.5)
    ic.poly(hexa(100, 95, 22), YELL[2], outline=False, sw=3.5)
    ic.poly(arrow(96, 120, 10, 176, 22, 50, 32), PINK[0])
    ic.line("M80,134 L44,156", PINK[1], 6)
    for yy in (96, 122):
        ic.poly(streak(170, yy, 0, 26, 10), CREAM, sw=3)
    return ic


def i_grito():
    ic = Ic(-10)
    ic.path("M24,82 L66,82 L136,38 L136,166 L66,122 L24,122 Z", ORNG[0])
    ic.path("M24,82 L66,82 L66,122 L24,122 Z", CREAM)
    ic.path("M120,50 L136,38 L136,166 L120,156 Z", ORNG[2], outline=False, sw=0)
    ic.path("M52,122 L76,124 L84,164 L60,166 Z", CREAM)
    for ang, ln in ((-30, 40), (0, 48), (30, 40)):
        a = math.radians(ang)
        ic.poly(streak(150 + math.cos(a) * 4, 102 + math.sin(a) * 30, ang, ln, 14), YELL[0], sw=3.5)
    return ic


def i_evacuacao():
    ic = Ic(-6)
    ic.path(heart_path(84, 110, 1.35), GREN[0])
    ic.path(heart_path(84, 110, 0.8), GREN[1], outline=False, sw=IW)
    ic.poly(arrow(88, 152, 172, 30, 22, 48, 32), GREN[0])
    plus(ic, 24, 168, 12)
    plus(ic, 150, 168, 10)
    plus(ic, 40, 30, 10)
    return ic


def i_execucao():
    ic = Ic(18)
    ic.poly(burst(100, 158, 10, 50, 22, seed=63), RED[0])
    ic.poly(burst(100, 158, 10, 28, 12, seed=64), YELL[0], outline=False, sw=IW)
    ic.poly([(100, 172), (74, 84), (100, 70), (126, 84)], CREAM)
    ic.poly([(100, 172), (100, 70), (126, 84)], CREAM2, outline=False, sw=IW)
    ic.path("M52,62 Q100,78 148,62 L148,80 Q100,96 52,80 Z", PURP[0])
    ic.path("M88,62 L112,62 L112,14 L88,14 Z", PURP[2])
    ic.circ(100, 10, 12, YELL[0])
    ic.line("M94,20 L94,56", PURP[1], 5)
    return ic


def i_contra():
    ic = Ic(-8)
    ic.poly(burst(132, 70, 9, 60, 24, seed=67), ORNG[0])
    ic.path("M40,176 L40,96 Q40,58 80,58 L118,58 L118,26 L176,82 L118,138 L118,106 L88,106 L88,176 Z", RED[0])
    ic.line("M54,166 L54,98 Q54,74 80,72", RED[1], 7)
    return ic


def i_rede():
    ic = Ic(-12)
    ic.poly([(100, 12), (188, 100), (100, 188), (12, 100)], CYAN[2])
    for k in range(1, 5):
        t = k / 5.0
        ic.line("M%.1f,%.1f L%.1f,%.1f" % (100 - 88 * t, 12 + 88 * t, 188 - 88 * t, 100 + 88 * t), CREAM, 7)
        ic.line("M%.1f,%.1f L%.1f,%.1f" % (100 + 88 * t, 12 + 88 * t, 12 + 88 * t, 100 + 88 * t), CREAM, 7)
    for k in range(1, 5):
        for j in range(1, 5):
            x = 100 + 88 * (k / 5.0) - 88 * (j / 5.0)
            y = 12 + 88 * (k / 5.0) + 88 * (j / 5.0)
            ic.circ(x, y, 6, YELL[0], outline=False, sw=3)
    return ic


ICONS = {n[2:]: f for n, f in globals().items() if n.startswith("i_") and callable(f)}


def render(name, dst, size=128):
    svg = ICONS[name]().svg(size * 2)
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as fh:
        fh.write(svg)
        tmp = fh.name
    big = dst + ".tmp.png"
    subprocess.run(["rsvg-convert", "-w", str(size * 2), "-h", str(size * 2), "-o", big, tmp], check=True)
    from PIL import Image
    Image.open(big).convert("RGBA").resize((size, size), Image.LANCZOS).save(dst)
    os.remove(big)
    os.remove(tmp)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or sorted(ICONS)
    for n in names:
        render(n, os.path.join(OUT, n + ".png"))
    print(len(names), "ícones")
