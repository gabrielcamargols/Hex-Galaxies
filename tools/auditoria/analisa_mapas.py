"""Auditoria espacial dos mapas (dados despejados do jogo) + figuras esquemáticas."""
import json, math, collections, glob, re, os, sys
import networkx as nx
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import RegularPolygon
from matplotlib.lines import Line2D

D = os.path.dirname(os.path.abspath(__file__))
NOMES = {"posto": "Valak", "tarhut": "Tarhut", "abnara": "Abnara", "goraida": "Gor'Aida"}
S3 = math.sqrt(3)


def dist(a, b):
    dq, dr = a[0] - b[0], a[1] - b[1]
    return max(abs(dq), abs(dr), abs(dq + dr))


def xy(h):
    # mesma projeção do board.gd (world_xz): x = 1.5 r, z = -S3 (q + r/2)
    q, r = h
    # mesma orientação da câmera do jogo: a base azul à esquerda, a vermelha à direita
    return S3 * (q + r / 2.0), -1.5 * r


def cor(x):
    k = x["k"]
    if x["occ"]:
        return {"verde": "#62d26f", "azul": "#4fb8ff", "roxo": "#d36bff"}.get(x["occ"], "#888")
    if not x["pass"]:
        if x["cover"]:
            return "#7a5a3a"
        if k in ("correnteza",):
            return "#2f7fd8"
        if k in ("fenda", "fosso", "buraco"):
            return "#141820"
        return "#3c3c46"
    base = {"duna": "#e6b56a", "areia": "#f3d79a", "instavel": "#d9a05a", "movedica": "#b07a3a", "trilha": "#b9d98a",
            "mata": "#3f8f45", "clareira": "#d8f0a8", "ponte": "#c08a50", "neve": "#eef4fa", "neve_base": "#ffffff",
            "gelo": "#a9dcf0", "gelo_fragil": "#7fc6e6", "avalanche": "#c9d6e6", "plano": "#8b86c9", "ossada_c": "#d9c9a0"}.get(k, "#c8c8c8")
    return base


