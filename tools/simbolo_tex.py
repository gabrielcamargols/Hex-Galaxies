"""Texturas do símbolo oficial de uma facção a partir do PNG enviado (branco em fundo transparente).
Limpa sujeira do recorte (pontinhos soltos e furinhos), centraliza com margem e grava:
  vfx/tex/simbolo_<fac>.png        (máscara branca nítida, padrão das outras: intensidade no R, alfa cheio)
  vfx/tex/simbolo_<fac>_sombra.png (silhueta engordada e suave, vai atrás para destacar em qualquer chão)
python3 tools/simbolo_tex.py <png> <fac> [furo_min] [ilha_min]"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

OUT = os.path.join(os.path.dirname(__file__), "..", "vfx", "tex")
N = 512


def limpa(m, furo_min, ilha_min):
    lab, n = ndi.label(m)
    if n:
        tam = ndi.sum(m, lab, range(1, n + 1))
        m = np.isin(lab, [i + 1 for i, t in enumerate(tam) if t >= ilha_min])
    fundo = ~m
    lab, n = ndi.label(fundo)
    if n:
        tam = ndi.sum(fundo, lab, range(1, n + 1))
        borda = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
        furos = [i + 1 for i, t in enumerate(tam) if t < furo_min and (i + 1) not in borda]
        m = m | np.isin(lab, furos)
    return m


def main(src, fac, furo_min=600, ilha_min=900):
    im = Image.open(src).convert("RGBA")
    a = np.asarray(im).astype(np.float32)
    lum = a[..., :3].mean(-1)
    m = (a[..., 3] > 128) & (lum > 128)
    m = limpa(m, furo_min, ilha_min)
    m = ndi.binary_opening(m, iterations=1)
    ys, xs = np.nonzero(m)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    lado = int(max(y1 - y0, x1 - x0) * 1.12)
    cy, cx = (y0 + y1) // 2, (x0 + x1) // 2
    can = np.zeros((lado, lado), np.uint8)
    sy, sx = cy - lado // 2, cx - lado // 2
    for yy in range(lado):
        oy = sy + yy
        if 0 <= oy < m.shape[0]:
            lo, hi = max(0, sx), min(m.shape[1], sx + lado)
            can[yy, lo - sx:hi - sx] = m[oy, lo:hi] * 255
    img = Image.fromarray(can).resize((N, N), Image.LANCZOS)
    v = np.asarray(img)
    rgba = np.dstack([v, v, v, np.full_like(v, 255)])
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, "simbolo_%s.png" % fac))
    sm = ndi.binary_dilation(v > 128, iterations=10)
    s = Image.fromarray((sm * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5))
    s = np.asarray(s)
    Image.fromarray(np.dstack([s, s, s, np.full_like(s, 255)]), "RGBA").save(os.path.join(OUT, "simbolo_%s_sombra.png" % fac))
    print("símbolo", fac, "ok")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], *[int(x) for x in sys.argv[3:]])
