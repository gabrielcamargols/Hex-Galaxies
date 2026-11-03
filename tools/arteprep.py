"""Hex Galaxies - prepara a arte de um personagem novo para o jogo.

Recebe a arte de corpo inteiro (PNG com fundo transparente) e gera:
  art/<id>.webp    corpo inteiro, recortado e reduzido para caber em 480x440
  art/p_<id>.webp  retrato 160x160 (centro e tamanho do recorte ajustáveis)

Uso: python tools/arteprep.py <imagem.png> <id> [cx cy lado [voo]]
  cx, cy = centro do retrato na imagem original (0..1); lado = fração da largura
  voo = fração do quadro deixada vazia embaixo (0.3 = paira bem acima do chão)
"""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))

ART = os.path.join(os.path.dirname(__file__), "..", "art")


def prep(src, cid, cx=0.5, cy=0.25, side=0.4, hover=0.0):
    im = Image.open(src).convert("RGBA")
    # some o halo quase invisível que o gerador deixa em volta
    a = im.getchannel("A").point(lambda v: 0 if v < 14 else v)
    im.putalpha(a)
    W, H = im.size
    s = side * W
    box = (int(cx * W - s / 2), int(cy * H - s / 2), int(cx * W + s / 2), int(cy * H + s / 2))
    por = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]))
    por.alpha_composite(im, (-box[0], -box[1]))
    por = por.resize((160, 160), Image.LANCZOS)
    body = im.crop(im.getbbox())
    # voo: a figura ocupa só a parte de cima do quadro e fica pairando acima da casa
    room = 440 * (1.0 - hover)
    k = min(480 / body.width, room / body.height)
    body = body.resize((max(1, round(body.width * k)), max(1, round(body.height * k))), Image.LANCZOS)
    if hover > 0:
        full = Image.new("RGBA", (body.width, 440))
        full.alpha_composite(body, (0, 0))
        body = full
    body.save(os.path.join(ART, "%s.webp" % cid), quality=92)
    por.save(os.path.join(ART, "p_%s.webp" % cid), quality=92)
    print(cid, body.size)


if __name__ == "__main__":
    a = sys.argv[1:]
    prep(a[0], a[1], *[float(x) for x in a[2:6]])