def analisa(m):
    d = json.load(open(os.path.join(D, "mapa_%s.json" % m)))
    H = {(x["q"], x["r"]): x for x in d["hexes"]}
    G = nx.DiGraph()
    for q, r, q2, r2, c in d["edges"]:
        G.add_edge((q, r), (q2, r2), w=max(1, c))
    e0, e1 = tuple(d["entry"][0]), tuple(d["entry"][1])
    dep0 = [tuple(h) for h in d["deploy0"]] or [e0]
    dep1 = [tuple(h) for h in d["deploy1"]] or [e1]
    passaveis = [h for h, x in H.items() if x["pass"]]
    # garante que os centros de entrada estão no grafo
    def perto(e):
        return min((h for h in G.nodes), key=lambda h: dist(h, e))
    s, t = perto(e0), perto(e1)
    custo = nx.shortest_path_length(G, s, t, weight="w")
    passos = nx.shortest_path_length(G, s, t)
    # rotas alternativas: caminho mais barato, depois penaliza as casas usadas e procura de novo
    Gp = G.copy()
    rotas = []
    for it in range(8):
        p = nx.shortest_path(Gp, s, t, weight="w")
        meio = [h for h in p if dist(h, e0) > 3 and dist(h, e1) > 3]
        novo = all(len(set(meio) & set(r)) / max(1, len(set(meio))) < 0.5 for r in rotas)
        if novo:
            rotas.append(meio)
        for h in meio:
            for u in list(Gp.predecessors(h)):
                Gp[u][h]["w"] = Gp[u][h]["w"] * 4
        if len(rotas) >= 4:
            break
    custo_rotas = []
    for r in rotas:
        full = [s] + r + [t]
        try:
            c = sum(nx.shortest_path_length(G, full[i], full[i + 1], weight="w") for i in range(len(full) - 1))
        except Exception:
            c = None
        custo_rotas.append(c)
    # gargalos: casas que, se bloqueadas, deixam o caminho base a base bem mais caro (média dos pares das áreas de entrada)
    pares = [(a, b) for a in dep0 for b in dep1 if a in G and b in G][:16] or [(s, t)]
    base_c = {pr: nx.shortest_path_length(G, pr[0], pr[1], weight="w") for pr in pares}
    meio_nodes = [h for h in G.nodes if dist(h, e0) > 3 and dist(h, e1) > 3]
    gargalos = []
    for v in meio_nodes:
        Gv = nx.restricted_view(G, [v], [])
        dl = []
        for pr in pares:
            try:
                dl.append(nx.shortest_path_length(Gv, pr[0], pr[1], weight="w") - base_c[pr])
            except nx.NetworkXNoPath:
                dl.append(30)
        md = sum(dl) / len(dl)
        if md >= 2.0:
            gargalos.append((v, md))
    gargalos.sort(key=lambda t: -t[1])
    # corte mínimo longe das bases: quantas casas fecham o meio do mapa de lado a lado
    U = G.to_undirected()
    Um = U.subgraph(meio_nodes).copy()
    anel0 = [h for h in meio_nodes if dist(h, e0) == 4]
    anel1 = [h for h in meio_nodes if dist(h, e1) == 4]
    Um.add_node("S")
    Um.add_node("T")
    for h in anel0:
        Um.add_edge("S", h)
    for h in anel1:
        Um.add_edge("T", h)
    try:
        corte = nx.minimum_node_cut(Um, "S", "T")
    except Exception:
        corte = set()
    # corredores de tiro: linhas longas (6+) que cruzam o meio do mapa
    meio_eq = lambda h: dist(h, e0) - dist(h, e1)
    corr = []
    for q, r, q2, r2, dd in d["los"]:
        a, b = (q, r), (q2, r2)
        if dd >= 6 and H[a]["pass"] and H[b]["pass"] and meio_eq(a) * meio_eq(b) < 0:
            corr.append((a, b, dd))
    exp = collections.Counter()
    for q, r, q2, r2, dd in d["los"]:
        exp[(q, r)] += 1
        exp[(q2, r2)] += 1
    banda = [h for h in passaveis if abs(meio_eq(h)) <= 4]
    expostas = [h for h in banda if exp[h] >= 25]
    # abrigo: casas andáveis com abrigo vizinho
    def vizinhos(h):
        q, r = h
        return [(q + a, r + b) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, -1), (-1, 1))]
    com_abrigo = [h for h in passaveis if any(H.get(v, {}).get("cover") for v in vizinhos(h))]
    # hex energy: distância de cada candidata às duas bases
    cores = [tuple(c[:2]) for c in d["cores"]]
    fair = []
    for c in cores:
        try:
            c0 = nx.shortest_path_length(G, s, c, weight="w")
            c1 = nx.shortest_path_length(G, t, c, weight="w")
        except Exception:
            c0 = c1 = None
        fair.append((c, c0, c1, exp[c]))
    return {"d": d, "H": H, "G": G, "s": s, "t": t, "custo": custo, "passos": passos, "rotas": rotas, "custo_rotas": custo_rotas,
            "gargalos": gargalos, "corte": corte, "corr": corr, "exp": exp, "banda": banda, "expostas": expostas,
            "com_abrigo": com_abrigo, "passaveis": passaveis, "fair": fair}


