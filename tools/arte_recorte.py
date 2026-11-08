"""Recorta o fundo claro de uma arte nova e entrega PNG transparente, PRESERVANDO retículas,
manchas e efeitos soltos (fazem parte do estilo do jogo).
python3 tools/arte_recorte.py entrada.png saida.png
Fluxo: flood fill a partir das bordas na cor do fundo; vãos fechados quase idênticos ao fundo
também somem. Na região do fundo (e 2px em volta) a transparência é calculada pela distância à cor
do fundo e a cor é "desmisturada" dele, assim pontos de retícula e bordas suaves ficam limpos,
sem halo claro."""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi


def cut(src, dst, tol=14, tol_in=7, min_hole=0.0012, full=70.0):
    im = Image.open(src).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    H, W, _ = a.shape
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    dist = np.abs(a - bg).max(axis=2)
    lab, n = ndi.label(dist <= tol)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgmask = np.isin(lab, list(edge))
    # vãos fechados quase idênticos ao fundo (entre braço e corpo etc.)
    lab2, n2 = ndi.label((dist <= tol_in) & ~bgmask)
    if n2:
        sizes = ndi.sum(np.ones_like(lab2), lab2, index=np.arange(1, n2 + 1))
        for i, s in enumerate(sizes, 1):
            if s > min_hole * W * H:
                bgmask |= lab2 == i
    # zona de matting: o fundo e 2px em volta dele (pontos soltos, bordas)
    zone = ndi.binary_dilation(bgmask, iterations=2)
    alpha = np.where(zone, np.clip(dist / full, 0.0, 1.0), 1.0)
    alpha = np.where(bgmask & (dist <= tol_in), 0.0, alpha)
    al = np.maximum(alpha, 1e-3)[..., None]
    col = np.where(zone[..., None], (a - bg * (1 - al)) / al, a)
    col = np.clip(col, 0, 255)
    out = np.dstack([col, alpha * 255]).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(dst)
    return im.size


if __name__ == "__main__":
    print(cut(sys.argv[1], sys.argv[2]))
