"""Recorta o fundo claro (com retícula) de uma arte nova e entrega PNG transparente.
python3 tools/arte_recorte.py entrada.png saida.png
Fluxo: flood fill a partir das bordas na cor do fundo; vãos fechados também somem se forem
quase idênticos ao fundo e grandes; ilhas pequenas (pontinhos da retícula) são removidas."""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi


def cut(src, dst, tol=20, tol_in=7, min_island=0.0006, min_hole=0.0012):
    im = Image.open(src).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    H, W, _ = a.shape
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    dist = np.abs(a - bg).max(axis=2)
    cand = dist <= tol
    lab, n = ndi.label(cand)
    edge_labels = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgmask = np.isin(lab, list(edge_labels))
    # vãos fechados quase idênticos ao fundo (entre braço e corpo etc.)
    tight = dist <= tol_in
    lab2, n2 = ndi.label(tight & ~bgmask)
    if n2:
        sizes = ndi.sum(np.ones_like(lab2), lab2, index=np.arange(1, n2 + 1))
        for i, s in enumerate(sizes, 1):
            if s > min_hole * W * H:
                bgmask |= lab2 == i
    fg = ~bgmask
    # tira ilhas pequenas (pontos da retícula)
    lab3, n3 = ndi.label(fg)
    if n3:
        sizes = ndi.sum(np.ones_like(lab3), lab3, index=np.arange(1, n3 + 1))
        keep = np.zeros(n3 + 1, bool)
        keep[1:] = sizes >= min_island * W * H
        fg = keep[lab3]
    fg = ndi.binary_opening(fg, iterations=1)
    # contorno suave: 1px menor + leve desfoque
    fg = ndi.binary_erosion(fg, iterations=1)
    al = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    out = im.convert("RGBA")
    out.putalpha(al)
    out.save(dst)
    return out.size


if __name__ == "__main__":
    print(cut(sys.argv[1], sys.argv[2]))
