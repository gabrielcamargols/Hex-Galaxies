"""Gera as molduras da interface no estilo HQ (quadrinho): contorno de tinta preta,
sombra dura deslocada, cantos cortados e retícula (pontinhos) no preenchimento.

As imagens são tingidas no jogo (modulate): partes brancas viram a cor do elemento,
partes pretas continuam pretas (tinta) e o cinza escuro vira a cor escurecida.

python3 tools/uigen_hq.py  ->  ui/panel.png, panel_soft.png, btn.png, btn_on.png, card.png, chip.png
"""
from PIL import Image, ImageDraw
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "ui")
SS = 4  # supersampling para bordas lisas


def poly(w, h, cut, inset=0):
    """polígono com o canto superior direito e o inferior esquerdo cortados (cara de quadro de HQ)"""
    i = inset
    return [(i, i), (w - cut - i, i), (w - i, cut + i), (w - i, h - i), (cut + i, h - i), (i, h - cut - i)]


def hexpts(x, y, r):
    """hexágono (ponta para cima) com raio r"""
    return [(x + r * math.cos(math.radians(60 * i + 30)), y + r * math.sin(math.radians(60 * i + 30))) for i in range(6)]


def halftone(draw, w, h, step, col, rmax, region):
    """retícula: pontos que crescem na direção do canto inferior direito (grade a 45°)"""
    for gy in range(-step, h + step, step):
        for gx in range(-step, w + step, step):
            x = gx + (step / 2 if (gy // step) % 2 else 0)
            y = gy
            t = region(x / w, y / h)
            if t <= 0:
                continue
            r = rmax * min(1.0, t)
            draw.polygon(hexpts(x, y, r * 1.15), fill=col)


def frame(name, w, h, cut, ink, shadow, stroke, fill, dots, dot_col, step, rmax, region, glow=None):
    W, H = w * SS, h * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    sh = shadow * SS
    body_w, body_h = W - sh, H - sh
    # sombra dura (tinta) deslocada para baixo/direita
    if sh > 0:
        d.polygon([(x + sh, y + sh) for x, y in poly(body_w, body_h, cut * SS)], fill=(0, 0, 0, 235))
    # contorno de tinta
    d.polygon(poly(body_w, body_h, cut * SS), fill=(0, 0, 0, 255))
    # traço colorido (branco = cor do tema)
    d.polygon(poly(body_w, body_h, cut * SS, ink * SS), fill=(255, 255, 255, 255))
    # miolo
    inner = poly(body_w, body_h, cut * SS, (ink + stroke) * SS)
    d.polygon(inner, fill=fill)
    if dots:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        halftone(ld, W, H, step * SS, dot_col, rmax * SS, region)
        mask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(mask).polygon(inner, fill=255)
        im.paste(layer, (0, 0), Image.composite(layer, Image.new("RGBA", (W, H)), mask).split()[3])
    if glow:
        # faixa de brilho no topo (tinta clara)
        gx0, gy0 = (ink + stroke + 3) * SS, (ink + stroke + 2) * SS
        gl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(gl).polygon([(gx0, gy0), (body_w * 0.62, gy0), (body_w * 0.55, gy0 + glow * SS), (gx0, gy0 + glow * SS)], fill=(255, 255, 255, 150))
        im.alpha_composite(gl)
    im = im.resize((w, h), Image.LANCZOS)
    im.save(os.path.join(OUT, name))
    print(name, im.size)


def corner(x, y):
    # mais pontos no canto inferior direito
    return (x + y - 0.9) * 1.4


def bottom(x, y):
    return (y - 0.45) * 2.0


# painel: fundo escuro (vira a cor do tema bem escura), retícula clara no canto
frame("panel.png", 128, 128, 18, ink=4, shadow=6, stroke=3, fill=(34, 30, 44, 238), dots=True,
      dot_col=(120, 110, 140, 200), step=9, rmax=2.6, region=corner)
frame("panel_soft.png", 96, 96, 12, ink=3, shadow=4, stroke=2, fill=(40, 36, 52, 225), dots=True,
      dot_col=(120, 110, 140, 170), step=8, rmax=2.2, region=corner)
# botões: miolo claro (vira a cor viva), retícula mais escura embaixo, brilho em cima
frame("btn.png", 64, 44, 8, ink=3, shadow=4, stroke=0, fill=(236, 236, 236, 255), dots=True,
      dot_col=(170, 170, 170, 255), step=6, rmax=1.9, region=bottom, glow=5)
frame("btn_on.png", 64, 44, 8, ink=3, shadow=2, stroke=0, fill=(255, 255, 255, 255), dots=True,
      dot_col=(205, 205, 205, 255), step=6, rmax=1.6, region=bottom, glow=6)
# cartas táticas e chips
frame("card.png", 128, 176, 16, ink=4, shadow=6, stroke=3, fill=(30, 28, 40, 245), dots=True,
      dot_col=(110, 100, 130, 210), step=9, rmax=2.6, region=corner)
frame("chip.png", 40, 28, 6, ink=2, shadow=2, stroke=0, fill=(230, 230, 230, 255), dots=False,
      dot_col=(0, 0, 0, 0), step=6, rmax=1, region=bottom)
