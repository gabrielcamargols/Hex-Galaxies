"""FORJA dos KRIEG (paleta oficial: azul-chumbo primária, laranja queimado secundária, sombras azul-chumbo,
explosões âmbar; padrão de hachura). Gera o ataque básico (kri_<carta>_ataque) de cada carta da facção
e o núcleo em vfx_personagens.json. Usa as primitivas da forja (tools/vfx_ter.py) e passa tudo pelo guia.
python3 tools/vfx_kri.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from vfx_ter import (luz, estrela, estouro, anel_chao, racha, faisca, estilhaco, lascas, pedregulhos,
                     poeira, pontos, arco, impacto, merge)
from forja_guia import aplica, audita_receita

ROOT = os.path.join(os.path.dirname(__file__), "..")
RECEITAS = os.path.join(ROOT, "data", "vfx_receitas.json")
PERS = os.path.join(ROOT, "data", "vfx_personagens.json")
CARTAS = os.path.join(ROOT, "data", "cards.json")

# rampas de valor (escuro -> claro): sombra azul-chumbo, primária, explosão âmbar; topo creme (nunca branco puro)
LARANJA = ["#303744", "#8A3A12", "#FF742B", "#F3AD58", "#FFF6DC"]
AZUL = ["#182A4D", "#2864B4", "#777F8E", "#B9C0CC", "#FFF6DC"]
AMBAR = ["#303744", "#7A4A1E", "#F3AD58", "#FFD9A0", "#FFF6DC"]
NUCLEOS = ["#FF742B", "#2864B4", "#F3AD58"]


def rajada(c):
    """risco de tiro cerrado: arco de traço + faíscas de cano em linha"""
    return merge(
        {"layers": [luz("#f3ad58", 2.8, 3.2, 0.22, 0.9), arco(-10, 3.2, AZUL, 0.0, 0.5, 0.26)]},
        {"layers": [faisca(16, None, 0.02, 0.9), estilhaco(5, 0.04, 0.9, ramp=AZUL),
                    pontos(8, c, 0.04, 0.95), pontos(5, "#FF742B", 0.06, 0.95, 0.14)]},
        {"shake": 0.18, "shake_delay": 0.04, "layers": []})


def granada(c):
    """explosão de granada: estouro laranja, anel de chão e lascas de metal"""
    return merge(
        {"layers": [luz("#ff742b", 3.4, 3.8, 0.28, 1.0), estrela(2.4, LARANJA, 0.0, 0.26, 0.95),
                    estouro(1.9, AMBAR, 0.0, 0.3, 0.95), anel_chao(2.8, LARANJA, 0.0, 0.5, dentes=False)]},
        {"layers": [lascas(7, 0.03, 0.9, ramp=AZUL), faisca(12, None, 0.02, 0.9), pontos(10, c, 0.03, 0.95)]},
        {"shake": 0.3, "shake_delay": 0.0, "layers": []})


def coronhada(c):
    """golpe de coronha/blindagem: impacto pesado em aço azul com poeira"""
    return impacto(1.0, AZUL, 0.0, 0.95, tremor=0.32, cor_pts="#F3AD58", cor_pts2=c)


ESTILOS = [rajada, granada, coronhada]


# ================= identidade Krieg: tática (mira/marcação), guerrilha (fumaça suja, estilhaço), sangrenta, perigosa =================
SANGUE = ["#1E0A0E", "#5A0F16", "#A3161C", "#C8322C"]
FULIGEM = ["#16181F", "#303744", "#4A4F5C"]
FIM = [[0, 1], [0.7, 1], [1, 0]]
PROJETIL = "res://models/kri_projetil/projetil.fbx"
GRANADA = "res://models/kri_granada/granada.fbx"


def sangue(n=10, delay=0.0, y=0.95, k=1.0, chao=True):
    """respingo de sangue: gotas lançadas para longe de quem bateu + mancha atrás do alvo + poça no chão"""
    L = [{"p": "gota", "blend": "mix", "mode": "vel", "amount": int(n * k), "size": [0.14, 0.5], "speed": [4 * k, 10 * k], "dir": "away",
          "lift": 0.35, "spread": 32, "grav": -18, "damp": [1, 2], "life": 0.5, "curve": [[0, 1.0], [1, 0.5]], "ramp": SANGUE,
          "alpha": FIM, "y": y, "delay": delay},
         {"p": "respingo", "blend": "mix", "amount": 1, "size": 1.5 * k, "life": 0.32, "life_rand": 0, "aim": True, "toward": -0.45,
          "curve": [[0, 0.4], [0.25, 1.0], [1, 1.1]], "erode": 1.0, "erode_pow": 1.6, "ramp": SANGUE, "alpha": FIM, "y": y, "delay": delay}]
    if chao:
        L.append({"p": "respingo", "mode": "chao", "amount": 1, "size": 1.3 * k, "life": 1.2, "life_rand": 0, "y": 0.0, "angle": [0, 360],
                  "toward": -0.5, "curve": [[0, 0.3], [0.12, 1.0], [1, 1.0]], "erode": 1.0, "erode_pow": 2.5, "ramp": SANGUE[:3],
                  "alpha": FIM, "delay": delay + 0.1})
    return {"layers": L}


def fumaca_suja(n=6, delay=0.0, y=0.4, size=1.4, life=1.0):
    return {"p": "fumaca", "blend": "mix", "amount": n, "size": size, "speed": [0.8, 2.2], "dir": [0, 1, 0], "spread": 45,
            "life": life, "spin": [-40, 40], "curve": [[0, 0.5], [1, 1.4]], "erode": 1.0, "erode_pow": 1.1, "halftone": 0.8,
            "ramp": FULIGEM, "alpha": [[0, 0.75], [0.6, 0.6], [1, 0]], "y": y, "delay": delay, "radius": 0.45}


def mira(size=1.7, life=0.3, delay=0.0, y=0.95, ramp=None):
    """retículo que fecha no alvo: anel encolhendo + cruz fina"""
    r = ramp or LARANJA
    return [{"p": "anel", "blend": "mix", "amount": 1, "size": size, "life": life, "life_rand": 0, "angle": [0, 0],
             "curve": [[0, 1.5], [0.8, 0.6], [1, 0.55]], "ramp": r, "alpha": [[0, 0], [0.2, 1], [0.85, 1], [1, 0]], "y": y, "delay": delay},
            {"p": "estrela4", "blend": "mix", "amount": 1, "size": size * 0.9, "life": life, "life_rand": 0, "angle": [0, 0],
             "curve": [[0, 1.3], [0.8, 0.5], [1, 0.45]], "ramp": r, "alpha": [[0, 0], [0.2, 1], [0.85, 1], [1, 0]], "y": y, "delay": delay}]


def explosao(k=1.0, delay=0.0, y=0.8, tremor=0.5):
    """explosão seca dos Krieg: clarão laranja, estilhaço de aço, fumaça de fuligem, cratera"""
    return merge(
        impacto(k, LARANJA, delay, y, tremor=tremor, cor_pts="#F3AD58", cor_pts2="#FF742B"),
        {"layers": [estouro(2.3 * k, AMBAR, delay + 0.03, 0.34, y, "estouro_b"),
                    estilhaco(int(10 * k), delay, y, (8, 15), (0.2, 0.55), AZUL[:2]),
                    lascas(int(6 * k), delay, y, AZUL),
                    fumaca_suja(int(4 * k), delay + 0.14, 0.6, 1.1 * k)]})


# símbolo oficial dos Krieg (vfx/tex/krieg_simbolo.png): branco com retícula, a rampa pinta
SIMBOLO_RAMP = ["#16181F", "#8A3A12", "#FF742B", "#F3AD58"]


def simbolo(size=1.2, life=0.4, delay=0.0, y=1.8, chao=False, ramp=None, em=None):
    L = {"p": "krieg_simbolo", "blend": "mix", "amount": 1, "size": size, "life": life, "life_rand": 0, "angle": [0, 0],
         "ramp": ramp or SIMBOLO_RAMP, "delay": delay}
    if chao:
        L.update({"mode": "chao", "y": 0.02, "curve": [[0, 1.35], [0.18, 1.0], [1, 1.0]], "erode": 1.0, "erode_pow": 2.2,
                  "alpha": [[0, 0], [0.12, 1], [0.75, 1], [1, 0]]})
    else:
        L.update({"y": y, "curve": [[0, 0.4], [0.18, 1.15], [0.35, 1.0], [1, 1.05]], "halftone": 0.3,
                  "alpha": [[0, 0], [0.12, 1], [0.7, 1], [1, 0]]})
    if em:
        L["em"] = em
    return L


def simbolo_marcado(size=1.2, life=0.4, delay=0.0, y=1.8, em=None):
    """símbolo com sombra escura por trás (destaca em qualquer chão) e o desenho em laranja por cima"""
    fundo = simbolo(size * 1.06, life, delay, y - 0.02, em=em, ramp=["#0E0F14", "#16181F", "#16181F", "#1E1410"])
    fundo["p"] = "krieg_simbolo_sombra"
    fundo["alpha"] = [[0, 0], [0.12, 0.9], [0.7, 0.9], [1, 0]]
    frente = simbolo(size, life, delay, y, em=em, ramp=["#16181F", "#8A3A12", "#FF742B", "#FFB060"])
    return [fundo, frente]


def especiais():
    """efeitos únicos por personagem (substituem o ataque genérico e cobrem as habilidades)"""
    R = {}

    def add(rid, nome, cid, d):
        R[rid] = {"nome": "KRIEG · " + nome, "personagem": cid, **d}

    # ---------- COMANDANTE ----------
    add("kri_k_cmd_ataque", "Comandante · Sabre (ataque)", "k_cmd", merge(
        {"layers": [luz("#ff742b", 3.4, 3.6, 0.25, 0.95),
                    *simbolo_marcado(1.1, 0.5, 0.0, 2.0, em="from"),
                    arco(-28, 4.0, LARANJA, 0.0, 0.45, 0.28), arco(24, 3.0, AMBAR, 0.07, 0.45, 0.22),
                    faisca(14, None, 0.03, 0.95), pontos(8, "#F3AD58", 0.04, 0.95)]},
        sangue(12, 0.05, 0.95, 1.1),
        {"shake": 0.3, "shake_delay": 0.03, "layers": []}))
    add("kri_cmd_bombardeio", "Comandante · Bombardeio (marca, projétil do céu, cratera)", "k_cmd", merge(
        {"layers": mira(2.6, 0.5, 0.0, 0.1)[:1] + simbolo_marcado(1.9, 0.55, 0.0, 0.35) + [
            anel_chao(3.4, LARANJA, 0.0, 0.5, dentes=False, fecha=True),
            *simbolo_marcado(1.5, 0.6, 0.0, 2.6, em="from"),
            {"modelo": PROJETIL, "escala": 0.7, "rot": [-90, 0, 0], "life": 0.46, "y": 5.5, "de": [2.2, -1.0], "queda": True, "delay": 0.12},
            {"p": "faisca", "mode": "vel", "amount": 10, "size": [0.1, 0.9], "speed": [10, 16], "dir": [0, -1, 0], "spread": 6,
             "life": 0.25, "ramp": ["#FF742B", "#F3AD58", "#FFF6DC"], "curve": [[0, 1.2], [1, 0]], "y": 3.5, "delay": 0.36}]},
        explosao(1.6, 0.58, 0.7, tremor=0.75),
        {"layers": [racha(3.2, 0.6, ["#16181F", "#303744", "#FF742B", "#F3AD58"]), pedregulhos(10, 0.6, 0.5),
                    # o símbolo fica queimado na cratera
                    {**simbolo(2.2, 1.8, 0.66, chao=True, ramp=["#0E0F14", "#16181F", "#3A1A0C", "#8A3A12"]), "angle": [0, 0]},
                    fumaca_suja(4, 0.78, 0.9, 1.5, 1.1)], "hit_t": 0.58}))

    # ---------- SNIPER ----------
    add("kri_k_sniper_ataque", "Sniper · Mira Travada e tiro (ataque)", "k_sniper",
        {"layers": mira(1.8, 0.34, 0.0, 0.95) + [
            {"em": "from", **luz("#f3ad58", 3.0, 3.0, 0.16, 1.0, 0.3)},
            {"em": "from", **estrela(1.3, LARANJA, 0.3, 0.14, 1.0)},
            {"em": "from", **fumaca_suja(2, 0.34, 0.9, 0.6, 0.6)},
            {"sub": "kri_sniper_tiro", "delay": 0.3}], "hit_t": 0.44})
    add("kri_sniper_tiro", "Sniper · Traçante", "k_sniper",
        {"hit": "kri_sniper_hit",
         "proj": {"speed": 46, "arc": 0.0, "y": 1.0,
                  "modelo": {"modelo": PROJETIL, "escala": 0.1, "rot": [-90, 0, 0]},
                  "arpao": {"tex": "feixe", "len": 3.2, "width": 0.22, "tile": 3.2, "blend_top": "mix", "ramp": ["#8A3A12", "#FF742B", "#F3AD58", "#FFF6DC"],
                            "boost": 1.0, "halftone": 0.0, "sombra": 1.3, "nucleo": False},
                  "parts": [{"p": "faisca", "blend": "mix", "mode": "vel", "trail": True, "amount": 12, "size": [0.05, 0.4], "speed": [0.5, 2],
                             "life": 0.18, "ramp": ["#FF742B", "#F3AD58", "#FFF6DC"], "alpha": [[0, 1], [1, 0]], "curve": [[0, 1], [1, 0]]}]}})
    add("kri_sniper_hit", "Sniper · Acerto (atravessa o alvo)", "k_sniper", merge(
        {"layers": [luz("#ff742b", 2.6, 3.0, 0.2, 0.95), estrela(1.6, LARANJA, 0.0, 0.18, 0.95),
                    faisca(8, None, 0.0, 0.95, (8, 16), (0.1, 0.7), 0.25, 40, "away")]},
        sangue(16, 0.0, 0.95, 1.5),
        {"shake": 0.28, "shake_delay": 0.0, "layers": []}))

    # ---------- GRANADEIRO ----------
    gran_proj = {"speed": 11, "arc": 2.2, "y": 1.0,
                 "modelo": {"modelo": GRANADA, "escala": 0.3, "rot": [-90, 0, 0], "giro": 620},
                 "parts": [{"p": "fumaca", "blend": "mix", "trail": True, "amount": 8, "size": 0.4, "speed": [0.1, 0.4], "life": 0.4,
                            "curve": [[0, 0.7], [1, 0.3]], "erode": 1.0, "ramp": FULIGEM, "alpha": [[0, 0.8], [1, 0]]}]}
    add("kri_k_granadeiro_ataque", "Granadeiro · Granada em arco (ataque)", "k_granadeiro", {"hit": "kri_gran_boom", "proj": gran_proj})
    add("kri_gran_granada", "Granadeiro · Granada (habilidade e última granada)", "k_granadeiro", {"hit": "kri_gran_boom", "proj": gran_proj})
    add("kri_gran_boom", "Granadeiro · Explosão de estilhaços", "k_granadeiro", merge(
        explosao(1.2, 0.0, 0.8, tremor=0.55), sangue(10, 0.02, 0.9, 1.0)))
    add("kri_gran_saraivada", "Granadeiro · Saraivada (explosões em volta)", "k_granadeiro",
        {"alvo": "self", "layers": [
            luz("#ff742b", 4.0, 5.0, 0.3, 0.8),
            {"p": "estouro_b", "blend": "mix", "amount": 6, "size": 2.5, "life": 0.3, "life_rand": 0.1, "angle": [0, 360], "ring": 1.55,
             "explosive": 0.6, "curve": [[0, 0.3], [0.2, 1.0], [1, 1.1]], "erode": 1.0, "erode_pow": 1.4, "ramp": LARANJA, "halftone": 0.25,
             "alpha": FIM, "y": 0.7},
            {"p": "estrela4", "blend": "mix", "amount": 6, "size": 2.1, "life": 0.2, "life_rand": 0.1, "ring": 1.55, "explosive": 0.6,
             "curve": [[0, 0.2], [0.18, 1.2], [1, 0.25]], "ramp": AMBAR, "alpha": FIM, "y": 0.7},
            {"p": "estilhaco", "blend": "mix", "mode": "vel", "amount": 18, "size": [0.2, 0.5], "speed": [7, 13], "spread": 180, "flat": 0.8,
             "grav": -12, "damp": [3, 5], "life": 0.45, "erode": 0.9, "ramp": AZUL[:2], "alpha": FIM, "y": 0.6, "ring": 1.4},
            anel_chao(4.2, LARANJA, 0.0, 0.45, dentes=True),
            {**fumaca_suja(4, 0.16, 0.4, 1.0, 0.8), "ring": 1.5},
            {**pontos(18, "#F3AD58", 0.02, 0.6), "ring": 1.4}, {**faisca(18, None, 0.0, 0.6), "ring": 1.4}],
         "shake": 0.5, "shake_delay": 0.0})
    return R


HABS = {"k_cmd": ["kri_cmd_bombardeio"], "k_sniper": [], "k_granadeiro": ["kri_gran_granada", "kri_gran_saraivada"]}


def main():
    cartas = json.load(open(CARTAS, encoding="utf-8"))["cards"]
    kri = [c for c in cartas if c.get("f") == "KRI"]
    rec = json.load(open(RECEITAS, encoding="utf-8"))
    pers = json.load(open(PERS, encoding="utf-8"))
    for i, c in enumerate(kri):
        cid = c["id"]
        nucleo = NUCLEOS[i % len(NUCLEOS)]
        estilo = ESTILOS[i % len(ESTILOS)]
        d = estilo(nucleo)
        d = {"nome": "KRIEG · %s (ataque)" % c["name"], "personagem": cid, **d}
        rec["kri_%s_ataque" % cid] = aplica(d)
        falhas = audita_receita(rec["kri_%s_ataque" % cid])
        assert not falhas["valor"] and not falhas["tempo"], (cid, falhas)
        pers[cid] = {"nucleo": nucleo, "motivo": c["name"], "ataque": "kri_%s_ataque" % cid, "habilidades": []}
    esp = especiais()
    for rid, d in esp.items():
        rec[rid] = aplica(d)
        falhas = audita_receita(rec[rid])
        assert not falhas["valor"] and not falhas["tempo"], (rid, falhas)
    for cid, hs in HABS.items():
        pers[cid]["habilidades"] = hs
        pers[cid]["nucleo"] = "#F3AD58" if cid == "k_sniper" else "#FF742B"
    json.dump(rec, open(RECEITAS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(pers, open(PERS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("ataques KRI gerados:", len(kri), "| especiais:", len(esp))


if __name__ == "__main__":
    main()
