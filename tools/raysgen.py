"""Fundo de quadrinho: raios de velocidade + retícula de pontos (branco com transparência; no jogo é tingido).
python3 tools/raysgen.py -> ui/rays.png"""
from PIL import Image, ImageDraw
import math, random, os
W, H = 1280, 800
SS = 2
im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
cx, cy = W * SS * 0.5, H * SS * 0.46
R = math.hypot(W, H) * SS
random.seed(7)
n = 44
a = 0.0
for i in range(n):
    step = 2 * math.pi / n * random.uniform(0.7, 1.3)
    if i % 2 == 0:
        a0, a1 = a, a + step * 0.8
        pts = [(cx, cy), (cx + R * math.cos(a0), cy + R * math.sin(a0)), (cx + R * math.cos(a1), cy + R * math.sin(a1))]
        d.polygon(pts, fill=(255, 255, 255, 78))
    a += step
# raios de relâmpago mais fortes (quebrados)
for k in range(6):
    ang = k * math.pi / 3 + 0.35
    pts = []
    r = R * 0.18
    side = 1
    pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    for j in range(5):
        r += R * 0.12
        ang2 = ang + side * 0.045
        pts.append((cx + r * math.cos(ang2), cy + r * math.sin(ang2)))
        side *= -1
    d.line(pts, fill=(255, 255, 255, 110), width=10 * SS, joint="curve")
def hexpts(x, y, r):
    """hexágono (ponta para cima) com raio r"""
    return [(x + r * math.cos(math.radians(60 * i + 30)), y + r * math.sin(math.radians(60 * i + 30))) for i in range(6)]


# retícula: hexágonos que crescem para as bordas
step = 22 * SS
for gy in range(0, H * SS, step):
    for gx in range(0, W * SS, step):
        x = gx + (step // 2 if (gy // step) % 2 else 0)
        dist = math.hypot(x - cx, gy - cy) / (R * 0.6)
        t = min(1.0, max(0.0, dist - 0.25))
        r = 1 + 6.5 * SS * t * t
        if r > 1.2:
            d.polygon(hexpts(x, gy, r * 1.15), fill=(255, 255, 255, 90))
im = im.resize((W, H), Image.LANCZOS)
im.save(os.path.join(os.path.dirname(__file__), "..", "ui", "rays.png"), optimize=True)
print(im.size)
