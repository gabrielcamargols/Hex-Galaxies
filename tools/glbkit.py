"""Hex Galaxies - kit mínimo para montar modelos 3D estilizados e salvar em .glb (sem dependências além do numpy).

Peças básicas (caixa, cilindro/cone, esfera, toro, prisma, cristal), cada uma com uma cor chapada.
Sombreamento "flat" (faces facetadas), como o estilo toon do jogo. As peças viram nós de uma cena,
com nomes, para o Godot poder animar partes (ex.: segmentos do verme, pétalas da boca).

Uso típico:
    from glbkit import Mesh, Scene
    m = Mesh(); m.cylinder(0.5, 0.6, 1.0, 8, "#c87440", at=(0,0.5,0))
    sc = Scene(); sc.add("pedra", m); sc.save("models/x.glb")
"""
import json, struct, math
import numpy as np


def hexcol(c):
    if isinstance(c, str):
        c = c.lstrip("#")
        return [int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return list(c)


def rot_matrix(rx=0.0, ry=0.0, rz=0.0):
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


class Mesh:
    """lista de triângulos com cor por face (flat shading na exportação)"""

    def __init__(self):
        self.tris = []   # (v0, v1, v2) arrays
        self.cols = []   # rgb por triângulo

    def _add(self, verts, faces, col, at=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), jitter=0.0, seed=0, ref_fn=None):
        v = np.array(verts, dtype=float) * np.array(scale, dtype=float)
        if jitter > 0:
            rng = np.random.default_rng(seed)
            v = v + rng.normal(0, jitter, v.shape)
        R = rot_matrix(*rot)
        v = v @ R.T + np.array(at, dtype=float)
        c = hexcol(col)
        center = v.mean(axis=0)
        for f in faces:
            for k in range(1, len(f) - 1):
                a, b, d = v[f[0]], v[f[k]], v[f[k + 1]]
                # face virada para fora (para a luz funcionar)
                if ref_fn is None:
                    ref = center
                else:
                    loc = R.T @ (((np.array(a) + b + d) / 3.0) - np.array(at, dtype=float))
                    ref = R @ ref_fn(loc) + np.array(at, dtype=float)
                nrm = np.cross(b - a, d - a)
                if np.dot(nrm, (a + b + d) / 3.0 - ref) < 0:
                    b, d = d, b
                self.tris.append((a, b, d))
                self.cols.append(c)
        return self

    def merge(self, other, at=(0, 0, 0), rot=(0, 0, 0), scale=1.0):
        R = rot_matrix(*rot)
        for (a, b, c), col in zip(other.tris, other.cols):
            self.tris.append(tuple(R @ (np.array(p) * scale) + np.array(at) for p in (a, b, c)))
            self.cols.append(col)
        return self

    # ---------- primitivas ----------
    def box(self, sx, sy, sz, col, **kw):
        x, y, z = sx / 2, sy / 2, sz / 2
        v = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)]
        return self._add(v, f, col, **kw)

    def cylinder(self, r_bot, r_top, h, seg, col, cap=True, **kw):
        """tronco de cone de y=0 até y=h (r_top=0 vira cone)"""
        v, f = [], []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            v.append((math.cos(a) * r_bot, 0, math.sin(a) * r_bot))
        for i in range(seg):
            a = 2 * math.pi * i / seg
            v.append((math.cos(a) * r_top, h, math.sin(a) * r_top))
        for i in range(seg):
            j = (i + 1) % seg
            if r_top > 1e-6:
                f.append((i, seg + i, seg + j, j))
            else:
                f.append((i, seg + i, j))
        if cap:
            f.append(tuple(range(seg - 1, -1, -1)) if r_bot > 0 else ())
            if r_top > 1e-6:
                f.append(tuple(range(seg, 2 * seg)))
        f = [x for x in f if len(x) >= 3]
        return self._add(v, f, col, **kw)

    def sphere(self, r, seg, rings, col, **kw):
        v, f = [], []
        for j in range(rings + 1):
            t = math.pi * j / rings
            for i in range(seg):
                a = 2 * math.pi * i / seg
                v.append((math.sin(t) * math.cos(a) * r, math.cos(t) * r, math.sin(t) * math.sin(a) * r))
        for j in range(rings):
            for i in range(seg):
                i2 = (i + 1) % seg
                a, b, c, d = j * seg + i, j * seg + i2, (j + 1) * seg + i2, (j + 1) * seg + i
                f.append((a, b, c, d))
        return self._add(v, f, col, **kw)

    def torus(self, R, r, seg, sides, col, **kw):
        v, f = [], []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            for j in range(sides):
                b = 2 * math.pi * j / sides
                rr = R + r * math.cos(b)
                v.append((math.cos(a) * rr, r * math.sin(b), math.sin(a) * rr))
        for i in range(seg):
            for j in range(sides):
                i2, j2 = (i + 1) % seg, (j + 1) % sides
                f.append((i * sides + j, i * sides + j2, i2 * sides + j2, i2 * sides + j))
        sc = np.array(kw.get("scale", (1, 1, 1)), dtype=float)

        def ring_pt(p):
            q = p / sc
            ang = math.atan2(q[2], q[0])
            return np.array([math.cos(ang) * R, 0, math.sin(ang) * R]) * sc
        return self._add(v, f, col, ref_fn=ring_pt, **kw)

    def crystal(self, r, h, col, sides=6, **kw):
        """cristal: prisma com ponta"""
        self.cylinder(r * 0.8, r, h * 0.7, sides, col, cap=False, **kw)
        at = np.array(kw.pop("at", (0, 0, 0)), dtype=float)
        rot = kw.pop("rot", (0, 0, 0))
        R = rot_matrix(*rot)
        tip = Mesh().cylinder(r, 0, h * 0.3, sides, col, cap=False)
        return self.merge(tip, at=tuple(at + R @ np.array([0, h * 0.7, 0])), rot=rot)

    def lathe(self, profile, seg, col, rmod=None, ymod=None, cap_top=True, cap_bot=True, **kw):
        """superfície de revolução: profile = [(raio, y), ...] de baixo para cima.
        rmod(theta, k) multiplica o raio no anel k; ymod(theta, k) soma na altura (bordas onduladas)"""
        v, f = [], []
        nring = len(profile)
        for k, (r, y) in enumerate(profile):
            for i in range(seg):
                a = 2 * math.pi * i / seg
                rr = r * (rmod(a, k) if rmod else 1.0)
                yy = y + (ymod(a, k) if ymod else 0.0)
                v.append((math.cos(a) * rr, yy, math.sin(a) * rr))
        for k in range(nring - 1):
            for i in range(seg):
                i2 = (i + 1) % seg
                f.append((k * seg + i, k * seg + i2, (k + 1) * seg + i2, (k + 1) * seg + i))
        if cap_bot and profile[0][0] > 1e-6:
            v.append((0, profile[0][1], 0))
            c = len(v) - 1
            for i in range(seg):
                f.append((c, (i + 1) % seg, i))
        if cap_top and profile[-1][0] > 1e-6:
            v.append((0, profile[-1][1] + (ymod(0, nring - 1) * 0 if ymod else 0), 0))
            c = len(v) - 1
            base = (nring - 1) * seg
            for i in range(seg):
                f.append((c, base + i, base + (i + 1) % seg))
        ymid = sum(y for _, y in profile) / len(profile)
        return self._add(v, f, col, ref_fn=lambda p: np.array([0.0, ymid, 0.0]), **kw)

    def blob(self, r, col, seg=14, rings=9, bump=0.18, seed=0, flat_bottom=True, **kw):
        """pedra/arbusto arredondado e irregular"""
        rng = np.random.default_rng(seed)
        ph = rng.uniform(0, 6.28, 6)
        v, f = [], []
        for j in range(rings + 1):
            t = math.pi * j / rings
            for i in range(seg):
                a = 2 * math.pi * i / seg
                d = 1 + bump * (math.sin(3 * a + ph[0]) * math.sin(2 * t + ph[1]) * 0.6 + math.sin(5 * a + ph[2]) * 0.25 + math.cos(4 * t + ph[3]) * 0.3)
                y = math.cos(t) * r * d
                if flat_bottom and y < -r * 0.25:
                    y = -r * 0.25
                v.append((math.sin(t) * math.cos(a) * r * d, y, math.sin(t) * math.sin(a) * r * d))
        for j in range(rings):
            for i in range(seg):
                i2 = (i + 1) % seg
                f.append((j * seg + i, j * seg + i2, (j + 1) * seg + i2, (j + 1) * seg + i))
        return self._add(v, f, col, **kw)

    def is_empty(self):
        return not self.tris


