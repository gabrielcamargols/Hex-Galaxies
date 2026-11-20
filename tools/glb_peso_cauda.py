# grava um atributo COLOR_0 (r = peso da cauda, 0 na base e 1 na ponta) num GLB do Tripo
import sys, json, struct, numpy as np
src, mask_path, base, out = sys.argv[1], sys.argv[2], [float(x) for x in sys.argv[3].split(',')], sys.argv[4]
b = open(src, 'rb').read()
L = struct.unpack('<I', b[12:16])[0]; j = json.loads(b[20:20+L])
bl = struct.unpack('<I', b[20+L:24+L])[0]; binb = bytearray(b[28+L:28+L+bl])
p = j['meshes'][0]['primitives'][0]
a = j['accessors'][p['attributes']['POSITION']]; bv = j['bufferViews'][a['bufferView']]
P = np.frombuffer(bytes(binb), dtype=np.float32, count=a['count']*3, offset=bv.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,3)
tail = np.load(mask_path)
d = np.linalg.norm(P - np.array(base), axis=1)
w = np.zeros(len(P), np.float32)
w[tail] = np.clip(d[tail] / d[tail].max(), 0, 1) ** 1.3
col = np.zeros((len(P), 4), np.float32); col[:, 0] = w; col[:, 3] = 1.0
raw = col.tobytes()
while len(binb) % 4: binb.append(0)
off = len(binb); binb += raw
j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': len(raw), 'target': 34962})
j['accessors'].append({'bufferView': len(j['bufferViews'])-1, 'componentType': 5126, 'count': len(P), 'type': 'VEC4'})
p['attributes']['COLOR_0'] = len(j['accessors'])-1
j['buffers'][0]['byteLength'] = len(binb)
js = json.dumps(j, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
while len(binb) % 4: binb.append(0)
o = struct.pack('<III', 0x46546C67, 2, 12+8+len(js)+8+len(binb)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(binb), 0x004E4942) + bytes(binb)
open(out, 'wb').write(o); print('ok', int(tail.sum()), 'vértices de cauda')
