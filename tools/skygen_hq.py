"""Céu de espaço no estilo HQ: fundo roxo profundo, nebulosas feitas de retícula
(pontos coloridos), estrelas de 4 pontas com contorno de tinta e estrelas neon.
python3 tools/skygen_hq.py -> sky/espaco.jpg (panorama 4096x2048)"""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 4096, 2048
rng = np.random.default_rng(7)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
v = yy / H
# fundo: índigo nos polos, roxo no horizonte
top = np.array([14, 6, 40], np.float32)
mid = np.array([52, 18, 98], np.float32)
k = np.exp(-((v - 0.5) / 0.22) ** 2)[..., None]
img = top * (1 - k) + mid * k

# nebulosas: campos suaves (soma de gaussianas) em 3 cores
def field(n, sx, sy, seed):
    r = np.random.default_rng(seed)
    f = np.zeros((H, W), np.float32)
    for _ in range(n):
        cx, cy = r.uniform(0, W), r.uniform(0.25 * H, 0.75 * H)
        ax, ay = r.uniform(*sx), r.uniform(*sy)
        dx = np.minimum(np.abs(xx - cx), W - np.abs(xx - cx))   # dá a volta no panorama
        f += r.uniform(0.6, 1.0) * np.exp(-(dx / ax) ** 2 - ((yy - cy) / ay) ** 2)
    return np.clip(f, 0, 1.3)

cols = [np.array([255, 62, 165], np.float32), np.array([41, 216, 255], np.float32), np.array([150, 80, 255], np.float32)]
fields = [field(5, (260, 520), (120, 260), 1), field(4, (220, 480), (100, 220), 2), field(6, (300, 600), (140, 300), 3)]
# retícula a 45°
step = 9.0
rx = (xx + yy) * 0.7071 / step
ry = (xx - yy) * 0.7071 / step
dd = np.hypot(rx - np.floor(rx) - 0.5, ry - np.floor(ry) - 0.5)
for c, f in zip(cols, fields):
    body = np.clip(f, 0, 1)[..., None]
    img = img * (1 - body * 0.45) + c * body * 0.45 * 0.6          # corpo leve da nebulosa
    r = 0.48 * np.sqrt(np.clip(f, 0, 1))
    dots = np.clip((r - dd) / 0.05 + 0.5, 0, 1)[..., None] * (body > 0.08)
    img = img * (1 - dots * 0.12) + c * dots * 0.12

im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
d = ImageDraw.Draw(im)
# poeira de estrelas
for _ in range(1600):
    x, y = rng.uniform(0, W), rng.uniform(0, H)
    r = rng.choice([1.2, 1.6, 2.2], p=[0.6, 0.3, 0.1])
    d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 250, 235, 255))

def star4(x, y, r, col, ink=True):
    pts = []
    for i in range(8):
        a = math.pi / 4 * i - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.26
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    if ink:
        big = [(x + (px - x) * 1.28, y + (py - y) * 1.28) for px, py in pts]
        d.polygon(big, fill=(14, 2, 30, 255))
    d.polygon(pts, fill=col)

def star5(x, y, r, col):
    pts = []
    for i in range(10):
        a = math.pi / 5 * i - math.pi / 2 + rng.uniform(-0.05, 0.05)
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    big = [(x + (px - x) * 1.22, y + (py - y) * 1.22) for px, py in pts]
    d.polygon(big, fill=(14, 2, 30, 255))
    d.polygon(pts, fill=col)

for _ in range(70):
    star4(rng.uniform(0, W), rng.uniform(0.12 * H, 0.88 * H), rng.uniform(7, 16), (255, 255, 255, 255))
neon = [(255, 225, 77, 255), (125, 255, 90, 255), (255, 62, 165, 255), (41, 240, 255, 255), (255, 150, 40, 255)]
for _ in range(16):
    star5(rng.uniform(0, W), rng.uniform(0.2 * H, 0.8 * H), rng.uniform(14, 26), neon[rng.integers(len(neon))])

out = os.path.join(os.path.dirname(__file__), "..", "sky", "espaco.jpg")
im.convert("RGB").save(out, quality=90)
im.convert("RGB").resize((1024, 512)).save("/tmp/claude-0/vit/sky_pv.png")
print("ok")
