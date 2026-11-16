"""FORJA dos FAURIANOS (pop HQ: laranja primária, lima secundária, ciano extra, contorno de tinta, creme no topo).
Identidade: mercenários animais — o estouro de quadrinho com os raios em zigue-zague das artes, e cada um ataca
com o jeito do próprio bicho (garra, chifre, mordida, pena, língua, espinho...).
Gera o ataque básico único (fau_<carta>_ataque) de cada carta e as ativas (Projétil Animal, Sistema Invadido).
python3 tools/forja_tex_fau.py && python3 tools/vfx_fau.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from vfx_ter import luz, merge, poeira, anel_chao, racha, pedregulhos
from forja_guia import aplica, audita_receita
import vfx_zuk as Z

ROOT = os.path.join(os.path.dirname(__file__), "..")
RECEITAS = os.path.join(ROOT, "data", "vfx_receitas.json")
PERS = os.path.join(ROOT, "data", "vfx_personagens.json")
CARTAS = os.path.join(ROOT, "data", "cards.json")

# rampas de valor: 0 = contorno de tinta, 4 = creme (nunca 0% nem 100%)
POP = ["#122634", "#263E49", "#FF8236", "#FFD12E", "#FFF6DC"]    # laranja (primária)
LIMA = ["#122634", "#3F5E1C", "#9BE348", "#E4FF9E", "#FFF6DC"]   # lima (secundária)
CIANO = ["#122634", "#1F4F5A", "#55D7EB", "#C8F6FF", "#FFF6DC"]  # ciano (extra)
OURO = ["#122634", "#5A3A12", "#FFD12E", "#FFEE9E", "#FFF6DC"]   # amarelo (Karo, Skarp)
RUBI = ["#122634", "#4A1820", "#E0483A", "#FF9E7A", "#FFF6DC"]   # vermelho dos casacos (Karo, Luna, Caninus Black)
NOITE = ["#122634", "#1C2233", "#3D4566", "#9AA6D6", "#FFF6DC"]  # Caninus Black (lâmina escura)
TOXICO = ["#122634", "#2E4A12", "#9BE348", "#D7FF6A", "#F4FFD0"]
TINTA = ["#0C1820", "#122634"]
FIM = [[0, 1], [0.7, 1], [1, 0]]
SOMBRA = TINTA


# ---------------- peças da linguagem Fauriana
def raios(n=4, delay=0.0, y=1.0, ramp=None, size=1.1, life=0.24, em=None):
    """os raios em zigue-zague das artes: estouram para fora do acerto"""
    d = {"p": "raio_zz", "blend": "mix", "amount": n, "size": [size, size * 0.6], "radius": 0.55, "speed": [3, 6], "spread": 180,
         "explosive": 0.9, "damp": [6, 8], "angle": [0, 360], "life": life, "life_rand": 0.2,
         "curve": [[0, 0.2], [0.2, 1.15], [1, 0.9]], "erode": 1.0, "erode_pow": 1.5, "ramp": ramp or POP, "alpha": FIM,
         "y": y, "delay": delay}
    if em:
        d["em"] = em
    return d


def estouro_hq(size=2.0, delay=0.0, y=0.95, ramp=None, life=0.28):
    """balão de estouro de quadrinho (pontas) com retícula"""
    return {"p": "estouro_b", "blend": "mix", "amount": 1, "size": size, "life": life, "life_rand": 0, "angle": [-15, 15],
            "curve": [[0, 0.3], [0.18, 1.1], [1, 1.15]], "erode": 1.0, "erode_pow": 1.5, "ramp": ramp or POP, "halftone": 0.35,
            "alpha": FIM, "y": y, "delay": delay, "nucleo": True}


def pontos(n=12, cor="#FFD12E", delay=0.0, y=0.95, size=0.17):
    return {"p": "ponto", "blend": "mix", "amount": n, "size": size, "scale": [0.5, 1.5], "speed": [4, 10], "spread": 180,
            "grav": -5, "damp": [3, 6], "life": 0.55, "life_rand": 0.4, "curve": [[0, 1], [0.6, 0.8], [1, 0]],
            "ramp": [cor, cor], "alpha": FIM, "y": y, "delay": delay}


def acerto(k=1.0, delay=0.0, y=0.95, ramp=None, ramp2=None, tremor=0.24, cor="#FFD12E"):
    """acerto padrão Fauriano: clarão, estouro de HQ, estrela, raios em zigue-zague e respingos"""
    r = ramp or POP
    r2 = ramp2 or LIMA
    return {"layers": [luz(r[2], 2.8 * k, 3.2, 0.24, y, delay), estouro_hq(1.8 * k, delay, y, r), Z.estrela(1.5 * k, delay, y, r2, 0.2),
                       raios(int(3 + 2 * k), delay + 0.02, y, r2, 1.0 * k), Z.faisca(int(10 * k), delay, y, r[1:]),
                       pontos(int(10 * k), cor, delay + 0.02, y)],
            "shake": tremor, "shake_delay": delay}


def garras(ramp=None, size=2.0, delay=0.0, y=1.0, ang=-30, n=1):
    return {"p": "garras_chao", "blend": "mix", "amount": n, "size": size, "life": 0.26, "life_rand": 0, "angle": [ang, ang],
            "curve": [[0, 0.4], [0.2, 1.08], [1, 1.12]], "erode": 1.0, "erode_pow": 1.3, "ramp": ramp or POP, "alpha": FIM,
            "y": y, "delay": delay}


def corte(tex="lamina", size=2.6, aim_off=0.0, delay=0.0, ramp=None, toward=0.3, life=0.24, y=0.95):
    return Z.corte(tex, size, aim_off, delay, ramp or POP, toward, life, y)


def voa(tex, n, size, ramp, delay=0.0, y=1.0, speed=(4, 8), grav=-10, spin=(-400, 400), life=0.5, spread=180, dirv=None):
    d = {"p": tex, "blend": "mix", "mode": "bill", "amount": n, "size": list(size) if isinstance(size, (list, tuple)) else size,
         "speed": list(speed), "spread": spread, "grav": grav, "damp": [2, 4], "spin": list(spin), "life": life, "life_rand": 0.3,
         "ramp": ramp, "alpha": FIM, "y": y, "delay": delay}
    if dirv:
        d["dir"] = dirv
    return d


def risco_vel(ramp=None, delay=0.0, y=1.0, n=6, em="from"):
    """linhas de velocidade de HQ saindo de quem ataca, na direção do alvo"""
    return {"em": em, "p": "feixe", "blend": "mix", "mode": "vel", "amount": n, "size": [0.08, 1.6], "speed": [16, 22],
            "dir": "toward", "spread": 8, "radius": 0.5, "explosive": 0.8, "life": 0.16, "ramp": ramp or POP[1:],
            "alpha": FIM, "y": y, "delay": delay}


# ================= efeitos por personagem =================
def especiais():
    R = {}

    def add(rid, nome, cid, d):
        R[rid] = {"nome": "FAURIANOS · " + nome, "personagem": cid, **d}

    # KARO (comandante) — Golpe do Chefe do Clã: cauda em meia-lua dourada e soco que estoura o balão de HQ
    add("fau_karo_ataque", "Karo Primepatas · Golpe do Chefe", "karo", merge(
        {"layers": [corte("crescente", 2.8, 90, 0.0, OURO, 0.3, 0.26, 1.0), Z.objeto("punho", 1.6, 0.1, RUBI, 1.0, 0.5, 0.22),
                    raios(3, 0.0, 1.3, OURO, 1.2, em="from")]},
        acerto(1.25, 0.12, 0.95, POP, OURO, 0.34),
        {"layers": [voa("crescente", 3, [0.35, 0.5], OURO, 0.14, 1.0, (4, 7))]}))

    # KARU — Chute Acrobático: giro com duas meias-luas e poeira (ele pula 1 casa depois do golpe)
    add("fau_karu_ataque", "Karu Primepatas · Chute Acrobático", "karu", merge(
        {"layers": [corte("lamina", 2.4, 60, 0.0, LIMA, 0.3, 0.2, 0.7), corte("lamina", 2.6, -120, 0.08, POP, 0.3, 0.2, 1.3),
                    poeira(4, 0.0, 0.2, 1.0)]},
        acerto(1.0, 0.1, 1.0, POP, LIMA, 0.24)))

    # VEXA — Fogo de Raposa: uma chama-espírito laranja voa até a presa e explode em três unhadas
    add("fau_vexa_ataque", "Vexa · Fogo de Raposa", "vexa",
        {"hit": "fau_vexa_hit", "proj": Z.proj([Z.miolo("pena", 0.95, POP[2:]),
                                               {"p": "pena", "blend": "mix", "trail": True, "amount": 10, "size": 0.4, "speed": [0.2, 0.8],
                                                "angle": [-30, 30], "life": 0.26, "ramp": POP, "alpha": [[0, 1], [1, 0]], "curve": [[0, 1], [1, 0.3]]}],
                                              20, 0.4, 1.1)})
    add("fau_vexa_hit", "Vexa · Caçada", "vexa", merge(
        {"layers": [garras(POP, 2.0, 0.0, 1.0, -35), garras(LIMA, 1.6, 0.08, 1.0, 145)]},
        acerto(1.0, 0.0, 1.0, POP, LIMA, 0.24)))

    # RHOMBO — Chifrada: linhas de velocidade, o chifre atravessa e o chão racha
    add("fau_rhombo_ataque", "Rhombo · Chifrada", "rhombo", merge(
        {"layers": [{"p": "feixe", "blend": "mix", "mode": "vel", "amount": 7, "size": [0.08, 1.6], "speed": [14, 20], "dir": "away", "spread": 6, "radius": 0.5, "explosive": 0.8, "toward": 1.6, "life": 0.18, "ramp": POP[1:], "alpha": FIM, "y": 1.0}, Z.objeto("chifre", [2.6, 1.0], 0.04, POP, 1.0, 0.9, 0.22, aim_off=180),
                    racha(2.6, 0.1, ["#122634", "#263E49", "#FF8236", "#FFD12E"]), pedregulhos(8, 0.1, 0.4)]},
        acerto(1.4, 0.1, 0.95, POP, LIMA, 0.5)))

    # GORUN — Tiro Pesado: clarão no cano, traçante laranja grosso e estouro
    add("fau_gorun_ataque", "Gorun · Tiro Pesado", "gorun", merge(
        {"layers": [{"em": "from", **luz("#ff8236", 3.0, 3.0, 0.2, 1.2)}, Z.estrela(1.4, 0.0, 1.2, POP, 0.14, em="from"),
                    raios(2, 0.0, 1.2, POP, 0.8, 0.18, em="from"),
                    {**Z.laser(POP[1:], 0.32, 0.18, 0.02, 1.15, 3.0), "ramp_sombra": SOMBRA}]},
        acerto(1.2, 0.06, 1.0, POP, LIMA, 0.3),
        {"hit_t": 0.06, "layers": []}))
    # Projétil Animal (ativa): o tiro vira uma fera de energia que ruge e atravessa as casas seguintes
    add("fau_gorun_animal", "Gorun · Projétil Animal", "gorun", merge(
        {"layers": [{"em": "from", **luz("#9be348", 4.0, 4.0, 0.4, 1.2)}, raios(5, 0.0, 1.2, LIMA, 1.4, 0.3, em="from"),
                    estouro_hq(2.2, 0.0, 1.2, LIMA, 0.3) | {"em": "from"},
                    {**Z.laser(LIMA[1:], 0.7, 0.42, 0.1, 1.15, 2.0), "ramp_sombra": SOMBRA},
                    {**Z.laser(POP[1:], 0.32, 0.36, 0.12, 1.15, 3.0), "ramp_sombra": SOMBRA},
                    # a fera: bocarra que avança e continua depois do alvo
                    {"p": "garra_grande", "blend": "mix", "mode": "vel", "amount": 1, "size": [1.8, 1.8], "speed": [9, 9],
                     "dir": "away", "spread": 0, "life": 0.4, "life_rand": 0, "toward": 1.8, "y": 1.2, "ramp": LIMA,
                     "alpha": [[0, 0], [0.15, 1], [0.8, 1], [1, 0]], "curve": [[0, 0.6], [0.3, 1.1], [1, 1.2]], "delay": 0.1},
                    {"p": "raio_zz", "blend": "mix", "mode": "vel", "amount": 6, "size": [0.5, 1.5], "speed": [18, 24], "dir": "away",
                     "spread": 12, "life": 0.35, "toward": 0.6, "y": 1.2, "ramp": POP, "alpha": FIM, "delay": 0.14}]},
        acerto(1.6, 0.16, 1.0, LIMA, POP, 0.6),
        {"layers": [anel_chao(3.4, POP, 0.18, 0.5, dentes=True)], "hit_t": 0.16}))

    # MANTIS KAI — Foices Gêmeas: duas foices em X e a cura volta para ele em gotinhas lima
    add("fau_mantis_ataque", "Mantis Kai · Foices Gêmeas", "mantis", merge(
        {"layers": [corte("lamina", 2.6, -40, 0.0, LIMA, 0.3, 0.2), corte("lamina", 2.6, 140, 0.06, LIMA, 0.3, 0.2),
                    {"em": "from", "p": "brilho", "blend": "mix", "amount": 8, "size": 0.3, "ring": 0.6, "ring_h": 1.6,
                     "speed": [1, 2], "dir": [0, 1, 0], "spread": 10, "life": 0.6, "ramp": TOXICO[1:], "alpha": FIM, "y": 0.2,
                     "delay": 0.25}]},
        acerto(1.05, 0.08, 1.0, LIMA, POP, 0.26, "#9BE348")))

    # ZABOO — Scratch: o disco gira e risca o alvo; notas e ondas de som saltam
    add("fau_zaboo_ataque", "Zaboo · Scratch", "zaboo", merge(
        {"layers": [Z.objeto("vinil", 1.5, 0.0, CIANO, 1.0, 0.6, 0.3, aim=False, spin=(900, 900)),
                    {"p": "arco_som", "blend": "mix", "amount": 3, "size": [2.2, 0.8], "life": 0.32, "life_rand": 0, "explosive": 0.5,
                     "aim": True, "toward": 0.9, "y": 1.1, "curve": [[0, 0.4], [1, 1.2]], "erode": 1.0, "erode_pow": 1.4,
                     "ramp": LIMA, "alpha": FIM},
                    voa("nota", 4, [0.35, 0.55], POP, 0.08, 1.2, (3, 6), 3, (-40, 40), 0.6)]},
        acerto(0.9, 0.12, 1.0, CIANO, LIMA, 0.2, "#55D7EB")))

    # CANINUS BLACK — Execução: corte escuro em diagonal, o brilho vermelho do olho e unhadas
    add("fau_caninus_black_ataque", "Caninus Black · Execução", "caninus_black", merge(
        {"layers": [Z.estrela(0.8, 0.0, 1.6, RUBI, 0.18, em="from"), corte("lamina", 3.0, -50, 0.04, NOITE, 0.3, 0.22),
                    garras(RUBI, 1.9, 0.1, 1.0, 140)]},
        acerto(1.2, 0.08, 1.0, RUBI, NOITE, 0.34, "#E0483A")))

    # BRAZUCÃO — Gambiarra: chave inglesa no cocuruto, porcas e engrenagens voando
    add("fau_brazucao_ataque", "Brazucão · Gambiarra", "brazucao", merge(
        {"layers": [Z.objeto("chave", 1.8, 0.0, POP, 1.3, 0.4, 0.26, aim=False, spin=(-700, -700)),
                    voa("engrenagem", 3, [0.3, 0.5], CIANO, 0.06, 1.1, (4, 8)), voa("moeda", 3, [0.2, 0.3], OURO, 0.06, 1.1, (4, 8))]},
        acerto(0.9, 0.08, 1.0, POP, CIANO, 0.22)))

    # TORK — Soco Bomba: punho de casco e explosão de verdade
    add("fau_tork_ataque", "Tork · Soco Bomba", "tork", merge(
        {"layers": [Z.objeto("punho", 2.0, 0.0, LIMA, 1.0, 0.5, 0.24),
                    {"p": "estouro", "blend": "mix", "amount": 1, "size": 2.8, "life": 0.36, "life_rand": 0, "angle": [0, 360],
                     "curve": [[0, 0.3], [0.2, 1.0], [1, 1.15]], "erode": 1.0, "erode_pow": 1.4, "ramp": POP, "halftone": 0.3,
                     "alpha": FIM, "y": 1.0, "delay": 0.06},
                    poeira(6, 0.1, 0.4, 1.5), anel_chao(3.2, POP, 0.08, 0.5, dentes=True)]},
        acerto(1.4, 0.06, 1.0, POP, LIMA, 0.55)))

    # ASTRAX — Investida do Bastião: escudo de frente, penas brancas e estouro ciano
    add("fau_astrax_ataque", "Astrax · Investida do Bastião", "astrax", merge(
        {"layers": [Z.objeto("hex_oco", 1.9, 0.0, CIANO, 1.0, 0.5, 0.24, aim=False) | {"p": "anel"},
                    voa("pena", 6, [0.3, 0.5], ["#122634", "#3D4566", "#C8D2F0", "#F4F6FF"], 0.04, 1.2, (3, 6), 2, (-200, 200), 0.6)]},
        acerto(1.1, 0.04, 1.0, CIANO, POP, 0.32, "#55D7EB")))

    # NOKKA — Gargalhada: um redemoinho lima gira até o alvo e explode em ondas que confundem
    add("fau_nokka_ataque", "Nokka · Gargalhada", "nokka",
        {"hit": "fau_nokka_hit", "proj": Z.proj([{"p": "anel_serra", "blend": "mix", "one_shot": False, "amount": 2, "size": 0.8, "life": 0.1,
                                                  "angle": [0, 0], "spin": [900, 900], "ramp": LIMA, "alpha": [[0, 1], [1, 0.8]]},
                                                 Z.miolo("brilho", 0.5, LIMA[2:]),
                                                 {"p": "raio_zz", "blend": "mix", "trail": True, "amount": 8, "size": [0.6, 0.35],
                                                  "angle": [0, 360], "speed": [0.3, 1.0], "life": 0.25, "ramp": POP, "alpha": [[0, 1], [1, 0]],
                                                  "curve": [[0, 1], [1, 0.3]]}], 17, 0.6, 1.2)})
    add("fau_nokka_hit", "Nokka · Ruído", "nokka", merge(
        {"layers": [{"p": "arco_som", "blend": "mix", "amount": 4, "size": [2.4, 0.9], "life": 0.36, "life_rand": 0.2, "angle": [0, 360],
                     "explosive": 0.6, "y": 1.0, "curve": [[0, 0.3], [1, 1.4]], "erode": 1.0, "ramp": LIMA, "alpha": FIM},
                    anel_chao(2.8, LIMA, 0.0, 0.5, dentes=False)]},
        acerto(1.0, 0.0, 1.0, LIMA, POP, 0.24, "#9BE348")))

    # CANINUS WHITE — Reflexo: o mesmo corte do irmão, espelhado e em ciano limpo
    add("fau_caninus_white_ataque", "Caninus White · Reflexo", "caninus_white", merge(
        {"layers": [Z.estrela(0.8, 0.0, 1.6, CIANO, 0.18, em="from"), corte("lamina", 3.0, 130, 0.04, CIANO, 0.3, 0.22),
                    garras(CIANO, 1.9, 0.1, 1.0, -40)]},
        acerto(1.15, 0.08, 1.0, CIANO, POP, 0.3, "#C8F6FF")))

    # RAPPY — Bombinha: a bomba voa em arco, quica e explode com confete
    add("fau_rappy_ataque", "Rappy · Bombinha", "rappy",
        {"hit": "fau_rappy_hit", "proj": Z.proj([{"p": "mina", "blend": "mix", "one_shot": False, "amount": 2, "size": 0.55, "life": 0.1,
                                                  "angle": [0, 0], "spin": [500, 500], "ramp": POP, "alpha": [[0, 1], [1, 0.9]]},
                                                 {"p": "faisca", "blend": "mix", "trail": True, "amount": 10, "size": [0.05, 0.2],
                                                  "speed": [0.5, 2], "life": 0.2, "ramp": OURO[1:], "alpha": [[0, 1], [1, 0]]}], 13, 1.6, 1.0)})
    add("fau_rappy_hit", "Rappy · Explosão", "rappy", merge(
        {"layers": [{"p": "estouro", "blend": "mix", "amount": 1, "size": 2.6, "life": 0.34, "life_rand": 0, "angle": [0, 360],
                     "curve": [[0, 0.3], [0.2, 1.0], [1, 1.15]], "erode": 1.0, "erode_pow": 1.4, "ramp": POP, "halftone": 0.3,
                     "alpha": FIM, "y": 0.9},
                    voa("pixel", 10, [0.12, 0.22], LIMA, 0.02, 1.0, (5, 9), -8, (-600, 600), 0.6),
                    voa("pixel", 10, [0.12, 0.22], CIANO, 0.02, 1.0, (5, 9), -8, (-600, 600), 0.6), poeira(4, 0.06, 0.3, 1.3)]},
        acerto(1.2, 0.0, 0.9, POP, OURO, 0.42)))

    # CAMEO — Língua Camaleoa: a língua estala até o alvo e a pele dele pisca em glitch verde
    add("fau_cameo_ataque", "Cameo · Língua Camaleoa", "cameo", merge(
        {"layers": [{**Z.laser(["#3F5E1C", "#E07A9B", "#FFC7D6", "#FFF6DC"], 0.3, 0.16, 0.0, 1.3, 6.0), "ramp_sombra": SOMBRA},
                    Z.glitch(1.4, 0.08, 1.0, LIMA, 3, 0.24)]},
        acerto(0.9, 0.1, 1.0, LIMA, POP, 0.2, "#9BE348")))
    # Sistema Invadido (ativa): cadeado aberto sobre a peça e o código da ativa escorre até a Cameo
    add("fau_cameo_hack", "Cameo · Sistema Invadido", "cameo", merge(
        {"layers": [{"p": "cadeado", "blend": "mix", "amount": 1, "size": 1.3, "life": 0.7, "life_rand": 0, "angle": [0, 0],
                     "curve": [[0, 0.3], [0.15, 1.15], [0.3, 1.0], [1, 1.0]], "ramp": LIMA, "alpha": [[0, 0], [0.1, 1], [0.8, 1], [1, 0]],
                     "y": 2.4},
                    Z.glitch(1.8, 0.0, 1.1, LIMA, 5, 0.4), Z.glitch(1.2, 0.2, 1.3, POP, 3, 0.3),
                    Z.pixels(18, 0.1, 1.2, LIMA, (2, 6), (0.12, 0.26), 0.6),
                    {**Z.laser(LIMA[1:], 0.24, 0.5, 0.25, 1.4, 1.2, "at", "from"), "ramp_sombra": SOMBRA},
                    {"em": "from", **Z.glitch(1.4, 0.55, 1.1, LIMA, 3, 0.3)},
                    {"em": "from", **luz("#9be348", 3.0, 3.0, 0.4, 1.2, 0.55)}]},
        {"layers": [Z.estrela(1.4, 0.2, 2.4, LIMA, 0.2)], "shake": 0.2, "shake_delay": 0.2}))

    # PIPA — Rasante de Radar: o radar trava no alvo e um mini-míssil desce em arco
    add("fau_pipa_ataque", "Pipa · Rasante de Radar", "pipa", merge(
        {"layers": [{"p": "mira_hex", "mode": "chao", "amount": 1, "size": 2.2, "life": 0.4, "life_rand": 0, "y": 0.0, "angle": [0, 0],
                     "spin": [200, 200], "curve": [[0, 1.5], [1, 0.9]], "ramp": LIMA, "alpha": [[0, 0], [0.2, 1], [0.85, 1], [1, 0]]} | {"p": "anel_serra"},
                    anel_chao(2.8, LIMA, 0.0, 0.4, dentes=False),
                    {"sub": "fau_pipa_missil", "delay": 0.12}]},
        {"hit_t": 0.45, "layers": []}))
    add("fau_pipa_missil", "Pipa · Míssil", "pipa",
        {"hit": "fau_pipa_hit", "proj": Z.proj([{"p": "seta", "blend": "mix", "one_shot": False, "amount": 2, "size": [0.9, 0.4], "life": 0.1,
                                                 "aim": True, "ramp": POP, "alpha": [[0, 1], [1, 0.9]]},
                                                {"p": "fumaca", "blend": "mix", "trail": True, "amount": 10, "size": 0.35, "speed": [0.2, 0.6],
                                                 "life": 0.35, "halftone": 0.6, "ramp": ["#263E49", "#5A6E78", "#C8D2D8"], "alpha": [[0, 0.8], [1, 0]],
                                                 "curve": [[0, 0.6], [1, 1.3]]}], 18, 1.4, 1.2)})
    add("fau_pipa_hit", "Pipa · Acerto do Míssil", "pipa", merge(acerto(1.1, 0.0, 0.9, POP, LIMA, 0.32), {"layers": [poeira(4, 0.04, 0.3, 1.2)]}))

    # TUPI — Espuma Adesiva: um jato de espuma creme e lima gruda no alvo em bolhas
    add("fau_tupi_ataque", "Tupi · Jato de Espuma", "tupi", merge(
        {"layers": [{"p": "jato", "blend": "mix", "amount": 1, "size": [2.8, 1.1], "life": 0.26, "life_rand": 0, "aim": True, "toward": 0.9,
                     "y": 1.0, "curve": [[0, 0.3], [0.3, 1.05], [1, 1.15]], "erode": 1.0, "erode_pow": 1.3,
                     "ramp": ["#122634", "#3F5E1C", "#E4FF9E", "#FFF6DC"], "alpha": FIM},
                    voa("bolha", 10, [0.25, 0.55], ["#122634", "#3F5E1C", "#E4FF9E", "#FFF6DC"], 0.12, 1.0, (1, 4), 1, (0, 0), 0.7),
                    {"p": "respingo", "blend": "mix", "amount": 2, "size": 1.4, "life": 0.4, "life_rand": 0, "angle": [0, 360],
                     "curve": [[0, 0.3], [0.2, 1.0], [1, 1.05]], "erode": 1.0, "ramp": LIMA, "alpha": FIM, "y": 0.9, "delay": 0.12}]},
        acerto(0.8, 0.14, 1.0, LIMA, POP, 0.18, "#E4FF9E")))

    # LUNA NARI — Chifres da Comandante: dois cortes curvos em forma de galhada, vermelho e ouro
    add("fau_luna_ataque", "Luna Nari · Galhada", "luna", merge(
        {"layers": [corte("crescente", 2.6, 30, 0.0, RUBI, 0.3, 0.24, 1.3), corte("crescente", 2.6, 150, 0.0, RUBI, 0.3, 0.24, 1.3),
                    corte("lamina", 2.2, -90, 0.1, OURO, 0.2, 0.2, 1.0)]},
        acerto(1.15, 0.12, 1.0, RUBI, OURO, 0.3, "#FFD12E")))

    # SKARP — Chuva de Espinhos: espinhos disparados em leque, com raios amarelos
    add("fau_skarp_ataque", "Skarp · Chuva de Espinhos", "skarp", merge(
        {"layers": [{"p": "espeto", "blend": "mix", "mode": "vel", "amount": 7, "size": [0.18, 1.0], "speed": [12, 16],
                     "dir": "away", "spread": 10, "radius": 0.4, "explosive": 0.6, "toward": 2.0, "life": 0.2, "ramp": OURO, "alpha": FIM, "y": 1.1},
                    raios(3, 0.0, 1.2, OURO, 1.0, 0.2, em="from"),
                    {"p": "espinhos", "blend": "mix", "amount": 1, "size": 2.0, "life": 0.26, "life_rand": 0, "angle": [0, 360],
                     "curve": [[0, 0.3], [0.2, 1.1], [1, 1.15]], "erode": 1.0, "ramp": OURO, "alpha": FIM, "y": 1.0, "delay": 0.16}]},
        acerto(1.0, 0.16, 1.0, OURO, POP, 0.26),
        {"hit_t": 0.16, "layers": []}))

    # BRAKKA — Rajada de Penas: três penas nas cores da facção voam uma atrás da outra
    add("fau_brakka_ataque", "Brakka · Rajada de Penas", "brakka",
        {"hit": "fau_brakka_hit", "proj": Z.proj([{"p": "pena", "blend": "mix", "one_shot": False, "amount": 2, "size": 1.1, "life": 0.1,
                                                   "aim": True, "aim_off": -90, "ramp": POP, "alpha": [[0, 1], [1, 0.9]]},
                                                  {"p": "pena", "blend": "mix", "trail": True, "amount": 6, "size": 0.3, "speed": [0.3, 1.0],
                                                   "angle": [0, 360], "life": 0.25, "ramp": LIMA, "alpha": [[0, 1], [1, 0]]}], 22, 0.5, 1.6,
                                                 rajada={"n": 3, "gap": 0.1, "spread": 0.4, "dy": 0.1, "vy": 0.2})})
    add("fau_brakka_hit", "Brakka · Acerto", "brakka", merge(
        acerto(0.9, 0.0, 1.0, POP, CIANO, 0.18),
        {"layers": [voa("pena", 4, [0.3, 0.5], CIANO, 0.02, 1.0, (3, 6), 3, (-200, 200), 0.5)]}))

    # MUGGO — Marretada de Cerco: a chave gigante desce de cima e espirra água de brejo em anel
    add("fau_muggo_ataque", "Muggo · Marretada de Cerco", "muggo", merge(
        {"layers": [Z.objeto("chave", 2.6, 0.0, CIANO, 1.6, 0.3, 0.2, aim=False, curve=[[0, 1.4], [0.3, 1.0], [1, 1.0]], spin=(-300, -300)),
                    {"p": "respingo", "blend": "mix", "amount": 3, "size": 1.6, "life": 0.4, "life_rand": 0.2, "angle": [0, 360],
                     "radius": 0.4, "explosive": 0.8, "curve": [[0, 0.3], [0.2, 1.0], [1, 1.05]], "erode": 1.0, "ramp": LIMA, "alpha": FIM,
                     "y": 0.6, "delay": 0.12},
                    voa("gota", 10, [0.15, 0.3], LIMA, 0.12, 0.5, (5, 8), -14, (0, 0), 0.5, 40, [0, 1, 0]),
                    anel_chao(3.4, LIMA, 0.12, 0.5, dentes=True)]},
        acerto(1.3, 0.12, 0.95, POP, LIMA, 0.48)))

    # BORO — Bola de Tatu: ele vira bola e rola até o alvo, deixando rastro de poeira
    add("fau_boro_ataque", "Boro · Bola de Tatu", "boro",
        {"hit": "fau_boro_hit", "proj": Z.proj([{"p": "anel_serra", "blend": "mix", "one_shot": False, "amount": 2, "size": 1.0, "life": 0.1,
                                                 "angle": [0, 0], "spin": [-900, -900], "ramp": POP, "alpha": [[0, 1], [1, 0.9]]},
                                                {"p": "fumaca", "blend": "mix", "trail": True, "amount": 12, "size": 0.5, "speed": [0.2, 0.8],
                                                 "life": 0.45, "halftone": 0.7, "ramp": ["#292C35", "#493D3D", "#8A6A4A", "#C9A574"],
                                                 "alpha": [[0, 0.8], [1, 0]], "curve": [[0, 0.6], [1, 1.4]]}], 16, 0.0, 0.5)})
    add("fau_boro_hit", "Boro · Impacto", "boro", merge(
        acerto(1.15, 0.0, 0.6, POP, LIMA, 0.36), {"layers": [pedregulhos(6, 0.02, 0.3), poeira(4, 0.02, 0.2, 1.2)]}))

    # DRAKO — Mordida Tóxica: mandíbula de croco e veneno borbulhando
    add("fau_drako_ataque", "Drako · Mordida Tóxica", "drako", merge(
        {"layers": [{"p": "mandibula", "blend": "mix", "amount": 1, "size": 1.8, "life": 0.22, "life_rand": 0, "angle": [0, 0],
                     "curve": [[0, 1.3], [0.5, 0.9], [1, 0.85]], "ramp": TOXICO, "alpha": FIM, "y": 1.4},
                    {"p": "mandibula", "blend": "mix", "amount": 1, "size": 1.8, "life": 0.22, "life_rand": 0, "angle": [180, 180],
                     "curve": [[0, 1.3], [0.5, 0.9], [1, 0.85]], "ramp": TOXICO, "alpha": FIM, "y": 0.55},
                    voa("bolha", 8, [0.18, 0.4], TOXICO, 0.12, 1.0, (1, 3), 3, (0, 0), 0.8),
                    voa("gota", 6, [0.15, 0.25], TOXICO, 0.1, 1.0, (3, 5), -10, (0, 0), 0.5)]},
        acerto(1.05, 0.1, 1.0, TOXICO, POP, 0.28, "#9BE348")))
    return R


HABS = {"gorun": ["fau_gorun_animal"], "cameo": ["fau_cameo_hack"]}
NUCLEO = {"karo": "#FFD12E", "luna": "#E0483A", "caninus_black": "#E0483A", "caninus_white": "#55D7EB", "zaboo": "#55D7EB",
          "astrax": "#55D7EB", "mantis": "#9BE348", "nokka": "#9BE348", "cameo": "#9BE348", "tupi": "#9BE348", "drako": "#9BE348",
          "muggo": "#9BE348", "skarp": "#FFD12E"}


def main():
    cartas = json.load(open(CARTAS, encoding="utf-8"))["cards"]
    fau = [c for c in cartas if c.get("f") == "FAU"]
    rec = json.load(open(RECEITAS, encoding="utf-8"))
    pers = json.load(open(PERS, encoding="utf-8"))
    for k in [k for k in rec if k.startswith("fau_")]:
        del rec[k]
    esp = especiais()
    for rid, d in esp.items():
        rec[rid] = aplica(d)
        falhas = audita_receita(rec[rid])
        assert not falhas["valor"] and not falhas["tempo"], (rid, falhas)
    for c in fau:
        cid = c["id"]
        rid = "fau_%s_ataque" % cid
        assert rid in esp, "falta o ataque de " + cid
        pers[cid] = {"nucleo": NUCLEO.get(cid, "#FF8236"), "motivo": c["name"], "ataque": rid, "habilidades": HABS.get(cid, [])}
    json.dump(rec, open(RECEITAS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(pers, open(PERS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("FAU: ataques", len(fau), "| receitas", len(esp))


if __name__ == "__main__":
    main()
