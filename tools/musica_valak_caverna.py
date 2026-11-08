"""Hex Galaxies - trilha de Valak (caverna de cristais), "Eco dos Cristais".

Valak é disputado pelos Lithari (cristal) contra os Terramorfos (mineradores):
a música mistura os dois povos.
  - Lithari:    vidro e quartzo em 5 contra 4, grãos cintilantes, melodia de seno fria
  - Terramorfos: picaretas (bigornas), tambores graves, broca, violoncelo humano
Ré menor, 92 BPM, 32 compassos, loop sem emenda.
  1-8   caverna: gotas, zumbido grave, picaretas ao longe, vidro bem baixinho
  9-16  a mina acorda: tambores e picaretas em groove, violoncelo com o tema Terramorfo
  17-24 o meio divertido: vira Fá maior, marimba saltitante, vidro em 5:4 brincalhão,
        congas, e os dois temas conversam (violoncelo pergunta, cristal responde)
  25-32 os dois povos juntos: violoncelo e cristal ao mesmo tempo, e a caverna volta a escurecer
Uso: python tools/musica_valak_caverna.py [saida.ogg] [--amb saida_amb.ogg]
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from musica_faccoes import Track, SR, filt  # noqa: E402


def drip(tr, t0, m, g=0.05, pan=0.0):
    """gota d'água na caverna: estalo agudo que desce de altura + eco"""
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f0 = 440.0 * 2 ** ((m - 69) / 12)
    f = f0 * (1.0 + 1.6 * np.exp(-t * 40))
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 18)
    tr.add(y, t0, g, pan, 0.9)


