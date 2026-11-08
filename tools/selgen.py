"""Peças da tela "Escolha o planeta" no estilo HQ (mockup do Gabriel).
python3 tools/selgen.py <mockup.png>  ->  ui/sel/*.png
Os planetas e o sol são recortados do mockup; fundo, painéis, banner e botões são desenhados aqui."""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi

OUT = os.path.join(os.path.dirname(__file__), "..", "ui", "sel")
os.makedirs(OUT, exist_ok=True)
SS = 2
INK = (12, 6, 28, 255)
PINK = (255, 46, 196, 255)
CYAN = (40, 226, 255, 255)
YEL = (255, 222, 30, 255)
NAVY = (22, 12, 52, 255)


def mask_of(size, poly):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon(poly, fill=255)
    return np.asarray(m) > 0


def layer(size, m, col):
    a = np.zeros((size[1], size[0], 4), np.uint8)
    a[m] = col
    return Image.fromarray(a, "RGBA")


def dots(size, col, region, step, rmax, clip=None):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    W, H = size
    for gy in range(0, H + step, step):
        for gx in range(0, W + step, step):
            x = gx + (step / 2 if (gy // step) % 2 else 0)
            t = region(x / W, gy / H)
            if t <= 0.02:
                continue
            r = rmax * min(1.0, t)
            d.ellipse([x - r, gy - r, x + r, gy + r], fill=col)
    if clip is not None:
        a = np.asarray(im).copy()
        a[~clip] = 0
        im = Image.fromarray(a, "RGBA")
    return im


def comic_panel(name, w, h, col, poly_fn, border=9, ink=5, shadow=12, dot_region=None):
    W, H = w * SS, h * SS
    body = mask_of((W, H), [(x * SS, y * SS) for x, y in poly_fn(w, h)])
    inkm = ndi.binary_dilation(body, iterations=ink * SS)
    shad = np.zeros_like(inkm)
    o = shadow * SS
    shad[o:, o:] = inkm[:-o, :-o]
    fill = ndi.binary_erosion(body, iterations=border * SS)
    inner_ink = fill & ~ndi.binary_erosion(fill, iterations=3 * SS)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    im.alpha_composite(layer((W, H), shad, (5, 2, 18, 230)))
    im.alpha_composite(layer((W, H), inkm, INK))
    im.alpha_composite(layer((W, H), body, col))
    # miolo com leve degradê
    g = np.zeros((H, W, 4), np.uint8)
    yy = np.linspace(0, 1, H)[:, None]
    base = np.array([30, 16, 70]) * (1 - yy[..., None]) + np.array([16, 8, 40]) * yy[..., None]
    g[..., :3] = np.broadcast_to(base, (H, W, 3)).astype(np.uint8)
    g[..., 3] = 250
    g[~fill] = 0
    im.alpha_composite(Image.fromarray(g, "RGBA"))
    if dot_region:
        im.alpha_composite(dots((W, H), col[:3] + (200,), dot_region, 11 * SS, 3.6 * SS, fill))
    im.alpha_composite(layer((W, H), inner_ink, INK))
    im = im.resize((w, h), Image.LANCZOS)
    im.save(os.path.join(OUT, name))
    print(name, im.size)


def card_poly(w, h):
    # quadro com raio no canto de cima e "rabicho" de balão embaixo à esquerda
    return [(24, 40), (w * 0.62, 40), (w * 0.72, 22), (w * 0.70, 40), (w - 70, 40), (w - 14, 10), (w - 40, 52), (w - 22, 58),
            (w - 22, h - 70), (w - 58, h - 40), (110, h - 40), (64, h - 8), (78, h - 40), (24, h - 40), (24, 66)]


def card_poly2(w, h):
    return [(30, 34), (w - 96, 34), (w - 40, 6), (w - 62, 44), (w - 22, 44), (w - 22, h - 82), (w - 4, h - 70), (w - 44, h - 48),
            (170, h - 48), (120, h - 8), (128, h - 48), (30, h - 48), (14, h - 100), (30, h - 110)]


def tr(x, y):
    return (x - 0.55) * 2.4 + (0.45 - y) * 2.4


def build_cards():
    comic_panel("card_pink.png", 470, 300, PINK, card_poly, dot_region=lambda x, y: tr(x, y) - 0.6)
    comic_panel("card_cyan.png", 490, 320, CYAN, card_poly2, dot_region=lambda x, y: tr(x, y) - 0.6)


def build_button():
    w, h = 340, 66
    W, H = w * SS, h * SS
    body = mask_of((W, H), [(x * SS, y * SS) for x, y in [(44, 6), (w - 6, 6), (w - 26, h - 12), (24, h - 12)]])
    st1 = mask_of((W, H), [(x * SS, y * SS) for x, y in [(16, 10), (26, 10), (12, h - 16), (2, h - 16)]])
    st2 = mask_of((W, H), [(x * SS, y * SS) for x, y in [(32, 10), (40, 10), (26, h - 16), (18, h - 16)]])
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    allm = body | st1 | st2
    inkm = ndi.binary_dilation(allm, iterations=3 * SS)
    shad = np.zeros_like(inkm)
    shad[6 * SS:, 6 * SS:] = inkm[:-6 * SS, :-6 * SS]
    im.alpha_composite(layer((W, H), shad, (5, 2, 18, 220)))
    im.alpha_composite(layer((W, H), inkm, INK))
    g = np.zeros((H, W, 4), np.uint8)
    yy = np.linspace(0, 1, H)[:, None]
    base = np.array([255, 240, 90]) * (1 - yy[..., None]) + np.array([255, 196, 0]) * yy[..., None]
    g[..., :3] = np.broadcast_to(base, (H, W, 3)).astype(np.uint8)
    g[..., 3] = 255
    g[~allm] = 0
    im.alpha_composite(Image.fromarray(g, "RGBA"))
    im.alpha_composite(dots((W, H), (230, 150, 0, 230), lambda x, y: (x - 0.72) * 3.2, 8 * SS, 2.6 * SS, body))
    im = im.resize((w, h), Image.LANCZOS)
    im.save(os.path.join(OUT, "btn_yellow.png"))
    print("btn_yellow.png", im.size)


def build_back():
    w, h = 270, 84
    comic_panel("back.png", w, h, PINK, lambda w, h: [(60, 14), (w - 16, 14), (w - 34, h - 20), (40, h - 20), (14, h / 2 - 3)],
                border=5, ink=4, shadow=8)
    # traço ciano atrás (deslocado), como no mockup
    im = Image.open(os.path.join(OUT, "back.png"))
    base = Image.new("RGBA", im.size, (0, 0, 0, 0))
    cy = layer((w, h), mask_of((w, h), [(66, 8), (w - 6, 8), (w - 24, h - 14), (46, h - 14), (20, h / 2 - 9)]), CYAN)
    base.alpha_composite(cy)
    base.alpha_composite(im)
    # miolo rosa (botão cheio)
    fill = mask_of((w, h), [(66, 22), (w - 30, 22), (w - 44, h - 28), (48, h - 28), (28, h / 2 - 3)])
    pk = layer((w, h), fill, (255, 40, 170, 255))
    base.alpha_composite(pk)
    base.alpha_composite(dots((w, h), (255, 120, 220, 200), lambda x, y: (x - 0.5) * 2.5, 7, 2.0, fill))
    base.save(os.path.join(OUT, "back.png"))
    print("back.png", base.size)


def build_banner():
    w, h = 980, 150
    W, H = w * SS, h * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    def P(pts):
        return [(x * SS, y * SS) for x, y in pts]
    back = mask_of((W, H), P([(10, 52), (90, 40), (70, 22), (180, 30), (260, 12), (720, 14), (800, 4), (860, 26), (960, 20), (900, 56),
                             (950, 70), (880, 84), (930, 104), (120, 100), (40, 110), (70, 82)]))
    front = mask_of((W, H), P([(70, 40), (300, 26), (290, 12), (380, 24), (700, 18), (740, 6), (760, 22), (880, 24), (850, 50),
                              (890, 62), (840, 74), (850, 92), (120, 96), (90, 78), (40, 76), (88, 60)]))
    sub = mask_of((W, H), P([(196, 98), (790, 98), (776, 134), (182, 134)]))
    for m, col in ((back, CYAN), (front, PINK), (sub, NAVY)):
        inkm = ndi.binary_dilation(m, iterations=4 * SS)
        im.alpha_composite(layer((W, H), inkm, INK))
        im.alpha_composite(layer((W, H), m, col))
    edge = sub & ~ndi.binary_erosion(sub, iterations=3 * SS)
    im.alpha_composite(layer((W, H), edge, CYAN))
    im.alpha_composite(dots((W, H), (255, 140, 230, 180), lambda x, y: (x - 0.62) * 3.0, 9 * SS, 2.6 * SS, front))
    # listras "//" dos lados da faixa de baixo
    for x0 in (150, 166, 806, 822):
        st = mask_of((W, H), P([(x0 + 10, 102), (x0 + 16, 102), (x0 + 6, 130), (x0, 130)]))
        im.alpha_composite(layer((W, H), st, CYAN))
    im = im.resize((w, h), Image.LANCZOS)
    im.save(os.path.join(OUT, "banner.png"))
    print("banner.png", im.size)


def star4(d, cx, cy, r, col, w=0.18):
    pts = []
    for i in range(8):
        a = i * math.pi / 4 - math.pi / 2
        rr = r if i % 2 == 0 else r * w
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=col)


def star5(size, r, col, rot=0.0):
    W = H = size * SS
    cx = cy = W / 2
    pts = []
    for i in range(10):
        a = i * math.pi / 5 - math.pi / 2 + rot
        rr = r * SS if i % 2 == 0 else r * SS * 0.45
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    m = mask_of((W, H), pts)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    im.alpha_composite(layer((W, H), ndi.binary_dilation(m, iterations=4 * SS), INK))
    im.alpha_composite(layer((W, H), m, col))
    im.alpha_composite(dots((W, H), (20, 150, 200, 200), lambda x, y: (y - 0.4) * 2.2, 7 * SS, 2.0 * SS, m))
    return im.resize((size, size), Image.LANCZOS)


def build_bg():
    w, h = 1600, 900
    random.seed(11)
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = 850, 390
    d = np.sqrt(((xx - cx) / w) ** 2 + ((yy - cy) / h) ** 2)
    t = np.clip(d / 0.75, 0, 1)[..., None]
    c0 = np.array([78, 34, 170])
    c1 = np.array([22, 8, 64])
    img = (c0 * (1 - t) + c1 * t).astype(np.uint8)
    im = Image.fromarray(img, "RGB").convert("RGBA")
    dr = ImageDraw.Draw(im, "RGBA")
    # pontinhos de retícula espalhados (fundo inteiro, bem leve)
    im.alpha_composite(dots((w, h), (150, 90, 255, 60), lambda x, y: 0.5, 14, 1.6))
    # retícula rosa forte nos cantos
    im.alpha_composite(dots((w, h), (255, 40, 200, 220), lambda x, y: max((x - 0.82) * 6.0 - y * 2.0, (x - 0.86) * 6 + (y - 0.75) * 4, -x * 7 + 0.5 - (1 - y) * 4), 18, 6.5))
    # pinceladas roxas nos cantos
    for (ax, ay, bx, by, wd, col) in [(-60, 40, 420, -40, 70, (150, 60, 255, 170)), (-80, 120, 260, 40, 40, (200, 90, 255, 150)),
                                      (1180, 900, 1660, 640, 90, (150, 60, 255, 170)), (1300, 940, 1680, 760, 50, (220, 110, 255, 150)),
                                      (-40, 760, 220, 640, 40, (150, 60, 255, 140))]:
        pts = []
        for i in range(30):
            s = i / 29
            pts.append((ax + (bx - ax) * s, ay + (by - ay) * s + math.sin(s * math.pi) * -50))
        for i in range(len(pts) - 1):
            ww = wd * math.sin((i + 1) / len(pts) * math.pi) + 6
            dr.line([pts[i], pts[i + 1]], fill=col, width=int(ww))
    # riscos amarelos de velocidade
    for (x0, y0, x1, y1, wd) in [(1450, 190, 1610, 130, 9), (1500, 250, 1610, 205, 6), (40, 860, 300, 740, 10), (0, 800, 190, 720, 7),
                                 (1400, 640, 1610, 560, 8), (60, 300, 230, 360, 5)]:
        dr.polygon([(x0, y0), (x1, y1 - wd / 2), (x1, y1 + wd / 2)], fill=(255, 220, 40, 230))
    # órbitas
    for (rx, ry) in [(330, 150), (520, 255), (720, 365)]:
        dr.ellipse([cx - rx, cy - ry + 30, cx + rx, cy + ry + 30], outline=(220, 200, 255, 120), width=3)
    # estrelas
    for _ in range(140):
        x, y = random.uniform(0, w), random.uniform(0, h)
        r = random.choice([1, 1, 1.5, 2])
        dr.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, random.randint(120, 230)))
    for (x, y, r) in [(230, 140, 22), (420, 690, 26), (1450, 650, 22), (1340, 610, 12), (1120, 430, 10), (1550, 90, 14), (380, 520, 10)]:
        star4(dr, x, y, r, (255, 255, 255, 240))
    for (x, y, s, rot) in [(1420, 210, 110, -0.2), (110, 640, 130, 0.15)]:
        st = star5(s, s * 0.42, CYAN, rot)
        im.alpha_composite(st, (int(x - s / 2), int(y - s / 2)))
    im.convert("RGB").save(os.path.join(OUT, "bg.jpg"), quality=88)
    print("bg.jpg", im.size)