def figura(m, A, out):
    H = A["H"]
    fig, ax = plt.subplots(figsize=(9, 9), dpi=110)
    xs, ys = [], []
    for h, x in H.items():
        px, py = xy(h)
        xs.append(px)
        ys.append(py)
        poly = RegularPolygon((px, py), 6, radius=1.0, orientation=0, facecolor=cor(x), edgecolor="#00000030", lw=0.4)
        ax.add_patch(poly)
        if x["pass"] and x["h"] > 0:
            ax.text(px, py, str(x["h"]), ha="center", va="center", fontsize=5, color="#00000080")
    # corredores de tiro (amostra das mais longas, sem repetir a mesma região)
    usados = []
    for a, b, dd in sorted(A["corr"], key=lambda t: -t[2]):
        ma = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        if any(abs(ma[0] - u[0]) + abs(ma[1] - u[1]) < 2.5 for u in usados):
            continue
        usados.append(ma)
        (x1, y1), (x2, y2) = xy(a), xy(b)
        ax.plot([x1, x2], [y1, y2], color="#ffcf1f", lw=2.2, alpha=0.85, solid_capstyle="round", zorder=4)
        if len(usados) >= 10:
            break
    cores_r = ["#ff3b6b", "#2bd1ff", "#7dff5a", "#ff9a1f"]
    for i, r in enumerate(A["rotas"]):
        pts = [xy(A["s"])] + [xy(h) for h in r] + [xy(A["t"])]
        ax.plot([p[0] for p in pts], [p[1] for p in pts], color=cores_r[i % 4], lw=3.2, alpha=0.9, zorder=5)
    for h, f in A["gargalos"]:
        px, py = xy(h)
        ax.add_patch(RegularPolygon((px, py), 6, radius=0.9, orientation=0, facecolor="none", edgecolor="#ff1f1f", lw=2.6, zorder=6))
    for c, c0, c1, e in A["fair"]:
        px, py = xy(c)
        ax.add_patch(RegularPolygon((px, py), 6, radius=0.7, orientation=0, facecolor="#9d2cff", edgecolor="white", lw=1.5, zorder=6))
    for i, e in enumerate((A["s"], A["t"])):
        px, py = xy(e)
        ax.plot(px, py, marker="*", color=["#2b7bff", "#ff4a3a"][i], ms=22, mec="white", mew=1.5, zorder=8)
    ax.set_xlim(min(xs) - 1.5, max(xs) + 1.5)
    ax.set_ylim(min(ys) - 1.5, max(ys) + 1.5)
    ax.set_aspect("equal")
    ax.axis("off")
    leg = [Line2D([0], [0], color=c, lw=3, label="rota %d" % (i + 1)) for i, c in enumerate(cores_r[:len(A["rotas"])])]
    leg += [Line2D([0], [0], color="#ffcf1f", lw=2.2, label="corredor de tiro (6+ casas)"),
            Line2D([0], [0], marker="h", color="w", markeredgecolor="#ff1f1f", markerfacecolor="none", ms=12, mew=2, label="gargalo"),
            Line2D([0], [0], marker="h", color="w", markerfacecolor="#9d2cff", ms=12, label="Hex Energy (locais)"),
            Line2D([0], [0], marker="*", color="w", markerfacecolor="#2b7bff", ms=15, label="base azul / vermelha")]
    ax.legend(handles=leg, loc="upper left", bbox_to_anchor=(1.0, 1.0), fontsize=9, framealpha=0.9)
    ax.set_title(NOMES[m], fontsize=16, fontweight="bold")
    fig.savefig(out, bbox_inches="tight", facecolor="#1b1d2b")
    plt.close(fig)


def partidas():
    R = collections.defaultdict(list)
    for f in glob.glob(os.path.join(D, "*.log")):
        for l in open(f, errors="ignore"):
            mm = re.search(r"AUDITORIA mapa=(\w+) primeiro_combate=(-?\d+) ataques=(\d+) capturas_hex=(\d+) rounds=(\d+)", l)
            if mm:
                R[mm.group(1)].append(tuple(int(x) for x in mm.groups()[1:]))
    return R


if __name__ == "__main__":
    P = partidas()
    resumo = {}
    for m in ["posto", "tarhut", "abnara", "goraida"]:
        A = analisa(m)
        figura(m, A, os.path.join(D, "fig_%s.png" % m))
        pm = P.get(m, [])
        r = {"casas": len(A["H"]), "andaveis": len(A["passaveis"]), "custo_base_base": A["custo"], "passos_base_base": A["passos"],
             "rotas": len(A["rotas"]), "custo_rotas": A["custo_rotas"], "gargalos": len(A["gargalos"]),
             "gargalos_lista": [(h, round(f, 1), A["H"][h]["k"]) for h, f in A["gargalos"][:12]],
             "corte_minimo": len(A["corte"]), "corte_k": [A["H"][h]["k"] for h in A["corte"]],
             "corredores_6mais": len(A["corr"]), "banda_meio": len(A["banda"]), "banda_expostas": len(A["expostas"]),
             "abrigo_pct": round(100 * len(A["com_abrigo"]) / max(1, len(A["passaveis"]))),
             "hex_energy": [(c, c0, c1, e) for c, c0, c1, e in A["fair"]],
             "partidas": len(pm), "primeiro_combate": [x[0] for x in pm], "ataques": [x[1] for x in pm],
             "capturas": [x[2] for x in pm], "rounds": [x[3] for x in pm]}
        resumo[m] = r
        print("\n==", NOMES[m])
        for k, v in r.items():
            print(" ", k, v)
    json.dump(resumo, open(os.path.join(D, "resumo.json"), "w"), default=str, indent=1)
