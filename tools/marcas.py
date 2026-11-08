"""Hex Galaxies - texturas de marcação no chão, no estilo HQ/pop do jogo.
python3 tools/marcas.py ->
  ui/terreno/movedica.png   redemoinho de areia movediça (3 braços em espiral, fundo escuro com retícula,
                            contorno preto, sombra magenta/violeta deslocada, bolhas)
  ui/terreno/marca.png      marca branca de casa (borda grossa + retícula), tingida pelo jogo para
                            mover / atacar / entrada / seleção"""
import math, os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "ui", "terreno")
S = 512
C = S / 2
INK = (20, 8, 24, 255)


def hexpts(r, rot=0.0):
    return [(C + r * math.cos(math.radians(60 * i) + rot), C + r * math.sin(math.radians(60 * i) + rot)) for i in range(6)]


def hexmask(r):
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).polygon(hexpts(r), fill=255)
    return m


def dots(mask, color, step, rfun):
    lay = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(lay)
    for yy in range(0, S + step, step):
        off = step / 2 if (yy // step) % 2 else 0
        for xx in range(0, S + step, step):
            px, py = xx + off, yy
            r = rfun(px, py)
            if r > 0.3:
                d.ellipse((px - r, py - r, px + r, py + r), fill=color)
    out = Image.new("RGBA", (S, S))
    out.paste(lay, (0, 0), mask)
    return out


def spiral_arm(a0, turns=0.85, r0=55, r1=230, w0=6, w1=28, n=80):
    left, right = [], []
    for i in range(n + 1):
        t = i / n
        a = a0 + t * turns * math.tau
        r = r0 + (r1 - r0) * t
        w = w0 + (w1 - w0) * math.sin(t * math.pi) ** 0.8
        cx, cy = C + math.cos(a) * r, C + math.sin(a) * r
        nx, ny = math.cos(a), math.sin(a)
        left.append((cx + nx * w / 2, cy + ny * w / 2))
        right.append((cx - nx * w / 2, cy - ny * w / 2))
    return left + right[::-1]


def movedica():
    img = Image.new("RGBA", (S, S))
    hm = hexmask(C * 0.97)
    # fundo: areia mais escura que afunda para o centro
    base = Image.new("RGBA", (S, S), (150, 82, 34, 255))
    d = ImageDraw.Draw(base)
    for k in range(10, 0, -1):
        r = C * 0.97 * k / 10
        t = 1 - k / 10
        col = (int(150 - 110 * t), int(82 - 70 * t), int(34 - 10 * t), 255)
        d.ellipse((C - r, C - r, C + r, C + r), fill=col)
    img.paste(base, (0, 0), hm)
    # retícula escura no fundo do poço
    pit = Image.new("L", (S, S), 0)
    ImageDraw.Draw(pit).ellipse((C - 150, C - 150, C + 150, C + 150), fill=255)
    img.alpha_composite(dots(pit, (20, 8, 24, 255), 10, lambda x, y: 3.6 * max(0, 1 - math.hypot(x - C, y - C) / 150)))
    # braços da espiral: sombra deslocada magenta e violeta, contorno, areia clara
    arms = [spiral_arm(i * math.tau / 3) for i in range(3)]

    def layer(fill, dx=0, dy=0, grow=0):
        m = Image.new("L", (S, S), 0)
        dd = ImageDraw.Draw(m)
        for p in arms:
            dd.polygon([(x + dx, y + dy) for x, y in p], fill=255)
        if grow:
            m = m.filter(ImageFilter.MaxFilter(grow))
        o = Image.new("RGBA", (S, S))
        o.paste(Image.new("RGBA", (S, S), fill), (0, 0), m)
        return o, m

    for fill, dx, dy, g in [((255, 40, 150, 255), 7, 6, 9), ((120, 60, 255, 255), -6, -4, 9), (INK, 0, 0, 9)]:
        img.alpha_composite(layer(fill, dx, dy, g)[0])
    sand, sm = layer((236, 158, 72, 255))
    img.alpha_composite(sand)
    img.alpha_composite(dots(sm, (255, 214, 120, 255), 9, lambda x, y: 2.2))
    # bolhas
    d = ImageDraw.Draw(img)
    for a, r, s in [(0.4, 95, 13), (2.3, 120, 10), (4.0, 80, 9), (5.2, 150, 11), (1.5, 170, 8)]:
        x, y = C + math.cos(a) * r, C + math.sin(a) * r
        d.ellipse((x - s + 3, y - s + 3, x + s + 3, y + s + 3), fill=(255, 40, 150, 255))
        d.ellipse((x - s, y - s, x + s, y + s), fill=(255, 224, 150, 255), outline=INK, width=4)
        d.ellipse((x - s * 0.45, y - s * 0.55, x - s * 0.05, y - s * 0.15), fill=(255, 255, 255, 255))
    a = img.getchannel("A")
    img.putalpha(Image.composite(a, Image.new("L", (S, S), 0), hm))
    return img


def marca():
    img = Image.new("RGBA", (S, S))
    outer, inner = C * 0.97, C * 0.84
    ring = Image.new("L", (S, S), 0)
    dr = ImageDraw.Draw(ring)
    dr.polygon(hexpts(outer), fill=255)
    dr.polygon(hexpts(inner), fill=0)
    # preenchimento fraco + retícula que fica mais densa perto da borda
    fill = Image.new("RGBA", (S, S))
    fill.paste(Image.new("RGBA", (S, S), (255, 255, 255, 55)), (0, 0), hexmask(inner))
    img.alpha_composite(fill)
    img.alpha_composite(dots(hexmask(inner), (255, 255, 255, 220), 22, lambda x, y: 6.0 * (math.hypot(x - C, y - C) / inner) ** 2.5))
    band = Image.new("RGBA", (S, S))
    band.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255)), (0, 0), ring)
    img.alpha_composite(band)
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    movedica().save(os.path.join(OUT, "movedica.png"))
    marca().save(os.path.join(OUT, "marca.png"))
    print("ok")
