"""Hex Galaxies - importa a arte dos Valakianos (Refugiados de Valak).

Uso: python3 tools/arte_valakianos.py <pasta com Ilustracoes/ e Avatares/>

Para cada personagem gera art/<id>.webp (corpo inteiro, 480x440) e art/p_<id>.webp (avatar 160x160)
a partir do pacote Hex_Galaxies_Valakianos_Ilustracoes_e_Avatares.zip. Os avatares já vêm prontos
(quadrados, fundo transparente); só são reduzidos. Corpo inteiro usa o mesmo enquadramento do
tools/arteprep.py (as peças largas e baixas, como o Golem Feram, ficam no chão).
"""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import arteprep

# arquivo (sem extensão) -> id da carta
MAPA = {
    "Rei_da_Mina": "rei_mina",
    "Perfurador": "perfurador",
    "Golem_de_Basalto": "t_basalto",
    "Carrinho_de_Minerio": "t_carrinho",
    "Britadeiro": "t_britadeira",
    "Fundidor": "t_fundidor",
    "Demolidora_de_Fendas": "t_fendas",
    "Sismico": "sismico",
    "Dinamitador": "t_dinamite",
    "Sentinela_de_Pedra": "t_sentinela",
    "Lanterneira": "t_lanterna",
    "Guarda_Raiz": "t_raiz",
    "Cartografo_Subterraneo": "t_cartografo",
    "Sniper": "t_sniper",
    "Enfermeira_dos_Cristais": "t_enfermeira",
    "Golem_Feram": "t_feram",
    "Engenheiro_de_Pontes": "t_pontes",
}


def main(base):
    for stem, cid in MAPA.items():
        ilu = os.path.join(base, "Ilustracoes", stem + ".png")
        av = os.path.join(base, "Avatares", stem + "_Avatar.png")
        arteprep.prep(ilu, cid)
        por = Image.open(av).convert("RGBA")
        a = por.getchannel("A").point(lambda v: 0 if v < 14 else v)
        por.putalpha(a)
        por = por.resize((160, 160), Image.LANCZOS)
        por.save(os.path.join(arteprep.ART, "p_%s.webp" % cid), quality=92)


if __name__ == "__main__":
    main(sys.argv[1])
