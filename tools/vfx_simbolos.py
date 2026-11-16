"""Símbolos das facções no impacto dos ataques básicos (Abyssais, Zukunft, Faurianos, Valakianos, Wächter, Lithari).
O símbolo é a peça principal do impacto: aparece grande sobre o alvo com uma silhueta escura por trás
(destaca em qualquer chão), dá um pulo e marca o chão; o impacto próprio de cada personagem toca por cima.
Gera simbolo_<FAC> em data/vfx_receitas.json. python3 tools/vfx_simbolos.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from vfx_ter import luz
from forja_guia import aplica, audita_receita

ROOT = os.path.join(os.path.dirname(__file__), "..")
RECEITAS = os.path.join(ROOT, "data", "vfx_receitas.json")
PALETAS = os.path.join(ROOT, "data", "vfx_paletas.json")
FACS = {"ABY": ("aby", "Abyssais"), "ZUK": ("zuk", "Zukunft"), "FAU": ("fau", "Faurianos"), "TER": ("ter", "Valakianos"),
        "WAC": ("wac", "Wächter"), "LIT": ("lit", "Lithari")}


def receita(fac, pal):
    tex, nome = FACS[fac]
    ramp = [pal["shadow"], pal["secondary"], pal["primary"], pal["highlight"]]
    sombra = [pal["outline"], pal["outline"], pal["shadow"], pal["shadow"]]
    pop = [[0, 0.25], [0.14, 1.22], [0.3, 1.0], [1, 1.06]]
    alfa = [[0, 0], [0.08, 1], [0.72, 1], [1, 0]]
    return {"nome": "SÍMBOLO · %s (impacto do ataque)" % nome, "personagem": "", "alvo": "self", "layers": [
        luz(pal["primary"], 2.6, 2.8, 0.28, 1.3),
        # silhueta escura por trás e o símbolo por cima: ele é o centro do golpe
        {"p": "simbolo_%s_sombra" % tex, "blend": "mix", "amount": 1, "size": 1.95, "life": 0.6, "life_rand": 0, "angle": [0, 0],
         "curve": pop, "ramp": sombra, "alpha": [[0, 0], [0.08, 0.92], [0.72, 0.92], [1, 0]], "y": 1.28},
        {"p": "simbolo_%s" % tex, "blend": "mix", "amount": 1, "size": 1.8, "life": 0.6, "life_rand": 0, "angle": [0, 0],
         "curve": pop, "ramp": ramp, "alpha": alfa, "y": 1.3},
        # marca no chão que apaga devagar
        {"p": "simbolo_%s" % tex, "mode": "chao", "amount": 1, "size": 1.9, "life": 0.9, "life_rand": 0, "angle": [0, 0], "y": 0.02,
         "curve": [[0, 1.3], [0.2, 1.0], [1, 1.0]], "erode": 1.0, "erode_pow": 2.2, "ramp": ramp[:3],
         "alpha": [[0, 0], [0.12, 0.75], [0.7, 0.75], [1, 0]], "delay": 0.04}]}


def main():
    rec = json.load(open(RECEITAS, encoding="utf-8"))
    pal = json.load(open(PALETAS, encoding="utf-8"))
    for fac in FACS:
        p = pal[fac] if fac in pal else pal["factions"][fac]
        r = aplica(receita(fac, p))
        falhas = audita_receita(r)
        assert not falhas["valor"] and not falhas["tempo"], (fac, falhas)
        rec["simbolo_" + fac] = r
    json.dump(rec, open(RECEITAS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("símbolos gerados:", ", ".join("simbolo_" + f for f in FACS))


if __name__ == "__main__":
    main()
