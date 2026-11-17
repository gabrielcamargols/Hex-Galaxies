"""Mudanças de level design aprovadas na auditoria dos planetas (17/11/2026), aplicadas em data/maps.json.
Roda uma vez sobre o maps.json original; cada planeta registra "ajuste_auditoria" para não aplicar de novo.
python3 tools/auditoria/ajusta_mapas.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import planeja as P

ARQ = os.path.join(P.ROOT, "data", "maps.json")


def espelho_m(h):
    """Abnara e Gor'Aida: espelho esquerda/direita do dossiê (troca q com s)"""
    return (-h[0] - h[1], h[1])


def linhas_longas(M):
    return P.corredores(M)


def escolhe_bloqueios(M, n, cand, espelho, longe_de, espaco=3, max_custo=None, tipo="rocha"):
    """escolhe n pares espelhados de obstáculos de abrigo: nota = corredores de tiro cortados + casas que ganham
    abrigo ao lado; nunca fecha caminho nem deixa o caminho base a base acima de max_custo"""
    escolhidas = []
    for it in range(n):
        conta = {}
        for a, b in P.corredores(M):
            for h in M.linha(a, b)[1:-1]:
                conta[h] = conta.get(h, 0) + 1
        sem_abrigo = {h for h in M.hexes if M.passa(h) and not any(M.inb(v) and M.t(v).get("cover", 0) for v in P.nbrs(h))}
        notas = []
        for h in cand:
            if not M.passa(h):
                continue
            g = espelho(h)
            if any(P.dist(h, x) < espaco or P.dist(g, x) < espaco for x in escolhidas):
                continue
            if any(P.dist(h, x) <= 1 or P.dist(g, x) <= 1 for x in longe_de):
                continue
            ganha = sum(1 for v in P.nbrs(h) if v in sem_abrigo)
            notas.append((conta.get(h, 0) * 0.15 + ganha * 2.0, h))
        notas.sort(reverse=True)
        melhor = None
        for nota, h in notas[:60]:
            g = espelho(h)
            antes = dict(M.terr)
            for x in {h, g}:
                M.terr[x] = (tipo, M.hh(x))
            try:
                cc, _, _ = P.custo_base(M)
                ok = max_custo is None or cc <= max_custo
            except Exception:
                ok = False
            M.terr = antes
            if ok:
                melhor = h
                break
        if melhor is None:
            break
        for x in {melhor, espelho(melhor)}:
            M.terr[x] = (tipo, M.hh(x))
            escolhidas.append(x)
    return escolhidas


def tarhut(D):
    m = D["maps"]["tarhut"]
    # entradas 2 casas mais perto do centro (base a base de 24 para ~20 passos)
    m["entry_centers"] = [{"q": 5, "r": -10}, {"q": -5, "r": 10}]
    M = P.Mapa(D, "tarhut", None)
    e0, e1 = M.e
    res = [tuple(r[:2]) for r in m["res"]] + [(-r[0], -r[1]) for r in m["res"]]
    # pedras só onde nenhuma das 4 dunas sobe mais de 1 nível (pedra não abre cratera no meio da duna)
    alto = set()
    for dn in range(len(m["dunes"])):
        Md = P.Mapa(D, "tarhut", dn)
        alto |= {h for h in Md.hexes if Md.k(h) == "duna" and Md.hh(h) >= 2}
    cand = {h for h in M.hexes if M.passa(h) and M.k(h) == "areia" and P.dist(h, e0) > 4 and P.dist(h, e1) > 4
            and h not in res and P.dist(h, (0, 0)) > 2 and h not in alto}
    # Hex Energy: casas no eixo do meio (mesma distância das duas bases), o centro e dois pares
    eixo = [h for h in M.hexes if P.dist(h, e0) == P.dist(h, e1) and M.passa(h)]
    eixo.sort(key=lambda h: P.dist(h, (0, 0)))
    cores = [(0, 0)]
    for alvo in (4, 7):
        h = next((x for x in eixo if P.dist(x, (0, 0)) == alvo and M.k(x) == "areia" and x not in res), None)
        if h:
            cores += [h, (-h[0], -h[1])]
    pedras = escolhe_bloqueios(M, 8, cand, lambda h: (-h[0], -h[1]), cores, espaco=2, max_custo=22)
    novos = []
    vistos = set()
    for i, h in enumerate(pedras):
        if h in vistos or (-h[0], -h[1]) in vistos:
            continue
        vistos.add(h)
        novos.append([h[0], h[1], "rocha" if i % 3 != 2 else "ossada", 0])
    m["half"] = m["half"] + novos
    m["cores"] = [list(c) for c in cores]
    return {"pedras": len(novos) * 2, "cores": cores}


def _set_cell(m, h, k):
    for c in m["cells"]:
        if c[0] == h[0] and c[1] == h[1]:
            c[2] = k
            return
    raise KeyError(h)


def _simetricos(M, perto=4):
    """casas que o espelho leva nelas mesmas: ficam exatamente à mesma distância das duas bases"""
    return [h for h in M.hexes if espelho_m(h) == h and M.passa(h) and P.dist(h, (0, 0)) <= perto]


def abnara(D):
    m = D["maps"]["abnara"]
    # abre o caminho até a ponte (1, -2), que estava fechada por plantas predadoras (ponte sem saída)
    for h in ((0, -3), (3, -3)):
        _set_cell(m, h, "trilha")
    # o meio fica um pouco mais caro: lama nas duas casas que encostam na ponte central
    for h in ((-1, 0), (1, 0)):
        _set_cell(m, h, "lama")
    M = P.Mapa(D, "abnara")
    m["cores"] = [list(h) for h in sorted(_simetricos(M), key=lambda h: P.dist(h, (0, 0)))]
    return {"cores": m["cores"]}


def goraida(D):
    m = D["maps"]["goraida"]
    M = P.Mapa(D, "goraida")
    e0, e1 = M.e
    cores = sorted(_simetricos(M), key=lambda h: P.dist(h, (0, 0)))
    cand = {h for h in M.hexes if M.k(h) in ("gelo", "gelo_fragil") and P.dist(h, e0) > 5 and P.dist(h, e1) > 5}
    pilares = escolhe_bloqueios(M, 6, cand, espelho_m, cores, espaco=2, max_custo=22, tipo="parede_gelo")
    for h in pilares:
        _set_cell(m, h, "parede_gelo")
    m["cores"] = [list(h) for h in cores]
    return {"pilares": len(pilares), "cores": m["cores"]}


def main():
    D = json.load(open(ARQ, encoding="utf-8"))
    rel = {}
    for mid, fn in (("tarhut", tarhut), ("abnara", abnara), ("goraida", goraida)):
        if D["maps"][mid].get("ajuste_auditoria"):
            print(mid, "já ajustado")
            continue
        rel[mid] = fn(D)
        D["maps"][mid]["ajuste_auditoria"] = "2026-11-17"
    json.dump(D, open(ARQ, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(rel)


if __name__ == "__main__":
    main()
