"""Auto-rig do Perfurador (Tripo, sem esqueleto): esqueleto com nomes do Tripo (o jogo já entende) e pesos
por distância geodésica (pela superfície), suavizados — braço não puxa o tronco, perna não puxa a outra."""
import sys, numpy as np, glbio
from scipy.spatial import cKDTree
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import dijkstra

src, dst = sys.argv[1], sys.argv[2]
j, b = glbio.load(src)
prim = j['meshes'][0]['primitives'][0]
P = glbio.acc(j, b, prim['attributes']['POSITION']).astype(np.float64)
I = glbio.acc(j, b, prim['indices']).astype(np.int64).reshape(-1, 3)

d = np.array([0.493, -0.868, 0.0]); d /= np.linalg.norm(d)       # direção do braço (A-pose)
n_out = np.array([0.868, 0.493, 0.0])                             # para fora do braço (lado do polegar)
W0 = np.array([0.267, 0.468, -0.013])                             # pulso esquerdo


def mir(p):
    return np.array([-p[0], p[1], p[2]])


J = {}   # nome: (pai, posição)
J['BoneRoot'] = (None, [0, 0.43, 0])
J['Hip'] = ('BoneRoot', [0, 0.43, 0])
J['Pelvis'] = ('Hip', [0, 0.428, 0])
J['Waist'] = ('Hip', [0, 0.47, 0])
J['Spine01'] = ('Waist', [0, 0.53, 0])
J['Spine02'] = ('Spine01', [0, 0.60, -0.005])
J['NeckTwist01'] = ('Spine02', [0, 0.69, -0.01])
J['NeckTwist02'] = ('NeckTwist01', [0, 0.715, -0.01])
J['Head'] = ('NeckTwist02', [0, 0.74, -0.005])
L = {
    'Clavicle': ('Spine02', [0.035, 0.655, -0.02]),
    'Upperarm': ('Clavicle', [0.15, 0.665, -0.025]),
    'Forearm': ('Upperarm', [0.21, 0.565, -0.02]),
    'Hand': ('Forearm', list(W0)),
    'Thigh': ('Pelvis', [0.075, 0.415, 0.005]),
    'Calf': ('Thigh', [0.088, 0.245, 0.005]),
    'Foot': ('Calf', [0.093, 0.095, -0.005]),
    'ToeBase': ('Foot', [0.095, 0.025, 0.075]),
}
# dedos: base nos nós dos dedos, 3 falanges; espalhados em z (indicador na frente)
for nome, z in [('Index', 0.024), ('Mid', 0.0), ('Ring', -0.022), ('Pinky', -0.044)]:
    pai = 'Hand'
    for k, t in enumerate([0.068, 0.09, 0.106]):
        p = W0 + d * t
        p[2] = z
        L['%s%d' % (nome, k + 1)] = (pai, list(p))
        pai = '%s%d' % (nome, k + 1)
pai = 'Hand'
for k, (t, o) in enumerate([(0.012, 0.018), (0.032, 0.03), (0.05, 0.036)]):
    p = W0 + d * t + n_out * o
    p[2] = 0.022
    L['Thumb%d' % (k + 1)] = (pai, list(p))
    pai = 'Thumb%d' % (k + 1)
for nm, (pai, p) in L.items():
    paiL = pai if pai in J else 'L_' + pai
    paiR = pai if pai in J else 'R_' + pai
    J['L_' + nm] = (paiL, p)
    J['R_' + nm] = (paiR, list(mir(np.array(p))))
nomes = list(J.keys())
pos = {k: np.array(v[1], dtype=float) for k, v in J.items()}
filhos = {k: [c for c in nomes if J[c][0] == k] for k in nomes}

# segmentos para os pesos: osso -> fim (filho principal ou ponta)
PONTAS = {'Head': [0, 0.98, 0.0], 'L_ToeBase': [0.095, 0.02, 0.15], 'L_Index3': list(W0 + d * 0.125 + [0, 0, 0]),
          'L_Thumb3': None}
fim = {}
principal = {'Hip': 'Waist', 'Spine02': 'NeckTwist01', 'Pelvis': None, 'BoneRoot': None}
for k in nomes:
    if k in principal:
        c = principal[k]
        fim[k] = pos[c] if c else None
        continue
    base = k[2:] if k[:2] in ('L_', 'R_') else k
    cs = [c for c in filhos[k] if not any(c.endswith(f + '1') for f in ['Index', 'Mid', 'Ring', 'Pinky', 'Thumb'])]
    if base == 'Hand':
        fim[k] = pos[k] + (d if k.startswith('L_') else d * [-1, 1, 1]) * 0.06
    elif cs:
        fim[k] = pos[cs[0]]
    elif base == 'Head' or k == 'Head':
        fim[k] = np.array([0, 0.98, 0.0])
    elif base == 'ToeBase':
        fim[k] = pos[k] + [0, -0.005, 0.07]
    elif base[-1] == '3':      # ponta do dedo
        pai = J[k][0]
        fim[k] = pos[k] + (pos[k] - pos[pai]) * 1.2
    else:
        fim[k] = None
pesaveis = [k for k in nomes if fim[k] is not None]
# ossos pequenos que não seguram pele (o resto herda)
pesaveis = [k for k in pesaveis if k not in ('NeckTwist02',)]


