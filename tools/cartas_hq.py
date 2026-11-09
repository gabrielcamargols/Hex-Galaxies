"""Hex Galaxies - molduras das cartas de tática no estilo HQ/pop.
python3 tools/cartas_hq.py -> ui/cartas/carta_<tipo>.png (256x344) e ui/cartas/estouro.png (selo de explosão)
Moldura: cantos cortados, contorno de tinta, faixa do tipo inclinada no topo, fundo roxo com retícula
na cor do tipo (mais densa embaixo) e sombra dura deslocada. O estouro é branco (o jogo tinge na cor do tipo)."""
import math, os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "ui", "cartas")
TYPES = {"manobra": (76, 217, 100), "comando": (77, 163, 255), "equipamento": (255, 171, 64), "reacao": (255, 106, 213)}
INK = (10, 4, 16, 255)
W, H = 256, 344


def cut_rect(x0, y0, x1, y1, c):
    return [(x0 + c, y0), (x1, y0), (x1, y1 - c), (x1 - c, y1), (x0, y1), (x0, y0 + c)]


def frame(col):
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    sh = tuple(int(v * 0.55) for v in col) + (255,)
    d.polygon(cut_rect(10, 10, W - 1, H - 1, 22), fill=sh)                 # sombra dura
    d.polygon(cut_rect(0, 0, W - 10, H - 10, 22), fill=INK)                # contorno
    d.polygon(cut_rect(6, 6, W - 16, H - 16, 18), fill=(28, 13, 51, 255))  # fundo
    # retícula na cor do tipo, crescendo para baixo
    dots = Image.new("RGBA", (W, H))
    dd = ImageDraw.Draw(dots)
    step = 12
    for y in range(0, H, step):
        off = step / 2 if (y // step) % 2 else 0
        for x in range(0, W, step):
            t = y / H
            r = 0.4 + 3.4 * t ** 1.6
            dd.polygon([(x + off + r * 1.15 * math.cos(math.radians(60 * i + 30)), y + r * 1.15 * math.sin(math.radians(60 * i + 30))) for i in range(6)], fill=col + (95,))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(cut_rect(6, 6, W - 16, H - 16, 18), fill=255)
    img.paste(Image.alpha_composite(img, dots), (0, 0), mask)
    # faixa do tipo (topo, base inclinada) com linha de tinta
    d = ImageDraw.Draw(img)
    band = [(6 + 18, 6), (W - 16, 6), (W - 16, 40), (6, 50), (6, 6 + 18)]
    d.polygon([(x + 0, y + 4) for x, y in band], fill=INK)
    d.polygon(band, fill=col + (255,))
    d.line([(6, 50), (W - 16, 40)], fill=INK, width=5)
    # brilho de canto
    d.polygon([(W - 60, 6), (W - 16, 6), (W - 16, 30)], fill=tuple(min(255, v + 70) for v in col) + (255,))
    return img


def burst():
    S = 160
    img = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(img)
    c = S / 2

    def star(cx, cy, ro, ri, n=12, rot=-0.13):
        pts = []
        for i in range(n * 2):
            r = ro if i % 2 == 0 else ri
            r *= 1.0 + (0.12 if i % 4 == 0 else 0.0)
            a = rot + math.pi * i / n
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        return pts
    d.polygon(star(c + 6, c + 5, 70, 46), fill=(255, 40, 150, 255))
    d.polygon(star(c, c, 70, 46), fill=INK)
    d.polygon(star(c, c, 62, 40), fill=(255, 255, 255, 255))
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for k, col in TYPES.items():
        frame(col).save(os.path.join(OUT, "carta_%s.png" % k))
    burst().save(os.path.join(OUT, "estouro.png"))
    print("ok")
