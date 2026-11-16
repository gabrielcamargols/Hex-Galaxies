"""FORJA — texturas dos FAURIANOS (pop HQ: os raios em zigue-zague das artes, disco, nota, cadeado).
Mesmo padrão da forja_tex.py: intensidade no R e no alfa; borda baixa (contorno) e miolo alto (brilho).
python3 tools/forja_tex_fau.py  ->  vfx/tex/{raio_zz,vinil,nota,cadeado}.png"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
sys.path.insert(0, os.path.dirname(__file__))
from forja_tex import save, N
from forja_tex_zuk import _down, _mask, _edge_soft, S


def raio_zz():
    """o raio das artes dos Faurianos: zigue-zague grosso que afina até uma ponta (deitado, ponta à direita)"""
    def f(d):
        # espinha dorsal em zigue-zague
        xs = [0.06, 0.3, 0.42, 0.66, 0.78, 0.97]
        ys = [0.56, 0.38, 0.6, 0.4, 0.58, 0.47]
        larg = [0.11, 0.1, 0.085, 0.06, 0.04, 0.0]
        top, bot = [], []
        for x, y, w in zip(xs, ys, larg):
            top.append((x * S, (y - w) * S))
            bot.append((x * S, (y + w) * S))
        d.polygon(top + bot[::-1], fill=255)
    m = _mask(f)
    v = _edge_soft(m, 16, 0.25)
    return _down(v)


def vinil():
    """disco de vinil: aro, sulcos e selo no meio (Zaboo)"""
    x, y = np.mgrid[0:S, 0:S].astype(np.float32) / S * 2 - 1
    r = np.hypot(x, y)
    disco = r < 0.94
    sulcos = 0.55 + 0.25 * (np.sin(r * 90) > 0.3)
    v = np.where(disco, sulcos, 0.0)
    v = np.where(r < 0.36, 1.0, v)                  # selo
    v = np.where(r < 0.06, 0.0, v)                  # furo
    v = np.where((r > 0.88) & disco, 0.3, v)        # borda escura
    brilho = (np.abs(np.arctan2(y, x) + 2.3) < 0.25) & (r > 0.45) & (r < 0.85)
    v = np.where(brilho, 1.0, v)
    return _down(v)


def nota():
    """colcheia (duas notas ligadas)"""
    def f(d):
        d.ellipse([S * 0.12, S * 0.62, S * 0.42, S * 0.86], fill=255)
        d.ellipse([S * 0.56, S * 0.52, S * 0.86, S * 0.76], fill=255)
        d.rectangle([S * 0.36, S * 0.16, S * 0.42, S * 0.74], fill=255)
        d.rectangle([S * 0.80, S * 0.08, S * 0.86, S * 0.64], fill=255)
        d.polygon([(S * 0.36, S * 0.16), (S * 0.86, S * 0.08), (S * 0.86, S * 0.22), (S * 0.36, S * 0.30)], fill=255)
    return _down(_edge_soft(_mask(f), 12, 0.25))


def cadeado():
    """cadeado aberto (Sistema Invadido): corpo cheio e alça solta"""
    def corpo(d):
        d.rounded_rectangle([S * 0.18, S * 0.44, S * 0.82, S * 0.92], radius=int(S * 0.07), fill=255)
    def alca(d):
        d.arc([S * 0.3, S * 0.06, S * 0.7, S * 0.56], 180, 360, fill=255, width=int(S * 0.08))
        d.line([(S * 0.34, S * 0.31), (S * 0.34, S * 0.36)], fill=255, width=int(S * 0.08))
    m = _mask(corpo)
    v = _edge_soft(m, 20, 0.2)
    buraco = _mask(lambda d: (d.ellipse([S * 0.44, S * 0.56, S * 0.56, S * 0.68], fill=255), d.rectangle([S * 0.475, S * 0.64, S * 0.525, S * 0.8], fill=255)))
    v = np.where(buraco, 0.25, v)
    v = np.maximum(v, _mask(alca) * 0.85)
    # alça levantada (aberta): desloca para cima
    return _down(v)


if __name__ == "__main__":
    for nm, fn in [("raio_zz", raio_zz), ("vinil", vinil), ("nota", nota), ("cadeado", cadeado)]:
        save(nm, fn())
        print("textura", nm)
