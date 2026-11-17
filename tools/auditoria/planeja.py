"""Modelo leve dos mapas (mesmas regras de passo, custo e linha de tiro do game.gd) para planejar mudanças
de level design e medir antes/depois sem abrir o Godot. Usado por tools/auditoria/ajusta_mapas.py."""
import json, math, os
import networkx as nx

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
DIRS = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]


def dist(a, b):
    dq, dr = a[0] - b[0], a[1] - b[1]
    return max(abs(dq), abs(dr), abs(dq + dr))


def nbrs(h):
    return [(h[0] + a, h[1] + b) for a, b in DIRS]


class Mapa:
    def __init__(self, data, mid, dune=None):
        self.D = data
        self.mid = mid
        self.m = data["maps"][mid]
        self.tt = data["terrain"]
        sh = self.m.get("shape", {"q": 6, "r": 6, "s": 6})
        self.SQ, self.SR, self.SS = sh["q"], sh["r"], sh["s"]
        R = max(self.SQ, self.SR, self.SS)
        self.hexes = [(q, r) for q in range(-R, R + 1) for r in range(-R, R + 1) if self.inb((q, r))]
        self.e = [tuple((c["q"], c["r"])) for c in self.m["entry_centers"]]
        self.terr = {}
        plain = self.m["plain"]
        for e in self.m.get("half", []):
            self.terr[(e[0], e[1])] = (e[2], e[3])
            self.terr[(-e[0], -e[1])] = (e[2], e[3])
        for e in self.m.get("cells", []):
            self.terr[(e[0], e[1])] = (e[2], e[3])
        if "dunes" in self.m and dune is not None:
            base = set(self.terr.keys())
            for pk in self.m["dunes"][dune]["peaks"]:
                hh = pk[2]
                for c in ((pk[0], pk[1]), (-pk[0], -pk[1])):
                    for h in self.hexes:
                        dd = dist(h, c)
                        if dd < hh and h not in base and dist(h, self.e[0]) > 1 and dist(h, self.e[1]) > 1:
                            k, v = self.terr.get(h, ("duna", 0))
                            self.terr[h] = ("duna", max(v, hh - dd))
        self.plain = plain

    def inb(self, h):
        return abs(h[0]) <= self.SQ and abs(h[1]) <= self.SR and abs(h[0] + h[1]) <= self.SS

    def k(self, h):
        return self.terr.get(h, (self.plain, 0))[0]

    def hh(self, h):
        return int(self.terr.get(h, (self.plain, 0))[1])

    def t(self, h):
        return self.tt[self.k(h)]

    def passa(self, h):
        return self.inb(h) and self.t(h).get("pass", 0) == 1

    def top(self, h):
        return self.hh(h) + int(self.t(h).get("top", 0))

    def can_step(self, a, b):
        if not self.passa(b):
            return False
        dh = self.hh(b) - self.hh(a)
        if dh <= -2 or dh >= 2:
            return False
        if dh == 1 and not (self.t(b).get("climb", 0) or self.k(a) == "rampa"):
            return False
        return True

    def cost(self, a, b):
        if self.k(b) == "duna":
            return 1 + (1 if self.hh(b) >= 4 and self.hh(b) > self.hh(a) else 0)
        return max(1, int(self.t(b).get("c", 1)))

    def grafo(self, extra_block=()):
        G = nx.DiGraph()
        eb = set(extra_block)
        for h in self.hexes:
            if not self.passa(h) or h in eb:
                continue
            for m in nbrs(h):
                if m in eb or not self.inb(m):
                    continue
                if self.can_step(h, m):
                    G.add_edge(h, m, w=self.cost(h, m))
        return G

    def linha(self, a, b):
        n = dist(a, b)
        out = []
        for i in range(n + 1):
            t = i / n
            q = a[0] + (b[0] - a[0]) * t + 1e-6
            r = a[1] + (b[1] - a[1]) * t + 1e-6
            s = -q - r
            rq, rr, rs = round(q), round(r), round(s)
            dq, dr, ds = abs(rq - q), abs(rr - r), abs(rs - s)
            if dq > dr and dq > ds:
                rq = -rr - rs
            elif dr > ds:
                rr = -rq - rs
            out.append((rq, rr))
        return out

    def los(self, a, b):
        lim = max(self.hh(a), self.hh(b))
        for h in self.linha(a, b)[1:-1]:
            if self.top(h) > lim:
                return False
        return True


def custo_base(M, G=None):
    G = G or M.grafo()
    s = min(G.nodes, key=lambda h: dist(h, M.e[0]))
    t = min(G.nodes, key=lambda h: dist(h, M.e[1]))
    return nx.shortest_path_length(G, s, t, weight="w"), s, t


def rotas(M, n=4):
    G = M.grafo()
    _, s, t = custo_base(M, G)
    Gp = G.copy()
    out = []
    for it in range(10):
        p = nx.shortest_path(Gp, s, t, weight="w")
        meio = [h for h in p if dist(h, M.e[0]) > 3 and dist(h, M.e[1]) > 3]
        if all(len(set(meio) & set(r)) / max(1, len(meio)) < 0.5 for r in out):
            out.append(meio)
        for h in meio:
            for u in list(Gp.predecessors(h)):
                Gp[u][h]["w"] *= 4
        if len(out) >= n:
            break
    custos = []
    for r in out:
        full = [s] + r + [t]
        custos.append(sum(nx.shortest_path_length(G, full[i], full[i + 1], weight="w") for i in range(len(full) - 1)))
    return out, custos


def corredores(M):
    pas = [h for h in M.hexes if M.passa(h)]
    e0, e1 = M.e
    out = []
    for i, a in enumerate(pas):
        for b in pas[i + 1:]:
            d = dist(a, b)
            if 6 <= d <= 8 and (dist(a, e0) - dist(a, e1)) * (dist(b, e0) - dist(b, e1)) < 0 and M.los(a, b):
                out.append((a, b))
    return out


def abrigo_pct(M):
    pas = [h for h in M.hexes if M.passa(h)]
    com = [h for h in pas if any(M.inb(v) and M.t(v).get("cover", 0) for v in nbrs(h))]
    return round(100 * len(com) / max(1, len(pas)))
