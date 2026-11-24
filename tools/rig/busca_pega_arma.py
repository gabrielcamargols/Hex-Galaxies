import numpy as np, glbio
from scipy.spatial import cKDTree
def rot_x(p,ang,piv):
    r=p-piv; c,s=np.cos(ang),np.sin(ang)
    return piv+np.stack([r[...,0], r[...,1]*c - r[...,2]*s, r[...,1]*s + r[...,2]*c],-1)
import sys
A=0.3; PIV=np.array([0,0.55,0]); TW=float(sys.argv[1])
def rot_y(p,ang,piv):
    r=p-piv; c,s=np.cos(ang),np.sin(ang)
    return piv+np.stack([r[...,0]*c + r[...,2]*s, r[...,1], -r[...,0]*s + r[...,2]*c],-1)
j,b=glbio.load('perfurador.glb')
Pb=glbio.acc(j,b,j['meshes'][0]['primitives'][0]['attributes']['POSITION']).astype(float)
corpo=Pb[(np.abs(Pb[:,0])<0.16)|(Pb[:,1]<0.42)]
up=corpo[:,1]>0.5
corpo[up]=rot_x(rot_y(corpo[up],TW,PIV),A,PIV)
tree=cKDTree(corpo[::2])
D=np.load('broca_pts.npy'); D=D[np.random.default_rng(0).choice(len(D),600,replace=False)]
SR=rot_x(rot_y(np.array([-0.15,0.665,-0.025]),TW,PIV),A,PIV); SL=rot_x(rot_y(np.array([0.15,0.665,-0.025]),TW,PIV),A,PIV)
rd_R=np.array([-0.45,-0.89,0.0]); rd_L=np.array([0.45,-0.89,0.0])
pegaR=np.array([0,-0.075,-0.483]); pegaL=np.array([0,0.165,-0.085])
REACH=0.275
res=[]
for s in [0.85,0.95,1.05]:
  for yaw in np.radians(np.arange(40,101,5)):
    for pitch in np.radians(np.arange(-60,1,5)):
      for roll in np.radians([0]):
        f=np.array([np.sin(yaw)*np.cos(pitch), np.sin(pitch), np.cos(yaw)*np.cos(pitch)])
        x=np.cross([0,1,0],f); x/=np.linalg.norm(x); y=np.cross(f,x)
        c,sn=np.cos(roll),np.sin(roll); x2=x*c+y*sn; y2=-x*sn+y*c
        B=np.stack([x2,y2,f],1)
        for gx in np.arange(-0.34,0.1,0.02):
          for gy in np.arange(0.36,0.7,0.02):
            for gz in np.arange(0.0,0.34,0.02):
              GR=np.array([gx,gy,gz]); dR=np.linalg.norm(GR-SR)
              if dR>REACH or dR<0.12: continue
              O=GR-B@(pegaR*s); GL=O+B@(pegaL*s)
              dL=np.linalg.norm(GL-SL)
              if dL>REACH or dL<0.12: continue
              W=O+(D*s)@B.T
              if W[:,1].min()<0.01: continue
              if W[:,0].mean()<0.0: continue        # do lado esquerdo
              dmin=tree.query(W)[0].min()
              if dmin<0.01: continue
              aR=np.degrees(np.arccos(np.clip(np.dot((GR-SR)/dR,rd_R),-1,1)))
              aL=np.degrees(np.arccos(np.clip(np.dot((GL-SL)/dL,rd_L),-1,1)))
              score=max(aR,aL)/60+(aR+aL)/240 - s*1.5
              res.append((round(score,3),s,round(np.degrees(yaw)),round(np.degrees(pitch)),round(np.degrees(roll)),GR.round(3),GL.round(3),O.round(3),round(aR),round(aL),dR.round(3),dL.round(3),round(dmin,3)))
res.sort(key=lambda r:r[0]); print(len(res))
for r in res[:10]: print(r)
