"""Hex Galaxies - trilha de Valak (caverna de cristais), "Caixinha de Cristal" (2ª versão).

Valak é disputado pelos Lithari (cristal) contra os Terramorfos (mineradores).
Ideia: uma caixinha de música de cristal (Lithari) que a mina inteira (Terramorfos)
transforma numa canção de trabalho, com picaretas fazendo o contratempo.
Mi menor -> Sol maior no meio. 104 BPM, 32 compassos, loop sem emenda.
  1-8   escuro: caixinha de cristal sozinha (ostinato), coração grave, zumbido de violoncelo
  9-16  a mina entra no ritmo: bumbo, picaretas no 2 e no 4, baixo sincopado, golpes de metais
  17-24 o meio divertido (Sol maior): melodia saltitante e grudenta, palmas, congas,
        o cristal faz contracanto
  25-32 os dois povos juntos: trompa (Terramorfos) e cristal tocam o mesmo tema, depois
        tudo se recolhe de volta para a caixinha (para o loop emendar)
Uso: python tools/musica_valak_caverna.py [saida.ogg] [--amb saida_amb.ogg]
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from musica_faccoes import Track, SR, filt  # noqa: E402


def drone(tr, t0, dur, m, g=0.06):
    """zumbido grave tipo violoncelo arrastado"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 440.0 * 2 ** ((m - 69) / 12)
    ph = 2 * np.pi * f * t
    y = np.sin(ph) + 0.45 * np.sin(2 * ph + 0.3) + 0.25 * np.sin(3 * ph) + 0.12 * np.sin(4.01 * ph)
    env = np.minimum(1.0, t / 1.2) * np.minimum(1.0, (dur - t) / 1.2)
    y = filt(y * env * (0.8 + 0.2 * np.sin(2 * np.pi * 4.5 * t)), "low", 900)
    tr.add(y, t0, g, 0.0, 0.5)


def music_box(tr, t0, m, g=0.05, pan=0.0):
    """caixinha de música de cristal: ataque de vidro + parcial inarmônico"""
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    f = 440.0 * 2 ** ((m - 69) / 12)
    y = np.sin(2 * np.pi * f * t) * np.exp(-t * 3.0) + 0.35 * np.sin(2 * np.pi * f * 3.98 * t) * np.exp(-t * 9.0)
    y += 0.15 * np.sin(2 * np.pi * f * 6.7 * t) * np.exp(-t * 18.0)
    tr.add(y, t0, g, pan, 0.55)


def clap(tr, t0, g=0.08, pan=0.0):
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    nz = tr.rng.normal(size=n)
    env = np.exp(-t * 30) + 0.6 * np.exp(-np.maximum(0, t - 0.012) * 30) * (t > 0.012) + 0.4 * np.exp(-np.maximum(0, t - 0.025) * 25) * (t > 0.025)
    tr.add(filt(nz * env, "band", [900, 2600]), t0, g, pan, 0.35)


