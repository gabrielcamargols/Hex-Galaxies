"""Importa os mapas do dossiê de level design (Abnara 217, Gor'Aida 331) para data/maps.json.

O dossiê usa coordenadas axiais pointy-top com as bases à esquerda/direita. O tabuleiro do jogo
desenha as casas flat-top, então o mapa é girado 90° na grade: (q, r) -> (q' = -r, r' = q + r).
Essa troca preserva todas as vizinhanças; a câmera desses mapas gira 90° ("cam_yaw") para as bases
voltarem a ficar à esquerda e à direita da tela, exatamente como na planta.

python3 tools/importar_mapas.py   (lê data/level_design/HEX_GALAXIES_MAPAS_217_331_LEVEL_DESIGN.json)"""
import json, os, collections

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "data", "level_design", "HEX_GALAXIES_MAPAS_217_331_LEVEL_DESIGN.json")
DST = os.path.join(ROOT, "data", "maps.json")

KEYS = {
    "ABNARA": {"T": "trilha", "M": "mata", "R": "raiz", "W": "correnteza", "P": "ponte", "U": "ruina_alta",
               "C": "planta", "S": "clareira", "B": "clareira"},
    "GORAIDA": {"N": "neve", "L": "gelo", "F": "gelo_fragil", "X": "fenda", "H": "parede_gelo", "A": "avalanche",
                "S": "neve_base", "B": "neve_base"},
}
TERRAIN = {
    "trilha": {"name": "Trilha", "c": 1, "pass": 1, "top": 0, "climb": 1},
    "clareira": {"name": "Clareira da base", "c": 1, "pass": 1, "top": 0, "climb": 1, "safe": 1},
    "mata": {"name": "Mata densa", "c": 1, "pass": 1, "top": 2, "climb": 1, "brush": 1},
    "raiz": {"name": "Raiz maciça", "c": 0, "pass": 0, "top": 2, "cover": 1},
    "correnteza": {"name": "Correnteza", "c": 1, "pass": 1, "top": 0, "climb": 1, "flow": 1},
    "ponte": {"name": "Ponte vegetal", "c": 1, "pass": 1, "top": 0, "climb": 1},
    "ruina_alta": {"name": "Ruína alta", "c": 0, "pass": 0, "top": 3, "cover": 1},
    "planta": {"name": "Planta predadora", "c": 0, "pass": 0, "top": 1, "bite": 1},
    "neve": {"name": "Neve firme", "c": 1, "pass": 1, "top": 0, "climb": 1},
    "neve_base": {"name": "Neve da base", "c": 1, "pass": 1, "top": 0, "climb": 1, "safe": 1},
    "gelo": {"name": "Gelo liso", "c": 1, "pass": 1, "top": 0, "climb": 1, "slide": 1},
    "gelo_fragil": {"name": "Gelo frágil", "c": 1, "pass": 1, "top": 0, "climb": 1, "fragile": 1},
    "fenda": {"name": "Fenda aberta", "c": 0, "pass": 0, "top": 0, "pit": 1},
    "parede_gelo": {"name": "Parede glacial", "c": 0, "pass": 0, "top": 3, "cover": 1},
    "avalanche": {"name": "Corredor de avalanche", "c": 1, "pass": 1, "top": 0, "climb": 1, "aval": 1},
}
INFO = {
    "ABNARA": {"id": "abnara", "name": "Abnara", "plain": "trilha", "biome": "jungle", "hex_scale": 1.3},
    "GORAIDA": {"id": "goraida", "name": "Gor'Aida", "plain": "neve", "biome": "ice", "hex_scale": 1.0},
}
D6 = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]


def conv(q, r):
    return [-r, q + r]


def check(cells, tdef, entries):
    """conectividade com as regras do jogo: só passa onde o terreno deixa e no máximo 1 nível de diferença"""
    walk = {(c[0], c[1]): c for c in cells if tdef[c[2]]["pass"]}
    start = tuple(entries[0])
    seen = {start}
    stack = [start]
    while stack:
        h = stack.pop()
        for dq, dr in D6:
            n = (h[0] + dq, h[1] + dr)
            if n in walk and n not in seen and abs(walk[n][3] - walk[h][3]) <= 1:
                seen.add(n)
                stack.append(n)
    return len(seen), len(walk), tuple(entries[1]) in seen


def main():
    src = json.load(open(SRC))
    maps = json.load(open(DST))
    maps["terrain"].update(TERRAIN)
    for key, info in INFO.items():
        M = src["maps"][key]
        cells = []
        for c in M["cells"]:
            q, r = conv(c["q"], c["r"])
            cells.append([q, r, KEYS[key][c["terrain"]], int(c["height_level"])])
        anchors = [conv(a["q"], a["r"]) for a in M["commander_anchors"]]
        # jogador 1 (lado 0) fica na base da esquerda da planta (menor x = sqrt3*(q-r)/2)
        anchors.sort(key=lambda a: 0)
        a0 = M["commander_anchors"]
        left = min(a0, key=lambda a: a["q"] - a["r"])
        right = max(a0, key=lambda a: a["q"] - a["r"])
        entries = [conv(left["q"], left["r"]), conv(right["q"], right["r"])]
        flow = []
        for c in M["cells"]:
            if c.get("flow_to"):
                flow.append(conv(c["q"], c["r"]) + conv(c["flow_to"]["q"], c["flow_to"]["r"]))
        cores = [conv(c["q"], c["r"]) for c in M["cores"]]
        sectors = collections.defaultdict(list)
        for c in M["cells"]:
            if c.get("event_candidate_sector"):
                sectors[c["event_candidate_sector"]].append(conv(c["q"], c["r"]))
        R = int(M["radius"])
        maps["maps"][info["id"]] = {
            "name": info["name"], "plain": info["plain"], "half": [], "cells": cells,
            "shape": {"q": R, "r": R, "s": R},
            "entry_centers": [{"q": e[0], "r": e[1]} for e in entries],
            "biome": info["biome"], "cam_yaw": 90, "zone_grow": 3, "hex_scale": info["hex_scale"],
            "cores": cores, "flow": flow, "sectors": dict(sectors),
            "fonte": "data/level_design (dossiê v1.0, 08/11/2026)",
        }
        cnt = collections.Counter(c[2] for c in cells)
        n_seen, n_walk, ok = check(cells, maps["terrain"], entries)
        print(info["name"], len(cells), "casas", dict(cnt), "| andáveis ligadas %d/%d" % (n_seen, n_walk),
              "| base a base:", ok, "| entradas", entries, "| núcleos", cores)
    json.dump(maps, open(DST, "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
