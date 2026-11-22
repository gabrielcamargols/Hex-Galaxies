"""Ícones das 28 táticas exclusivas da Disputa (ui/cartas/ic/x_*.png, 128x128):
símbolo da facção na cor da facção + selo hexagonal da função (ui/hud/*.svg) no canto.
Precisa do rsvg-convert. python3 tools/icones_exclusivas.py
"""
import json, os, subprocess, tempfile
from PIL import Image, ImageOps, ImageFilter
R = os.path.join(os.path.dirname(__file__), "..")
SIMB = {"KRI": "krieg_simbolo", "WAC": "simbolo_wac", "ZUK": "simbolo_zuk", "FAU": "simbolo_fau", "ABY": "simbolo_aby", "LIT": "simbolo_lit", "TER": "simbolo_ter"}
GLIFO = {"x_fogo_cruzado": "ataque", "x_retirada_ordem": "movimento", "x_marcacao": "alcance", "x_cobrir": "defesa",
         "x_retomar": "hex", "x_linha_escudos": "defesa", "x_troca_sentinela": "movimento", "x_interposicao": "defesa",
         "x_desvio": "movimento", "x_rele": "movimento", "x_holo": "habilidade", "x_janela": "movimento",
         "x_revezamento": "movimento", "x_suprimento": "vida", "x_caminhos": "movimento", "x_ritmo": "ataque",
         "x_corrente": "habilidade", "x_mare_recuo": "chuva", "x_pressao": "ataque", "x_cerco": "alcance",
         "x_esporao": "habilidade", "x_reacao_cadeia": "habilidade", "x_semente": "habilidade", "x_ocupacao": "defesa",
         "x_escora": "seta_sobe", "x_desvio_trilho": "passar", "x_passagem": "dunas", "x_ferramenta": "ataque"}
cards = json.load(open(os.path.join(R, "data/cards.json")))
fcol = {k: v["color"] for k, v in cards["factions"].items()}
tmp = tempfile.mkdtemp()
for t in cards["tactics_ex"]:
    f = t["fac"]
    s = Image.open(os.path.join(R, "vfx/tex/%s.png" % SIMB[f])).convert("L").resize((112, 112), Image.LANCZOS)
    c = fcol[f].lstrip("#")
    rgb = tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))
    cor = Image.new("RGBA", s.size, rgb + (255,))
    cor.putalpha(s)
    # contorno escuro para ler em cima da carta
    sombra = Image.new("RGBA", s.size, (18, 10, 30, 255))
    sombra.putalpha(s.filter(ImageFilter.MaxFilter(7)))
    im = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    im.alpha_composite(sombra, (4, 2))
    im.alpha_composite(cor, (4, 2))
    png = os.path.join(tmp, t["id"] + ".png")
    subprocess.run(["rsvg-convert", "-w", "60", "-h", "60", os.path.join(R, "ui/hud/%s.svg" % GLIFO[t["id"]]), "-o", png], check=True)
    g = Image.open(png).convert("RGBA")
    im.alpha_composite(g, (66, 66))
    im.save(os.path.join(R, "ui/cartas/ic/%s.png" % t["id"]))
print(len(cards["tactics_ex"]), "ícones")