def valak(dst):
    tr = Track(104, 32, seed=4242)
    # Mi menor no escuro; Sol maior no meio
    dark = [(40, [64, 67, 71]), (36, [64, 67, 72]), (38, [62, 66, 69]), (35, [63, 66, 71])]   # Mim - Dó - Ré - Si
    bright = [(43, [67, 71, 74]), (36, [64, 67, 72]), (38, [62, 66, 69]), (40, [64, 67, 71])]  # Sol - Dó - Ré - Mim
    # ostinato da caixinha (8 colcheias por compasso)
    box = [0, 2, 1, 2, 0, 2, 1, 3]
    for bar in range(tr.bars):
        sec = bar // 8
        prog = bright if sec == 2 else dark
        root, ch = prog[(bar // 2) % 4]
        tones = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[0] + 24]
        last = bar == tr.bars - 1
        # ---------- caixinha de cristal (Lithari): sempre ----------
        bg = [0.05, 0.035, 0.03, 0.04][sec]
        for i, k in enumerate(box):
            if sec == 2 and i % 2 == 1:
                continue
            music_box(tr, tr.T(bar, i * 0.5), tones[k], bg * (1.15 if i == 0 else 1.0), -0.35 + 0.1 * i)
        # ---------- fundo ----------
        if bar % 2 == 0:
            drone(tr, tr.T(bar), tr.bar * 2.1, root - 12 + (12 if root < 38 else 0), [0.07, 0.05, 0.03, 0.05][sec])
            tr.pad([n - 12 for n in ch], tr.T(bar), tr.bar * 2, [0.02, 0.03, 0.03, 0.035][sec], cut=900, det=0.1)
        if sec == 0:
            tr.heart(tr.T(bar, 0), 0.18)
            if bar % 2 == 1:
                tr.anvil(tr.T(bar, 3.0), 0.025, 0.7, 0.6)
            continue
        if last:
            continue
        # ---------- a mina no ritmo (Terramorfos) ----------
        tr.kick(tr.T(bar, 0), 0.45, 40)
        tr.kick(tr.T(bar, 1.75), 0.3, 40)
        tr.kick(tr.T(bar, 2.5), 0.38, 40)
        tr.anvil(tr.T(bar, 1), 0.07, 0.85, -0.4)      # picareta no contratempo
        tr.anvil(tr.T(bar, 3), 0.07, 0.95, 0.4)
        tr.hat(tr.T(bar, 0.5), 0.035, 0.3)
        tr.hat(tr.T(bar, 1.5), 0.035, 0.3)
        tr.hat(tr.T(bar, 2.5), 0.035, 0.3)
        tr.hat(tr.T(bar, 3.5), 0.04, 0.3, open_=True)
        # baixo sincopado com salto de oitava
        for b, o, d in ((0, 0, 0.7), (0.75, 12, 0.3), (1.5, 0, 0.4), (2.5, 7, 0.6), (3.25, 12, 0.3)):
            tr.bass(tr.T(bar, b), root + o, tr.beat * d, 0.2, cut=520, dist=0.25)
        if sec == 1 and bar % 4 == 3:
            for m in ch:
                tr.brass(m - 12, tr.T(bar, 2.5), tr.beat * 1.2, 0.045, 2200)
        if sec >= 2:
            clap(tr, tr.T(bar, 1), 0.07, -0.2)
            clap(tr, tr.T(bar, 3), 0.08, 0.2)
        if sec == 2:
            for b, p, sl in ((0.5, 1.2, False), (1.25, 1.0, True), (2.0, 1.3, False), (3.5, 1.1, True)):
                tr.conga(tr.T(bar, b), 0.1, p, -0.4 if p > 1.1 else 0.4, sl)
        if sec == 3:
            tr.taiko(tr.T(bar, 0), 0.2, True)
            tr.taiko(tr.T(bar, 2), 0.14)
            tr.snare(tr.T(bar, 3.75), 0.05)
    # ---------- melodias ----------
    # tema (Sol maior, saltitante): 4 compassos, tocado 2x no meio
    theme = [(74, 0.5), (74, 0.25), (76, 0.25), (79, 0.5), (76, 0.5), (74, 1.0), (71, 1.0),
             (72, 0.5), (72, 0.25), (74, 0.25), (76, 0.5), (72, 0.5), (69, 2.0),
             (74, 0.5), (74, 0.25), (76, 0.25), (79, 0.5), (81, 0.5), (83, 1.0), (79, 1.0),
             (78, 0.5), (76, 0.5), (74, 0.5), (78, 0.5), (79, 2.0)]
    for start in (17, 21):
        tr.lead(theme, tr.T(start), 0.065, "square", vib=0.004, glide=0.015, cut=3800, pan=0.0, rev=0.35)
    for start, notes in ((18, [(86, 0.5), (83, 0.5)]), (20, [(81, 0.5), (79, 0.5), (78, 1.0)]),
                         (22, [(88, 0.5), (86, 0.5)]), (24, [(83, 1.0)])):
        t = tr.T(start - 1, 2.0)
        for m, d in notes:
            music_box(tr, t, m, 0.06, 0.4)
            t += d * tr.beat
    # escuro: o mesmo tema, lento e em menor, no violoncelo (o lado humano, Terramorfos)
    dark_theme = [(64, 1.5), (67, 0.5), (71, 1.0), (67, 1.0), (66, 2.0), (62, 2.0),
                  (64, 1.5), (67, 0.5), (72, 1.0), (71, 1.0), (66, 4.0)]
    tr.cello(dark_theme, tr.T(9), 0.09)
    tr.cello(dark_theme, tr.T(13), 0.08)
    # os dois povos juntos: trompa e cristal no tema, em Mi menor
    joint = [(76, 0.5), (76, 0.25), (79, 0.25), (83, 0.5), (79, 0.5), (78, 1.0), (75, 1.0),
             (76, 0.5), (76, 0.25), (78, 0.25), (79, 0.5), (76, 0.5), (71, 2.0)]
    for start in (25, 27):
        t = tr.T(start)
        for m, d in joint:
            if m is not None:
                tr.horn(m - 12, t, d * tr.beat * 0.92, 0.075)
                music_box(tr, t, m + 12, 0.05, 0.3)
            t += d * tr.beat
    tr.lead([(71, 4.0), (72, 2.0), (74, 2.0), (71, 8.0)], tr.T(29), 0.04, "saw", vib=0.006, glide=0.2, cut=1800, pan=-0.2, rev=0.8)
    tr.riser(tr.T(8), tr.bar, 0.03)
    tr.riser(tr.T(16), tr.bar, 0.035)
    tr.boom(tr.T(9), 0.1)
    tr.boom(tr.T(17), 0.1)
    tr.boom(tr.T(25), 0.12)
    return tr.render(dst, 3.5, 0.5, 1.35)


def ambiente(dst):
    """caverna sem música: zumbido grave, pedrinhas e um tilintar de cristal distante"""
    tr = Track(60, 16, seed=919)
    for bar in range(tr.bars):
        if bar % 4 == 0:
            drone(tr, tr.T(bar), tr.bar * 4.3, 28, 0.1)
        if tr.rng.random() < 0.5:
            music_box(tr, tr.T(bar, tr.rng.uniform(0, 4)), int(tr.rng.choice([83, 86, 88, 91])), 0.025, tr.rng.uniform(-0.9, 0.9))
        if tr.rng.random() < 0.35:
            tr.stone(tr.T(bar, tr.rng.uniform(0, 4)), 0.05, tr.rng.uniform(-0.8, 0.8))
    return tr.render(dst, 5.0, 0.8, 1.0)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "sounds/musica_valak.ogg"
    print("tema", round(valak(out), 1), "s")
    if "--amb" in sys.argv:
        amb = sys.argv[sys.argv.index("--amb") + 1]
        print("ambiente", round(ambiente(amb), 1), "s")
