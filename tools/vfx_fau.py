"""FORJA dos FAUR IANOS (pop HQ: contorno de tinta, cores chapadas, acento lima/ciano).
Gera o ataque básico (fau_<carta>_ataque) de cada carta da facção e o núcleo em vfx_personagens.json.
Usa as mesmas primitivas da forja (tools/vfx_ter.py) e passa tudo pelo guia (tools/forja_guia.py).
python3 tools/vfx_fau.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from vfx_ter import (luz, estrela, estouro, anel_chao, racha, faisca, estilhaco, lascas, pedregulhos,
                     poeira, pontos, arco, impacto, merge)
from forja_guia import aplica, audita_receita

ROOT = os.path.join(os.path.dirname(__file__), "..")
RECEITAS = os.path.join(ROOT, "data", "vfx_receitas.json")
PERS = os.path.join(ROOT, "data", "vfx_personagens.json")
CARTAS = os.path.join(ROOT, "data", "cards.json")

# rampas de valor: 0 = contorno de tinta, 4 = creme (nunca 0% nem 100%)
POP = ["#122634", "#263E49", "#FF8236", "#FFD12E", "#FFF6DC"]    # laranja (primária)
LIMA = ["#122634", "#3F5E1C", "#9BE348", "#E4FF9E", "#FFF6DC"]   # lima (secundária)
CIANO = ["#122634", "#1F4F5A", "#55D7EB", "#C8F6FF", "#FFF6DC"]  # ciano (extra)
NUCLEOS = ["#FFD12E", "#9BE348", "#55D7EB", "#FF8236"]


def garra(c):
    """três cortes curvos + lascas: ataque de unhada"""
    return merge(
        {"layers": [luz("#ff8236", 3.0, 3.4, 0.25, 0.9), arco(-20, 3.0, POP, 0.0, 0.5, 0.28)]},
        {"layers": [estilhaco(7, 0.05, 0.9, ramp=LIMA), lascas(6, 0.05, 0.9, ramp=POP),
                    pontos(10, c, 0.04, 0.95), pontos(6, "#55D7EB", 0.06, 0.95, 0.14)]},
        {"shake": 0.22, "shake_delay": 0.05, "layers": []})


def mordida(c):
    """estrela de impacto + dentes em anel: ataque de mordida"""
    return merge(
        {"layers": [luz("#9be348", 3.2, 3.6, 0.28, 1.0), estrela(2.2, POP, 0.0, 0.24, 0.95),
                    estouro(1.5, LIMA, 0.0, 0.26, 0.95), anel_chao(2.4, POP, 0.0, 0.45, dentes=True)]},
        {"layers": [faisca(14, None, 0.02, 0.9), pontos(12, c, 0.02, 0.95)]},
        {"shake": 0.25, "shake_delay": 0.0, "layers": []})


def pancada(c):
    """impacto pesado (base da pancada dos Valakianos, nas cores pop)"""
    return impacto(1.0, POP, 0.0, 0.95, tremor=0.3, cor_pts="#FFD12E", cor_pts2=c)


ESTILOS = [garra, mordida, pancada]


def main():
    cartas = json.load(open(CARTAS, encoding="utf-8"))["cards"]
    fau = [c for c in cartas if c.get("f") == "FAU"]
    rec = json.load(open(RECEITAS, encoding="utf-8"))
    pers = json.load(open(PERS, encoding="utf-8"))
    for i, c in enumerate(fau):
        cid = c["id"]
        nucleo = NUCLEOS[i % len(NUCLEOS)]
        estilo = ESTILOS[i % len(ESTILOS)]
        d = estilo(nucleo)
        d = {"nome": "FAURIANOS · %s (ataque)" % c["name"], "personagem": cid, **d}
        rec["fau_%s_ataque" % cid] = aplica(d)
        falhas = audita_receita(rec["fau_%s_ataque" % cid])
        assert not falhas["valor"] and not falhas["tempo"], (cid, falhas)
        pers[cid] = {"nucleo": nucleo, "motivo": c["name"], "ataque": "fau_%s_ataque" % cid, "habilidades": []}
    json.dump(rec, open(RECEITAS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(pers, open(PERS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("ataques FAU gerados:", len(fau))


if __name__ == "__main__":
    main()
