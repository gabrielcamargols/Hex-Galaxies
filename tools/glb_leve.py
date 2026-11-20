# GLB do Meshy mais leve: só a cor (jpg 2048), sem normal/metálico (o sombreado de quadrinho não usa)
import sys, json, struct, io
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
b = open(src, 'rb').read()
L = struct.unpack('<I', b[12:16])[0]; j = json.loads(b[20:20+L])
bl = struct.unpack('<I', b[20+L:24+L])[0]; B = b[28+L:28+L+bl]
mat = j['materials'][0]
ci = j['textures'][mat['pbrMetallicRoughness']['baseColorTexture']['index']]['source']
im = Image.open(io.BytesIO(B[j['bufferViews'][j['images'][ci]['bufferView']]['byteOffset']:][:j['bufferViews'][j['images'][ci]['bufferView']]['byteLength']])).convert('RGB')
im.thumbnail((2048, 2048), Image.LANCZOS)
jb = io.BytesIO(); im.save(jb, 'JPEG', quality=90); jpg = jb.getvalue()
keep_img = j['images'][ci]
drop_views = {img['bufferView'] for k, img in enumerate(j['images']) if k != ci}
j['images'] = [{'name': 'cor', 'mimeType': 'image/jpeg', 'bufferView': keep_img['bufferView']}]
j['textures'] = [{'source': 0, **({'sampler': j['textures'][0]['sampler']} if 'sampler' in j['textures'][0] else {})}]
mat.pop('normalTexture', None); mat['pbrMetallicRoughness'].pop('metallicRoughnessTexture', None)
mat['pbrMetallicRoughness']['baseColorTexture'] = {'index': 0}
nb = bytearray(); remap = {}
for i, bv in enumerate(j['bufferViews']):
    if i in drop_views:
        data = b''
    elif i == keep_img['bufferView']:
        data = jpg
    else:
        data = B[bv.get('byteOffset', 0): bv.get('byteOffset', 0) + bv['byteLength']]
    while len(nb) % 4: nb.append(0)
    bv['byteOffset'] = len(nb); bv['byteLength'] = len(data); nb += data
while len(nb) % 4: nb.append(0)
j['buffers'][0]['byteLength'] = len(nb)
js = json.dumps(j, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
o = struct.pack('<III', 0x46546C67, 2, 12+8+len(js)+8+len(nb)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(nb), 0x004E4942) + bytes(nb)
open(out, 'wb').write(o); print('ok', len(o) // 1024, 'KB', im.size)
