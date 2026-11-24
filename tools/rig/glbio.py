import json,struct,numpy as np
def load(f):
    b=open(f,'rb').read()
    l=struct.unpack('<I',b[12:16])[0]; j=json.loads(b[20:20+l])
    off=20+l; bl=struct.unpack('<I',b[off:off+4])[0]; binb=b[off+8:off+8+bl]
    return j,bytearray(binb)
CT={5121:np.uint8,5123:np.uint16,5125:np.uint32,5126:np.float32}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def acc(j,binb,i):
    a=j['accessors'][i]; bv=j['bufferViews'][a['bufferView']]
    o=bv.get('byteOffset',0)+a.get('byteOffset',0); n=NC[a['type']]
    return np.frombuffer(bytes(binb[o:o+a['count']*n*np.dtype(CT[a['componentType']]).itemsize]),dtype=CT[a['componentType']]).reshape(a['count'],n) if n>1 else np.frombuffer(bytes(binb[o:o+a['count']*np.dtype(CT[a['componentType']]).itemsize]),dtype=CT[a['componentType']])
def add(j,binb,arr,typ,ct,target=None,minmax=False):
    while len(binb)%4: binb.append(0)
    o=len(binb); data=np.ascontiguousarray(arr.astype(CT[ct])).tobytes(); binb.extend(data)
    bv={'buffer':0,'byteOffset':o,'byteLength':len(data)}
    if target: bv['target']=target
    j['bufferViews'].append(bv)
    a={'bufferView':len(j['bufferViews'])-1,'componentType':ct,'count':int(arr.shape[0]),'type':typ}
    if minmax:
        a['min']=[float(x) for x in arr.min(0)]; a['max']=[float(x) for x in arr.max(0)]
    j['accessors'].append(a); return len(j['accessors'])-1
def save(f,j,binb):
    while len(binb)%4: binb.append(0)
    j['buffers']=[{'byteLength':len(binb)}]
    js=json.dumps(j,separators=(',',':')).encode()
    while len(js)%4: js+=b' '
    out=struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(binb))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(binb),0x004E4942)+bytes(binb)
    open(f,'wb').write(out)
