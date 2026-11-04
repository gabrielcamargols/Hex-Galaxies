"""Hex Galaxies - gerador das molduras da HUD tecnológica (9-slice para o Godot).

Desenha em branco (o jogo tinge com a cor de cada uso): cantos chanfrados,
linha fina com brilho, marcas nos cantos, listras diagonais e pontinhos.
Saída em ui/:
  panel.png       painel grande (listras + marcas)        margem 9-slice 30
  panel_soft.png  painel simples                           margem 22
  btn.png         botão                                    margem 14
  btn_on.png      botão ativo/selecionado (preenchido)     margem 14
  chip.png        etiqueta pequena (status, round)         margem 10

Uso: python tools/uigen.py [pasta_saida] [--preview arquivo.png]
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 4  # supersample


def chamfer_poly(w, h, c_tl, c_tr, c_br, c_bl, inset=0.0):
    i = inset
    return [(c_tl + i, i), (w - c_tr - i, i), (w - i, c_tr + i), (w - i, h - c_br - i),
            (w - c_br - i, h - i), (c_bl + i, h - i), (i, h - c_bl - i), (i, c_tl + i)]


def draw(w, h, cuts, fill_a, line_w, extras, fill_rgb=(255, 255, 255)):
    W, H = w * SS, h * SS
    fill = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    line = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    df = ImageDraw.Draw(fill)
    dl = ImageDraw.Draw(line)
    c = [x * SS for x in cuts]
    lw = line_w * SS
    pf = chamfer_poly(W, H, *c, inset=lw * 0.5)
    df.polygon(pf, fill=fill_rgb + (int(255 * fill_a),))
    pl = chamfer_poly(W, H, *c, inset=lw * 0.5 + 6 * SS)
    dl.line(pl + [pl[0]], fill=(255, 255, 255, 255), width=int(lw), joint="curve")
    extras(dl, W, H, c, lw)
    glow = line.filter(ImageFilter.GaussianBlur(3 * SS))
    ga = np.asarray(glow).copy()
    ga[..., 3] = (ga[..., 3] * 0.55).astype(np.uint8)
    out = Image.alpha_composite(fill, Image.fromarray(ga))
    out = Image.alpha_composite(out, line)
    return out.resize((w, h), Image.LANCZOS)


def hatch(dl, x, y, n, size, gap, slant):
    for k in range(n):
        x0 = x + k * (size + gap)
        dl.polygon([(x0, y), (x0 + size, y), (x0 + size + slant, y + size * 0.9), (x0 + slant, y + size * 0.9)], fill=(255, 255, 255, 255))


def panel_extras(dl, W, H, c, lw):
    m = 6 * SS + lw
    # marcas grossas perto dos chanfros
    dl.line([(c[0] + m + 4 * SS, m - lw * 0.2), (c[0] + m + 40 * SS, m - lw * 0.2)], fill=(255, 255, 255, 255), width=int(lw * 2.4))
    dl.line([(W - c[2] - m - 40 * SS, H - m), (W - c[2] - m - 4 * SS, H - m)], fill=(255, 255, 255, 255), width=int(lw * 2.4))
    # listras diagonais no alto à direita
    hatch(dl, W - 60 * SS, m + 3 * SS, 4, 5 * SS, 3 * SS, 4 * SS)
    # pontinhos embaixo à esquerda
    for k in range(5):
        x = m + 8 * SS + k * 7 * SS
        dl.rectangle([x, H - m - 7 * SS, x + 3 * SS, H - m - 4 * SS], fill=(255, 255, 255, 220))
    # cantos em L internos
    L = 10 * SS
    dl.line([(m + 4 * SS, H - c[3] - m - L), (m + 4 * SS, H - c[3] - m)], fill=(255, 255, 255, 200), width=int(lw))
    dl.line([(W - m - 4 * SS, c[1] + m), (W - m - 4 * SS, c[1] + m + L)], fill=(255, 255, 255, 200), width=int(lw))


def soft_extras(dl, W, H, c, lw):
    m = 6 * SS + lw
    dl.line([(c[0] + m + 4 * SS, m - lw * 0.2), (c[0] + m + 26 * SS, m - lw * 0.2)], fill=(255, 255, 255, 255), width=int(lw * 2.2))


def btn_extras(dl, W, H, c, lw):
    m = 6 * SS + lw
    dl.line([(W - m - 14 * SS, H - m - lw), (W - c[2] - m, H - m - lw)], fill=(255, 255, 255, 0), width=1)


def none(dl, W, H, c, lw):
    pass


def build(out):
    os.makedirs(out, exist_ok=True)
    draw(128, 128, (22, 0, 22, 0), 0.86, 2.0, panel_extras, (14, 22, 40)).save(os.path.join(out, "panel.png"))
    draw(96, 96, (14, 0, 14, 0), 0.82, 1.6, soft_extras, (14, 22, 40)).save(os.path.join(out, "panel_soft.png"))
    draw(64, 44, (10, 0, 10, 0), 0.55, 2.0, none, (20, 30, 52)).save(os.path.join(out, "btn.png"))
    draw(64, 44, (10, 0, 10, 0), 0.9, 2.6, none, (110, 120, 140)).save(os.path.join(out, "btn_on.png"))
    draw(40, 28, (7, 0, 7, 0), 0.7, 1.4, none, (14, 22, 40)).save(os.path.join(out, "chip.png"))
    return ["panel", "panel_soft", "btn", "btn_on", "chip"]


def preview(out, path, names):
    bg = Image.new("RGBA", (900, 360), (8, 10, 24, 255))
    tints = {"panel": (41, 216, 255), "panel_soft": (41, 216, 255), "btn": (76, 217, 100), "btn_on": (255, 77, 77), "chip": (255, 171, 64)}
    x = 20
    for n in names:
        im = Image.open(os.path.join(out, n + ".png")).convert("RGBA")
        sz = {"panel": (300, 200), "panel_soft": (200, 140), "btn": (150, 50), "btn_on": (150, 50), "chip": (90, 34)}[n]
        # 9-slice simples para a prévia
        m = {"panel": 30, "panel_soft": 22, "btn": 14, "btn_on": 14, "chip": 10}[n]
        w, h = im.size
        tgt = Image.new("RGBA", sz, (0, 0, 0, 0))
        xs = [0, m, w - m, w]
        ys = [0, m, h - m, h]
        X = [0, m, sz[0] - m, sz[0]]
        Y = [0, m, sz[1] - m, sz[1]]
        for i in range(3):
            for j in range(3):
                piece = im.crop((xs[i], ys[j], xs[i + 1], ys[j + 1])).resize((max(1, X[i + 1] - X[i]), max(1, Y[j + 1] - Y[j])))
                tgt.paste(piece, (X[i], Y[j]))
        a = np.asarray(tgt).astype(float)
        a[..., :3] *= np.array(tints[n]) / 255.0
        tgt = Image.fromarray(a.astype(np.uint8))
        bg.alpha_composite(tgt, (x, 30 if n.startswith("panel") else 260))
        x += sz[0] + 20 if n.startswith("panel") else 0
        if not n.startswith("panel"):
            x += sz[0] + 20
    bg.save(path)


if __name__ == "__main__":
    a = sys.argv[1:]
    prev = None
    if "--preview" in a:
        i = a.index("--preview")
        prev = a[i + 1]
        a = a[:i] + a[i + 2:]
    out = a[0] if a else "ui"
    names = build(out)
    if prev:
        preview(out, prev, names)
    print("ok:", names)


# ================= cartas de tática =================
def card_frame(out):
    """moldura de carta: cantos chanfrados, faixa de título e linha interna"""
    w, h = 128, 176
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = 14 * SS
    poly = chamfer_poly(W, H, c, 0, c, 0, inset=2 * SS)
    d.polygon(poly, fill=(16, 24, 44, 245))
    d.line(poly + [poly[0]], fill=(255, 255, 255, 255), width=3 * SS, joint="curve")
    inner = chamfer_poly(W, H, c, 0, c, 0, inset=8 * SS)
    d.line(inner + [inner[0]], fill=(255, 255, 255, 90), width=1 * SS)
    # faixa do topo (tipo) e marcas
    d.rectangle([10 * SS, 9 * SS, W - 10 * SS, 26 * SS], fill=(255, 255, 255, 60))
    hatch(d, W - 40 * SS, H - 16 * SS, 3, 5 * SS, 3 * SS, 4 * SS)
    img = img.resize((w, h), Image.LANCZOS)
    img.save(os.path.join(out, "card.png"))


def icon(name, draw_fn, out):
    S2 = 96 * SS
    img = Image.new("RGBA", (S2, S2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_fn(d, S2)
    glow = img.filter(ImageFilter.GaussianBlur(4 * SS))
    ga = np.asarray(glow).copy()
    ga[..., 3] = (ga[..., 3] * 0.5).astype(np.uint8)
    img = Image.alpha_composite(Image.fromarray(ga), img).resize((96, 96), Image.LANCZOS)
    os.makedirs(os.path.join(out, "icons"), exist_ok=True)
    img.save(os.path.join(out, "icons", name + ".png"))


Wt = (255, 255, 255, 255)


def _arrow(d, S, x0, y0, x1, y1, w):
    import math
    d.line([x0, y0, x1, y1], fill=Wt, width=int(w))
    a = math.atan2(y1 - y0, x1 - x0)
    L = w * 2.6
    d.polygon([(x1 + math.cos(a) * L * 0.6, y1 + math.sin(a) * L * 0.6),
               (x1 + math.cos(a + 2.4) * L, y1 + math.sin(a + 2.4) * L),
               (x1 + math.cos(a - 2.4) * L, y1 + math.sin(a - 2.4) * L)], fill=Wt)


def _hexagon(d, cx, cy, r, w=0, fill=None):
    import math
    pts = [(cx + math.cos(math.pi / 3 * k) * r, cy + math.sin(math.pi / 3 * k) * r) for k in range(6)]
    if fill:
        d.polygon(pts, fill=fill)
    else:
        d.line(pts + [pts[0]], fill=Wt, width=int(w))


def _shield(d, S, cx, cy, s, fill=True):
    pts = [(cx - s, cy - s * 0.9), (cx + s, cy - s * 0.9), (cx + s, cy), (cx, cy + s * 1.1), (cx - s, cy)]
    if fill:
        d.polygon(pts, fill=Wt)
    else:
        d.line(pts + [pts[0]], fill=Wt, width=int(S * 0.06))


ICONS = {
    "flanquear": lambda d, S: (_hexagon(d, S * 0.3, S * 0.6, S * 0.16, S * 0.04), _arrow(d, S, S * 0.36, S * 0.45, S * 0.72, S * 0.3, S * 0.07)),
    "retirada": lambda d, S: (_shield(d, S, S * 0.68, S * 0.45, S * 0.16, False), _arrow(d, S, S * 0.6, S * 0.6, S * 0.22, S * 0.6, S * 0.07)),
    "troca": lambda d, S: (_arrow(d, S, S * 0.2, S * 0.38, S * 0.75, S * 0.38, S * 0.06), _arrow(d, S, S * 0.8, S * 0.64, S * 0.25, S * 0.64, S * 0.06)),
    "avanco": lambda d, S: [d.polygon([(S * x, S * 0.25), (S * (x + 0.2), S * 0.5), (S * x, S * 0.75), (S * (x + 0.08), S * 0.75), (S * (x + 0.28), S * 0.5), (S * (x + 0.08), S * 0.25)], fill=Wt) for x in (0.2, 0.46)],
    "cobertura": lambda d, S: [d.rectangle([S * 0.2, S * (0.25 + 0.17 * k), S * 0.8, S * (0.36 + 0.17 * k)], fill=Wt) for k in range(3)],
    "escudo": lambda d, S: _shield(d, S, S * 0.5, S * 0.45, S * 0.28),
    "dispersao": lambda d, S: [_arrow(d, S, S * 0.5, S * 0.5, S * 0.5 + S * 0.3 * c, S * 0.5 + S * 0.3 * s, S * 0.05) for c, s in ((1, 0), (-1, 0), (0, 1), (0, -1))],
    "propulsor": lambda d, S: (d.rounded_rectangle([S * 0.35, S * 0.15, S * 0.65, S * 0.6], radius=S * 0.1, fill=Wt), d.polygon([(S * 0.38, S * 0.64), (S * 0.62, S * 0.64), (S * 0.5, S * 0.9)], fill=Wt)),
    "placas": lambda d, S: [_hexagon(d, S * (0.32 + 0.36 * (k % 2)), S * (0.32 + 0.36 * (k // 2)), S * 0.15, fill=Wt) for k in range(4)],
    "lente": lambda d, S: (d.ellipse([S * 0.22, S * 0.22, S * 0.78, S * 0.78], outline=Wt, width=int(S * 0.06)), d.line([S * 0.5, S * 0.1, S * 0.5, S * 0.9], fill=Wt, width=int(S * 0.04)), d.line([S * 0.1, S * 0.5, S * 0.9, S * 0.5], fill=Wt, width=int(S * 0.04))),
    "reparo": lambda d, S: (d.rectangle([S * 0.42, S * 0.15, S * 0.58, S * 0.85], fill=Wt), d.rectangle([S * 0.15, S * 0.42, S * 0.85, S * 0.58], fill=Wt)),
    "dados": lambda d, S: (d.rounded_rectangle([S * 0.2, S * 0.2, S * 0.8, S * 0.8], radius=S * 0.1, outline=Wt, width=int(S * 0.06)), [d.ellipse([S * x - S * 0.06, S * y - S * 0.06, S * x + S * 0.06, S * y + S * 0.06], fill=Wt) for x, y in ((0.35, 0.35), (0.5, 0.5), (0.65, 0.65))]),
    "fogo": lambda d, S: d.polygon([(S * 0.5, S * 0.1), (S * 0.72, S * 0.45), (S * 0.66, S * 0.38), (S * 0.75, S * 0.7), (S * 0.5, S * 0.9), (S * 0.25, S * 0.7), (S * 0.32, S * 0.42), (S * 0.4, S * 0.5)], fill=Wt),
    "reforco": lambda d, S: (d.ellipse([S * 0.32, S * 0.15, S * 0.56, S * 0.39], fill=Wt), d.pieslice([S * 0.2, S * 0.42, S * 0.68, S * 0.9], 180, 360, fill=Wt), d.rectangle([S * 0.7, S * 0.2, S * 0.78, S * 0.5], fill=Wt), d.rectangle([S * 0.59, S * 0.31, S * 0.89, S * 0.39], fill=Wt)),
    "pulso": lambda d, S: [d.arc([S * (0.5 - r), S * (0.5 - r), S * (0.5 + r), S * (0.5 + r)], -50, 50, fill=Wt, width=int(S * 0.05)) for r in (0.15, 0.27, 0.39)],
    "granada": lambda d, S: (d.ellipse([S * 0.25, S * 0.32, S * 0.71, S * 0.8], fill=Wt), d.rectangle([S * 0.4, S * 0.2, S * 0.56, S * 0.34], fill=Wt), d.line([S * 0.56, S * 0.24, S * 0.78, S * 0.14], fill=Wt, width=int(S * 0.05))),
    "sinalizador": lambda d, S: (d.ellipse([S * 0.2, S * 0.2, S * 0.8, S * 0.8], outline=Wt, width=int(S * 0.05)), d.ellipse([S * 0.42, S * 0.42, S * 0.58, S * 0.58], fill=Wt), [d.line(l, fill=Wt, width=int(S * 0.05)) for l in ([S * 0.5, S * 0.06, S * 0.5, S * 0.3], [S * 0.5, S * 0.7, S * 0.5, S * 0.94], [S * 0.06, S * 0.5, S * 0.3, S * 0.5], [S * 0.7, S * 0.5, S * 0.94, S * 0.5])]),
    "adrenalina": lambda d, S: (d.rectangle([S * 0.42, S * 0.2, S * 0.58, S * 0.66], fill=Wt), d.polygon([(S * 0.42, S * 0.66), (S * 0.58, S * 0.66), (S * 0.5, S * 0.9)], fill=Wt), d.rectangle([S * 0.3, S * 0.16, S * 0.7, S * 0.22], fill=Wt)),
    "barreira": lambda d, S: [d.rectangle([S * (0.14 + 0.25 * (k % 3) + (0.12 if (k // 3) % 2 else 0)), S * (0.3 + 0.16 * (k // 3)), S * (0.34 + 0.25 * (k % 3) + (0.12 if (k // 3) % 2 else 0)), S * (0.42 + 0.16 * (k // 3))], fill=Wt) for k in range(8)],
    "gancho": lambda d, S: (d.arc([S * 0.25, S * 0.4, S * 0.65, S * 0.8], 0, 200, fill=Wt, width=int(S * 0.07)), d.line([S * 0.65, S * 0.6, S * 0.65, S * 0.12], fill=Wt, width=int(S * 0.07)), d.polygon([(S * 0.25, S * 0.6), (S * 0.18, S * 0.48), (S * 0.34, S * 0.5)], fill=Wt)),
    "camuflagem": lambda d, S: (d.ellipse([S * 0.15, S * 0.32, S * 0.85, S * 0.68], outline=Wt, width=int(S * 0.05)), d.ellipse([S * 0.4, S * 0.4, S * 0.6, S * 0.6], fill=Wt), d.line([S * 0.18, S * 0.82, S * 0.82, S * 0.18], fill=Wt, width=int(S * 0.06))),
    "onda": lambda d, S: [d.arc([S * (0.5 - r), S * (0.5 - r), S * (0.5 + r), S * (0.5 + r)], 0, 360, fill=Wt, width=int(S * 0.045)) for r in (0.12, 0.25, 0.38)],
    "orbital": lambda d, S: (d.polygon([(S * 0.5, S * 0.9), (S * 0.38, S * 0.55), (S * 0.62, S * 0.55)], fill=Wt), d.rectangle([S * 0.46, S * 0.08, S * 0.54, S * 0.55], fill=Wt), d.arc([S * 0.2, S * 0.7, S * 0.8, S * 0.98], 180, 360, fill=Wt, width=int(S * 0.04))),
    "kit": lambda d, S: (d.rounded_rectangle([S * 0.15, S * 0.3, S * 0.85, S * 0.82], radius=S * 0.08, outline=Wt, width=int(S * 0.05)), d.rectangle([S * 0.38, S * 0.2, S * 0.62, S * 0.3], outline=Wt, width=int(S * 0.04)), d.rectangle([S * 0.45, S * 0.42, S * 0.55, S * 0.72], fill=Wt), d.rectangle([S * 0.35, S * 0.52, S * 0.65, S * 0.62], fill=Wt)),
    "ultimo": lambda d, S: (d.polygon([(S * 0.5, S * 0.85), (S * 0.16, S * 0.5), (S * 0.16, S * 0.3), (S * 0.33, S * 0.18), (S * 0.5, S * 0.3), (S * 0.67, S * 0.18), (S * 0.84, S * 0.3), (S * 0.84, S * 0.5)], outline=Wt, width=int(S * 0.05)), d.line([S * 0.2, S * 0.5, S * 0.38, S * 0.5, S * 0.46, S * 0.34, S * 0.56, S * 0.64, S * 0.62, S * 0.5, S * 0.8, S * 0.5], fill=Wt, width=int(S * 0.05))),
    "revide": lambda d, S: (_shield(d, S, S * 0.4, S * 0.5, S * 0.22, False), _arrow(d, S, S * 0.5, S * 0.5, S * 0.9, S * 0.2, S * 0.06)),
    "resgate": lambda d, S: (_hexagon(d, S * 0.25, S * 0.7, S * 0.13, S * 0.04), _hexagon(d, S * 0.75, S * 0.3, S * 0.13, S * 0.04), d.arc([S * 0.25, S * 0.2, S * 0.85, S * 0.8], 100, 200, fill=Wt, width=int(S * 0.05)), d.arc([S * 0.15, S * 0.2, S * 0.75, S * 0.8], 280, 20, fill=Wt, width=int(S * 0.05))),
    "quantica": lambda d, S: (d.ellipse([S * 0.42, S * 0.42, S * 0.58, S * 0.58], fill=Wt), d.ellipse([S * 0.12, S * 0.34, S * 0.88, S * 0.66], outline=Wt, width=int(S * 0.04)), d.ellipse([S * 0.34, S * 0.12, S * 0.66, S * 0.88], outline=Wt, width=int(S * 0.04))),
    "interceptar": lambda d, S: (d.rounded_rectangle([S * 0.18, S * 0.2, S * 0.5, S * 0.7], radius=S * 0.05, outline=Wt, width=int(S * 0.05)), d.rounded_rectangle([S * 0.5, S * 0.3, S * 0.82, S * 0.8], radius=S * 0.05, fill=Wt), _arrow(d, S, S * 0.3, S * 0.86, S * 0.7, S * 0.86, S * 0.05)),
    "grito": lambda d, S: (d.polygon([(S * 0.15, S * 0.4), (S * 0.35, S * 0.4), (S * 0.6, S * 0.2), (S * 0.6, S * 0.8), (S * 0.35, S * 0.6), (S * 0.15, S * 0.6)], fill=Wt), [d.arc([S * (0.6 - r), S * (0.5 - r), S * (0.6 + r), S * (0.5 + r)], -40, 40, fill=Wt, width=int(S * 0.045)) for r in (0.14, 0.26)]),
    "evacuacao": lambda d, S: (d.rectangle([S * 0.42, S * 0.3, S * 0.58, S * 0.8], fill=Wt), d.rectangle([S * 0.25, S * 0.47, S * 0.75, S * 0.63], fill=Wt), _arrow(d, S, S * 0.5, S * 0.3, S * 0.5, S * 0.06, S * 0.06)),
    "execucao": lambda d, S: (d.polygon([(S * 0.5, S * 0.08), (S * 0.6, S * 0.6), (S * 0.5, S * 0.7), (S * 0.4, S * 0.6)], fill=Wt), d.rectangle([S * 0.28, S * 0.66, S * 0.72, S * 0.72], fill=Wt), d.rectangle([S * 0.46, S * 0.72, S * 0.54, S * 0.92], fill=Wt)),
    "contra": lambda d, S: (_arrow(d, S, S * 0.8, S * 0.3, S * 0.2, S * 0.3, S * 0.06), _arrow(d, S, S * 0.2, S * 0.7, S * 0.84, S * 0.7, S * 0.08)),
    "rede": lambda d, S: ([d.line([S * 0.15, S * y, S * 0.85, S * y], fill=Wt, width=int(S * 0.04)) for y in (0.25, 0.42, 0.58, 0.75)], [d.line([S * x, S * 0.15, S * x, S * 0.85], fill=Wt, width=int(S * 0.04)) for x in (0.25, 0.42, 0.58, 0.75)]),
}


def build_cards(out):
    card_frame(out)
    for n, fn in ICONS.items():
        icon(n, fn, out)
    return list(ICONS.keys())


if __name__ == "__main__" and "--cards" in sys.argv:
    print("cartas:", build_cards(sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "ui"))