def build_from_mock(path):
    m = Image.open(path).convert("RGBA")
    for name, cx, cy, r, ring, rr in (("planet_tarhut.png", 259, 386, 104, PINK, 120), ("planet_valak.png", 688, 678, 122, CYAN, 140)):
        S = rr * 2 + 20
        crop = m.crop((cx - S // 2, cy - S // 2, cx + S // 2, cy + S // 2)).resize((S * SS, S * SS), Image.LANCZOS)
        W = S * SS
        yy, xx = np.mgrid[0:W, 0:W]
        dd = np.sqrt((xx - W / 2) ** 2 + (yy - W / 2) ** 2) / SS
        out = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        # brilho atrás
        glow = np.zeros((W, W, 4), np.uint8)
        glow[..., :3] = ring[:3]
        glow[..., 3] = (np.clip(1 - (dd - r) / (rr - r + 8), 0, 1) ** 2 * 170).astype(np.uint8)
        out.alpha_composite(Image.fromarray(glow, "RGBA"))
        ink = (dd <= r + 9)
        out.alpha_composite(layer((W, W), ink, INK))
        out.alpha_composite(layer((W, W), dd <= r + 6, ring))
        out.alpha_composite(layer((W, W), dd <= r + 1, INK))
        a = np.asarray(crop).copy()
        a[..., 3] = np.where(dd <= r - 1, 255, 0)
        out.alpha_composite(Image.fromarray(a, "RGBA"))
        out = out.resize((S, S), Image.LANCZOS)
        out.save(os.path.join(OUT, name))
        print(name, out.size)
    # sol
    cx, cy, S = 892, 400, 420
    crop = m.crop((cx - S // 2, cy - S // 2, cx + S // 2, cy + S // 2))
    a = np.asarray(crop).copy()
    yy, xx = np.mgrid[0:S, 0:S]
    dd = np.sqrt((xx - S / 2) ** 2 + (yy - S / 2) ** 2)
    lum = a[..., :3].astype(float).mean(axis=2)
    warm = (a[..., 0].astype(int) + a[..., 1].astype(int) - 2 * a[..., 2].astype(int)) / 255.0
    core = np.clip(1 - (dd - 80) / 30, 0, 1)
    rays = np.clip(warm * 1.4, 0, 1) * np.clip(1 - (dd - 150) / 60, 0, 1)
    al = np.maximum(core, rays)
    a[..., 3] = (np.clip(al, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(a, "RGBA").save(os.path.join(OUT, "sun.png"))
    print("sun.png", S)


if __name__ == "__main__":
    build_bg()
    build_cards()
    build_button()
    build_back()
    build_banner()
    if len(sys.argv) > 1:
        build_from_mock(sys.argv[1])
