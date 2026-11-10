"""FORJA dos KRIEG (paleta oficial: azul-chumbo primária, laranja queimado secundária, sombras azul-chumbo,
explosões âmbar; padrão de hachura). Gera o ataque básico (kri_<carta>_ataque) de cada carta da facção
e o núcleo em vfx_personagens.json. Usa as primitivas da forja (tools/vfx_ter.py) e passa tudo pelo guia.
python3 tools/vfx_kri.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from vfx_ter import (luz, estrela, estouro, anel_chao, racha, faisca, estilhaco, lascas,
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
    json.dump(rec, open(RECEITAS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(pers, open(PERS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("ataques KRI gerados:", len(kri))


if __name__ == "__main__":
    main()
