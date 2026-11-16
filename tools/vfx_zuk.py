"""FORJA dos ZUKUNFT (paleta oficial: ciano primária, azul secundária, sombra índigo, destaque gelo, extra violeta;
padrão de pixel). Identidade: tecnologia limpa, hologramas, hexágonos de energia e desintegração em pixels.
Cada personagem tem um ataque básico único (zuk_<carta>_ataque) e as habilidades ativas têm o seu efeito.
O símbolo dos Zukunft entra por cima no impacto (simbolo_ZUK, tools/vfx_simbolos.py).
python3 tools/forja_tex_zuk.py && python3 tools/vfx_zuk.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from vfx_ter import luz, merge
from forja_guia import aplica, audita_receita

ROOT = os.path.join(os.path.dirname(__file__), "..")
RECEITAS = os.path.join(ROOT, "data", "vfx_receitas.json")
PERS = os.path.join(ROOT, "data", "vfx_personagens.json")

# rampas de valor (escuro -> claro); topo gelo, nunca branco puro
CI = ["#122038", "#222A63", "#27DDF4", "#9BF2FB", "#D9FCFF"]
AZ = ["#122038", "#222A63", "#5778FF", "#9DB0FF", "#D9FCFF"]
VI = ["#122038", "#2E1F63", "#9C7FFD", "#CDBEFF", "#E8E2FF"]
OURO = ["#122038", "#3A2A63", "#F2C14E", "#FFE39A", "#FFF4D6"]     # Guardião Real (coroa)
CHAMA = ["#122038", "#5A1F63", "#9C7FFD", "#27DDF4", "#D9FCFF"]    # Fênix: chama fria violeta -> ciano
SOMBRA = ["#0E1428", "#122038"]
FIM = [[0, 1], [0.7, 1], [1, 0]]
POP = [[0, 0.3], [0.16, 1.2], [0.35, 1.0], [1, 1.05]]


# ---------------- peças da linguagem Zukunft
def pixels(n=14, delay=0.0, y=0.95, ramp=None, speed=(3, 8), size=(0.12, 0.3), life=0.5, dirv=None, spread=180, grav=3.0, em=None):
    """desintegração digital: blocos quadrados retos que voam, sobem um pouco e somem"""
    d = {"p": "pixel", "blend": "mix", "amount": n, "size": list(size), "speed": list(speed), "spread": spread, "grav": grav,
         "damp": [4, 7], "life": life, "life_rand": 0.4, "angle": [0, 0], "curve": [[0, 1], [0.7, 0.9], [1, 0]],
         "ramp": ramp or CI, "alpha": FIM, "y": y, "delay": delay}
    if dirv == "away":
        d.update({"dir": "away", "lift": 0.3})
    elif dirv:
        d["dir"] = dirv
    if em:
        d["em"] = em
    return d


def hexpop(size=1.4, delay=0.0, y=0.95, ramp=None, life=0.32, em=None, spin=None):
    d = {"p": "hex_oco", "blend": "mix", "amount": 1, "size": size, "life": life, "life_rand": 0, "angle": [0, 0],
         "curve": [[0, 0.3], [0.2, 1.1], [1, 1.35]], "erode": 1.0, "erode_pow": 1.6, "ramp": ramp or CI, "alpha": FIM, "y": y, "delay": delay}
    if em:
        d["em"] = em
    if spin:
        d["spin"] = list(spin)
    return d


def hexchao(size=2.6, delay=0.0, ramp=None, life=0.5, fecha=False, em=None):
    """onda hexagonal no chão (abre) ou fechando sobre o alvo"""
    d = {"p": "hex_oco", "mode": "chao", "amount": 1, "size": size, "life": life, "life_rand": 0, "y": 0.0, "angle": [0, 0],
         "curve": [[0, 1.8], [1, 0.45]] if fecha else [[0, 0.3], [1, 1.6]], "erode": 1.0, "erode_pow": 1.3, "ramp": ramp or CI,
         "alpha": [[0, 0], [0.3, 1], [1, 0]] if fecha else FIM, "delay": delay}
    if em:
        d["em"] = em
    return d


def grade(size=2.0, delay=0.0, y=1.0, ramp=None, life=0.4, chao=False, em=None):
    """matriz de colmeia (escudo / tela de energia)"""
    d = {"p": "hex_grade", "blend": "mix", "amount": 1, "size": size, "life": life, "life_rand": 0, "angle": [0, 0],
         "curve": [[0, 0.6], [0.2, 1.0], [1, 1.08]], "erode": 1.0, "erode_pow": 1.2, "ramp": ramp or CI,
         "alpha": [[0, 0], [0.12, 1], [0.7, 0.9], [1, 0]], "y": y, "delay": delay}
    if chao:
        d.update({"mode": "chao", "y": 0.0})
        d.pop("blend")
    if em:
        d["em"] = em
    return d


def glitch(size=1.3, delay=0.0, y=1.0, ramp=None, n=3, life=0.22, em=None):
    d = {"p": "glitch", "blend": "mix", "amount": n, "size": [size * 1.4, size * 0.7], "life": life, "life_rand": 0.4, "angle": [0, 0],
         "radius": 0.35, "speed": [0, 0.6], "curve": [[0, 1.0], [0.5, 1.15], [1, 0.8]], "ramp": ramp or CI,
         "alpha": [[0, 1], [0.3, 0.4], [0.5, 1], [0.8, 0.6], [1, 0]], "y": y, "delay": delay, "explosive": 0.6}
    if em:
        d["em"] = em
    return d


def faisca(n=12, delay=0.0, y=0.95, ramp=None, speed=(7, 14), dirv=None, life=0.26):
    d = {"p": "faisca", "blend": "mix", "mode": "vel", "amount": n, "size": [0.08, 0.6], "speed": list(speed), "spread": 180,
         "grav": -6, "damp": [5, 9], "life": life, "curve": [[0, 1.3], [1, 0]], "ramp": ramp or CI[1:], "boost": 1.2, "y": y, "delay": delay}
    if dirv == "away":
        d.update({"dir": "away", "lift": 0.2, "spread": 45})
    return d


def estrela(size=1.8, delay=0.0, y=0.95, ramp=None, life=0.22, em=None):
    d = {"p": "estrela4", "blend": "mix", "amount": 1, "size": size, "life": life, "life_rand": 0, "angle": [0, 0],
         "curve": [[0, 0.2], [0.18, 1.2], [1, 0.25]], "ramp": ramp or CI, "alpha": FIM, "y": y, "delay": delay, "nucleo": True}
    if em:
        d["em"] = em
    return d


def corte(tex="lamina", size=2.6, aim_off=0.0, delay=0.0, ramp=None, toward=0.3, life=0.24, y=0.95):
    return {"p": tex, "blend": "mix", "amount": 1, "size": size, "life": life, "life_rand": 0, "aim": True, "aim_off": aim_off,
            "toward": toward, "y": y, "curve": [[0, 0.5], [0.25, 1.05], [1, 1.15]], "erode": 1.0, "erode_pow": 1.3,
            "ramp": ramp or CI, "alpha": FIM, "delay": delay}


def objeto(tex, size, delay=0.0, ramp=None, y=0.95, toward=0.6, life=0.26, aim=True, aim_off=0.0, curve=None, spin=None):
    d = {"p": tex, "blend": "mix", "amount": 1, "size": size, "life": life, "life_rand": 0, "toward": toward, "y": y,
         "curve": curve or [[0, 1.5], [0.2, 0.95], [1, 1.0]], "erode": 1.0, "erode_pow": 3.0, "ramp": ramp or CI,
         "alpha": FIM, "delay": delay}
    if aim:
        d.update({"aim": True, "aim_off": aim_off})
    else:
        d["angle"] = [0, 0]
    if spin:
        d["spin"] = list(spin)
    return d


def laser(ramp=None, width=0.28, dur=0.24, delay=0.0, y=1.0, tile=2.4, de="from", para="at"):
    """feixe reto de energia entre quem atira e o alvo (pulsa trocando o desenho)"""
    return {"raio": 1, "tex": "feixe", "de": de, "para": para, "y": y, "dur": dur, "flick": 0.04, "cresce": 0.05,
            "width": width, "tile": tile, "blend_top": "mix", "ramp": ramp or CI[1:], "ramp_sombra": SOMBRA, "sombra": 1.7,
            "boost": 1.0, "halftone": 0.0, "delay": delay}


def acerto(k=1.0, delay=0.0, y=0.95, ramp=None, tremor=0.22, pix=True):
    """acerto padrão Zukunft: clarão, estrela, hexágono que estoura e pixels"""
    r = ramp or CI
    L = [luz(r[2], 2.6 * k, 3.0, 0.22, y, delay), estrela(1.7 * k, delay, y, r), hexpop(1.3 * k, delay, y, r),
         faisca(int(10 * k), delay, y, r[1:])]
    if pix:
        L.append(pixels(int(12 * k), delay + 0.02, y, r))
    return {"layers": L, "shake": tremor, "shake_delay": delay}


def proj(parts, speed=24, arc=0.1, y=1.0, orbe=None, arpao=None, rajada=None):
    P = {"speed": speed, "arc": arc, "y": y, "parts": parts}
    if orbe:
        P["orbe"] = orbe
    if arpao:
        P["arpao"] = arpao
    if rajada:
        P["rajada"] = rajada
    return P


def trilha_pix(ramp=None, n=10):
    return {"p": "pixel", "blend": "mix", "mode": "bill", "trail": True, "amount": n, "size": [0.08, 0.2], "speed": [0.2, 1.0],
            "angle": [0, 0], "life": 0.3, "ramp": ramp or CI, "alpha": [[0, 1], [1, 0]], "curve": [[0, 1], [1, 0]]}


def miolo(tex="brilho", size=0.6, ramp=None):
    return {"p": tex, "blend": "mix", "one_shot": False, "amount": 3, "size": size, "life": 0.12, "angle": [0, 0],
            "ramp": ramp or CI[2:], "alpha": [[0, 1], [1, 0.6]], "curve": [[0, 1], [1, 0.8]]}


# ================= efeitos por personagem =================
def especiais():
    R = {}

    def add(rid, nome, cid, d):
        R[rid] = {"nome": "ZUKUNFT · " + nome, "personagem": cid, **d}

    # VANGUARDA — Lâmina de Fase: dois cortes em X de energia; a imagem dele se desfaz em pixels no lugar de onde partiu
    add("zuk_z_vang_ataque", "Vanguarda · Lâmina de Fase", "z_vang", merge(
        {"layers": [corte("lamina", 2.8, -35, 0.0, CI), corte("lamina", 2.4, 145, 0.07, AZ),
                    pixels(16, 0.0, 1.0, CI, (1, 4), (0.12, 0.34), 0.55, [0, 1, 0], 60, 4.0, em="from"),
                    glitch(1.2, 0.0, 1.1, CI, 2, 0.2, em="from")]},
        acerto(1.0, 0.06, 0.95, CI, 0.22)))

    # TANK — Choque Inercial: placa de colmeia avança no golpe e uma onda hexagonal corre no chão
    add("zuk_z_tank_ataque", "Tank · Choque Inercial", "z_tank", merge(
        {"layers": [grade(2.2, 0.0, 1.0, AZ, 0.32), hexpop(2.2, 0.0, 1.0, AZ, 0.3),
                    hexchao(3.4, 0.03, AZ, 0.5), luz("#5778ff", 3.2, 3.6, 0.28, 1.0)]},
        acerto(1.15, 0.03, 0.95, AZ, 0.38, pix=False),
        {"layers": [pixels(10, 0.05, 0.4, AZ, (4, 8), (0.14, 0.3), 0.45, "away", 50, -6.0)]}))

    # BRAWLER HOLOGRÁFICO — Combo de Sósias: três socos em sequência, cada um de um sósia de luz que pisca
    add("zuk_z_brawler_ataque", "Brawler Holográfico · Combo de Sósias", "z_brawler", merge(
        {"layers": [objeto("punho", 1.3, 0.0, VI, 1.2, 0.7, 0.2, aim_off=-12),
                    objeto("punho", 1.3, 0.1, CI, 0.75, 0.6, 0.2, aim_off=14),
                    objeto("punho", 1.7, 0.2, VI, 1.0, 0.45, 0.24),
                    glitch(1.1, 0.0, 1.0, VI, 2, 0.18, em="from"), glitch(1.1, 0.12, 1.0, CI, 2, 0.18, em="from"),
                    estrela(1.1, 0.02, 1.2, VI, 0.16), estrela(1.1, 0.12, 0.75, CI, 0.16)]},
        acerto(1.1, 0.22, 1.0, VI, 0.3)))

    # ATIRADOR DE PRECISÃO — Disparo de Trilho: retículo hexagonal trava no alvo e um feixe atravessa
    add("zuk_z_piloto_ataque", "Atirador de Precisão · Disparo de Trilho", "z_piloto", merge(
        {"layers": [{"p": "mira_hex", "blend": "mix", "amount": 1, "size": 1.9, "life": 0.36, "life_rand": 0, "angle": [0, 0],
                     "spin": [120, 120], "curve": [[0, 1.6], [0.6, 0.85], [1, 0.8]], "ramp": CI, "alpha": [[0, 0], [0.2, 1], [0.85, 1], [1, 0]],
                     "y": 1.0},
                    {"em": "from", **luz("#27ddf4", 2.6, 2.6, 0.2, 1.0, 0.3)},
                    estrela(1.2, 0.3, 1.0, CI, 0.14, em="from"),
                    laser(CI[1:], 0.34, 0.26, 0.3, 1.0, 3.0)]},
        acerto(1.2, 0.34, 1.0, CI, 0.32),
        {"layers": [faisca(10, 0.34, 1.0, CI[1:], (10, 18), "away")], "hit_t": 0.34}))

    # PILOTO DE NAVES — Rasante: três disparos caem do céu em diagonal, como uma nave passando
    add("zuk_z_naves_ataque", "Piloto de Naves · Rasante", "z_naves", merge(
        {"layers": [{"p": "feixe", "blend": "mix", "mode": "vel", "amount": 3, "size": [0.3, 3.2], "speed": [26, 30], "dir": [0, -1, 0],
                     "spread": 6, "explosive": 0.75, "life": 0.13, "life_rand": 0, "ramp": AZ[1:], "alpha": FIM, "y": 4.2,
                     "radius": 0.5, "curve": [[0, 1], [1, 0.8]]},
                    {"p": "hex_oco", "mode": "chao", "amount": 3, "size": 1.0, "life": 0.4, "life_rand": 0.2, "y": 0.0, "angle": [0, 0],
                     "radius": 0.7, "explosive": 0.7, "curve": [[0, 0.3], [1, 1.3]], "erode": 1.0, "ramp": AZ, "alpha": FIM, "delay": 0.1}]},
        acerto(1.0, 0.12, 0.8, AZ, 0.28),
        {"layers": [estrela(1.0, 0.18, 1.2, CI, 0.14), estrela(0.9, 0.24, 0.6, AZ, 0.14)]}))

    # DIPLOMATA — Argumento Irrefutável: ondas de som violeta saem da voz e o alvo fica envolto em glitch
    add("zuk_z_diplo_ataque", "Diplomata · Argumento Irrefutável", "z_diplo", merge(
        {"layers": [{"p": "arco_som", "blend": "mix", "amount": 3, "size": [2.4, 0.9], "life": 0.32, "life_rand": 0, "explosive": 0.5,
                     "aim": True, "toward": 1.2, "y": 1.2, "curve": [[0, 0.4], [1, 1.2]], "erode": 1.0, "erode_pow": 1.4,
                     "ramp": VI, "alpha": FIM},
                    glitch(1.5, 0.12, 1.1, VI, 4, 0.3), hexchao(2.2, 0.1, VI, 0.5, fecha=True)]},
        acerto(0.9, 0.14, 1.0, VI, 0.18)))

    # DUELISTA — Estocada: uma linha finíssima atravessa o alvo e o corte aparece em X um instante depois
    add("zuk_z_duel_ataque", "Duelista · Estocada", "z_duel", merge(
        {"layers": [{"p": "feixe", "blend": "mix", "amount": 1, "size": [3.4, 0.5], "life": 0.12, "life_rand": 0, "aim": True,
                     "toward": 0.4, "y": 1.0, "curve": [[0, 0.3], [0.4, 1.1], [1, 1.2]], "ramp": CI, "alpha": FIM},
                    estrela(2.2, 0.03, 1.0, CI, 0.2),
                    corte("lamina", 2.2, 40, 0.14, CI, 0.0, 0.2), corte("lamina", 2.2, 220, 0.18, AZ, 0.0, 0.2),
                    faisca(14, 0.02, 1.0, CI[1:], (12, 20), "away", 0.2)]},
        acerto(0.9, 0.16, 1.0, CI, 0.26, pix=False),
        {"layers": [pixels(8, 0.2, 1.0, CI, (2, 5), (0.08, 0.2), 0.4)]}))

    # BIOENGENHEIRO — Enxame de Nanitos: nuvem de nanitos gira em volta do alvo e fecha nele
    add("zuk_z_bio_ataque", "Bioengenheiro · Enxame de Nanitos", "z_bio", merge(
        {"layers": [{"p": "pixel", "blend": "mix", "amount": 30, "size": [0.16, 0.3], "ring": 1.3, "ring_h": 1.4, "speed": [0, 0.5],
                     "tangential": [10, 14], "radial": [-6, -4], "life": 0.42, "life_rand": 0.2, "explosive": 0.8, "angle": [0, 0],
                     "ramp": CI, "alpha": [[0, 0], [0.15, 1], [0.8, 1], [1, 0]], "curve": [[0, 1], [1, 0.4]], "y": 0.4},
                    {"p": "ponto", "blend": "mix", "amount": 16, "size": 0.2, "ring": 1.1, "ring_h": 1.2, "tangential": [-12, -9],
                     "radial": [-5, -3], "life": 0.4, "explosive": 0.8, "ramp": [VI[2], VI[3]], "alpha": FIM, "y": 0.5},
                    hexchao(2.4, 0.0, CI, 0.45, fecha=True)]},
        acerto(0.85, 0.32, 1.0, CI, 0.2),
        {"hit_t": 0.32, "layers": []}))

    # HACKER — Pacote Malicioso: um orbe de dados voa e o alvo trava em glitch e pixels
    add("zuk_z_hacker_ataque", "Hacker · Pacote Malicioso", "z_hacker",
        {"hit": "zuk_hacker_hit", "proj": proj([trilha_pix(VI, 14), miolo("pixel", 0.35, VI[2:])], 16, 0.5, 1.1,
                                               orbe={"size": 0.22, "ramp": ["#122038", "#2E1F63", "#9C7FFD", "#CDBEFF"], "boost": 1.2})})
    add("zuk_hacker_hit", "Hacker · Travamento", "z_hacker", merge(
        {"layers": [glitch(1.8, 0.0, 1.0, VI, 5, 0.32), glitch(1.2, 0.08, 1.2, CI, 3, 0.26),
                    pixels(20, 0.0, 1.0, VI, (2, 6), (0.1, 0.3), 0.55)]},
        acerto(0.9, 0.0, 1.0, VI, 0.2, pix=False)))

    # GUARDIÃO REAL — Juízo da Coroa: a coroa de luz aparece sobre o alvo e a alabarda desce num golpe vertical
    add("zuk_z_real_ataque", "Guardião Real · Juízo da Coroa", "z_real", merge(
        {"layers": [{"p": "coroa", "blend": "mix", "amount": 1, "size": 1.3, "life": 0.4, "life_rand": 0, "angle": [0, 0],
                     "curve": POP, "ramp": OURO, "alpha": [[0, 0], [0.12, 1], [0.7, 1], [1, 0]], "y": 2.3},
                    corte("lamina", 3.0, -90, 0.12, OURO, 0.1, 0.22, 1.2),
                    hexchao(3.0, 0.14, OURO, 0.5)]},
        acerto(1.1, 0.14, 0.95, CI, 0.34),
        {"layers": [pixels(8, 0.16, 0.95, OURO, (3, 7))]}))

    # CÃO ZUKUNFT — Mordida Cibernética: mandíbulas de energia se fecham e três riscos de garra rasgam
    add("zuk_z_cao_ataque", "Cão Zukunft · Mordida Cibernética", "z_cao", merge(
        {"layers": [{"p": "mandibula", "blend": "mix", "amount": 1, "size": 1.6, "life": 0.22, "life_rand": 0, "angle": [0, 0],
                     "curve": [[0, 1.3], [0.5, 0.9], [1, 0.85]], "ramp": CI, "alpha": FIM, "y": 1.35},
                    {"p": "mandibula", "blend": "mix", "amount": 1, "size": 1.6, "life": 0.22, "life_rand": 0, "angle": [180, 180],
                     "curve": [[0, 1.3], [0.5, 0.9], [1, 0.85]], "ramp": CI, "alpha": FIM, "y": 0.6},
                    corte("rasgo", 1.8, -50, 0.1, AZ, 0.1, 0.2)]},
        acerto(1.0, 0.1, 0.95, CI, 0.26)))

    # DRAGÃO (comandante) — Sopro de Plasma: jato de plasma em cone que estoura em hexágonos
    add("zuk_z_dragao_ataque", "Dragão · Sopro de Plasma", "z_dragao", merge(
        {"layers": [{"p": "jato", "blend": "mix", "amount": 1, "size": [3.6, 1.4], "life": 0.3, "life_rand": 0, "aim": True,
                     "toward": 1.1, "y": 1.2, "curve": [[0, 0.3], [0.3, 1.05], [1, 1.2]], "erode": 1.0, "erode_pow": 1.3,
                     "ramp": CI, "alpha": FIM},
                    estrela(1.4, 0.0, 1.3, CI, 0.18, em="from"),
                    {"em": "from", **luz("#27ddf4", 3.2, 3.4, 0.3, 1.3)}]},
        acerto(1.3, 0.16, 1.0, CI, 0.4),
        {"layers": [hexchao(3.2, 0.18, CI, 0.5), pixels(14, 0.2, 0.9, AZ, (4, 9))], "hit_t": 0.16}))
    # Rajada Tecnológica (passiva do ataque): choque hexagonal que pega os vizinhos do alvo
    add("zuk_dragao_rajada", "Dragão · Rajada Tecnológica (vizinhos)", "z_dragao",
        {"alvo": "self", "layers": [hexchao(5.0, 0.0, CI, 0.45), hexchao(4.0, 0.08, AZ, 0.45),
                                    {"p": "faisca", "blend": "mix", "mode": "vel", "amount": 18, "size": [0.1, 0.7], "speed": [9, 14],
                                     "spread": 180, "flat": 0.9, "damp": [4, 6], "life": 0.3, "ramp": CI[1:], "alpha": FIM, "y": 0.6},
                                    pixels(14, 0.04, 0.6, CI, (5, 9), (0.1, 0.24), 0.4)], "shake": 0.2})
    # Salto Orbital (ativa): decola num risco de luz, cai do céu como um feixe e explode em colmeia
    add("zuk_dragao_orbital", "Dragão · Salto Orbital", "z_dragao", merge(
        {"layers": [
            {"em": "from", **luz("#27ddf4", 4.0, 4.0, 0.4, 1.0)},
            {"em": "from", "p": "feixe", "blend": "mix", "mode": "vel", "amount": 1, "size": [0.9, 6.0], "speed": [30, 30], "dir": [0, 1, 0],
             "spread": 0, "life": 0.3, "life_rand": 0, "ramp": CI[1:], "alpha": FIM, "y": 0.5},
            pixels(24, 0.0, 0.6, CI, (3, 8), (0.12, 0.32), 0.6, [0, 1, 0], 35, 6.0, em="from"),
            hexchao(3.0, 0.0, CI, 0.45, em="from"),
            # o alvo é marcado enquanto ele está no ar
            hexchao(3.6, 0.1, CI, 0.5, fecha=True),
            {"p": "mira_hex", "mode": "chao", "amount": 1, "size": 2.6, "life": 0.55, "life_rand": 0, "y": 0.0, "angle": [0, 0],
             "spin": [200, 200], "curve": [[0, 1.4], [1, 0.9]], "ramp": CI, "alpha": [[0, 0], [0.2, 1], [0.85, 1], [1, 0]], "delay": 0.05},
            {"p": "feixe", "blend": "mix", "mode": "vel", "amount": 1, "size": [1.4, 7.0], "speed": [40, 40], "dir": [0, -1, 0],
             "spread": 0, "life": 0.18, "life_rand": 0, "ramp": CI[1:], "alpha": FIM, "y": 7.0, "delay": 0.42}]},
        acerto(1.7, 0.55, 0.8, CI, 0.7),
        {"layers": [hexchao(5.2, 0.55, CI, 0.55), hexchao(4.0, 0.62, AZ, 0.5), grade(3.6, 0.55, 0.0, CI, 0.7, chao=True),
                    {"p": "faisca", "blend": "mix", "mode": "vel", "amount": 22, "size": [0.1, 0.8], "speed": [10, 16], "spread": 180,
                     "flat": 0.85, "damp": [4, 6], "life": 0.32, "ramp": CI[1:], "alpha": FIM, "y": 0.5, "delay": 0.55},
                    pixels(26, 0.56, 0.7, CI, (5, 11), (0.12, 0.34), 0.6)], "hit_t": 0.55}))

    # GUARDIÃO MECA — Pistão Hidráulico: punho blindado gigante, engrenagens voando e onda no chão
    add("zuk_z_meca_ataque", "Guardião Meca · Pistão Hidráulico", "z_meca", merge(
        {"layers": [objeto("punho", 2.3, 0.0, AZ, 1.0, 0.5, 0.26),
                    {"p": "engrenagem", "blend": "mix", "mode": "bill", "amount": 4, "size": [0.35, 0.6], "speed": [4, 8], "spread": 70,
                     "dir": [0, 1, 0], "grav": -14, "spin": [-400, 400], "life": 0.55, "ramp": AZ, "alpha": FIM, "y": 1.0, "delay": 0.06}]},
        acerto(1.3, 0.05, 0.95, AZ, 0.45),
        {"layers": [hexchao(3.4, 0.07, AZ, 0.5), grade(1.8, 0.05, 1.0, CI, 0.3)]}))

    # FÊNIX — Chama Fria: uma pena de fogo violeta voa e explode em penas e brasas
    add("zuk_z_fenix_ataque", "Guardião Fênix · Chama Fria", "z_fenix",
        {"hit": "zuk_fenix_hit", "proj": proj([miolo("pena", 0.7, CHAMA[2:]),
                                              {"p": "pena", "blend": "mix", "trail": True, "amount": 10, "size": 0.45, "speed": [0.2, 0.8],
                                               "angle": [-20, 20], "life": 0.3, "ramp": CHAMA, "alpha": [[0, 1], [1, 0]], "curve": [[0, 1], [1, 0.3]]},
                                              {"p": "brilho", "blend": "mix", "trail": True, "amount": 12, "size": 0.25, "speed": [0.3, 1.2],
                                               "life": 0.28, "ramp": CHAMA[1:], "alpha": [[0, 1], [1, 0]], "curve": [[0, 1], [1, 0]]}],
                                             17, 0.7, 1.1)})
    add("zuk_fenix_hit", "Guardião Fênix · Explosão de Penas", "z_fenix", merge(
        {"layers": [{"p": "pena", "blend": "mix", "mode": "vel", "amount": 9, "size": [0.35, 0.8], "speed": [4, 8], "spread": 180,
                     "grav": 3, "damp": [3, 5], "life": 0.5, "erode": 1.0, "erode_pow": 1.5, "ramp": CHAMA, "alpha": FIM, "y": 1.0},
                    {"p": "estouro", "blend": "mix", "amount": 1, "size": 2.0, "life": 0.3, "life_rand": 0, "angle": [0, 360],
                     "curve": [[0, 0.3], [0.2, 1.0], [1, 1.1]], "erode": 1.0, "erode_pow": 1.4, "ramp": CHAMA, "alpha": FIM, "y": 1.0}]},
        acerto(1.0, 0.0, 1.0, VI, 0.26, pix=False)))

    # GUARDA DOS PORTAIS — Disparo Dimensional: um portal se abre ao lado do alvo e o tiro sai de dentro dele
    add("zuk_z_portais_ataque", "Guarda dos Portais · Disparo Dimensional", "z_portais", merge(
        {"layers": [hexpop(1.4, 0.0, 1.1, CI, 0.24, em="from"),
                    {"p": "hex_oco", "blend": "mix", "amount": 1, "size": 1.9, "life": 0.5, "life_rand": 0, "angle": [0, 0], "spin": [180, 180],
                     "toward": -1.0, "y": 1.3, "curve": [[0, 0.1], [0.25, 1.0], [0.8, 1.0], [1, 0.2]], "ramp": VI,
                     "alpha": [[0, 1], [0.8, 1], [1, 0]], "delay": 0.05},
                    {"p": "brilho", "blend": "mix", "amount": 1, "size": 1.4, "life": 0.45, "life_rand": 0, "toward": -1.0, "y": 1.3,
                     "curve": [[0, 0.1], [0.25, 1.0], [1, 0.3]], "ramp": VI[1:], "alpha": FIM, "delay": 0.05},
                    {"p": "feixe", "blend": "mix", "amount": 1, "size": [2.2, 0.55], "life": 0.14, "life_rand": 0, "aim": True, "aim_off": 180,
                     "toward": -0.5, "y": 1.15, "curve": [[0, 0.3], [0.4, 1.1], [1, 1.2]], "ramp": CI, "alpha": FIM, "delay": 0.2}]},
        acerto(1.1, 0.24, 1.0, CI, 0.28),
        {"layers": [], "hit_t": 0.24}))
    # Portalis: entrada (ciano, por onde aliados e ataques entram) e saída (violeta, por onde saem)
    for lado, ramp, nome in (("entrada", CI, "Entrada"), ("saida", VI, "Saída")):
        add("zuk_portais_" + lado, "Guarda dos Portais · Portalis (%s)" % nome, "z_portais",
            {"alvo": "self", "layers": [
                luz(ramp[2], 3.6, 3.6, 0.5, 0.8),
                hexchao(3.0, 0.0, ramp, 0.6, fecha=True),
                {"p": "hex_oco", "mode": "chao", "amount": 1, "size": 1.9, "life": 0.9, "life_rand": 0, "y": 0.02, "angle": [0, 0],
                 "spin": [160 if lado == "entrada" else -160] * 2, "curve": [[0, 0.1], [0.3, 1.0], [1, 1.0]], "ramp": ramp,
                 "alpha": [[0, 1], [0.75, 1], [1, 0]], "delay": 0.15},
                grade(2.0, 0.18, 0.0, ramp, 0.8, chao=True),
                {"p": "brilho", "blend": "mix", "mode": "vel", "amount": 14, "size": [0.15, 0.35], "speed": [2, 4],
                 "dir": [0, 1 if lado == "entrada" else -1, 0], "spread": 10, "radius": 0.7, "explosive": 0.3, "life": 0.6,
                 "ramp": ramp[1:], "alpha": FIM, "y": 0.1 if lado == "entrada" else 2.4, "delay": 0.15},
                pixels(14, 0.2, 0.3, ramp, (1, 3), (0.1, 0.24), 0.7, [0, 1, 0], 30, 2.0)], "shake": 0.15})

    # DRONE-SENTINELA — Rajada Dupla: três tiros curtos de laser, um atrás do outro
    add("zuk_z_drone_ataque", "Drone-Sentinela · Rajada Tripla", "z_drone",
        {"hit": "zuk_drone_hit",
         "proj": proj([{"p": "faisca", "blend": "mix", "mode": "vel", "trail": True, "amount": 5, "size": [0.04, 0.24], "speed": [0.3, 1.2],
                        "life": 0.12, "ramp": AZ[1:], "alpha": [[0, 1], [1, 0]], "curve": [[0, 1], [1, 0]]}], 34, 0.0, 1.4,
                      arpao={"tex": "feixe", "len": 1.3, "width": 0.3, "tile": 1.3, "blend_top": "mix", "ramp": AZ[1:],
                             "boost": 1.0, "halftone": 0.0, "sombra": 1.4, "ramp_sombra": SOMBRA, "nucleo": False},
                      rajada={"n": 3, "gap": 0.09, "spread": 0.35, "dy": 0.0, "vy": 0.1})})
    add("zuk_drone_hit", "Drone-Sentinela · Acerto", "z_drone", merge(
        acerto(0.8, 0.0, 1.0, AZ, 0.16),
        {"layers": [estrela(0.9, 0.08, 1.15, CI, 0.12), estrela(0.9, 0.16, 0.8, AZ, 0.12)]}))

    # ENGENHEIRA DE ESCUDOS — Placa Arremessada: um hexágono de escudo gira até o alvo e quebra em cacos de colmeia
    add("zuk_z_escudo_ataque", "Engenheira de Escudos · Placa Arremessada", "z_escudo",
        {"hit": "zuk_escudo_hit", "proj": proj([{"p": "hex_oco", "blend": "mix", "one_shot": False, "amount": 2, "size": 0.75, "life": 0.1,
                                                 "angle": [0, 0], "spin": [720, 720], "ramp": CI, "alpha": [[0, 1], [1, 0.8]]},
                                                {"p": "hex_grade", "blend": "mix", "one_shot": False, "amount": 2, "size": 0.7, "life": 0.1,
                                                 "angle": [0, 0], "ramp": CI, "alpha": [[0, 0.8], [1, 0.6]]},
                                                trilha_pix(CI, 8)], 15, 0.9, 1.1)})
    add("zuk_escudo_hit", "Engenheira de Escudos · Quebra da Placa", "z_escudo", merge(
        {"layers": [{"p": "hexa", "blend": "mix", "mode": "bill", "amount": 7, "size": [0.25, 0.45], "speed": [5, 9], "spread": 180,
                     "grav": -12, "damp": [2, 4], "spin": [-500, 500], "life": 0.5, "ramp": CI, "alpha": FIM, "y": 1.0},
                    grade(1.9, 0.0, 1.0, CI, 0.26)]},
        acerto(0.9, 0.0, 1.0, CI, 0.22, pix=False)))

    # CÃO — Farejador (ativa: corre e ataca): rastro de faro no chão e pixels na arrancada
    add("zuk_cao_faro", "Cão Zukunft · Farejador (arrancada)", "z_cao",
        {"alvo": "self", "layers": [hexchao(2.2, 0.0, CI, 0.4), pixels(16, 0.0, 0.5, CI, (2, 6), (0.1, 0.26), 0.5, [0, 1, 0], 70, 2.0),
                                    glitch(1.2, 0.0, 0.9, CI, 3, 0.2),
                                    {"p": "mira_hex", "mode": "chao", "amount": 1, "size": 1.7, "life": 0.5, "life_rand": 0, "y": 0.0,
                                     "angle": [0, 0], "spin": [240, 240], "curve": [[0, 0.4], [1, 1.2]], "ramp": CI, "alpha": FIM}],
         "shake": 0.08})
    return R


# habilidade (abfx do motor) -> receita: main.gd (TER_ABFX) usa estes mesmos ids
HABS = {"z_dragao": ["zuk_dragao_orbital", "zuk_dragao_rajada"], "z_portais": ["zuk_portais_entrada", "zuk_portais_saida"],
        "z_cao": ["zuk_cao_faro"]}
NUCLEO = {"z_brawler": "#9C7FFD", "z_diplo": "#9C7FFD", "z_hacker": "#9C7FFD", "z_fenix": "#9C7FFD", "z_real": "#F2C14E",
          "z_tank": "#5778FF", "z_meca": "#5778FF", "z_drone": "#5778FF", "z_naves": "#5778FF"}


def main():
    cartas = json.load(open(os.path.join(ROOT, "data", "cards.json"), encoding="utf-8"))["cards"]
    zuk = [c["id"] for c in cartas if c.get("f") == "ZUK"]
    rec = json.load(open(RECEITAS, encoding="utf-8"))
    pers = json.load(open(PERS, encoding="utf-8"))
    for k in [k for k in rec if k.startswith("zuk_")]:
        del rec[k]
    esp = especiais()
    for rid, d in esp.items():
        rec[rid] = aplica(d)
        falhas = audita_receita(rec[rid])
        assert not falhas["valor"] and not falhas["tempo"], (rid, falhas)
    for cid in zuk:
        rid = "zuk_%s_ataque" % cid
        assert rid in esp, "falta o ataque de " + cid
        pers[cid] = {"nucleo": NUCLEO.get(cid, "#27DDF4"), "motivo": cid, "ataque": rid, "habilidades": HABS.get(cid, [])}
    json.dump(rec, open(RECEITAS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(pers, open(PERS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("ZUK: ataques", len(zuk), "| receitas", len(esp))


if __name__ == "__main__":
    main()
