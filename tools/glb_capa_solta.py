# Tira a capa dos ossos dos braços: vértices pesados nos braços mas longe do eixo do braço
# (capa/manto) passam a seguir o Spine2. Uso: glb_capa_solta.py entrada.glb saida.glb [dist=0.06]
import sys, json, struct, numpy as np
src, out = sys.argv[1], sys.argv[2]
dist = float(sys.argv[3]) if len(sys.argv) > 3 else 0.06
b = bytearray(open(src, 'rb').read())
L = struct.unpack('<I', b[12:16])[0]; j = json.loads(bytes(b[20:20+L])); B0 = 28 + L
def view(i):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
    comp = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a['componentType']]
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
    off = B0 + bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    return comp, n, off, a['count']
def get(i):
    comp, n, off, c = view(i)
    return np.frombuffer(bytes(b[off:off + c * n * np.dtype(comp).itemsize]), dtype=comp).reshape(c, n).copy()
def put(i, arr):
    comp, n, off, c = view(i)
    raw = arr.astype(comp).tobytes(); b[off:off + len(raw)] = raw
p = j['meshes'][0]['primitives'][0]
P = get(p['attributes']['POSITION'])
JT = get(p['attributes']['JOINTS_0']).astype(int); W = get(p['attributes']['WEIGHTS_0'])
sk = j['skins'][0]; names = [j['nodes'][n]['name'].replace(':', '_') for n in sk['joints']]
ibm = get(sk['inverseBindMatrices']).reshape(-1, 4, 4)
pos = {names[i]: np.linalg.inv(ibm[i].T)[:3, 3] for i in range(len(names))}
armj = [i for i, n in enumerate(names) if ('Arm' in n or 'Hand' in n)]
sp2 = names.index('mixamorig_Spine2')
def segd(X, a, c):
    ab = c - a; t = np.clip(((X - a) @ ab) / (ab @ ab), 0, 1); return np.linalg.norm(X - (a + t[:, None] * ab), axis=1)
d = np.full(len(P), 9.0); dh = np.full(len(P), 9.0)
for s in ['Left', 'Right']:
    A = pos[f'mixamorig_{s}Arm']; F = pos[f'mixamorig_{s}ForeArm']; H = pos[f'mixamorig_{s}Hand']
    T = H + (H - F) * 0.8          # ponta dos dedos
    d = np.minimum(d, np.minimum(np.minimum(segd(P, A, F), segd(P, F, H)), segd(P, H, T)))
isarm = np.isin(JT, armj)
aw = (W * isarm).sum(1)
sel = (aw > 0.0) & (d > dist)
# peças soltas da malha (capa, faixas): decide pela peça inteira, para não esticar triângulos
from scipy import sparse
from scipy.sparse.csgraph import connected_components
idx = get(p['indices']).reshape(-1, 3)
key = np.round(P, 5); _, inv = np.unique(key, axis=0, return_inverse=True); inv = inv.ravel()
T = inv[idx]; nv = inv.max() + 1
G = sparse.coo_matrix((np.ones(len(T) * 3), (np.r_[T[:, 0], T[:, 1], T[:, 2]], np.r_[T[:, 1], T[:, 2], T[:, 0]])), shape=(nv, nv))
nc, lab = connected_components(G, directed=False)
vl = lab[inv]
maior = np.argmax(np.bincount(vl))
for c in range(nc):
    m = (vl == c) & (aw > 0.0)
    if c == maior or not m.any():
        continue
    sel[vl == c] = np.median(d[vl == c]) > dist
sel &= aw > 0.0
for v in np.where(sel)[0]:
    moved = (W[v] * isarm[v]).sum()
    W[v][isarm[v]] = 0.0
    if sp2 in JT[v]:
        W[v][list(JT[v]).index(sp2)] += moved
    else:
        k = int(np.argmin(W[v])); JT[v][k] = sp2; W[v][k] += moved
    W[v] /= W[v].sum()
put(p['attributes']['JOINTS_0'], JT); put(p['attributes']['WEIGHTS_0'], W)
open(out, 'wb').write(bytes(b)); print('capa solta dos braços:', int(sel.sum()), 'vértices')
