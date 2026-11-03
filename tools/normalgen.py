"""Hex Galaxies - mapas de relevo (normal maps) para os personagens 2D parecerem 3D.

Para cada art/<id>.webp gera art/n_<id>.webp:
  - o contorno vira um "travesseiro" (mais alto no meio do corpo, caindo nas bordas)
  - detalhes da pintura (roupa, músculos, armadura) dão um relevo leve por cima
O jogo usa esse relevo com a luz do sol: o lado virado para o sol clareia e o outro escurece.

Uso: python tools/normalgen.py [pasta_art]
"""
import os, sys, glob
import numpy as np
from PIL import Image
from scipy import ndimage


def normal_map(img: Image.Image) -> Image.Image:
    a = np.asarray(img.convert("RGBA")).astype(np.float32) / 255.0
    alpha = a[..., 3]
    lum = (a[..., 0] * 0.3 + a[..., 1] * 0.55 + a[..., 2] * 0.15)
    mask = alpha > 0.35
    h, w = alpha.shape
    # forma: distância até a borda -> cúpula
    d = ndimage.distance_transform_edt(mask)
    R = max(6.0, min(h, w) * 0.16)
    t = np.clip(d / R, 0, 1)
    dome = np.sqrt(1 - (1 - t) ** 2)
    dome = ndimage.gaussian_filter(dome, 1.6)
    # detalhe da pintura (só dentro do personagem)
    det = ndimage.gaussian_filter(lum, 1.2) - ndimage.gaussian_filter(lum, 5.0)
    hmap = dome * 1.0 + det * 2.2 * mask
    gx = ndimage.sobel(hmap, axis=1) / 8.0
    gy = ndimage.sobel(hmap, axis=0) / 8.0
    s = 14.0
    nx = -gx * s
    ny = gy * s          # convenção OpenGL (verde = para cima)
    nz = np.ones_like(nx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / ln, ny / ln, nz / ln], -1)
    # fora do personagem: normal reta (não importa, é transparente)
    n[~mask] = [0, 0, 1]
    rgb = ((n * 0.5 + 0.5) * 255).astype(np.uint8)
    return Image.fromarray(rgb, "RGB")


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "art"
    files = [f for f in glob.glob(os.path.join(src, "*.webp"))
             if not os.path.basename(f).startswith(("p_", "n_"))]
    for f in sorted(files):
        out = os.path.join(src, "n_" + os.path.basename(f))
        normal_map(Image.open(f)).save(out, quality=88)
    print("relevos:", len(files))