def _smooth_normals(P, N, limit_deg=55.0):
    """média das normais das faces que dividem o mesmo ponto, sem arredondar quinas vivas"""
    keys = np.round(P / 1e-4).astype(np.int64)
    acc = {}
    for i, k in enumerate(map(tuple, keys)):
        acc.setdefault(k, []).append(i)
    out = N.copy()
    cos_lim = math.cos(math.radians(limit_deg))
    for idxs in acc.values():
        if len(idxs) < 2:
            continue
        ns = N[idxs]
        for j, i in enumerate(idxs):
            near = ns[(ns @ N[i]) > cos_lim]
            v = near.sum(axis=0)
            ln = np.linalg.norm(v)
            if ln > 1e-9:
                out[i] = v / ln
    return out


def _paint(P, C):
    """topo claro e quente, base escura e fria, pinceladas diagonais (estilo pintado)"""
    y = P[:, 1]
    t = (y - y.min()) / max(1e-6, y.max() - y.min())
    k = 0.7 + 0.34 * t
    streak = np.sin(P[:, 0] * 7.0 + P[:, 1] * 11.0) * np.sin(P[:, 2] * 9.0 - P[:, 1] * 5.0)
    k = k * (1.0 + 0.07 * streak)
    out = C.copy()
    out[:, 0] = np.clip(C[:, 0] * k + 0.04 * t, 0, 1)
    out[:, 1] = np.clip(C[:, 1] * k + 0.03 * t, 0, 1)
    out[:, 2] = np.clip(C[:, 2] * (k * 0.95), 0, 1)
    return out