def dist_seg(Pv, a, bb):
    ab = bb - a
    t = np.clip(((Pv - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    return np.linalg.norm(Pv - (a + t[:, None] * ab), axis=1)


# grafo da malha: arestas dos triângulos + vizinhos muito próximos (costuras de UV, peças encostadas)
e = np.vstack([I[:, [0, 1]], I[:, [1, 2]], I[:, [2, 0]]])
tree = cKDTree(P)
pares = np.array(list(tree.query_pairs(0.006)), dtype=np.int64).reshape(-1, 2)
e = np.vstack([e, pares])
w = np.linalg.norm(P[e[:, 0]] - P[e[:, 1]], axis=1) + 1e-5
n = len(P)
G = coo_matrix((np.concatenate([w, w]), (np.concatenate([e[:, 0], e[:, 1]]), np.concatenate([e[:, 1], e[:, 0]]))), shape=(n, n)).tocsr()

D_e = np.stack([dist_seg(P, pos[k], fim[k]) for k in pesaveis], 1)       # euclidiana até cada osso
dono = D_e.argmin(1)
geo = np.full((n, len(pesaveis)), np.inf)
for bi, k in enumerate(pesaveis):
    mine = np.where(dono == bi)[0]
    if len(mine) == 0:
        mine = np.argsort(D_e[:, bi])[:5]
    # sementes: os vértices deste osso mais colados nele
    lim = np.percentile(D_e[mine, bi], 40) if len(mine) > 5 else np.inf
    seeds = mine[D_e[mine, bi] <= lim]
    g = dijkstra(G, directed=False, indices=seeds, min_only=True, limit=0.25)
    geo[:, bi] = g + np.min(D_e[seeds, bi])
# cachecol (roxo, pela cor da textura): só o tronco e o pescoço o carregam — as pontas penduradas ao lado
# dos braços não podem ir junto com o braço
import os
if os.path.exists('scarf_mask.npy'):
    sc = np.load('scarf_mask.npy') & (P[:, 1] > 0.45) & (P[:, 1] < 0.76) & (np.abs(P[:, 0]) < 0.2)
    ok = [pesaveis.index(k) for k in ('Spine01', 'Spine02', 'NeckTwist01') if k in pesaveis]
    outros = [i for i in range(len(pesaveis)) if i not in ok]
    for i in outros:
        geo[sc, i] = np.inf
    for i in ok:
        geo[sc, i] = np.minimum(geo[sc, i], D_e[sc, i] * 1.2 + 0.01)
    print('cachecol', int(sc.sum()))
# peças soltas que o grafo não alcançou: cai para a distância euclidiana (com penalidade)
sem = ~np.isfinite(geo)
ninguem = sem.all(1)
geo[ninguem] = D_e[ninguem] * 1.6 + 0.02
# pesos: inverso da distância geodésica; 4 maiores
eps = 0.004
wts = 1.0 / (geo + eps) ** 4
top = np.argsort(-wts, 1)[:, :4]
Wt = np.take_along_axis(wts, top, 1)
Wt /= Wt.sum(1, keepdims=True)
# suaviza nos vizinhos (juntas dobram macio)
full = np.zeros_like(wts)
np.put_along_axis(full, top, Wt, 1)
A = G.copy(); A.data = np.ones_like(A.data)
deg = np.asarray(A.sum(1)).ravel() + 1
for _ in range(5):
    full = 0.5 * full + 0.5 * (A @ full + full) / deg[:, None]
if os.path.exists('scarf_mask.npy'):
    full[np.ix_(sc, outros)] = 0
top = np.argsort(-full, 1)[:, :4]
Wt = np.take_along_axis(full, top, 1)
Wt[Wt < 0.02] = 0
Wt /= Wt.sum(1, keepdims=True)
jidx = np.array([nomes.index(pesaveis[t]) for t in top.ravel()]).reshape(top.shape)

# ---- escreve o glb com esqueleto e pele
base_nodes = len(j['nodes'])
idx = {k: base_nodes + i for i, k in enumerate(nomes)}
for k in nomes:
    pai = J[k][0]
    t = pos[k] - (pos[pai] if pai else np.zeros(3))
    j['nodes'].append({'name': k, 'translation': [float(x) for x in t]})
for k in nomes:
    ch = [idx[c] for c in filhos[k]]
    if ch:
        j['nodes'][idx[k]]['children'] = ch
arm = {'name': 'Armature', 'children': [idx['BoneRoot']]}
j['nodes'].append(arm)
arm_i = len(j['nodes']) - 1
ibm = np.zeros((len(nomes), 16), dtype=np.float32)
for i, k in enumerate(nomes):
    m = np.eye(4); m[:3, 3] = -pos[k]
    ibm[i] = m.T.ravel()
ai = glbio.add(j, b, ibm, 'MAT4', 5126)
j['skins'] = [{'joints': [idx[k] for k in nomes], 'inverseBindMatrices': ai, 'skeleton': idx['BoneRoot'], 'name': 'Perfurador'}]
mesh_node = [i for i, nd in enumerate(j['nodes']) if 'mesh' in nd][0]
j['nodes'][mesh_node]['skin'] = 0
j['nodes'][mesh_node]['name'] = 'Perfurador'
j['scenes'][0]['nodes'] = [mesh_node, arm_i]
prim['attributes']['JOINTS_0'] = glbio.add(j, b, jidx.astype(np.uint16), 'VEC4', 5123, 34962)
prim['attributes']['WEIGHTS_0'] = glbio.add(j, b, Wt.astype(np.float32), 'VEC4', 5126, 34962)
glbio.save(dst, j, b)
print('ossos', len(nomes), 'pesaveis', len(pesaveis), 'vertices sem grafo', int(ninguem.sum()))
for k in ['Head', 'L_Hand', 'L_Upperarm', 'Spine02', 'L_Thigh', 'L_Mid2']:
    bi = nomes.index(k)
    print(k, 'vertices com peso>0.5:', int(((jidx == bi) & (Wt > 0.5)).any(1).sum()))