def drone(tr, t0, dur, m, g=0.06):
    """zumbido grave da caverna (respiração da terra)"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 440.0 * 2 ** ((m - 69) / 12)
    y = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.5 * t + 1.0) + 0.3 * np.sin(2 * np.pi * f * 2.003 * t)
    wob = 0.6 + 0.4 * np.sin(2 * np.pi * 0.11 * t)
    env = np.minimum(1.0, t / 1.5) * np.minimum(1.0, (dur - t) / 1.5)
    y = filt(y * wob * env, "low", 500)
    tr.add(y, t0, g, 0.0, 0.6)


def valak(dst):
    tr = Track(92, 32, seed=909)
    # Ré menor (escuro) e, no meio, Fá maior (divertido)
    dark = [(38, [62, 65, 69]), (34, [62, 65, 70]), (36, [60, 64, 67]), (37, [61, 64, 69])]   # Rém - Si♭ - Dó - Lá
    fun = [(41, [65, 69, 72]), (36, [64, 67, 72]), (38, [62, 65, 69]), (34, [65, 70, 74])]    # Fá - Dó - Rém - Si♭
    lit_scale = [62, 63, 66, 67, 69, 70, 73]
    for bar in range(tr.bars):
        sec = bar // 8
        prog = fun if sec == 2 else dark
        root, ch = prog[(bar // 2) % 4]
        # ---------- caverna: gotas e zumbido (sempre, mais forte no começo e no fim) ----------
        if bar % 4 == 0:
            drone(tr, tr.T(bar), tr.bar * 4.2, 26 if sec != 2 else 29, 0.07 if sec in (0, 3) else 0.04)
        for k in range(2 if sec in (0, 3) else 1):
            b = tr.rng.uniform(0, 4)
            drip(tr, tr.T(bar, b), int(tr.rng.choice([86, 89, 91, 93, 96])), 0.035, tr.rng.uniform(-0.8, 0.8))
        # ---------- Terramorfos: picaretas ----------
        if sec == 0:
            if bar % 2 == 1:
                tr.anvil(tr.T(bar, 0), 0.035, 0.7, -0.7)        # picareta ao longe
                tr.anvil(tr.T(bar, 2.5), 0.025, 0.8, 0.7)
        else:
            tr.anvil(tr.T(bar, 0), 0.06, 0.75, -0.5)
            tr.anvil(tr.T(bar, 1.5), 0.045, 0.9, 0.5)
            tr.anvil(tr.T(bar, 2.5), 0.05, 0.75, -0.3)
            if sec != 2:
                tr.taiko(tr.T(bar, 0), 0.22, True)
                tr.taiko(tr.T(bar, 2), 0.16)
            tr.kick(tr.T(bar, 0), 0.4, 38)
            tr.kick(tr.T(bar, 2.5), 0.3, 38)
        if sec == 1 and bar % 4 == 3:
            tr.drill(tr.T(bar, 1), tr.beat * 2.0, 0.025)
        # ---------- Lithari: vidro em 5 contra 4 ----------
        vol = [0.018, 0.035, 0.055, 0.045][sec]
        for i in range(5):
            m = ch[i % 3] + 24 + (12 if i == 4 else 0)
            tr.glass(tr.T(bar, i * 4 / 5), m, vol, -0.6 + 0.3 * i, 3.5 if sec != 2 else 2.0)
        if sec >= 1:
            tr.click(tr.T(bar, 1.25), 0.06, tr.rng.uniform(-0.5, 0.5))
            tr.glass(tr.T(bar, 2.75), lit_scale[tr.rng.integers(len(lit_scale))] + 36, 0.02, tr.rng.uniform(-0.8, 0.8), 8.0)
        tr.grains(tr.T(bar), tr.bar, ch[0] + 12, 0.008 + 0.006 * (sec in (1, 3)), 20 + 10 * sec)
        # ---------- baixo e cordas ----------
        if sec >= 1:
            tr.bass(tr.T(bar, 0), root, tr.beat * (1.4 if sec == 2 else 2.4), 0.22, cut=340, dist=0.15)
            tr.bass(tr.T(bar, 2.5), root + (7 if sec == 2 else 0), tr.beat * 1.2, 0.18, cut=340, dist=0.15)
        if bar % 2 == 0:
            tr.pad([n - 12 for n in ch], tr.T(bar), tr.bar * 2, 0.03 if sec != 2 else 0.022, cut=750, det=0.12)
        # ---------- o meio divertido: marimba saltitante e congas ----------
        if sec == 2:
            pat = [ch[0], ch[1] + 12, ch[2], ch[1] + 12, ch[0] + 12, ch[2], ch[1] + 12, ch[2] + 12]
            for i, m in enumerate(pat):
                tr.marimba(tr.T(bar, i * 0.5), m, 0.075 if i % 2 == 0 else 0.05, -0.4 if i % 2 else 0.4)
            for b, p, sl in ((0, 1.0, False), (0.75, 1.3, False), (1.5, 1.0, True), (2.5, 1.3, False), (3.25, 1.1, True)):
                tr.conga(tr.T(bar, b), 0.12, p, -0.3 if p > 1 else 0.3, sl)
            tr.shaker(tr.T(bar, 1.0), 0.04)
            tr.shaker(tr.T(bar, 3.0), 0.04)
            tr.snare(tr.T(bar, 1), 0.06)
            tr.snare(tr.T(bar, 3), 0.07)
    # ---------- temas ----------
    # Terramorfos: violoncelo (o lado humano, teimoso)
    cel = [(57, 1.5), (60, 0.5), (62, 1.0), (65, 1.0), (64, 2.0), (60, 1.0), (62, 1.0),
           (57, 1.5), (58, 0.5), (60, 1.0), (62, 1.0), (57, 4.0)]
    tr.cello(cel, tr.T(10), 0.1)
    # Lithari: cristal frio e estranho
    lit = [(74, 1.0), (75, 0.5), (78, 1.5), (None, 1.0), (74, 0.5), (73, 0.5), (70, 2.0), (None, 1.0),
           (81, 1.0), (82, 0.5), (78, 1.5), (75, 1.0), (74, 3.0)]
    tr.lead(lit, tr.T(4), 0.035, "sine", vib=0.0, glide=0.01, cut=6000, pan=0.3, rev=1.0)
    # meio divertido: o violoncelo pergunta (Fá maior) e o cristal responde, brincando
    q1 = [(65, 0.5), (67, 0.5), (69, 1.0), (72, 1.0), (69, 1.0)]
    a1 = [(81, 0.5), (84, 0.5), (81, 0.5), (77, 0.5), (79, 2.0)]
    q2 = [(70, 0.5), (69, 0.5), (67, 1.0), (65, 1.0), (67, 1.0)]
    a2 = [(77, 0.5), (79, 0.5), (81, 0.5), (84, 0.5), (86, 2.0)]
    for i, (q, a) in enumerate(((q1, a1), (q2, a2), (q1, a1), (q2, [(77, 0.5), (76, 0.5), (74, 1.0), (72, 2.0)]))):
        tr.cello(q, tr.T(16 + i * 2), 0.09)
        tr.lead(a, tr.T(17 + i * 2), 0.06, "sine", vib=0.004, glide=0.02, cut=7000, pan=-0.3, rev=0.7)
    # os dois povos juntos: violoncelo e cristal ao mesmo tempo
    tr.cello(cel, tr.T(24), 0.09)
    tr.lead([(n + 12 if n else None, d) for n, d in cel[:6]] + [(81, 2.0), (78, 1.0), (74, 4.0)], tr.T(24), 0.04, "sine", vib=0.0, glide=0.01, cut=6000, pan=0.35, rev=1.0)
    tr.riser(tr.T(15), tr.bar, 0.035)
    tr.riser(tr.T(23), tr.bar, 0.03)
    tr.boom(tr.T(16), 0.1)
    tr.boom(tr.T(24), 0.12)
    return tr.render(dst, 4.5, 0.6, 1.3)


def ambiente(dst):
    """caverna sem música: gotas, zumbido grave e pedrinhas caindo (loop curto)"""
    tr = Track(60, 16, seed=919)
    for bar in range(tr.bars):
        if bar % 4 == 0:
            drone(tr, tr.T(bar), tr.bar * 4.3, 26, 0.12)
        for k in range(3):
            drip(tr, tr.T(bar, tr.rng.uniform(0, 4)), int(tr.rng.choice([84, 88, 91, 95])), 0.05, tr.rng.uniform(-0.9, 0.9))
        if tr.rng.random() < 0.35:
            tr.stone(tr.T(bar, tr.rng.uniform(0, 4)), 0.05, tr.rng.uniform(-0.8, 0.8))
    return tr.render(dst, 5.0, 0.8, 1.0)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "sounds/musica_valak.ogg"
    print("tema", round(valak(out), 1), "s")
    if "--amb" in sys.argv:
        amb = sys.argv[sys.argv.index("--amb") + 1]
        print("ambiente", round(ambiente(amb), 1), "s")
