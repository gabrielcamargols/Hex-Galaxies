"""Hex Galaxies - importa a arte dos Zukunft (pacote HEX_GALAXIES_Zukunft_Aprovados.zip).

Uso: python3 tools/arte_zukunft.py <pasta com Ilustracoes/ e Avatares/> [id,id,...]

Para cada personagem gera art/<id>.webp (corpo inteiro, 480x440) e art/p_<id>.webp (avatar 160x160).
Os avatares já vêm prontos (quadrados, fundo transparente); só são reduzidos. O corpo inteiro usa o
enquadramento do tools/arteprep.py; quem paira (HOVER) deixa espaço embaixo, como na arte anterior.
"""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import arteprep

# arquivo (sem extensão) -> id da carta
MAPA = {
    "01_Vanguarda": "z_vang",
    "02_Tank": "z_tank",
    "03_Engenheira_de_Escudos": "z_escudo",
    "04_Drone_Sentinela": "z_drone",
    "06_Cao": "z_cao",
    "07_Dragao": "z_dragao",
    "08_Guardiao_Fenix": "z_fenix",
    "09_Guardiao_Meca": "z_meca",
    "10_Duelista": "z_duel",
    "11_Bioengenheiro": "z_bio",
    "12_Hacker_Tatico": "z_hacker",
    "14_Guardiao_Real": "z_real",
    "15_Brawler_Holografico": "z_brawler",
    "16_Diplomata_Comandante": "z_diplo",
}
HOVER = {"z_drone": 0.38}


def main(base, only=None):
    for stem, cid in MAPA.items():
        if only and cid not in only:
            continue
        ilu = os.path.join(base, "Ilustracoes", stem + ".png")
        av = os.path.join(base, "Avatares", stem + ".png")
        arteprep.prep(ilu, cid, hover=HOVER.get(cid, 0.0))
        por = Image.open(av).convert("RGBA")
        a = por.getchannel("A").point(lambda v: 0 if v < 14 else v)
        por.putalpha(a)
        por = por.resize((160, 160), Image.LANCZOS)
        por.save(os.path.join(arteprep.ART, "p_%s.webp" % cid), quality=92)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2].split(",") if len(sys.argv) > 2 else None)
