"""Hex Galaxies - músicas de batalha dos planetas novos (sintetizadas, loops sem emenda).

ABNARA - "Coração da Selva" (Ré dório, 100 BPM, 32 compassos)
  A selva viva: o mapa respira, cresce e morde. Marimba de madeira em polirritmo (3 contra 4)
  é o "chão" da floresta; o rio borbulha no fundo; flauta de madeira canta o tema; congas e
  tambores de tronco empurram o ritmo; no fim, as raízes "crescem" com taikos e trompa grave.
  1-8   a selva acorda: marimba, chocalho, bolhas do rio, tambor de tronco como coração
  9-16  a caça começa: congas, bumbo, baixo dório, flauta com o tema
  17-24 clareira (Fá maior): palmas, pergunta e resposta flauta x marimba, a planta predadora
        rosna (metais dissonantes)
  25-32 pulso das raízes: taikos, trompa no tema, tudo cresce e volta para a marimba (loop)

GOR'AIDA - "Gelo Instável" (Si menor/frígio, 6/8, 168 colcheias/min, 32 compassos)
  Gelo que canta e racha: sinos de vidro em ostinato de 6/8 (passos que escorregam), vento,
  estalos de gelo, um tema largo e frio no violoncelo/trompa, glissandos que deslizam como o
  gelo liso, e uma avalanche de taikos e metais antes de voltar ao silêncio branco.
  1-8   planalto branco: sinos de vidro, vento, gemidos graves do gelo, estalos
  9-16  a marcha no frio: taikos distantes, baixo longo, violoncelo com o tema
  17-24 gelo liso (Ré maior): arpejos rápidos, melodia que desliza (glissando), chocalho
  25-32 avalanche: rufos de taiko, metais no acorde frígio (Dó sobre Si), e volta ao vento

Uso: python tools/musica_planetas.py [pasta_sounds] [abnara,goraida]   (precisa de ffmpeg)
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from musica_faccoes import Track, SR, filt, hz  # noqa: E402


# ---------------- instrumentos extras ----------------
def flute(tr, notes, t0, g=0.07, pan=0.1):
    """flauta de madeira: seno com sopro e vibrato que entra devagar"""
    tr.lead(notes, t0, g, "sine", vib=0.007, glide=0.04, cut=4200, pan=pan, rev=0.55, breath=0.05)


def log_drum(tr, t0, m, g=0.12, pan=0.0):
    """tambor de tronco (fenda de madeira): tom curto e oco"""
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = hz(m)
    y = np.sin(2 * np.pi * f * t * (1 + 0.15 * np.exp(-t * 30))) * np.exp(-t * 9) + 0.3 * np.sin(2 * np.pi * f * 2.7 * t) * np.exp(-t * 25)
    tr.add(y, t0, g, pan, 0.35)


def growl(tr, t0, dur, m, g=0.05):
    """planta predadora: acorde grave dissonante que rosna"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for k in (0, 1, 6):
        y += tr.saw(hz(m + k), n, 0.12)
    y = filt(np.tanh(y * 2.0), "low", 700 + 900 * np.clip(t / dur, 0, 1).mean())
    y *= (1 + 0.5 * np.sin(2 * np.pi * 7 * t)) * tr.env(n, 0.08, 0.3)
    tr.add(y, t0, g, tr.rng.uniform(-0.4, 0.4), 0.5)


def wind(tr, t0, dur, g=0.05):
    """vento gelado: ruído em faixa que sobe e desce"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = tr.rng.normal(size=n)
    y = np.zeros(n)
    seg = 12
    for i in range(seg):
        a, b = i * n // seg, (i + 1) * n // seg
        c = 500 + 900 * (0.5 + 0.5 * np.sin(i / seg * 2 * np.pi + tr.rng.random()))
        y[a:b] = filt(x, "band", [c, c * 1.8])[a:b]
    y *= np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    tr.add(y, t0, g, tr.rng.uniform(-0.7, 0.7), 0.9)


def crack(tr, t0, g=0.06, pan=None):
    """estalo de gelo: estalo seco + ping agudo de vidro + baque grave"""
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    y = filt(tr.rng.normal(size=n), "high", 2500) * np.exp(-t * 90)
    y += 0.5 * np.sin(2 * np.pi * hz(tr.rng.choice([93, 95, 98])) * t) * np.exp(-t * 14)
    y += 0.6 * np.sin(2 * np.pi * 55 * t) * np.exp(-t * 20)
    tr.add(y, t0, g, tr.rng.uniform(-0.8, 0.8) if pan is None else pan, 0.6)


def groan(tr, t0, dur, g=0.08):
    """gemido grave do gelo: tom grave que desce devagar"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 62 * (1 - 0.18 * t / dur)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * filt(tr.rng.normal(size=n), "low", 160)
    y *= np.sin(np.pi * t / dur)
    tr.add(y, t0, g, 0.0, 0.7)


