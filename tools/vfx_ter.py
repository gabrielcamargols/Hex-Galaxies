"""VFX dos VALAKIANOS — receitas em camadas (data/vfx_receitas.json, ids ter_*) e núcleo de cada personagem.
Linguagem: ESTRELA DE IMPACTO de 4 pontas, estouro serrilhado, arcos de golpe com recortes negativos, lascas de pedra,
poeira de HQ e cores chapadas em faixas (contorno escuro -> âmbar -> miolo branco).
Cores: âmbar #FFAC45 (corpo), turquesa #4CD4BD (ajuda/energia), roxo de cristal de Valak, marrom-sombra #493D3D.
AJUDA x ATAQUE (regra do diretor): ajuda é turquesa, sobe, anel que fecha, sem preto e sem tremor; ataque é âmbar,
explode para fora, estilhaços pretos, poeira, tremor.
python3 tools/vfx_ter.py   (precisa das texturas: python3 tools/forja_tex_ter.py)"""
import json, os, sys

sys.path.insert(0, os.path.dirname(__file__))
from forja_guia import aplica, audita_receita   # regras do guia de VFX (valor, tempo, dissipação)

ROOT = os.path.join(os.path.dirname(__file__), "..")
AMB = ["#292C35", "#493D3D", "#FFAC45", "#FFD97A", "#FFF6DC"]
AMB2 = ["#292C35", "#493D3D", "#E6BD85", "#FFD97A", "#FFF6DC"]
TEAL = ["#292C35", "#1F5F5A", "#4CD4BD", "#B8FFDF", "#FFFFFF"]
CRY = ["#1b0f2b", "#4a2d6e", "#a957ec", "#e3c2ff", "#ffffff"]
TERRA = ["#292C35", "#493D3D", "#8A6A4A", "#E6BD85"]
INK = ["#292C35", "#292C35"]
FIRE = ["#292C35", "#7a2e12", "#ff6a1f", "#ffd24a", "#fff6dc"]
ALFA1 = [[0, 1], [1, 1]]


def luz(c, e=4.0, a=4.0, dur=0.3, y=1.0, delay=0.0):
    return {"luz": c, "energia": e, "alcance": a, "dur": dur, "y": y, "delay": delay}


def estrela(size=2.0, ramp=AMB, delay=0.0, life=0.24, y=0.95, nucleo=True, ang=(-12, 12)):
    d = {"p": "estrela4", "blend": "mix", "amount": 1, "size": size, "life": life, "life_rand": 0, "angle": list(ang),
         "curve": [[0, 0.2], [0.18, 1.2], [1, 0.25]], "ramp": ramp, "boost": 1.1, "alpha": ALFA1, "y": y, "delay": delay}
    if nucleo:
        d["nucleo"] = True
    return d


def estouro(size=1.7, ramp=AMB, delay=0.0, life=0.3, y=0.95, tex="estouro", nucleo=True):
    d = {"p": tex, "blend": "mix", "amount": 1, "size": size, "life": life, "life_rand": 0, "angle": [0, 360],
         "curve": [[0, 0.3], [0.2, 1.0], [1, 1.1]], "erode": 1.0, "erode_pow": 1.4, "ramp": ramp, "halftone": 0.25,
         "alpha": ALFA1, "y": y, "delay": delay}
    if nucleo:
        d["nucleo"] = True
    return d


def anel_chao(size=2.8, ramp=AMB, delay=0.0, life=0.5, dentes=True, fecha=False):
    cv = [[0, 1.8], [1, 0.5]] if fecha else [[0, 0.3], [1, 1.9]]
    return {"p": "anel_serra" if dentes else "anel", "mode": "chao", "amount": 1, "size": size, "life": life, "life_rand": 0,
            "y": 0.0, "curve": cv, "erode": 1.0, "erode_pow": 1.1, "halftone": 0.8 if not dentes else 0.0, "dot": 8,
            "ramp": ramp, "alpha": ALFA1 if not fecha else [[0, 0], [0.3, 1], [1, 0]], "delay": delay}


def racha(size=2.4, delay=0.0, ramp=None):
    return {"p": "racha", "mode": "chao", "amount": 1, "size": size, "life": 1.6, "life_rand": 0, "y": 0.0, "angle": [0, 360],
            "curve": [[0, 0.5], [0.08, 1.0], [1, 1.0]], "erode": 1.0, "erode_pow": 3.0, "soft": 0.08,
            "ramp": ramp or ["#292C35", "#493D3D", "#FFAC45", "#FFD97A"], "alpha": ALFA1, "delay": delay}


def faisca(n=22, ramp=None, delay=0.0, y=0.9, speed=(7, 14), size=(0.1, 0.8), life=0.32, spread=180, direc=None, boost=1.5):
    d = {"p": "faisca", "mode": "vel", "amount": n, "size": list(size), "speed": list(speed), "spread": spread, "grav": -12,
         "damp": [5, 9], "life": life, "curve": [[0, 1.3], [1, 0]], "ramp": ramp or ["#FFAC45", "#FFD97A", "#ffffff"],
         "boost": boost, "y": y, "delay": delay}
    if direc:
        d["dir"] = direc
        d["lift"] = 0.15
    return d


def estilhaco(n=9, delay=0.0, y=0.9, speed=(6, 11), size=(0.22, 0.62), ramp=None):
    return {"p": "estilhaco", "blend": "mix", "mode": "vel", "amount": n, "size": list(size), "speed": list(speed), "spread": 180,
            "grav": -14, "damp": [3, 5], "life": 0.45, "erode": 0.9, "ramp": ramp or INK, "alpha": ALFA1, "y": y, "delay": delay}


def lascas(n=8, delay=0.0, y=0.9, ramp=None, speed=(5, 10), size=(0.4, 0.9), direc=None):
    d = {"p": "lasca", "blend": "mix", "mode": "vel", "amount": n, "size": list(size), "speed": list(speed), "spread": 180,
         "grav": -9, "damp": [3, 6], "life": 0.5, "curve": [[0, 1.0], [1, 0.45]], "ramp": ramp or AMB,
         "alpha": [[0, 1], [0.8, 1], [1, 0]], "y": y, "delay": delay}
    if direc:
        d["dir"] = direc
        d["lift"] = 0.3
        d["spread"] = 50
    return d


