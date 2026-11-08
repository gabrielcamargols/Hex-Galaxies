"""Hex Galaxies - letreiros de impacto (K.O., NOCAUTE, NO LIMITE) no estilo HQ/anime de luta.
Letras com degradê, retícula, extrusão escura e contorno preto serrilhado; estouro e linhas de velocidade.
python3 tools/splash_hq.py -> ui/splash/*.png"""
import math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "ui", "splash")
FONT = os.path.join(ROOT, "ui", "fonts", "InterDisplay-BlackItalic.otf")
INK = (20, 8, 30, 255)


def hexc(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def rough(mask, grow, seed, passes=16):
    rng = random.Random(seed)
    out = Image.new("L", mask.size, 0)
    for _ in range(passes):
        r = grow + rng.choice([-3, -1, 0, 2, 4])
        dx, dy = rng.randint(-4, 4), rng.randint(-4, 4)
        m = mask.filter(ImageFilter.MaxFilter(max(3, r * 2 + 1)))
        out = ImageChops.lighter(out, ImageChops.offset(m, dx, dy))
    return out.filter(ImageFilter.GaussianBlur(1.0)).point(lambda v: 255 if v > 110 else 0)


def spikes(mask, n, seed, length=(40, 110)):
    """estilhaços pontudos saindo das letras (como no CLASH)"""
    rng = random.Random(seed)
    w, h = mask.size
    out = Image.new("L", mask.size, 0)
    d = ImageDraw.Draw(out)
    px = mask.load()
    tries = 0
    while n > 0 and tries < 4000:
        tries += 1
        x, y = rng.randrange(w), rng.randrange(h)
        if px[x, y] == 0:
            continue
        # só na borda de cima/baixo
        ang = rng.choice([-1, 1]) * rng.uniform(55, 125)
        a = math.radians(ang)
        ux, uy = math.cos(a), math.sin(a)
        L = rng.uniform(*length)
        clear = True
        for k in range(12, int(L) + 60, 6):     # o espinho só sai para fora: nada de letra no caminho
            ex, ey = int(x + ux * k), int(y + uy * k)
            if not (0 <= ex < w and 0 <= ey < h) or px[ex, ey] != 0:
                clear = False
                break
        if not clear:
            continue
        bw = rng.uniform(10, 20)
        d.polygon([(x - uy * bw, y + ux * bw), (x + ux * L, y + uy * L), (x + uy * bw, y - ux * bw)], fill=255)
        n -= 1
    return out


def word(text, c1, c2, dot, seed, size=230, track=-6, name=None, sub=None):
    font = ImageFont.truetype(FONT, size)
    # mede letra por letra para apertar o espaçamento
    widths = [font.getlength(ch) * (1.6 if ch == ' ' else 1.0) for ch in text]
    W = int(sum(widths) + track * len(text) + size * 1.4)
    H = int(size * 2.1)
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    rng = random.Random(seed)
    x = size * 0.6
    for i, ch in enumerate(text):
        dy = rng.uniform(-14, 14)          # letras pulando, como pintadas à mão
        d.text((x, size * 0.45 + dy), ch, font=font, fill=255)
        x += widths[i] + track
    # inclinação extra para dar velocidade
    m = m.transform(m.size, Image.AFFINE, (1, 0.18, -H * 0.09, 0, 1, 0), resample=Image.BICUBIC)
    m = m.point(lambda v: 255 if v > 100 else 0)
    sp = spikes(m, 9, seed + 1)
    body = ImageChops.lighter(m, sp.filter(ImageFilter.MinFilter(3)))

    # degradê vertical no corpo das letras
    bb = m.getbbox()
    grad = Image.new("RGBA", (W, H))
    gd = ImageDraw.Draw(grad)
    for yy in range(H):
        t = min(1.0, max(0.0, (yy - bb[1]) / max(1, bb[3] - bb[1])))
        t = t * t * (3 - 2 * t)
        col = tuple(int(c1[k] + (c2[k] - c1[k]) * t) for k in range(3)) + (255,)
        gd.line([(0, yy), (W, yy)], fill=col)
    # retícula: pontos crescem para baixo
    dots = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(dots)
    step = 14
    for yy in range(bb[1], bb[3], step):
        t = (yy - bb[1]) / max(1, bb[3] - bb[1])
        r = 1.0 + 5.2 * t
        off = (step // 2) if (yy // step) % 2 else 0
        for xx in range(bb[0] - step, bb[2] + step, step):
            dd.ellipse([xx + off - r, yy - r, xx + off + r, yy + r], fill=255)
    dots = ImageChops.multiply(dots, body)
    # brilho de cima (faixa clara)
    hi = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hi).rectangle([0, bb[1], W, bb[1] + (bb[3] - bb[1]) * 0.22], fill=150)
    hi = ImageChops.multiply(hi, m.filter(ImageFilter.MinFilter(9)))

    ink = rough(body, 13, seed + 2)
    ext = Image.new("L", (W, H), 0)
    for k in range(1, 15):                 # extrusão 3D para baixo-direita
        ext = ImageChops.lighter(ext, ImageChops.offset(ink, k, k))
    white = rough(body, 5, seed + 3, 10)    # filete branco entre letra e tinta

    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (W, H), hexc("#0a0412")), (0, 0), ext)
    out.paste(Image.new("RGBA", (W, H), INK), (0, 0), ink)
    out.paste(Image.new("RGBA", (W, H), (255, 252, 240, 255)), (0, 0), white)
    out.paste(grad, (0, 0), body)
    out.paste(Image.new("RGBA", (W, H), dot), (0, 0), dots)
    out.paste(Image.new("RGBA", (W, H), (255, 255, 255, 255)), (0, 0), hi)
    out = out.crop(out.getbbox())
    out.thumbnail((1100, 520), Image.LANCZOS)
    out.save(os.path.join(OUT, name + ".png"))
    return out


