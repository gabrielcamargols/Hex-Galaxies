"""GUIA DE VFX aplicado à FORJA (regras do VFX Styleguide, seções III a VI).
Audita e ajusta as receitas data/vfx_receitas.json (ids ter_*, ou todas com --todas):
  VALOR   : nada de branco puro (100%) nem preto puro (0%); o VFX fica numa faixa própria.
  TEMPO   : efeito não pode ficar na tela tempo demais (vida máxima); todo efeito se dissipa (alpha cai no fim).
  COR     : uma cor de foco por efeito; cor oposta de apoio pede opacidade menor (aviso, não muda sozinho).
Uso:
  python3 tools/forja_guia.py            # relatório (não altera nada)
  python3 tools/forja_guia.py --aplicar  # aplica as correções de VALOR e TEMPO nas receitas ter_*
  python3 tools/forja_guia.py --aplicar --todas
"""
import json, os, sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
RECEITAS = os.path.join(ROOT, "data", "vfx_receitas.json")

BRANCO_MAX = "#F2EBDD"      # teto de valor: nada de #FFFFFF (100%)
PRETO_MIN = "#292C35"       # piso de valor: contorno de tinta, nunca #000
SUBSTITUI = {"#FFFFFF": BRANCO_MAX, "#FFFBE8": BRANCO_MAX, "#FFF6DC": "#F2E6CC", "#FFFFFE": BRANCO_MAX}
VIDA_MAX = 1.2              # segundos: acima disso o efeito "fica" na tela
LUZ_DUR_MAX = 0.9
FIM_ALFA = [[0, 1], [0.7, 1], [1, 0]]   # dissipação: a partir de 70% da vida, some


def _ajusta(no, ctx):
    """percorre o nó da receita; devolve o número de correções feitas"""
    n = 0
    if isinstance(no, dict):
        for k, v in list(no.items()):
            if k == "ramp" and isinstance(v, list):
                novo = [SUBSTITUI.get(str(c).upper(), c) for c in v]
                if novo != v:
                    no[k] = novo
                    n += 1
                    ctx["valor"] += 1
            elif k == "life" and isinstance(v, (int, float)) and v > VIDA_MAX:
                no[k] = VIDA_MAX
                n += 1
                ctx["tempo"] += 1
            elif k == "dur" and isinstance(v, (int, float)) and v > LUZ_DUR_MAX:
                no[k] = LUZ_DUR_MAX
                n += 1
                ctx["tempo"] += 1
            elif k == "alpha" and v == [[0, 1], [1, 1]]:
                no[k] = [list(p) for p in FIM_ALFA]
                n += 1
                ctx["tempo"] += 1
            else:
                n += _ajusta(v, ctx)
    elif isinstance(no, list):
        for v in no:
            n += _ajusta(v, ctx)
    return n


def _audita(no, out):
    if isinstance(no, dict):
        for k, v in no.items():
            if k == "ramp" and isinstance(v, list):
                for c in v:
                    if str(c).upper() in ("#FFFFFF", "#000000"):
                        out["valor"] += 1
            elif k == "life" and isinstance(v, (int, float)) and v > VIDA_MAX:
                out["tempo"] += 1
            elif k == "alpha" and v == [[0, 1], [1, 1]]:
                out["tempo"] += 1
            else:
                _audita(v, out)
    elif isinstance(no, list):
        for v in no:
            _audita(v, out)


def _cores_opostas(no):
    """aviso COR: efeito que mistura âmbar e turquesa (opostas) sem um lado discreto"""
    s = json.dumps(no).upper()
    return ("#FFAC45" in s or "#FFD97A" in s) and ("#4CD4BD" in s or "#B8FFDF" in s)


def main():
    aplicar = "--aplicar" in sys.argv
    todas = "--todas" in sys.argv
    rec = json.load(open(RECEITAS, encoding="utf-8"))
    alvo = [k for k in rec if not k.startswith("_") and isinstance(rec[k], dict) and (todas or k.startswith("ter_"))]
    tot = {"valor": 0, "tempo": 0}
    avisos = 0
    for k in alvo:
        out = {"valor": 0, "tempo": 0}
        _audita(rec[k], out)
        tot["valor"] += out["valor"]
        tot["tempo"] += out["tempo"]
        if _cores_opostas(rec[k]):
            avisos += 1
        if aplicar:
            _ajusta(rec[k], {"valor": 0, "tempo": 0})
    print("receitas auditadas: %d" % len(alvo))
    print("violações de VALOR (branco/preto puro): %d" % tot["valor"])
    print("violações de TEMPO (vida longa ou sem dissipação): %d" % tot["tempo"])
    print("avisos de COR (âmbar + turquesa no mesmo efeito): %d" % avisos)
    if aplicar:
        json.dump(rec, open(RECEITAS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print("correções aplicadas em", RECEITAS)


if __name__ == "__main__":
    main()