def pedregulhos(n=8, delay=0.0, y=0.7, ramp=None, size=(0.16, 0.28)):
    return {"p": "pedra", "blend": "mix", "amount": n, "size": list(size), "speed": [5, 10], "dir": [0, 1, 0], "spread": 45,
            "grav": -26, "spin": [-500, 500], "life": 0.55, "ramp": ramp or TERRA + ["#ffffff"],
            "alpha": [[0, 1], [0.85, 1], [1, 0]], "y": y, "delay": delay}


def poeira(n=6, delay=0.0, y=0.25, size=1.3, ramp=None):
    """poeira de HQ: fumaça com retícula em tons de terra, some por erosão e alfa (sem manchas chapadas)"""
    return {"p": "fumaca", "blend": "mix", "amount": max(2, n // 2), "size": size * 0.8, "speed": [0.8, 2.2], "dir": [0, 1, 0], "spread": 80,
            "life": 0.75, "spin": [-30, 30], "curve": [[0, 0.5], [1, 1.25]], "erode": 1.0, "erode_pow": 1.1, "halftone": 0.8,
            "ramp": ramp or ["#292C35", "#493D3D", "#8A6A4A", "#C9A574"], "alpha": [[0, 0.9], [0.5, 0.7], [1, 0]], "y": y, "delay": delay}


def pontos(n=16, ramp=None, delay=0.0, y=0.95, size=0.17):
    c = ramp or "#FFAC45"
    return {"p": "ponto", "blend": "mix", "amount": n, "size": size, "scale": [0.5, 1.5], "speed": [4, 10], "spread": 180,
            "grav": -5, "damp": [3, 6], "life": 0.6, "life_rand": 0.4, "curve": [[0, 1], [0.6, 0.8], [1, 0]],
            "ramp": [c, c], "alpha": ALFA1, "y": y, "delay": delay}


def raios_oco(n=3, delay=0.0, y=0.95):
    return {"p": "raio_oco", "blend": "mix", "amount": n, "size": 0.9, "speed": [3, 7], "spread": 180, "life": 0.2,
            "life_rand": 0.3, "angle": [0, 360], "curve": [[0, 0.8], [1, 1.1]], "ramp": TEAL, "boost": 1.3,
            "alpha": [[0, 1], [0.8, 1], [1, 0]], "y": y, "delay": delay}


def arco(aim_off=-30, size=3.6, ramp=None, delay=0.0, toward=0.4, life=0.3, y=0.95):
    return {"p": "arco_golpe", "blend": "mix", "amount": 1, "size": size, "life": life, "life_rand": 0, "aim": True,
            "aim_off": aim_off, "toward": toward, "y": y, "curve": [[0, 0.5], [0.3, 1.05], [1, 1.15]], "erode": 1.0,
            "erode_pow": 1.2, "halftone": 0.3, "ramp": ramp or AMB, "alpha": ALFA1, "delay": delay}


def objeto(tex, size, life=0.28, aim_off=0.0, toward=0.6, delay=0.0, ramp=None, y=0.95, curve=None, spin=None, aim=True):
    d = {"p": tex, "blend": "mix", "amount": 1, "size": size, "life": life, "life_rand": 0, "toward": toward, "y": y,
         "curve": curve or [[0, 1.5], [0.2, 0.95], [1, 1.0]], "erode": 1.0, "erode_pow": 3.0, "halftone": 0.0,
         "ramp": ramp or AMB, "alpha": ALFA1, "delay": delay}
    if aim:
        d["aim"] = True
        d["aim_off"] = aim_off
    if spin:
        d["spin"] = list(spin)
    return d


def impacto(grande=1.0, ramp=AMB, delay=0.0, y=0.95, chao=True, tremor=0.3, poeira_n=5, cor_pts="#FFAC45", cor_pts2="#4CD4BD"):
    """estrela de impacto + estouro + anel serrilhado + lascas + poeira (o 'golpe' dos Valakianos)"""
    L = [luz("#ffac45", 4.0 * grande, 4.5, 0.3, 1.0, delay),
         estrela(2.4 * grande, ramp, delay, 0.26, y),
         estouro(1.7 * grande, ramp, delay, 0.3, y),
         faisca(int(16 * grande), None, delay, y),
         estilhaco(int(9 * grande), delay, y),
         lascas(int(7 * grande), delay, y),
         pontos(int(14 * grande), cor_pts, delay + 0.02, y),
         pontos(int(9 * grande), cor_pts2, delay + 0.02, y, 0.14)]
    if chao:
        L += [anel_chao(2.8 * grande, ramp, delay, 0.5), racha(2.4 * grande, delay), poeira(poeira_n, delay)]
    return {"layers": L, "shake": tremor, "shake_delay": delay}


def merge(*fx):
    out = {"layers": []}
    for f in fx:
        out["layers"] += f["layers"]
        for k in ("shake", "shake_delay"):
            if k in f:
                out[k] = max(out.get(k, 0), f[k]) if k == "shake" else f[k]
    return out


# ---------------------------------------------------------------- projéteis
def proj_cristal(speed=26, y=1.0, ramp=CRY, arc=0.15):
    return {"speed": speed, "arc": arc, "y": y,
            "arpao": {"tex": "cristal_lanca", "len": 1.7, "width": 0.52, "tile": 1.7, "blend_top": "mix", "ramp": ramp,
                      "boost": 1.0, "halftone": 0.0, "sombra": 1.35, "nucleo": False},
            "parts": [{"p": "faisca", "blend": "mix", "mode": "vel", "trail": True, "amount": 16, "size": [0.08, 0.6], "speed": [1, 3],
                       "spread": 25, "life": 0.22, "ramp": ["#a957ec", "#e3c2ff", "#ffffff"], "alpha": [[0, 1], [1, 0]], "curve": [[0, 1], [1, 0]]},
                      {"p": "poeira", "blend": "mix", "trail": True, "amount": 10, "size": 0.5, "speed": [0.1, 0.5], "spin": [-60, 60],
                       "life": 0.35, "curve": [[0, 0.8], [1, 0.3]], "erode": 1.0, "ramp": ["#1b0f2b", "#4a2d6e", "#a957ec"],
                       "alpha": ALFA1}]}


def proj_objeto(tex, size, speed=13, arc=1.5, spin=420, ramp=AMB, rastro=None):
    parts = [{"p": tex, "blend": "mix", "amount": 1, "one_shot": True, "explosive": 1.0, "life": 2.0, "life_rand": 0, "size": size,
              "spin": [spin, spin], "ramp": ramp, "halftone": 0.1, "alpha": ALFA1},
             {"p": "faisca", "blend": "mix", "mode": "vel", "trail": True, "amount": 14, "size": [0.06, 0.45], "speed": [0.5, 1.5],
              "life": 0.2, "ramp": ["#FFAC45", "#FFD97A", "#ffffff"], "alpha": [[0, 1], [1, 0]], "curve": [[0, 1], [1, 0]]},
             {"p": "poeira", "blend": "mix", "trail": True, "amount": 8, "size": 0.45, "speed": [0.1, 0.5], "life": 0.4,
              "curve": [[0, 0.8], [1, 0.3]], "erode": 1.0, "ramp": rastro or ["#292C35", "#493D3D", "#8A6A4A"], "alpha": ALFA1}]
    return {"speed": speed, "arc": arc, "y": 1.0, "parts": parts}


def proj_orbe(cores, speed=22, arc=0.5, size=0.3):
    return {"speed": speed, "arc": arc, "y": 1.0,
            "parts": [{"p": "estrela4", "blend": "mix", "amount": 2, "size": 0.9, "life": 0.25, "explosive": 0, "spin": [-300, 300],
                       "ramp": cores, "boost": 1.2, "nucleo": True},
                      {"p": "faisca", "blend": "mix", "mode": "vel", "trail": True, "amount": 20, "size": [0.08, 0.5], "speed": [1, 3],
                       "life": 0.25, "ramp": cores[2:] + ["#ffffff"] if len(cores) > 2 else cores, "alpha": [[0, 1], [1, 0]],
                       "curve": [[0, 1], [1, 0]]}],
            "orbe": {"size": size, "ramp": cores, "boost": 1.3},
            "rastro": {"len": 1.6, "width": 0.3, "ramp": cores[1:] + ["#ffffff"], "boost": 1.2}}


# ---------------------------------------------------------------- ajuda (turquesa, sobe, fecha, sem preto, sem tremor)
def ajuda(extra, cor="#4CD4BD", luz_e=2.4, anel_r=TEAL):
    L = [luz(cor, luz_e, 3.8, 1.0, 1.0, 0.1),
         {"p": "anel", "mode": "chao", "amount": 1, "size": 3.0, "life": 0.9, "life_rand": 0, "y": 0.0, "curve": [[0, 1.7], [1, 0.5]],
          "halftone": 0.8, "dot": 8, "ramp": anel_r, "alpha": [[0, 0], [0.3, 1], [1, 0]], "delay": 0.1},
         {"p": "brilho", "mode": "chao", "amount": 1, "size": 2.6, "life": 1.3, "life_rand": 0, "y": 0.0, "curve": [[0, 0.6], [0.3, 1], [1, 1]],
          "halftone": 0.8, "ramp": anel_r, "alpha": [[0, 0], [0.25, 0.8], [1, 0]], "delay": 0.1},
         {"p": "seta", "blend": "mix", "ring": 0.8, "amount": 6, "explosive": 0.3, "dir": [0, 1, 0], "spread": 0, "speed": [1.2, 1.8],
          "life": 1.0, "size": 0.55, "angle": [0, 0], "ramp": anel_r, "boost": 1.3, "alpha": [[0, 0], [0.2, 1], [0.8, 1], [1, 0]],
          "y": 0.3, "delay": 0.2},
         {"p": "estrela4", "blend": "mix", "ring": 0.6, "amount": 8, "explosive": 0.4, "dir": [0, 1, 0], "spread": 6, "speed": [0.8, 1.5],
          "life": 1.2, "size": [0.25, 0.42], "spin": [-90, 90], "ramp": anel_r, "boost": 1.3,
          "alpha": [[0, 0], [0.2, 1], [0.8, 1], [1, 0]], "y": 0.2, "delay": 0.2}]
    return {"layers": L + extra}


def feixe_aliado(ramp=TEAL):
    return {"raio": "raio", "de": "from", "para": "at", "dur": 0.9, "flick": 0.12, "cresce": 0.15, "width": 0.3, "tile": 1.1,
            "blend_top": "mix", "ramp": ["#1F5F5A", "#4CD4BD", "#B8FFDF", "#ffffff"], "boost": 1.0, "halftone": 0.6, "sombra": 1.5, "y": 1.0}


def receitas():
    R = {}
    N = {}

    def add(id_, nome, pers, d, alvo=None, nucleo=None):
        d = dict(d)
        d = {"nome": nome, "personagem": pers, **({"alvo": alvo} if alvo else {}), **d}
        R["ter_" + id_] = d

    # ===== REI DA MINA (comandante, cristal roxo + ouro) =====
    add("rei_cristal", "REI DA MINA · Lança de Cristal (ataque)", "rei_mina",
        {"hit": "ter_rei_cristal_hit", "proj": proj_cristal()})
    add("rei_cristal_hit", "REI DA MINA · Cristal estilhaça (acerto)", "rei_mina",
        merge(impacto(1.15, CRY, cor_pts="#a957ec", cor_pts2="#FFAC45", tremor=0.3),
              {"layers": [{"p": "cristal_ter", "blend": "mix", "amount": 5, "size": [0.4, 0.7], "speed": [5, 9], "dir": [0, 1, 0],
                           "spread": 60, "grav": -16, "spin": [-400, 400], "life": 0.8, "ramp": CRY,
                           "alpha": [[0, 1], [0.85, 1], [1, 0]], "y": 0.8}]}))
    # Manipulação: pedra/cristal arremessado
    add("rei_manip", "REI DA MINA · Manipulação Mineral (move estrutura)", "rei_mina",
        {"alvo": "meio", "layers": [
            luz("#a957ec", 3.0, 4.0, 0.6, 0.6),
            anel_chao(3.2, CRY, 0.0, 0.7, dentes=False, fecha=True),
            {"p": "cristal_ter", "blend": "mix", "amount": 6, "ring": 0.7, "explosive": 0.4, "dir": [0, 1, 0], "spread": 4,
             "speed": [1.8, 3.2], "life": 1.1, "size": [0.5, 0.8], "spin": [-60, 60], "ramp": CRY,
             "alpha": [[0, 0], [0.2, 1], [0.8, 1], [1, 0]], "y": 0.1, "delay": 0.05},
            {"p": "pedra", "blend": "mix", "ring": 0.9, "amount": 7, "explosive": 0.4, "dir": [0, 1, 0], "spread": 4, "speed": [1.4, 2.6],
             "life": 1.1, "size": [0.25, 0.4], "spin": [-120, 120], "ramp": TERRA + ["#ffffff"],
             "alpha": [[0, 0], [0.2, 1], [0.8, 1], [1, 0]], "y": 0.1, "delay": 0.1},
            estrela(1.5, CRY, 0.3, 0.3, 0.9, False),
            pontos(14, "#a957ec", 0.3, 0.5, 0.14)], "shake": 0.15, "shake_delay": 0.3})
    add("rei_barreira", "REI DA MINA · Barreira de Valak (5 cristais)", "rei_mina",
        {"alvo": "meio", "layers": [
            luz("#a957ec", 4.0, 5.0, 0.7, 0.8, 0.0),
            anel_chao(3.4, CRY, 0.0, 0.55),
            racha(2.8, 0.0, ["#1b0f2b", "#4a2d6e", "#a957ec", "#e3c2ff"]),
            {"p": "cristal_ter", "blend": "mix", "amount": 1, "size": 2.3, "life": 0.7, "life_rand": 0, "curve": [[0, 0.05], [0.25, 1.15], [0.4, 1.0], [1, 1.0]],
             "ramp": CRY, "alpha": ALFA1, "angle": [0, 0], "y": 1.0, "base": True},
            estrela(2.2, CRY, 0.05, 0.28, 0.5, False),
            faisca(24, ["#a957ec", "#e3c2ff", "#ffffff"], 0.0, 0.3, (6, 12)),
            estilhaco(8, 0.0, 0.3, ramp=["#1b0f2b", "#4a2d6e"]),
            poeira(5, 0.0), pontos(14, "#FFAC45", 0.02, 0.6)], "shake": 0.35})

    # ===== PERFURADOR (broca) =====
    add("perf_broca", "PERFURADOR · Broca (ataque)", "perfurador",
        {"layers": [objeto("broca", 2.2, 0.26, 0.0, 0.55, 0.0, AMB, 0.9, [[0, 1.6], [0.25, 0.95], [1, 1.0]]),
                    merge(impacto(1.0, AMB, 0.12, 0.9, tremor=0.25))["layers"][0]] + merge(impacto(1.0, AMB, 0.12, 0.9, tremor=0.25))["layers"][1:],
         "shake": 0.25, "shake_delay": 0.12})
    add("perf_furo", "PERFURADOR · Perfuração (entra no subsolo)", "perfurador",
        {"alvo": "self", "layers": [
            anel_chao(2.6, AMB2, 0.0, 0.5), racha(2.2, 0.0),
            {"p": "estrela4", "blend": "mix", "amount": 1, "size": 1.3, "life": 0.25, "curve": [[0, 0.2], [0.2, 1.1], [1, 0.3]],
             "ramp": AMB, "y": 0.4, "boost": 1.1},
            pedregulhos(9, 0.0, 0.2), poeira(8, 0.0, 0.2, 1.5), faisca(16, None, 0.0, 0.3, (4, 9)),
            lascas(6, 0.0, 0.3), pontos(12, "#4CD4BD", 0.02, 0.3)], "shake": 0.3})

    # ===== GOLEM DE BASALTO =====
    add("basalto_soco", "BASALTO · Punho de Pedra (ataque)", "t_basalto",
        {"layers": [objeto("pedra", 2.0, 0.3, 0, 0.5, 0.0, ["#292C35", "#493D3D", "#8A6A4A", "#E6BD85", "#FFF6DC"], 0.95, spin=(-420, -420))]
         + impacto(1.25, AMB, 0.1, 0.9, tremor=0.45)["layers"], "shake": 0.45, "shake_delay": 0.1})
    add("basalto_muralha", "BASALTO · Muralha de Basalto (cria barreira)", "t_basalto",
        {"alvo": "meio", "layers": [
            luz("#ffac45", 3.5, 4.5, 0.6, 0.8),
            anel_chao(3.2, AMB2, 0.0, 0.55), racha(2.6, 0.0),
            {"p": "coluna", "blend": "mix", "amount": 1, "size": 2.6, "life": 0.9, "life_rand": 0, "curve": [[0, 0.05], [0.18, 1.12], [0.3, 1.0], [1, 1.0]],
             "ramp": ["#292C35", "#493D3D", "#8A6A4A", "#E6BD85", "#FFF6DC"], "alpha": ALFA1, "angle": [0, 0], "y": 1.2, "base": True},
            estrela(2.0, AMB, 0.04, 0.26, 0.5, False), pedregulhos(8, 0.0, 0.3), poeira(8, 0.0, 0.2, 1.5),
            faisca(18, None, 0.0, 0.3), estilhaco(6, 0.0, 0.3), pontos(12, "#4CD4BD", 0.02, 0.6)], "shake": 0.4})

    # ===== CARRINHO DE MINÉRIO =====
    add("carrinho_batida", "CARRINHO · Batida de Minério (ataque)", "t_carrinho",
        {"layers": [objeto("dinamite", 0.01, 0.01, aim=False)] and
         [objeto("arco_golpe", 3.0, 0.3, -40, 0.3, 0.0, AMB2, 0.7)] + impacto(1.0, AMB, 0.1, 0.8, tremor=0.35)["layers"] + [
             {"p": "pedra", "blend": "mix", "amount": 7, "size": [0.25, 0.4], "speed": [6, 11], "dir": "away", "lift": 0.4, "spread": 40,
              "grav": -18, "spin": [-500, 500], "life": 0.8, "ramp": CRY, "alpha": [[0, 1], [0.85, 1], [1, 0]], "y": 0.8, "delay": 0.1}],
         "shake": 0.35, "shake_delay": 0.1})
    add("carrinho_carga", "CARRINHO · Carga de Impacto (investida)", "t_carrinho",
        {"hit": "ter_carrinho_carga_hit", "proj": {"speed": 24, "arc": 0.0, "y": 0.5, "parts": [
            {"p": "poeira", "blend": "mix", "trail": True, "amount": 20, "size": 1.0, "speed": [0.3, 1.5], "spin": [-60, 60], "life": 0.55,
             "curve": [[0, 0.8], [1, 0.3]], "erode": 1.0, "halftone": 0.5, "ramp": ["#292C35", "#493D3D", "#8A6A4A", "#E6BD85"], "alpha": ALFA1},
            {"p": "faisca", "blend": "mix", "mode": "vel", "trail": True, "amount": 24, "size": [0.08, 0.7], "speed": [1, 4], "spread": 30,
             "life": 0.25, "ramp": ["#FFAC45", "#FFD97A", "#ffffff"], "alpha": [[0, 1], [1, 0]], "curve": [[0, 1], [1, 0]]}],
            "arpao": {"tex": "arco_golpe", "len": 1.6, "width": 1.1, "tile": 1.6, "blend_top": "mix", "ramp": AMB, "boost": 1.0,
                      "halftone": 0.0, "sombra": 1.2, "nucleo": False}}})
    add("carrinho_carga_hit", "CARRINHO · Carga bate e empurra (acerto)", "t_carrinho",
        impacto(1.2, AMB, 0.0, 0.8, tremor=0.4))

    # ===== BRITADEIRO (marteleta) =====
    brit = {"layers": [], "shake": 0.5, "shake_delay": 0.0}
    for i in range(3):
        dl = i * 0.09
        brit["layers"] += [estrela(1.5 + 0.2 * i, AMB, dl, 0.14, 0.8 + 0.1 * i, False, (-25, 25)),
                           faisca(10, None, dl, 0.7, (8, 14)), pedregulhos(3, dl, 0.5, size=(0.22, 0.34)),
                           {"p": "estouro", "blend": "mix", "amount": 1, "size": 1.0, "life": 0.16, "angle": [0, 360],
                            "curve": [[0, 0.4], [1, 1.0]], "erode": 1.0, "ramp": AMB, "y": 0.8, "delay": dl}]
    brit["layers"] += impacto(1.35, AMB, 0.28, 0.9, tremor=0.55)["layers"]
    add("brit_marteleta", "BRITADEIRO · Triturar (rajada de marteladas)", "t_britadeira", brit)

    # ===== FUNDIDOR =====
    add("fundidor_gota", "FUNDIDOR · Metal Fundido (ataque)", "t_fundidor",
        {"hit": "ter_fundidor_gota_hit", "proj": proj_orbe(FIRE, 18, 1.0, 0.34)})
    add("fundidor_gota_hit", "FUNDIDOR · Respingo de metal (acerto)", "t_fundidor",
        merge(impacto(1.0, FIRE, 0.0, 0.9, tremor=0.25, cor_pts="#ff6a1f", cor_pts2="#ffd24a"),
              {"layers": [{"p": "gota", "blend": "mix", "mode": "vel", "amount": 22, "size": 0.3, "speed": [4, 9], "dir": [0, 1, 0], "spread": 60,
                           "grav": -16, "life": 0.7, "ramp": FIRE, "alpha": [[0, 1], [0.85, 1], [1, 0]], "y": 0.9}]}))
    add("fundidor_reves", "FUNDIDOR · Revestimento Fundido (ajuda: -2 no próximo dano)", "t_fundidor",
        {"alvo": "aliado", "layers": [feixe_aliado()] + ajuda([
            {"p": "hexa", "blend": "mix", "amount": 1, "one_shot": True, "explosive": 1.0, "life": 1.5, "life_rand": 0, "size": 2.2,
             "angle": [0, 0], "curve": [[0, 0.2], [0.15, 1.2], [0.25, 1.0], [1, 1.0]], "ramp": TEAL, "halftone": 0.3,
             "alpha": [[0, 0], [0.1, 0.85], [0.75, 0.85], [1, 0]], "y": 1.0, "delay": 0.25}])["layers"]})

    # ===== DEMOLIDOR DE FENDAS (picareta) =====
    add("fendas_picareta", "FENDAS · Picareta (ataque)", "t_fendas",
        {"layers": [objeto("picareta", 2.3, 0.3, -20, 0.5, 0.0, AMB2, 1.0, [[0, 1.6], [0.2, 0.95], [1, 1.0]], aim=True)]
         + impacto(1.1, AMB, 0.12, 0.9, tremor=0.35)["layers"], "shake": 0.35, "shake_delay": 0.12})
    add("fendas_ruptura", "FENDAS · Ruptura (quebra a barreira e empurra)", "t_fendas",
        {"alvo": "meio", "layers": [luz("#ffac45", 4.5, 4.5, 0.4, 0.8),
                                    racha(3.4, 0.0), racha(2.2, 0.06), anel_chao(3.4, AMB, 0.0, 0.5),
                                    estrela(2.6, AMB, 0.0, 0.28, 0.8), estouro(2.0, AMB, 0.0, 0.32, 0.8),
                                    pedregulhos(12, 0.0, 0.6), lascas(8, 0.0, 0.8), faisca(24, None, 0.0, 0.8), estilhaco(10, 0.0, 0.8),
                                    poeira(8, 0.0, 0.2, 1.6), pontos(14, "#4CD4BD", 0.02, 0.8)], "shake": 0.55})

    # ===== SÍSMICO =====
    add("sismico_pisao", "SÍSMICO · Pisão (ataque)", "sismico",
        {"layers": [objeto("pedra", 1.9, 0.3, 0, 0.5, 0.0, ["#292C35", "#493D3D", "#8A6A4A", "#E6BD85", "#FFF6DC"], 0.95, spin=(420, 420))]
         + impacto(1.2, AMB, 0.1, 0.85, tremor=0.45)["layers"], "shake": 0.45, "shake_delay": 0.1})
    add("sismico_onda", "SÍSMICO · Onda Sísmica (empurra os vizinhos)", "sismico",
        {"alvo": "self", "layers": [luz("#ffac45", 4.0, 5.0, 0.5, 0.4),
                                    anel_chao(2.0, AMB, 0.0, 0.55), anel_chao(3.2, AMB2, 0.1, 0.65), anel_chao(4.6, AMB, 0.22, 0.75),
                                    racha(3.4, 0.0), {"p": "estrela4", "mode": "chao", "amount": 1, "size": 3.4, "life": 0.5, "curve": [[0, 0.2], [0.2, 1.1], [1, 0.9]],
                                                      "erode": 1.0, "ramp": AMB, "y": 0.0, "alpha": ALFA1, "angle": [0, 90]},
                                    pedregulhos(10, 0.0, 0.2), poeira(10, 0.0, 0.2, 1.7), faisca(20, None, 0.0, 0.3, (5, 10)),
                                    estilhaco(7, 0.0, 0.3)], "shake": 0.65})

    # ===== DINAMITADOR =====
    add("dina_lancar", "DINAMITADOR · Dinamite Arremessada (ataque)", "t_dinamite",
        {"hit": "ter_dina_boom", "proj": proj_objeto("dinamite", 1.4, 12, 1.8, 480)})
    add("dina_boom", "DINAMITADOR · Explosão (acerto e carga)", "t_dinamite",
        merge(impacto(1.6, FIRE, 0.0, 0.8, tremor=0.7, cor_pts="#ff6a1f", cor_pts2="#ffd24a"),
              {"layers": [estouro(2.8, FIRE, 0.04, 0.4, 0.8, "estouro_b"), estrela(3.2, FIRE, 0.0, 0.3, 0.8),
                          {"p": "fumaca", "blend": "mix", "amount": 8, "size": 1.4, "speed": [0.8, 2.0], "dir": [0, 1, 0], "spread": 40,
                           "life": 1.0, "spin": [-40, 40], "curve": [[0, 0.5], [1, 1.4]], "erode": 1.0, "halftone": 0.8,
                           "ramp": ["#292C35", "#493D3D", "#7a2e12"], "alpha": [[0, 0.9], [1, 0.9]], "y": 0.4},
                          pedregulhos(10, 0.0, 0.5)]}))
    add("dina_carga", "DINAMITADOR · Carga Temporizada (coloca a carga)", "t_dinamite",
        {"alvo": "meio", "layers": [
            {"p": "dinamite", "blend": "mix", "amount": 1, "one_shot": True, "life": 1.4, "life_rand": 0, "size": 0.9, "dir": [0, -1, 0],
             "spread": 0, "speed": [6, 6], "damp": [10, 10], "y": 2.4, "spin": [-40, -40], "curve": [[0, 1], [0.9, 1], [1, 0]],
             "ramp": AMB, "alpha": ALFA1},
            poeira(5, 0.28, 0.2, 1.1), anel_chao(2.2, AMB2, 0.3, 0.45), pontos(10, "#FFAC45", 0.3, 0.3),
            estrela(1.0, AMB, 0.3, 0.2, 0.3, False)], "shake": 0.12, "shake_delay": 0.28})

    # ===== SENTINELA DE PEDRA =====
    add("sentinela_golpe", "SENTINELA · Golpe de Pedra (ataque)", "t_sentinela",
        {"layers": [arco(-30, 3.4, AMB2, 0.0, 0.4)] + impacto(1.05, AMB, 0.1, 0.9, tremor=0.3)["layers"], "shake": 0.3, "shake_delay": 0.1})
    add("sentinela_guarda", "SENTINELA · Guarda Firme (ela e vizinhos: -1 de dano)", "t_sentinela",
        {"alvo": "self", "layers": ajuda([
            {"p": "hexa", "blend": "mix", "amount": 1, "one_shot": True, "explosive": 1.0, "life": 1.6, "life_rand": 0, "size": 2.8,
             "angle": [0, 0], "curve": [[0, 0.2], [0.15, 1.2], [0.25, 1.0], [1, 1.0]], "ramp": TEAL, "halftone": 0.3,
             "alpha": [[0, 0], [0.1, 0.8], [0.75, 0.8], [1, 0]], "y": 1.0, "delay": 0.15},
            anel_chao(4.2, TEAL, 0.25, 0.9, dentes=False, fecha=True)])["layers"]})

    # ===== LANTERNEIRA =====
    add("lanterna_luz", "LANTERNEIRA · Clarão (ataque)", "t_lanterna",
        {"hit": "ter_lanterna_luz_hit", "proj": proj_orbe(["#7a5a1a", "#FFAC45", "#FFE9A0", "#fffbe8", "#ffffff"], 20, 0.4, 0.26)})
    add("lanterna_luz_hit", "LANTERNEIRA · Clarão estoura (acerto)", "t_lanterna",
        impacto(0.85, ["#292C35", "#7a5a1a", "#FFD97A", "#FFF6DC", "#ffffff"], 0.0, 0.95, tremor=0.15))
    add("lanterna_amparo", "LANTERNEIRA · Luz de Amparo (ajuda: cura 2)", "t_lanterna",
        {"alvo": "aliado", "layers": [feixe_aliado()] + ajuda([
            {"p": "lanterna", "blend": "mix", "amount": 1, "one_shot": True, "explosive": 1.0, "life": 1.5, "life_rand": 0, "size": 1.0,
             "angle": [0, 0], "curve": [[0, 0.2], [0.2, 1.1], [0.3, 1.0], [1, 1.0]], "ramp": ["#292C35", "#7a5a1a", "#FFD97A", "#B8FFDF", "#ffffff"],
             "alpha": [[0, 0], [0.15, 1], [0.8, 1], [1, 0]], "y": 2.7, "delay": 0.15}])["layers"]})

    # ===== GUARDA-RAIZ =====
    add("raiz_chicote", "GUARDA-RAIZ · Chicote de Raiz (ataque)", "t_raiz",
        {"layers": [arco(-30, 3.4, ["#1c2a14", "#3d5a22", "#8bd34a", "#d6ff9a", "#ffffff"], 0.0, 0.4)] + impacto(1.0, AMB, 0.1, 0.9, tremor=0.25,
                                                                                                           cor_pts="#8bd34a")["layers"],
         "shake": 0.25, "shake_delay": 0.1})
    add("raiz_trama", "GUARDA-RAIZ · Trama Protetora (raízes brotam)", "t_raiz",
        {"alvo": "meio", "layers": [luz("#8bd34a", 3.0, 4.0, 0.6, 0.6),
                                    anel_chao(3.0, ["#1c2a14", "#3d5a22", "#8bd34a", "#d6ff9a"], 0.0, 0.6, dentes=False),
                                    {"p": "espeto", "blend": "mix", "mode": "vel", "ring": 0.5, "amount": 12, "explosive": 0.6, "dir": [0, 1, 0],
                                     "spread": 14, "speed": [5, 9], "damp": [4, 8], "life": 0.7, "size": [0.8, 1.5], "curve": [[0, 1], [1, 0.8]],
                                     "ramp": ["#1c2a14", "#3d5a22", "#8bd34a", "#d6ff9a"], "alpha": [[0, 1], [0.8, 1], [1, 0]], "y": 0.1},
                                    poeira(6, 0.0), pontos(14, "#8bd34a", 0.05, 0.4), pontos(8, "#FFAC45", 0.05, 0.4, 0.14)], "shake": 0.15})

    # ===== CARTÓGRAFO =====
    add("cartografo_bussola", "CARTÓGRAFO · Compasso (ataque)", "t_cartografo",
        {"hit": "ter_cartografo_hit", "proj": proj_orbe(["#1F5F5A", "#4CD4BD", "#B8FFDF", "#ffffff"], 22, 0.6, 0.26)})
    add("cartografo_hit", "CARTÓGRAFO · Acerto de compasso", "t_cartografo",
        impacto(0.85, TEAL, 0.0, 0.95, tremor=0.15, cor_pts="#4CD4BD", cor_pts2="#FFAC45"))
    add("cartografo_rota", "CARTÓGRAFO · Rota Traçada (ajuda: +1 Movimento)", "t_cartografo",
        {"alvo": "aliado", "layers": [feixe_aliado()] + ajuda([
            {"p": "seta", "blend": "mix", "amount": 4, "explosive": 0.2, "ring": 0.5, "dir": [1, 0, 0], "spread": 0, "speed": [2.2, 2.8],
             "life": 0.9, "size": 0.7, "angle": [-90, -90], "ramp": TEAL, "boost": 1.3, "alpha": [[0, 0], [0.2, 1], [0.8, 1], [1, 0]],
             "y": 0.4, "delay": 0.25}])["layers"]})

    # ===== SNIPER =====
    add("sniper_tiro", "SNIPER · Tiro de Descarga (ataque)", "t_sniper",
        {"hit": "ter_sniper_hit", "proj": {"speed": 40, "arc": 0.0, "y": 1.0,
                                           "arpao": {"tex": "feixe", "len": 2.4, "width": 0.4, "tile": 2.4, "blend_top": "mix",
                                                     "ramp": ["#1F5F5A", "#4CD4BD", "#B8FFDF", "#ffffff"], "boost": 1.0, "halftone": 0.0, "sombra": 1.3, "nucleo": False},
                                           "parts": [{"p": "faisca", "blend": "mix", "mode": "vel", "trail": True, "amount": 16, "size": [0.06, 0.5], "speed": [1, 3],
                                                      "life": 0.2, "ramp": ["#4CD4BD", "#B8FFDF", "#ffffff"], "alpha": [[0, 1], [1, 0]], "curve": [[0, 1], [1, 0]]}]}})
    add("sniper_hit", "SNIPER · Acerto e carga elétrica", "t_sniper",
        merge(impacto(1.0, TEAL, 0.0, 0.95, tremor=0.2, cor_pts="#4CD4BD", cor_pts2="#FFAC45"),
              {"layers": [raios_oco(4, 0.02), {"raio": "raio", "para": "aleatorio", "n": 3, "raio_len": [0.5, 1.0], "dur": 0.4, "flick": 0.04,
                                                "width": 0.32, "tile": 0.8, "blend_top": "mix", "ramp": ["#1F5F5A", "#4CD4BD", "#B8FFDF", "#ffffff"],
                                                "boost": 1.0, "halftone": 0.5, "sombra": 1.6, "y": 0.95}]}))

    # ===== ENFERMEIRA =====
    add("enfermeira_cristal", "ENFERMEIRA · Estilhaço de Cristal (ataque)", "t_enfermeira",
        {"hit": "ter_enfermeira_cristal_hit", "proj": proj_cristal(22, 1.0, CRY, 0.3)})
    add("enfermeira_cristal_hit", "ENFERMEIRA · Estilhaço (acerto)", "t_enfermeira",
        merge(impacto(0.9, CRY, 0.0, 0.95, tremor=0.2, cor_pts="#a957ec", cor_pts2="#4CD4BD")))
    add("enfermeira_tratamento", "ENFERMEIRA · Tratamento Mineral (ajuda: cura 3/4)", "t_enfermeira",
        {"alvo": "aliado", "layers": [feixe_aliado()] + ajuda([
            {"p": "cristal_ter", "blend": "mix", "ring": 0.5, "amount": 5, "explosive": 0.4, "dir": [0, 1, 0], "spread": 4, "speed": [0.9, 1.5],
             "life": 1.3, "size": [0.35, 0.55], "spin": [-40, 40], "ramp": TEAL, "alpha": [[0, 0], [0.2, 1], [0.8, 1], [1, 0]], "y": 0.2, "delay": 0.2},
            {"p": "bolha", "blend": "mix", "ring": 0.6, "amount": 8, "explosive": 0.3, "dir": [0, 1, 0], "spread": 6, "speed": [0.8, 1.6], "life": 1.4,
             "size": 0.26, "ramp": TEAL, "alpha": [[0, 0], [0.2, 1], [0.8, 1], [1, 0]], "y": 0.1, "delay": 0.2}])["layers"]})

    # ===== GOLEM FERAM =====
    add("feram_cabecada", "FERAM · Cabeçada Escavadora (ataque)", "t_feram",
        {"layers": [arco(-10, 3.6, AMB, 0.0, 0.3, 0.3, 0.6)] + impacto(1.3, AMB, 0.1, 0.8, tremor=0.5)["layers"], "shake": 0.5, "shake_delay": 0.1})
    add("feram_investida", "FERAM · Investida Escavadora", "t_feram",
        {"hit": "ter_feram_investida_hit", "proj": {"speed": 22, "arc": 0.0, "y": 0.5, "parts": [
            {"p": "poeira", "blend": "mix", "trail": True, "amount": 24, "size": 1.1, "speed": [0.3, 1.5], "spin": [-60, 60], "life": 0.6,
             "curve": [[0, 0.8], [1, 0.3]], "erode": 1.0, "halftone": 0.5, "ramp": ["#292C35", "#493D3D", "#8A6A4A", "#E6BD85"], "alpha": ALFA1},
            {"p": "pedra", "blend": "mix", "trail": True, "amount": 10, "size": 0.3, "speed": [1, 4], "grav": -10, "spin": [-400, 400], "life": 0.5,
             "ramp": TERRA + ["#ffffff"], "alpha": [[0, 1], [1, 0]]}],
            "arpao": {"tex": "arco_golpe", "len": 1.8, "width": 1.2, "tile": 1.8, "blend_top": "mix", "ramp": AMB, "boost": 1.0,
                      "halftone": 0.0, "sombra": 1.2, "nucleo": False}}})
    add("feram_investida_hit", "FERAM · Choque da investida (acerto)", "t_feram", impacto(1.4, AMB, 0.0, 0.8, tremor=0.55))

    # ===== ENGENHEIRO DE PONTES =====
    add("pontes_chave", "ENGENHEIRO · Golpe de Ferramenta (ataque)", "t_pontes",
        {"layers": [arco(-30, 3.2, AMB2, 0.0, 0.4)] + impacto(0.95, AMB, 0.1, 0.9, tremor=0.25, cor_pts2="#4CD4BD")["layers"], "shake": 0.25, "shake_delay": 0.1})
    add("pontes_conexao", "ENGENHEIRO · Conexão de Terrenos (eleva a casa)", "t_pontes",
        {"alvo": "meio", "layers": [luz("#ffac45", 3.0, 4.0, 0.6, 0.6),
                                    anel_chao(2.8, AMB2, 0.0, 0.55), racha(2.2, 0.0),
                                    {"p": "hexa", "mode": "chao", "amount": 1, "size": 2.1, "life": 0.9, "life_rand": 0, "y": 0.0,
                                     "curve": [[0, 0.3], [0.3, 1.05], [1, 1.0]], "ramp": AMB, "halftone": 0.2,
                                     "alpha": [[0, 0], [0.2, 1], [0.8, 1], [1, 0]], "angle": [0, 0]},
                                    pedregulhos(8, 0.1, 0.1), poeira(6, 0.0), faisca(14, None, 0.0, 0.3, (4, 8)),
                                    {"p": "seta", "blend": "mix", "ring": 0.6, "amount": 4, "explosive": 0.3, "dir": [0, 1, 0], "spread": 0,
                                     "speed": [1.2, 1.8], "life": 1.0, "size": 0.5, "angle": [0, 0], "ramp": AMB, "boost": 1.2,
                                     "alpha": [[0, 0], [0.2, 1], [0.8, 1], [1, 0]], "y": 0.3, "delay": 0.2}], "shake": 0.3})

    # ===== REI: túnel (entrada/saída) =====
    add("rei_tunel", "REI DA MINA · Túnel (abre a passagem)", "rei_mina",
        {"alvo": "meio", "layers": [luz("#a957ec", 3.0, 4.0, 0.7, 0.3),
                                    {"p": "brilho", "mode": "chao", "amount": 1, "size": 2.4, "life": 1.0, "curve": [[0, 0.3], [0.3, 1], [1, 1]],
                                     "ramp": ["#0b0612", "#1b0f2b", "#4a2d6e", "#a957ec"], "alpha": [[0, 0], [0.2, 1], [0.85, 1], [1, 0]]},
                                    anel_chao(3.0, CRY, 0.0, 0.55), racha(2.4, 0.0, ["#1b0f2b", "#4a2d6e", "#a957ec", "#e3c2ff"]),
                                    pedregulhos(9, 0.0, 0.1), poeira(8, 0.0, 0.2, 1.4), faisca(16, ["#a957ec", "#e3c2ff", "#ffffff"], 0.0, 0.3, (4, 9))],
         "shake": 0.3})

    # ===== núcleo de cada personagem (cor do miolo nos efeitos) =====
    N = {
        "rei_mina": {"nucleo": "#a957ec", "motivo": "cristal de Valak roxo", "ataque": "ter_rei_cristal", "habilidades": ["ter_rei_manip", "ter_rei_barreira", "ter_rei_tunel"]},
        "perfurador": {"nucleo": "#ffac45", "motivo": "broca de bronze", "ataque": "ter_perf_broca", "habilidades": ["ter_perf_furo"]},
        "t_basalto": {"nucleo": "#4cd4bd", "motivo": "olho de energia turquesa", "ataque": "ter_basalto_soco", "habilidades": ["ter_basalto_muralha"]},
        "t_carrinho": {"nucleo": "#a957ec", "motivo": "carga de cristal", "ataque": "ter_carrinho_batida", "habilidades": ["ter_carrinho_carga"]},
        "t_britadeira": {"nucleo": "#ffd24a", "motivo": "luz de sinalização", "ataque": "ter_brit_marteleta", "habilidades": []},
        "t_fundidor": {"nucleo": "#ff6a1f", "motivo": "metal derretido", "ataque": "ter_fundidor_gota", "habilidades": ["ter_fundidor_reves"]},
        "t_fendas": {"nucleo": "#4cd4bd", "motivo": "sobra de energia nas fendas", "ataque": "ter_fendas_picareta", "habilidades": ["ter_fendas_ruptura"]},
        "sismico": {"nucleo": "#ffac45", "motivo": "tremor e pedra", "ataque": "ter_sismico_pisao", "habilidades": ["ter_sismico_onda"]},
        "t_dinamite": {"nucleo": "#ff6a1f", "motivo": "fogo da dinamite", "ataque": "ter_dina_lancar", "habilidades": ["ter_dina_carga"]},
        "t_sentinela": {"nucleo": "#e6bd85", "motivo": "pedra clara", "ataque": "ter_sentinela_golpe", "habilidades": ["ter_sentinela_guarda"]},
        "t_lanterna": {"nucleo": "#ffe9a0", "motivo": "luz da lanterna", "ataque": "ter_lanterna_luz", "habilidades": ["ter_lanterna_amparo"]},
        "t_raiz": {"nucleo": "#8bd34a", "motivo": "raízes vivas", "ataque": "ter_raiz_chicote", "habilidades": ["ter_raiz_trama"]},
        "t_cartografo": {"nucleo": "#4cd4bd", "motivo": "mapa luminoso", "ataque": "ter_cartografo_bussola", "habilidades": ["ter_cartografo_rota"]},
        "t_sniper": {"nucleo": "#4cd4bd", "motivo": "eletricidade turquesa", "ataque": "ter_sniper_tiro", "habilidades": []},
        "t_enfermeira": {"nucleo": "#b8ffdf", "motivo": "cristal curativo", "ataque": "ter_enfermeira_cristal", "habilidades": ["ter_enfermeira_tratamento"]},
        "t_feram": {"nucleo": "#ffac45", "motivo": "ferro e poeira", "ataque": "ter_feram_cabecada", "habilidades": ["ter_feram_investida"]},
        "t_pontes": {"nucleo": "#4cd4bd", "motivo": "ferramentas e cabos turquesa", "ataque": "ter_pontes_chave", "habilidades": ["ter_pontes_conexao"]},
    }
    return R, N


if __name__ == "__main__":
    R, N = receitas()
    p = os.path.join(ROOT, "data", "vfx_receitas.json")
    d = json.load(open(p))
    for k in [k for k in d if k.startswith("ter_")]:
        del d[k]
    for k in R:
        R[k] = aplica(R[k])
        falhas = audita_receita(R[k])
        if falhas["valor"] or falhas["tempo"]:
            raise SystemExit("guia de VFX violado em %s: %s" % (k, falhas))
    d.update(R)
    json.dump(d, open(p, "w"), ensure_ascii=False, indent=1)
    q = os.path.join(ROOT, "data", "vfx_personagens.json")
    pd = json.load(open(q))
    for k in N:
        N[k] = aplica(N[k])
    pd.update(N)
    json.dump(pd, open(q, "w"), ensure_ascii=False, indent=1)
    print(len(R), "receitas ter_*,", len(N), "personagens")
