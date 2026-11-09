"""Hex Galaxies - relatório de balanceamento a partir do JSON do modo --balance.

Uso: python tools/balance_report.py resultado.json [saida.md]
Mostra: vitórias por facção (geral e por mapa), matriz de confronto, vantagem de quem começa,
como as partidas terminam, uso e efeito das ativas dos líderes, tropas que mais vencem/morrem e táticas.
"""
import json, sys, collections, math

FN = {"FAU": "Faurianos", "ABY": "Abyssais", "KRI": "Krieg", "WAC": "Wächter", "ZUK": "Zukunft", "LIT": "Lithari", "TER": "Valakianos"}
LEAD = {"FAU": "Karo", "ABY": "Rhazur", "KRI": "Krieg Comandante", "WAC": "Mamute", "ZUK": "Dragão", "LIT": "Lithari General", "TER": "Rei da Mina"}


def score(rs, fac):
    w = l = d = 0
    for r in rs:
        side = 0 if r["a"] == fac else (1 if r["b"] == fac else None)
        if side is None:
            continue
        if r["winner"] == 2:
            d += 1
        elif r["winner"] == side:
            w += 1
        else:
            l += 1
    n = w + l + d
    return (w + 0.5 * d) / n if n else 0.0, n, w, l, d


def ci(p, n):
    return 1.96 * math.sqrt(max(p * (1 - p), 1e-9) / max(n, 1))


def main():
    rs = json.load(open(sys.argv[1]))
    out = []
    P = out.append
    facs = sorted({r["a"] for r in rs})
    maps = sorted({r["map"] for r in rs})
    P("# Relatório de balanceamento (%d partidas CPU x CPU)\n" % len(rs))
    P("## Vitórias por facção\n")
    P("| Facção | Geral | " + " | ".join(m for m in maps) + " |")
    P("|---|---|" + "---|" * len(maps))
    rows = []
    for f in facs:
        g = score(rs, f)
        cols = []
        for m in maps:
            s = score([r for r in rs if r["map"] == m], f)
            cols.append("%.0f%%" % (s[0] * 100))
        rows.append((g[0], f, cols, g))
    for g0, f, cols, g in sorted(rows, reverse=True):
        P("| %s | **%.0f%%** ±%.0f | %s |" % (FN[f], g0 * 100, ci(g0, g[1]) * 100, " | ".join(cols)))
    P("\n## Confrontos (vitórias da facção da linha contra a da coluna)\n")
    P("| | " + " | ".join(FN[f][:4] for f in facs) + " |")
    P("|---|" + "---|" * len(facs))
    for a in facs:
        cells = []
        for b in facs:
            if a == b:
                cells.append("—")
                continue
            sub = [r for r in rs if {r["a"], r["b"]} == {a, b}]
            cells.append("%.0f%%" % (score(sub, a)[0] * 100))
        P("| %s | %s |" % (FN[a], " | ".join(cells)))
    # primeiro jogador
    fw = sum(1 for r in rs if r["winner"] == r["first"])
    nd = sum(1 for r in rs if r["winner"] != 2)
    P("\n## Ritmo das partidas\n")
    P("- Quem começa o round 1 vence %.0f%% das partidas decididas." % (100 * fw / max(nd, 1)))
    s0 = sum(1 for r in rs if r["winner"] == 0)
    P("- Lado 0 (entrada de baixo) vence %.0f%%." % (100 * s0 / max(nd, 1)))
    for m in maps:
        sub = [r for r in rs if r["map"] == m]
        ko = [r for r in sub if not r["by_score"]]
        P("- %s: %.0f%% terminam com o comandante derrotado (round médio %.1f), %.0f%% vão à contagem do round 10, %.0f%% empates." % (
            m, 100 * len(ko) / len(sub), sum(r["round"] for r in ko) / max(len(ko), 1),
            100 * sum(1 for r in sub if r["by_score"]) / len(sub), 100 * sum(1 for r in sub if r["winner"] == 2) / len(sub)))
    P("\n## Líderes: ativa de uso único\n")
    P("| Líder | Usou a ativa | Vitória quando usa | Vitória quando não usa | Vida final média |")
    P("|---|---|---|---|---|")
    for f in facs:
        used = nused = wu = wn = 0
        hp = []
        for r in rs:
            for side, fac in ((0, r["a"]), (1, r["b"])):
                if fac != f:
                    continue
                hp.append(r["cmd_hp"][side])
                win = r["winner"] == side
                if r["ults"][side]:
                    used += 1
                    wu += win
                else:
                    nused += 1
                    wn += win
        P("| %s | %.0f%% | %s | %s | %.1f |" % (LEAD[f], 100 * used / max(used + nused, 1),
                                                 ("%.0f%%" % (100 * wu / used)) if used else "—",
                                                 ("%.0f%%" % (100 * wn / nused)) if nused else "—", sum(hp) / max(len(hp), 1)))
    # tropas
    st = collections.defaultdict(lambda: {"n": 0, "win": 0, "alive": 0, "kills": 0, "f": ""})
    for r in rs:
        for u in r["units"]:
            s = st[u["id"]]
            s["n"] += 1
            s["win"] += r["winner"] == u["p"]
            s["alive"] += u["alive"]
            s["kills"] += u["kills"]
            s["f"] = r["a"] if u["p"] == 0 else r["b"]
    rowsu = []
    for k, s in st.items():
        if s["n"] < 40:
            continue
        rowsu.append((s["win"] / s["n"], k, s))
    rowsu.sort(reverse=True)
    P("\n## Tropas (aparecem em 40+ partidas)\n")
    P("Mais vitoriosas:\n")
    P("| Tropa | Facção | Vitórias com ela | Sobrevive | Abates/partida |")
    P("|---|---|---|---|---|")
    for w, k, s in rowsu[:8]:
        P("| %s | %s | %.0f%% | %.0f%% | %.2f |" % (k, FN[s["f"]], 100 * w, 100 * s["alive"] / s["n"], s["kills"] / s["n"]))
    P("\nMenos vitoriosas:\n")
    P("| Tropa | Facção | Vitórias com ela | Sobrevive | Abates/partida |")
    P("|---|---|---|---|---|")
    for w, k, s in rowsu[-8:][::-1]:
        P("| %s | %s | %.0f%% | %.0f%% | %.2f |" % (k, FN[s["f"]], 100 * w, 100 * s["alive"] / s["n"], s["kills"] / s["n"]))
    # táticas
    tc = collections.Counter()
    tw = collections.Counter()
    for r in rs:
        for side in (0, 1):
            for k, v in r["tactics"][side].items():
                tc[k] += v
                if r["winner"] == side:
                    tw[k] += v
    P("\n## Táticas mais usadas pela CPU\n")
    P("| Tática | Usos | % em partidas vencidas |")
    P("|---|---|---|")
    for k, v in tc.most_common():
        P("| %s | %d | %.0f%% |" % (k, v, 100 * tw[k] / v))
    txt = "\n".join(out)
    if len(sys.argv) > 2:
        open(sys.argv[2], "w").write(txt)
    print(txt)


if __name__ == "__main__":
    main()
