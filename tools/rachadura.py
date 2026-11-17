"""Hex Galaxies - textura de 'Areia instável' no estilo HQ/pop do jogo.
Rachaduras em raio (zigue-zague tipo relâmpago) com contorno preto grosso, deslocamento de cor
(magenta/violeta, como impressão desalinhada), retícula de pontos e lascas soltas.
python3 tools/rachadura.py  -> ui/terreno/rachadura_0..2.png (512x512, transparente)"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "ui", "terreno")
S = 512
C = S / 2
INK = (20, 8, 24, 255)
DEEP = (70, 20, 30, 255)


def bolt(rng, ang, length, width):
    """polígono de uma rachadura em zigue-zague que afina na ponta"""
    pts_l, pts_r = [], []
    n = 7
    x, y = C + math.cos(ang) * 18, C + math.sin(ang) * 18
    for i in range(n + 1):
        t = i / n
        w = width * (1 - t) ** 0.8 + 1.5
        a = ang + (rng.uniform(-0.55, 0.55) if 0 < i < n else 0)
        nx, ny = -math.sin(a), math.cos(a)
        pts_l.append((x + nx * w, y + ny * w))
        pts_r.append((x - nx * w, y - ny * w))
        step = length / n * rng.uniform(0.8, 1.2)
        zz = rng.choice([-1, 1]) * rng.uniform(0.35, 0.8)
        x += math.cos(ang + zz) * step
        y += math.sin(ang + zz) * step
    return pts_l + pts_r[::-1], (x, y)


def halftone(mask, color, step=11, rmax=3.6, phase=0.0):
    lay = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(lay)
    for yy in range(0, S, step):
        off = step / 2 if (yy // step) % 2 else 0
        for xx in range(0, S, step):
            px, py = int(xx + off) % S, yy
            dist = math.hypot(px - C, py - C) / C
            r = rmax * max(0.25, 1.0 - dist * 0.9)
            d.ellipse((px - r, py - r, px + r, py + r), fill=color)
    out = Image.new("RGBA", (S, S))
    out.paste(lay, (0, 0), mask)
    return out


def hexmask(scale=0.98):
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    r = C * scale
    d.polygon([(C + r * math.cos(math.radians(60 * i)), C + r * math.sin(math.radians(60 * i))) for i in range(6)], fill=255)
    return m


# paletas: areia (Tarhut) e gelo (Gor'Aida)
PAL = {
    "areia": {"glow": (255, 214, 120, 150), "mag": (255, 40, 150, 255), "cya": (120, 60, 255, 255), "ink": INK, "deep": DEEP,
              "dots": (255, 120, 40, 255), "chip": (255, 210, 90, 255)},
    "gelo": {"glow": (210, 245, 255, 170), "mag": (244, 56, 169, 255), "cya": (64, 200, 255, 255), "ink": (14, 16, 48, 255), "deep": (28, 52, 130, 255),
             "dots": (110, 210, 255, 255), "chip": (230, 248, 255, 255)},
}


def make(seed, pal="areia", fino=1.0, linha=False):
    """linha=True: uma rachadura só que atravessa a casa (dois braços opostos e um galho), sem forma de estrela/X"""
    P = PAL[pal]
    rng = random.Random(seed)
    k = 2 if linha else rng.randint(4, 6)
    base = rng.uniform(0, math.tau)
    polys = []
    for i in range(k):
        a = base + math.tau * i / k + rng.uniform(-0.3, 0.3)
        p, tip = bolt(rng, a, rng.uniform(170, 215) if linha else rng.uniform(150, 215), rng.uniform(13, 20) * fino)
        polys.append(p)
        # galho
        if rng.random() < (0.5 if linha and i == 0 else 0.0 if linha else 0.7):
            mid = p[len(p) // 4]
            a2 = a + rng.choice([-1, 1]) * rng.uniform(0.6, 1.0)
            q, _ = bolt(rng, a2, rng.uniform(50, 90), rng.uniform(5, 8) * fino)
            dx, dy = mid[0] - (C + math.cos(a2) * 18), mid[1] - (C + math.sin(a2) * 18)
            polys.append([(x + dx, y + dy) for x, y in q])

    def layer(fill, dx=0, dy=0, grow=0):
        im = Image.new("L", (S, S), 0)
        d = ImageDraw.Draw(im)
        for p in polys:
            d.polygon([(x + dx, y + dy) for x, y in p], fill=255)
        rc = 8 if linha else 30
        d.ellipse((C - rc + dx, C - rc + dy, C + rc + dx, C + rc + dy), fill=255)
        if grow:
            im = im.filter(ImageFilter.MaxFilter(grow))
        col = Image.new("RGBA", (S, S), fill)
        out = Image.new("RGBA", (S, S))
        out.paste(col, (0, 0), im)
        return out, im

    img = Image.new("RGBA", (S, S))
    # 1) brilho das bordas (placas levantadas), 2) deslocamentos de cor, 3) contorno, 4) fenda
    glow, gm = layer(P["glow"], grow=29)
    img.alpha_composite(glow)
    mag, _ = layer(P["mag"], 7, 6, grow=9)
    img.alpha_composite(mag)
    cya, _ = layer(P["cya"], -6, -4, grow=9)
    img.alpha_composite(cya)
    ink, _ = layer(P["ink"], grow=9)
    img.alpha_composite(ink)
    deep, dm = layer(P["deep"])
    img.alpha_composite(deep)
    img.alpha_composite(halftone(dm, P["dots"], step=9, rmax=2.6))
    # lascas soltas (triângulos tipo estilhaço)
    d = ImageDraw.Draw(img)
    for _ in range(rng.randint(2, 3) if linha else rng.randint(7, 11)):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(70, 200)
        x, y = C + math.cos(a) * r, C + math.sin(a) * r
        s = rng.uniform(7, 15)
        tri = [(x + math.cos(a + t) * s * (1.6 if j == 0 else 1), y + math.sin(a + t) * s * (1.6 if j == 0 else 1)) for j, t in enumerate((0, 2.3, 4.0))]
        d.polygon([(px + 4, py + 4) for px, py in tri], fill=P["mag"])
        d.polygon(tri, fill=P["chip"], outline=P["ink"], width=4)
    # recorta no hexágono
    hm = hexmask()
    a = img.getchannel("A")
    a = Image.composite(a, Image.new("L", (S, S), 0), hm)
    img.putalpha(a)
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for i in range(3):
        make(11 + i * 7).save(os.path.join(OUT, "rachadura_%d.png" % i))
        make(41 + i * 5, "gelo", 1.0).save(os.path.join(OUT, "rachadura_gelo_%d.png" % i))
        make(61 + i * 3, "gelo", 0.55, linha=True).save(os.path.join(OUT, "rachadura_gelo_linha_%d.png" % i))
    print("ok")