# =====================================================================
# ABNARA - Coração da Selva
# =====================================================================
def abnara(dst):
    tr = Track(100, 32, seed=2170)
    dorian = [(38, [62, 65, 69]), (36, [60, 64, 67]), (43, [62, 67, 71]), (38, [62, 65, 69])]   # Rém - Dó - Sol - Rém
    lift = [(41, [65, 69, 72]), (36, [64, 67, 72]), (43, [62, 67, 71]), (38, [62, 65, 69])]    # Fá - Dó - Sol - Rém
    cyc = [0, 1, 2]          # marimba: ciclo de 3 notas sobre colcheias (3 contra 4)
    for bar in range(tr.bars):
        sec = bar // 8
        prog = lift if sec == 2 else dorian
        root, ch = prog[(bar // 2) % 4]
        last = bar == tr.bars - 1
        # ---------- marimba (o chão da floresta): sempre ----------
        tones = [ch[0] + 12, ch[1] + 12, ch[2] + 12]
        mg = [0.08, 0.06, 0.055, 0.06][sec]
        for i in range(8):
            k = cyc[(bar * 8 + i) % 3]
            tr.marimba(tr.T(bar, i * 0.5), tones[k] + (12 if (bar * 8 + i) % 6 == 5 else 0), mg * (1.2 if i % 4 == 0 else 1.0), -0.3 + 0.08 * i)
        # rio ao fundo
        tr.bubbles(tr.T(bar), tr.bar, [0.02, 0.012, 0.012, 0.015][sec], 5)
        if bar % 2 == 0:
            tr.pad([n - 12 for n in ch], tr.T(bar), tr.bar * 2, [0.025, 0.03, 0.035, 0.035][sec], cut=1100, det=0.08)
        tr.shaker(tr.T(bar, 0.5), 0.025, 0.5)
        tr.shaker(tr.T(bar, 1.5), 0.02, 0.5)
        tr.shaker(tr.T(bar, 2.5), 0.025, 0.5)
        tr.shaker(tr.T(bar, 3.5), 0.02, 0.5)
        if sec == 0:
            # tambor de tronco = coração da selva
            log_drum(tr, tr.T(bar, 0), 45, 0.14)
            log_drum(tr, tr.T(bar, 0.75), 45, 0.08)
            if bar % 2 == 1:
                log_drum(tr, tr.T(bar, 3), 52, 0.07, 0.3)
            continue
        if last:
            log_drum(tr, tr.T(bar, 0), 45, 0.12)
            continue
        # ---------- a caça ----------
        tr.kick(tr.T(bar, 0), 0.4, 42)
        tr.kick(tr.T(bar, 2.5), 0.3, 42)
        for b, p, sl in ((0.5, 1.0, False), (1.0, 1.3, True), (1.75, 1.0, False), (2.0, 1.2, False), (3.0, 1.3, True), (3.5, 1.0, False)):
            tr.conga(tr.T(bar, b), 0.1, p, -0.45 if p > 1.1 else 0.45, sl)
        log_drum(tr, tr.T(bar, 3.75), 50, 0.07, -0.3)
        for b, o, d in ((0, 0, 0.6), (1.0, 7, 0.4), (1.5, 12, 0.3), (2.5, 0, 0.5), (3.25, 10, 0.4)):
            tr.bass(tr.T(bar, b), root + o, tr.beat * d, 0.18, cut=600, dist=0.1)
        if sec == 2:
            tr.snare(tr.T(bar, 1), 0.06, 0.1)   # palmas/caixa leve
            tr.snare(tr.T(bar, 3), 0.07, -0.1)
            if bar in (19, 23):
                growl(tr, tr.T(bar, 2.0), tr.beat * 2.0, 38, 0.06)
        if sec == 3:
            tr.taiko(tr.T(bar, 0), 0.22, True)
            tr.taiko(tr.T(bar, 1.5), 0.14)
            tr.taiko(tr.T(bar, 2), 0.16)
            if bar % 2 == 1:
                for b in (3.0, 3.25, 3.5, 3.75):
                    tr.taiko(tr.T(bar, b), 0.08 + 0.02 * (b - 3) * 4)
    # ---------- tema (flauta de madeira) ----------
    theme = [(74, 0.75), (72, 0.25), (69, 0.5), (72, 0.5), (74, 1.0), (77, 1.0),
             (76, 0.5), (74, 0.5), (72, 0.5), (71, 0.5), (69, 2.0),
             (74, 0.75), (72, 0.25), (69, 0.5), (72, 0.5), (74, 1.0), (79, 1.0),
             (77, 0.5), (76, 0.5), (74, 0.5), (72, 0.5), (74, 2.0)]
    flute(tr, theme, tr.T(9), 0.07)
    flute(tr, theme, tr.T(13), 0.075)
    # clareira: pergunta (flauta) e resposta (marimba aguda)
    call = [(81, 0.5), (79, 0.5), (77, 1.0), (79, 2.0)]
    ans = [(77, 0.5), (76, 0.5), (72, 1.0), (74, 2.0)]
    for b0 in (17, 19, 21, 23):
        flute(tr, call, tr.T(b0), 0.07, 0.2)
        t = tr.T(b0 + 1)
        for m, d in ans:
            tr.marimba(t, m, 0.1, -0.3)
            tr.marimba(t, m + 12, 0.05, -0.3)
            t += d * tr.beat
    # pulso das raízes: trompa no tema, oitava abaixo
    for b0 in (25, 27):
        t = tr.T(b0)
        for m, d in theme[:11]:
            tr.horn(m - 12, t, d * tr.beat * 0.92, 0.08)
            t += d * tr.beat
    flute(tr, [(74, 4.0), (72, 2.0), (69, 2.0), (74, 8.0)], tr.T(29), 0.05, -0.1)
    tr.riser(tr.T(8), tr.bar, 0.03)
    tr.riser(tr.T(24), tr.bar, 0.04)
    tr.boom(tr.T(9), 0.09)
    tr.boom(tr.T(25), 0.13)
    return tr.render(dst, 3.0, 0.45, 1.3)


# =====================================================================
# GOR'AIDA - Gelo Instável (6/8: cada "beat" é uma colcheia)
# =====================================================================
def goraida(dst):
    tr = Track(168, 32, beats=6, seed=3310)
    cold = [(35, [59, 62, 66, 73]), (31, [55, 59, 62, 66]), (33, [57, 61, 64, 69]), (30, [54, 57, 61, 66])]   # Sim(add9) - Sol - Lá - Fá#m
    smooth = [(38, [62, 66, 69, 76]), (33, [57, 61, 64, 69]), (40, [55, 59, 64, 67]), (35, [59, 62, 66, 73])]  # Ré - Lá - Mim - Sim
    q = 3   # uma semínima pontuada = 3 colcheias
    for bar in range(tr.bars):
        sec = bar // 8
        prog = smooth if sec == 2 else cold
        root, ch = prog[(bar // 2) % 4]
        last = bar == tr.bars - 1
        # ---------- sinos de vidro (ostinato 6/8): sempre ----------
        pat = [0, 2, 1, 3, 2, 1]
        gg = [0.055, 0.04, 0.035, 0.04][sec]
        for i, k in enumerate(pat):
            if sec == 0 and bar % 2 == 1 and i in (1, 4):
                continue
            tr.glass(tr.T(bar, i), ch[k] + 12, gg * (1.25 if i in (0, 3) else 1.0), -0.5 + 0.2 * i, 3.5)
        if sec == 2:
            # gelo liso: arpejo rápido por cima, deslizando
            for i in range(6):
                tr.arp(ch[(i + bar) % 4] + 24, tr.T(bar, i + 0.5), 0.022, 0.5 - 0.2 * i, 4200, 12, echo=True)
        # ---------- fundo ----------
        if bar % 2 == 0:
            tr.pad([n - 12 for n in ch[:3]], tr.T(bar), tr.bar * 2, [0.03, 0.03, 0.035, 0.035][sec], cut=1300, det=0.12, shimmer=0.15)
        if bar % 4 == 0:
            wind(tr, tr.T(bar), tr.bar * 4, [0.06, 0.04, 0.035, 0.05][sec])
        if tr.rng.random() < (0.5 if sec != 2 else 0.25):
            crack(tr, tr.T(bar, tr.rng.uniform(0, 6)), 0.05)
        if sec == 0:
            if bar % 4 == 0:
                groan(tr, tr.T(bar, 0), tr.bar * 1.8, 0.09)
            tr.heart(tr.T(bar, 0), 0.12)
            continue
        if last:
            continue
        # ---------- marcha no frio ----------
        tr.taiko(tr.T(bar, 0), 0.2 if sec != 1 else 0.15, sec == 3)
        tr.taiko(tr.T(bar, q), 0.13)
        if sec >= 2:
            tr.kick(tr.T(bar, 0), 0.32, 40)
            tr.kick(tr.T(bar, 4), 0.2, 40)
            for i in (1, 2, 4, 5):
                tr.shaker(tr.T(bar, i), 0.02, 0.6 if i < 3 else -0.6)
            tr.hat(tr.T(bar, 3), 0.03, 0.2, open_=True)
        for b, o, d in ((0, 0, 2.6), (3, 7, 1.4), (4.5, 12, 1.2)):
            tr.bass(tr.T(bar, b), root + o, tr.beat * d, 0.17, cut=480, dist=0.05)
        if sec == 3:
            # avalanche: rufos e metais no acorde frígio (Dó maior sobre Si)
            for i in range(6):
                tr.taiko(tr.T(bar, 4.5 + i * 0.25), 0.05 + 0.015 * i)
            if bar % 2 == 0:
                for m in (48, 52, 55):
                    tr.brass(m, tr.T(bar, 0), tr.beat * 2.5, 0.05, 2400)
            else:
                for m in (47, 50, 54):
                    tr.brass(m, tr.T(bar, 0), tr.beat * 2.5, 0.05, 2400)
            crack(tr, tr.T(bar, 2), 0.07)
    # ---------- tema largo e frio (violoncelo e trompa) ----------
    theme = [(71, 3.0), (73, 1.5), (74, 1.5), (76, 3.0), (74, 3.0),
             (73, 3.0), (71, 1.5), (69, 1.5), (66, 6.0),
             (71, 3.0), (73, 1.5), (74, 1.5), (78, 3.0), (76, 3.0),
             (74, 3.0), (73, 1.5), (72, 1.5), (71, 6.0)]
    tr.cello([(m - 12, d) for m, d in theme], tr.T(9), 0.09)
    t = tr.T(13)
    for m, d in theme[9:]:
        tr.horn(m - 12, t, d * tr.beat * 0.95, 0.06)
        t += d * tr.beat
    # gelo liso: melodia que desliza (glissando longo entre as notas)
    slide = [(78, 3.0), (81, 3.0), (85, 4.5), (83, 1.5), (81, 3.0), (78, 3.0), (76, 6.0),
             (78, 3.0), (81, 3.0), (86, 4.5), (85, 1.5), (83, 3.0), (81, 3.0), (78, 6.0)]
    tr.lead(slide, tr.T(17), 0.05, "sine", vib=0.004, glide=0.22, cut=5000, pan=0.15, rev=0.75)
    tr.lead(slide, tr.T(21), 0.045, "square", vib=0.003, glide=0.22, cut=3200, pan=-0.15, rev=0.75)
    # avalanche: o tema volta forte na trompa
    t = tr.T(25)
    for m, d in theme[:9]:
        tr.horn(m - 12, t, d * tr.beat * 0.95, 0.085)
        t += d * tr.beat
    tr.lead([(71, 12.0), (66, 12.0)], tr.T(29), 0.03, "saw", vib=0.005, glide=0.3, cut=1600, pan=0.0, rev=0.9)
    tr.riser(tr.T(8), tr.bar, 0.03)
    tr.riser(tr.T(24), tr.bar * 1.0, 0.05)
    tr.boom(tr.T(9), 0.1)
    tr.boom(tr.T(17), 0.08)
    tr.boom(tr.T(25), 0.15)
    tr.boom(tr.T(27), 0.12)
    return tr.render(dst, 4.5, 0.6, 1.25)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "sounds"
    which = sys.argv[2].split(",") if len(sys.argv) > 2 else ["abnara", "goraida"]
    if "abnara" in which:
        print("abnara", round(abnara(os.path.join(out, "musica_abnara.ogg")), 1), "s")
    if "goraida" in which:
        print("goraida", round(goraida(os.path.join(out, "musica_goraida.ogg")), 1), "s")