class Scene:
    """nós com nome, malha opcional, posição/rotação e filhos"""

    def __init__(self):
        self.nodes = []
        self.roots = []

    def add(self, name, mesh=None, at=(0, 0, 0), rot=(0, 0, 0), parent=None, smooth=False, paint=False):
        """smooth: normais suavizadas (formas arredondadas, quinas vivas acima de ~55 graus continuam)
        paint: cor pintada à mão (topo mais claro e quente, base mais escura, pinceladas leves)"""
        idx = len(self.nodes)
        self.nodes.append({"name": name, "mesh": mesh, "at": at, "rot": rot, "children": [], "smooth": smooth, "paint": paint})
        if parent is None:
            self.roots.append(idx)
        else:
            self.nodes[parent]["children"].append(idx)
        return idx

    def save(self, path):
        buf = bytearray()
        views, accessors, meshes, gnodes = [], [], [], []

        def push(data, target):
            nonlocal buf
            while len(buf) % 4:
                buf += b"\0"
            off = len(buf)
            b = data.tobytes()
            buf += b
            views.append({"buffer": 0, "byteOffset": off, "byteLength": len(b), "target": target})
            return len(views) - 1

        for n in self.nodes:
            gn = {"name": n["name"]}
            if any(abs(x) > 1e-9 for x in n["at"]):
                gn["translation"] = [float(x) for x in n["at"]]
            if any(abs(x) > 1e-9 for x in n["rot"]):
                rx, ry, rz = n["rot"]
                # Y * X * Z como em rot_matrix -> quaternion
                def q(ax, a):
                    s = math.sin(a / 2)
                    return np.array([ax[0] * s, ax[1] * s, ax[2] * s, math.cos(a / 2)])

                def qm(a, b):
                    x1, y1, z1, w1 = a
                    x2, y2, z2, w2 = b
                    return np.array([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
                                     w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2])
                qq = qm(qm(q((0, 1, 0), ry), q((1, 0, 0), rx)), q((0, 0, 1), rz))
                gn["rotation"] = [float(x) for x in qq]
            if n["children"]:
                gn["children"] = n["children"]
            m = n["mesh"]
            if m is not None and not m.is_empty():
                P = np.array([p for t in m.tris for p in t], dtype=np.float32)
                N = []
                for t in m.tris:
                    nrm = np.cross(t[1] - t[0], t[2] - t[0])
                    ln = np.linalg.norm(nrm)
                    nrm = nrm / ln if ln > 1e-12 else np.array([0, 1, 0])
                    N += [nrm, nrm, nrm]
                N = np.array(N, dtype=np.float32)
                if n.get("smooth"):
                    N = _smooth_normals(P, N)
                C = np.array([c + [1.0] for c in m.cols for _ in range(3)], dtype=np.float32)
                if n.get("paint"):
                    C = _paint(P, C)
                pv = push(P, 34962)
                nv = push(N, 34962)
                cv = push(C, 34962)
                a0 = len(accessors)
                accessors.append({"bufferView": pv, "componentType": 5126, "count": len(P), "type": "VEC3",
                                  "min": P.min(axis=0).tolist(), "max": P.max(axis=0).tolist()})
                accessors.append({"bufferView": nv, "componentType": 5126, "count": len(N), "type": "VEC3"})
                accessors.append({"bufferView": cv, "componentType": 5126, "count": len(C), "type": "VEC4"})
                meshes.append({"name": n["name"], "primitives": [{"attributes": {"POSITION": a0, "NORMAL": a0 + 1, "COLOR_0": a0 + 2}, "material": 0}]})
                gn["mesh"] = len(meshes) - 1
            gnodes.append(gn)
        gltf = {
            "asset": {"version": "2.0", "generator": "hexgalaxies-glbkit"},
            "scene": 0, "scenes": [{"nodes": self.roots}],
            "nodes": gnodes, "meshes": meshes, "accessors": accessors, "bufferViews": views,
            "buffers": [{"byteLength": len(buf)}],
            "materials": [{"name": "toon", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 1.0}, "doubleSided": True}],
        }
        js = json.dumps(gltf).encode()
        while len(js) % 4:
            js += b" "
        while len(buf) % 4:
            buf += b"\0"
        out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf))
        out += struct.pack("<II", len(js), 0x4E4F534A) + js
        out += struct.pack("<II", len(buf), 0x004E4942) + bytes(buf)
        with open(path, "wb") as f:
            f.write(out)
