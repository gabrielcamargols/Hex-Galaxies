"""Hex Galaxies - ícones das cartas: branco com contorno de tinta irregular (pincel), estilo HQ.
python3 tools/icones_cartas.py -> ui/cartas/ic/<id>.png a partir de ui/icons/<id>.png"""
import os, random
from PIL import Image, ImageFilter, ImageChops

SRC = os.path.join(os.path.dirname(__file__), "..", "ui", "icons")
OUT = os.path.join(os.path.dirname(__file__), "..", "ui", "cartas", "ic")
S = 192   # trabalha em 2x para o contorno ficar liso


def rough(mask, grow, seed):
    """dilata a máscara com raio variável: borda grossa e fina como pincelada"""
    rng = random.Random(seed)
    out = Image.new("L", mask.size, 0)
    for _ in range(14):
        r = grow + rng.choice([-2, -1, 0, 1, 2, 3])
        dx, dy = rng.randint(-3, 3), rng.randint(-3, 3)
        m = mask.filter(ImageFilter.MaxFilter(max(3, r * 2 + 1)))
        out = ImageChops.lighter(out, ImageChops.offset(m, dx, dy))
    return out.filter(ImageFilter.GaussianBlur(0.8)).point(lambda v: 255 if v > 110 else 0)


def make(path, dst, seed):
    im = Image.open(path).convert("RGBA").resize((S - 48, S - 48), Image.LANCZOS)
    a = Image.new("L", (S, S), 0)
    a.paste(im.getchannel("A"), (24, 24))
    a = a.point(lambda v: 255 if v > 60 else 0)
    ink = rough(a, 7, seed)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (S, S), (12, 4, 20, 255)), (0, 0), ink)
    white = Image.new("RGBA", (S, S), (255, 255, 255, 255))
    out.paste(white, (0, 0), a)
    # brilho de HQ: um traço claro deslocado não; mantém branco puro com leve sombra interna
    out.resize((S // 2, S // 2), Image.LANCZOS).save(dst)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for i, f in enumerate(sorted(os.listdir(SRC))):
        if f.endswith(".png"):
            make(os.path.join(SRC, f), os.path.join(OUT, f), i * 13 + 5)
    print("ok")