def burst(name, cols, n=14, seed=5, S=900):
    rng = random.Random(seed)
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = S / 2
    for li, (col, ro, ri) in enumerate(cols):
        pts = []
        for i in range(n * 2):
            a = math.radians(i * 180.0 / n + rng.uniform(-6, 6))
            r = (ro if i % 2 == 0 else ri) * rng.uniform(0.72, 1.0) * S / 2
            pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
        if li == 0:
            d.polygon(pts, fill=INK)
            pts = [(c + (x - c) * 0.95, c + (y - c) * 0.95) for x, y in pts]
        d.polygon(pts, fill=hexc(col))
    im.save(os.path.join(OUT, name + ".png"))


def lines(name, col, S=1024, n=90, seed=9):
    """linhas de velocidade radiais, centro vazio"""
    rng = random.Random(seed)
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = S / 2
    for i in range(n):
        a = rng.uniform(0, math.tau)
        r0 = rng.uniform(0.30, 0.48) * S
        w = rng.uniform(0.006, 0.022)
        p = [(c + math.cos(a - w) * S, c + math.sin(a - w) * S), (c + math.cos(a) * r0, c + math.sin(a) * r0),
             (c + math.cos(a + w) * S, c + math.sin(a + w) * S)]
        d.polygon(p, fill=hexc(col) if i % 3 else (255, 255, 255, 255))
    im.save(os.path.join(OUT, name + ".png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    word("K.O.!", hexc("#a8f6ff"), hexc("#5a46e0"), hexc("#3a2cb0"), 11, name="ko")
    word("NOCAUTE!", hexc("#ffd12e"), hexc("#ff4b3e"), hexc("#c21f3a"), 23, name="nocaute")
    word("NO LIMITE!", hexc("#fff08a"), hexc("#f438a9"), hexc("#b8217c"), 37, size=200, name="limite")
    burst("estouro_ko", [("#ffd12e", 1.0, 0.55), ("#fff6c8", 0.62, 0.34)], seed=5)
    burst("estouro_limite", [("#ff4b3e", 1.0, 0.6), ("#ffb36b", 0.6, 0.36)], n=12, seed=8)
    lines("linhas", "#ffd12e")
    print("ok")
