"""Hex Galaxies - gerador do céu (panorama equiretangular para o Godot).

Estilo das referências: ilustração vetorial chapada, sem contorno; degradê
roxo -> azul-turquesa, faixas de nebulosa rosa ondulando, nuvens fofas
brilhantes, planetas e lua com faixas e brilho suave, estrelas cadentes,
brilhos de 4 pontas, poeira colorida e um redemoinho galáctico com feixe.
Saída: sky/galaxias.jpg (PanoramaSkyMaterial).

Uso: python tools/skygen.py [arquivo_saida] [--seed N] [--preview arquivo.png]
"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter

W, H = 4096, 2048


def hexc(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def lerp(a, b, t):
    return a + (b - a) * t


def gradient():
    v = np.linspace(0, 1, H)
    stops = [(0.0, "#0c0730"), (0.22, "#24104f"), (0.42, "#4a1f86"), (0.55, "#6a2fa8"),
             (0.66, "#3a4ac0"), (0.78, "#1f86c0"), (0.9, "#1450a0"), (1.0, "#0a1a50")]
    out = np.zeros((H, 3))
    for i in range(len(stops) - 1):
        a, ca = stops[i]
        b, cb = stops[i + 1]
        m = (v >= a) & (v <= b)
        t = ((v[m] - a) / (b - a))[:, None]
        out[m] = np.array(hexc(ca)[:3]) * (1 - t) + np.array(hexc(cb)[:3]) * t
    return np.broadcast_to(out[:, None, :], (H, W, 3)).copy()


def soft_layer(fn, blur):
    L = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fn(ImageDraw.Draw(L))
    return L.filter(ImageFilter.GaussianBlur(blur)) if blur > 0 else L


def ribbons(img, rng):
    """faixas de nebulosa ondulando pelo céu"""
    x = np.arange(W)
    yy = np.arange(H)[:, None]
    acc = np.zeros((H, W, 4))
    for k in range(4):
        y0 = H * (0.32 + 0.4 * rng.random())
        amp = H * (0.06 + 0.06 * rng.random())
        ph = rng.random() * 6.28
        freq = 2 * 2 * math.pi / W
        width = H * (0.06 + 0.07 * rng.random())
        yc = y0 + amp * np.sin(x * freq + ph) + amp * 0.4 * np.sin(x * freq * 2.7 + ph * 1.7)
        d = np.abs(yy - yc[None, :]) / width
        a = np.clip(1 - d, 0, 1) ** 2.2 * (0.22 + 0.18 * rng.random())
        col = np.array(hexc(["#ff7ad8", "#c890ff", "#ffa8e8", "#9a7aff", "#ff9ad0", "#b0c8ff"][k])[:3], float)
        core = np.clip(1 - d * 6, 0, 1) * 0.08
        acc[..., :3] += (a + core)[..., None] * col
        acc[..., 3] += a + core
    rgb = np.asarray(img).astype(float)
    a = np.clip(acc[..., 3:4], 0, 1)
    col = acc[..., :3] / np.maximum(acc[..., 3:4], 1e-6)
    rgb[..., :3] = rgb[..., :3] * (1 - a * 0.9) + col * a * 0.9
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))


def stars(img, rng):
    d = ImageDraw.Draw(img)
    for k in range(7000):
        x, y = rng.random() * W, rng.random() * H
        b = rng.random() ** 3
        s = 0.7 + b * 2.0
        c = rng.choice([(255, 255, 255), (200, 230, 255), (255, 210, 240), (180, 255, 240)])
        d.ellipse([x - s, y - s, x + s, y + s], fill=tuple(c) + (int(110 + 145 * b),))
    # poeira colorida (riscos curtos como na referência)
    for k in range(500):
        x, y = rng.random() * W, rng.random() * H
        a = rng.random() * 6.28
        l = 3 + rng.random() * 7
        c = rng.choice([(90, 220, 255), (190, 140, 255), (255, 140, 220)])
        d.line([x, y, x + math.cos(a) * l, y + math.sin(a) * l], fill=tuple(c) + (150,), width=2)


def sparkle(img, x, y, s, col):
    glow = soft_layer(lambda d: d.ellipse([x - s * 1.6, y - s * 1.6, x + s * 1.6, y + s * 1.6], fill=hexc(col, 110)), s * 0.8)
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    pts = []
    for k in range(8):
        a = math.pi / 4 * k - math.pi / 2
        r = s if k % 2 == 0 else s * 0.16
        pts.append((x + math.cos(a) * r, y + math.sin(a) * r))
    d.polygon(pts, fill=(255, 255, 255, 255))


def cloud(img, cx, cy, w, rng, tint="#ffffff", shade="#8aa8ff"):
    """nuvem fofa chapada com sombra azulada embaixo e brilho em volta"""
    puffs = []
    n = 6 + int(rng.random() * 5)
    for k in range(n):
        px = cx + (k / (n - 1) - 0.5) * w
        r = w * (0.12 + 0.1 * rng.random()) * (1.25 - abs(k / (n - 1) - 0.5))
        puffs.append((px, cy - r * 0.5 * rng.random(), r))
    glow = soft_layer(lambda d: [d.ellipse([x - r * 1.3, y - r * 1.3, x + r * 1.3, y + r * 1.3], fill=hexc(tint, 70)) for x, y, r in puffs], w * 0.06)
    img.alpha_composite(glow)
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(base)
    for x, y, r in puffs:
        bd.ellipse([x - r, y - r + r * 0.18, x + r, y + r + r * 0.18], fill=hexc(shade))
    for x, y, r in puffs:
        bd.ellipse([x - r * 0.94, y - r * 1.05, x + r * 0.94, y + r * 0.7], fill=hexc(tint))
    # base reta da nuvem: corta tudo abaixo da linha
    a = np.asarray(base).copy()
    cut = int(cy + w * 0.07)
    if 0 < cut < H:
        a[cut:, :, 3] = 0
    img.alpha_composite(Image.fromarray(a))


def planet(img, cx, cy, r, c1, c2, rng, ring=None, glow_col=None, plain=False):
    """planeta chapado: faixas onduladas, lado escuro em meia-lua, brilho suave"""
    gc = glow_col or c1
    img.alpha_composite(soft_layer(lambda d: d.ellipse([cx - r * 1.35, cy - r * 1.35, cx + r * 1.35, cy + r * 1.35], fill=hexc(gc, 120)), r * 0.25))
    n = int(r * 2 + 4)
    yy, xx = np.mgrid[-n / 2:n / 2, -n / 2:n / 2]
    dist = np.sqrt(xx ** 2 + yy ** 2)
    m = dist <= r
    warp = gaussian_filter(rng.random(xx.shape), r * 0.08) * 6
    bands = (np.sin(yy / r * 7 + warp + np.sin(xx / r * 3) * 0.8) > 0.15).astype(float)
    if plain:
        # lua: manchas suaves e crateras no lugar das faixas
        bands = (gaussian_filter(rng.random(xx.shape), r * 0.12) > 0.52).astype(float) * 0.6
    col = np.array(hexc(c1)[:3]) * (1 - bands[..., None]) + np.array(hexc(c2)[:3]) * bands[..., None]
    # lado escuro: meia-lua deslocada
    shadow = np.sqrt((xx - r * 0.35) ** 2 + (yy - r * 0.2) ** 2) > r * 1.02
    col = np.where(shadow[..., None], col * 0.55 + np.array([20, 10, 60]) * 0.45, col)
    hi = np.sqrt((xx + r * 0.45) ** 2 + (yy + r * 0.45) ** 2) < r * 0.28
    col = np.where(hi[..., None] & m[..., None], col * 0.6 + 255 * 0.4, col)
    rgba = np.dstack([np.clip(col, 0, 255).astype(np.uint8), (m * 255).astype(np.uint8)])
    pl = Image.fromarray(rgba, "RGBA").filter(ImageFilter.GaussianBlur(0.6))
    if ring:
        rl = Image.new("RGBA", (int(r * 5), int(r * 5)), (0, 0, 0, 0))
        rd = ImageDraw.Draw(rl)
        c = rl.size[0] / 2
        rd.ellipse([c - r * 2.1, c - r * 0.5, c + r * 2.1, c + r * 0.5], outline=hexc(ring, 230), width=max(2, int(r * 0.07)))
        rl = rl.rotate(-12, resample=Image.BICUBIC)
        img.alpha_composite(rl, (int(cx - rl.size[0] / 2), int(cy - rl.size[1] / 2)))
        img.alpha_composite(pl, (int(cx - n / 2), int(cy - n / 2)))
        front = rl.crop((0, rl.size[1] // 2, rl.size[0], rl.size[1]))
        img.alpha_composite(front, (int(cx - rl.size[0] / 2), int(cy)))
    else:
        img.alpha_composite(pl, (int(cx - n / 2), int(cy - n / 2)))


def comet(img, x0, y0, x1, y1, col="#ff7ad8"):
    """estrela cadente: rastro que afina, cabeça branca e faíscas"""
    L = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    n = 40
    for i in range(n):
        t = i / (n - 1)
        x = lerp(x0, x1, t)
        y = lerp(y0, y1, t)
        w = 1 + t * 9
        c = hexc(col, int(40 + 200 * t))
        d.ellipse([x - w, y - w, x + w, y + w], fill=c)
    img.alpha_composite(L.filter(ImageFilter.GaussianBlur(4)))
    img.alpha_composite(L)
    d2 = ImageDraw.Draw(img)
    d2.ellipse([x1 - 9, y1 - 9, x1 + 9, y1 + 9], fill=(255, 255, 255, 255))
    rr = np.random.default_rng(int(x0))
    for k in range(10):
        t = rr.random()
        x, y = lerp(x0, x1, t) + rr.normal(0, 8), lerp(y0, y1, t) + rr.normal(0, 8)
        d2.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(255, 230, 250, 220))


def vortex(img, cx, cy, r, rng):
    """redemoinho galáctico com núcleo verde-turquesa e feixe (referência 2)"""
    disk = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(disk)
    for k in range(260):
        t = rng.random()
        a = rng.random() * 6.28
        rr = r * (0.15 + t * 0.95)
        x = cx + math.cos(a) * rr
        y = cy + math.sin(a) * rr * 0.32
        s = r * (0.05 + 0.08 * (1 - t))
        col = ["#1a2a8a", "#2a50c8", "#3a80e0", "#60c8ff"][min(3, int((1 - t) * 4))]
        d.ellipse([x - s, y - s * 0.6, x + s, y + s * 0.6], fill=hexc(col, 230))
    img.alpha_composite(disk.filter(ImageFilter.GaussianBlur(2)))
    img.alpha_composite(soft_layer(lambda dd: dd.ellipse([cx - r * 0.35, cy - r * 0.15, cx + r * 0.35, cy + r * 0.15], fill=hexc("#80ffd0", 230)), r * 0.08))
    beam = soft_layer(lambda dd: dd.polygon([(cx - 10, cy), (cx + 10, cy), (cx + r * 0.25 + 6, cy - r * 2.2), (cx + r * 0.25 - 6, cy - r * 2.2)], fill=hexc("#7aff9a", 210)), 6)
    img.alpha_composite(beam)
    ImageDraw.Draw(img).ellipse([cx - 14, cy - 8, cx + 14, cy + 8], fill=(255, 255, 255, 255))


def build(seed=11):
    rng = np.random.default_rng(seed)
    img = Image.fromarray(gradient().astype(np.uint8)).convert("RGBA")
    img = ribbons(img.convert("RGB"), rng).convert("RGBA")
    # bolinhas desfocadas (bokeh)
    img.alpha_composite(soft_layer(lambda d: [d.ellipse([x - s, y - s, x + s, y + s], fill=hexc(c, 60)) for x, y, s, c in
                                              [(rng.random() * W, rng.random() * H, 8 + rng.random() * 26, rng.choice(["#a080ff", "#60c0ff", "#ff90d8"])) for _ in range(160)]], 6))
    stars(img, rng)
    for k in range(40):
        sparkle(img, rng.random() * W, rng.random() * H, 8 + rng.random() * 18, rng.choice(["#ffd0f0", "#c0e0ff", "#ffe8b0"]))
    # elementos grandes (o céu aparece em volta e abaixo do horizonte por causa do planeta pequeno)
    vortex(img, W * 0.70, H * 0.58, 330, rng)
    planet(img, W * 0.16, H * 0.62, 230, "#2a8ad8", "#1a5ab0", rng, glow_col="#60c0ff")
    planet(img, W * 0.42, H * 0.36, 120, "#f6f2ff", "#d6c8f0", rng, glow_col="#ffffff", plain=True)  # lua
    planet(img, W * 0.55, H * 0.78, 95, "#8ab0e8", "#c890c0", rng, ring="#e8d0ff")
    planet(img, W * 0.90, H * 0.42, 70, "#90b8f0", "#7a6ad0", rng)
    planet(img, W * 0.31, H * 0.86, 55, "#ff9ad0", "#c060b0", rng)
    for i in range(8):
        sz = rng.random()
        planet(img, rng.random() * W, H * (0.25 + 0.6 * rng.random()), 10 + sz * 22, rng.choice(["#a0d8ff", "#ffb0e0", "#b0a0ff", "#80f0d0"]), "#7060c0", rng)
    for i in range(5):
        x0 = rng.random() * W
        y0 = H * (0.2 + 0.5 * rng.random())
        comet(img, x0, y0, x0 + 300 + rng.random() * 300, y0 + 120 + rng.random() * 120, rng.choice(["#ff7ad8", "#c890ff", "#80d0ff"]))
    for i in range(14):
        cloud(img, rng.random() * W, H * (0.62 + 0.3 * rng.random()), 280 + rng.random() * 380, rng,
              "#ffffff" if i % 3 else "#f0e8ff", rng.choice(["#8aa8ff", "#a090f0", "#70b8f0"]))
    return img.convert("RGB")


if __name__ == "__main__":
    a = sys.argv[1:]
    seed, prev = 11, None
    if "--seed" in a:
        i = a.index("--seed")
        seed = int(a[i + 1])
        a = a[:i] + a[i + 2:]
    if "--preview" in a:
        i = a.index("--preview")
        prev = a[i + 1]
        a = a[:i] + a[i + 2:]
    out = a[0] if a else "sky/galaxias.jpg"
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    img = build(seed)
    img.save(out, quality=90)
    if prev:
        img.resize((W // 4, H // 4), Image.LANCZOS).save(prev)
    print("céu:", out)
