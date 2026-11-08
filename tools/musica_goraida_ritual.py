"""Hex Galaxies - Gor'Aida: "Canto do Gelo" (música ritual da tribo do gelo).

Sem sintetizador: todos os instrumentos são arcaicos e feitos por modelagem física
(o som nasce de uma corda, pele, tubo ou garganta simulados, não de ondas prontas):
  lira de cordas (cítara)      corda beliscada (Karplus-Strong) + caixa de madeira
  rabeca de arco (tagelharpa)  corda friccionada por arco de crina, arranha e geme
  gaita de fole                palheta dupla com bordões, ar instável
  vozes                        coro de homens e mulheres (pulso da glote + formantes das vogais),
                               canto gutural grave (kargyraa) com assobio de harmônicos
  flauta de osso               sopro com muito ar e afinação imperfeita
  chifre                       lábios vibrando num chifre de animal
  tambores de pele             tambor grande de guerra, tambores de mão (pele de animal)
  chocalhos de osso, gelo percutido, vento
Si menor, 6/8 (150 colcheias/min), 32 compassos, loop sem emenda.
  1-4   o planalto: vento, gelo tilintando, canto gutural, o tambor grande como coração
  5-8   a lira e a gaita de fole entram; a gaita canta o lamento
  9-16  o ritual: tambores de mão em 6/8, chocalhos, o xamã canta e a tribo responde; chifres
  17-20 a calmaria: flauta de osso sobre a lira, gelo percutido
  21-24 AVISO: tambores grandes acelerando, rabecas em tremolo subindo, gritos da tribo, chifre
  25-30 AVALANCHE: rabecas agressivas em ostinato, tambores em fúria, coro forte
  31-32 o vento volta com o canto gutural e a gaita (emenda com o começo)
Uso: python tools/musica_goraida_ritual.py [saida.ogg]
"""
import os
import sys

import numpy as np
from scipy.signal import lfilter, butter

sys.path.insert(0, os.path.dirname(__file__))
from musica_faccoes import Track, SR, filt, hz  # noqa: E402

RNG = np.random.default_rng(331)


# ---------------- blocos de física ----------------
def string_loop(x, f, decay=0.996, damp=0.5):
    """laço de corda (Karplus-Strong) com filtro: x é a excitação (beliscada ou arco)"""
    N = max(2, int(round(SR / f)))
    a = np.zeros(N + 2)
    a[0] = 1.0
    a[N] = -decay * (1 - damp)
    a[N + 1] = -decay * damp
    return lfilter([1.0], a, x)


def body(y, peaks, q=6.0):
    """caixa de ressonância de madeira/couro: soma de ressonâncias"""
    out = filt(y, "low", 2200) * 0.35       # o corpo abafa os agudos crus
    for f, gain in peaks:
        bw = f / q
        sos = butter(2, [max(20, f - bw / 2), f + bw / 2], "band", fs=SR, output="sos")
        from scipy.signal import sosfilt
        out = out + sosfilt(sos, y) * gain
    return out


def glottal(f, n, jitter=0.006, shimmer=0.05, vib=0.0):
    """pulso da glote: trem de pulsos com micro-variações, inclinação de -12 dB/oitava"""
    t = np.arange(n) / SR
    fr = f * (1 + vib * np.sin(2 * np.pi * 5.1 * t + RNG.random() * 6) + jitter * filt(RNG.normal(size=n), "low", 12) * 8)
    ph = np.cumsum(fr) / SR
    saw = (ph % 1.0) * 2 - 1
    pulse = -np.diff(np.concatenate([[0], np.maximum(0, np.sin(np.pi * (ph % 1.0) / 0.6) * ((ph % 1.0) < 0.6))]))
    src = pulse * 30 + saw * 0.05
    src = lfilter([1], [1, -0.95], src)   # inclinação espectral
    src *= 1 + shimmer * filt(RNG.normal(size=n), "low", 20) * 6
    return src


VOWELS = {   # formantes (Hz) e ganhos: voz masculina; a feminina sobe ~17%
    "a": [(730, 1.0), (1090, 0.6), (2440, 0.25), (3400, 0.1)],
    "o": [(570, 1.0), (840, 0.55), (2410, 0.15), (3300, 0.06)],
    "u": [(330, 1.0), (760, 0.35), (2240, 0.08), (3200, 0.04)],
    "e": [(530, 1.0), (1840, 0.45), (2480, 0.25), (3500, 0.08)],
    "i": [(300, 1.0), (2200, 0.35), (2950, 0.25), (3600, 0.08)],
}


def formants(src, vowel, fem=False, bw=80):
    from scipy.signal import sosfilt
    out = np.zeros_like(src)
    k = 1.17 if fem else 1.0
    for f, g in VOWELS[vowel]:
        f *= k
        b = bw + f * 0.06
        sos = butter(2, [f - b / 2, f + b / 2], "band", fs=SR, output="sos")
        out += sosfilt(sos, src) * g
    return out


# ---------------- instrumentos ----------------
def lira(tr, t0, m, g=0.1, pan=0.0, dur=3.0):
    """lira/cítara de cordas de tripa: beliscada com o dedo, caixa de madeira"""
    n = int(dur * SR)
    f = hz(m) * (1 + RNG.normal(0, 0.0015))
    N = int(SR / f)
    ex = RNG.normal(size=N)
    ex = lfilter([0.5], [1, -0.5], ex)                       # dedo (não palheta): mais macio
    p = max(1, int(N * 0.22))
    ex = ex - np.concatenate([np.zeros(p), ex[:-p]])          # ponto onde a corda é beliscada
    x = np.zeros(n)
    x[:N] = ex
    y = string_loop(x, f, 0.9965, 0.5)
    y = body(y, [(210, 0.8), (430, 0.6), (1100, 0.35), (2600, 0.12)])
    y = filt(y, "low", 3500)
    tr.add(y * 1.6, t0, g, pan, 0.5)


def rabeca(tr, t0, m, dur, g=0.08, press=0.5, tremolo=0.0, cresc=False, pan=None):
    """rabeca de arco arcaica (tagelharpa): crina arrastada na corda, chiado e aspereza"""
    n = int((dur + 0.4) * SR)
    t = np.arange(n) / SR
    f = hz(m) * (1 + RNG.normal(0, 0.002))
    bow = np.minimum(1, t / 0.035) * np.clip((dur - t) / 0.08, 0, 1)
    if tremolo:
        bow *= 0.35 + 0.65 * np.abs(np.sin(np.pi * tremolo * t))
    if cresc:
        bow *= 0.2 + 0.8 * np.clip(t / dur, 0, 1) ** 1.6
    # arco: "gruda e escorrega" (dente de serra irregular) + crina chiando
    ph = np.cumsum(f * (1 + 0.003 * np.sin(2 * np.pi * 5.5 * t)) * (1 + 0.004 * filt(RNG.normal(size=n), "low", 30) * 5)) / SR
    stick = (ph % 1.0) * 2 - 1
    x = (stick * (0.25 + 0.5 * press) + RNG.normal(size=n) * (0.15 + 0.35 * press)) * bow * 0.02
    y = string_loop(x, f, 0.999, 0.45)
    y = body(y, [(280, 0.9), (520, 0.6), (900, 0.5), (2900, 0.35 + 0.3 * press)], q=5)
    y = filt(np.tanh(y * (1.0 + press * 1.5)), "low", 4500)
    tr.add(y * 1.1, t0, g, RNG.uniform(-0.5, 0.5) if pan is None else pan, 0.45)


def gaita(tr, notes, t0, beat, g=0.06, pan=0.15, drone=True):
    """gaita de fole de couro: palheta dupla (pulso estreito que varia), bordões e ornamentos"""
    seq = []
    prev = None
    for m, d in notes:
        if prev is not None and m != prev and d >= 1.0:
            seq += [(83, 0.1), (m, d - 0.1)]
        else:
            seq.append((m, d))
        prev = m
    total = sum(d for _, d in seq)
    n = int((total * beat + 0.6) * SR)
    f = np.zeros(n)
    pos = 0
    for m, d in seq:
        k = int(d * beat * SR)
        f[pos:pos + k] = hz(m)
        pos += k
    f[pos:] = f[max(0, pos - 1)]
    t = np.arange(n) / SR
    bag = 1 + 0.006 * filt(RNG.normal(size=n), "low", 3) * 12      # pressão do fole oscila
    ph = np.cumsum(f * bag) / SR
    duty = 0.3 + 0.03 * np.sin(2 * np.pi * 0.7 * t)
    reed = np.where((ph % 1.0) < duty, 1.0, -0.45) + RNG.normal(size=n) * 0.08
    y = filt(body(reed, [(1150, 1.0), (2300, 0.6), (3400, 0.25)], q=3), "low", 3800)
    amp = np.minimum(1, t / 0.06) * np.clip((n / SR - t - 0.4) / 0.25, 0, 1)
    tr.add(np.tanh(y * amp * 0.8), t0, g, pan, 0.5)


def bordao(tr, t0, dur, g=0.05):
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for m, a in ((35, 1.0), (47, 0.6)):
        ph = np.cumsum(np.full(n, hz(m)) * (1 + 0.003 * filt(RNG.normal(size=n), "low", 2) * 10)) / SR
        reed = np.where((ph % 1.0) < 0.35, 1.0, -0.5)
        y += filt(body(reed, [(380, 1.0), (900, 0.5), (1800, 0.25)], q=3), "low", 2400) * a
    y *= np.minimum(1, t / 1.2) * np.minimum(1, (dur - t) / 1.2)
    tr.add(np.tanh(y * 0.7), t0, g, -0.1, 0.5)


def voz(tr, t0, m, dur, vowel="a", g=0.05, fem=False, pan=0.0, att=0.08, vib=0.008, to=None):
    """uma voz cantando uma vogal (pode mudar de vogal no meio: to)"""
    n = int((dur + 0.3) * SR)
    t = np.arange(n) / SR
    src = glottal(hz(m), n, vib=vib)
    env = np.minimum(1, t / att) * np.clip((dur - t) / 0.18, 0, 1)
    y = formants(src * env, vowel, fem)
    if to:
        y2 = formants(src * env, to, fem)
        k = np.clip(t / dur, 0, 1)
        y = y * (1 - k) + y2 * k
    y += filt(RNG.normal(size=n), "band", [1500, 5000]) * env * 0.02     # ar na voz
    tr.add(y, t0, g, pan, 0.6)


def coro(tr, t0, m, dur, vowel="a", g=0.04, fem=False, voices=5, **kw):
    for i in range(voices):
        voz(tr, t0 + RNG.uniform(0, 0.04), m + (12 if fem and i % 2 else 0) + RNG.normal(0, 0.06), dur,
            vowel, g / np.sqrt(voices) * 0.45, fem, RNG.uniform(-0.7, 0.7), **kw)


def gutural(tr, t0, dur, m=35, g=0.07, vowels=("o", "a")):
    """canto gutural (kargyraa): voz grave com subharmônico e assobio de harmônicos por cima"""
    n = int((dur + 0.3) * SR)
    t = np.arange(n) / SR
    src = glottal(hz(m), n, jitter=0.01, shimmer=0.1, vib=0.002)
    src += glottal(hz(m) / 2, n, jitter=0.01) * 0.6               # dobra da falsa prega: subharmônico
    env = np.minimum(1, t / 0.6) * np.clip((dur - t) / 0.6, 0, 1)
    a = formants(src * env, vowels[0], bw=60)
    b = formants(src * env, vowels[1], bw=60)
    k = 0.5 - 0.5 * np.cos(2 * np.pi * t / max(1.0, dur))
    y = a * (1 - k) + b * k
    # assobio: um harmônico alto em destaque, passeando
    from scipy.signal import sosfilt
    whistle = np.zeros(n)
    seg = 6
    for i in range(seg):
        h = [8, 9, 10, 12, 10, 9][i]
        fc = hz(m) * h
        sos = butter(2, [fc * 0.985, fc * 1.015], "band", fs=SR, output="sos")
        a0, b0 = i * n // seg, (i + 1) * n // seg
        whistle[a0:b0] = sosfilt(sos, src * env)[a0:b0]
    y += whistle * 2.5
    tr.add(y, t0, g, 0.0, 0.55)


def grito(tr, t0, g=0.06, voices=8):
    """a tribo grita "Hei!" junta"""
    for i in range(voices):
        m = RNG.choice([50, 52, 55, 57, 62, 64])
        voz(tr, t0 + RNG.uniform(0, 0.05), m, 0.32, "e", g / np.sqrt(voices) * 0.5, i % 3 == 0, RNG.uniform(-0.8, 0.8), att=0.015, vib=0.0, to="i")


def flauta_osso(tr, notes, t0, beat, g=0.07, pan=0.2):
    """flauta de osso: pouca nota pura, muito ar, afinação que oscila"""
    total = sum(d for _, d in notes)
    n = int((total * beat + 0.6) * SR)
    f = np.zeros(n)
    amp = np.zeros(n)
    pos = 0
    prev = hz(notes[0][0])
    for m, d in notes:
        k = int(d * beat * SR)
        tgt = hz(m)
        gl = np.minimum(1, np.arange(k) / (0.03 * SR))
        f[pos:pos + k] = prev + (tgt - prev) * gl
        amp[pos:pos + k] = np.minimum(1, np.arange(k) / (0.05 * SR)) * np.clip((k - np.arange(k)) / (0.07 * SR), 0, 1)
        prev = tgt
        pos += k
    f[pos:] = prev
    t = np.arange(n) / SR
    f *= 1 + 0.006 * filt(RNG.normal(size=n), "low", 4) * 10 + 0.004 * np.sin(2 * np.pi * 4.5 * t) * np.minimum(1, t / 0.6)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    from scipy.signal import sosfilt
    air = np.zeros(n)
    noise = RNG.normal(size=n)
    for i in range(0, n, SR // 20):
        fc = f[i]
        sos = butter(2, [fc * 0.8, fc * 1.25], "band", fs=SR, output="sos")
        air[i:i + SR // 20] = sosfilt(sos, noise[i:i + SR // 20 + 200])[:len(air[i:i + SR // 20])]
    chiff = filt(noise, "high", 2500) * 0.0
    y = (tone * 0.7 + air * 1.3 + filt(noise, "band", [2000, 6000]) * 0.08) * amp
    tr.add(y, t0, g, pan, 0.6)


def chifre(tr, t0, m, dur, g=0.08, pan=0.0):
    """chifre de animal soprado: lábios vibrando, ataque que sobe de baixo, som rouco"""
    n = int((dur + 0.5) * SR)
    t = np.arange(n) / SR
    f = hz(m) * (1 - 0.06 * np.exp(-t * 8)) * (1 + 0.004 * filt(RNG.normal(size=n), "low", 6) * 8)
    ph = np.cumsum(f) / SR
    lips = filt(np.where((ph % 1.0) < 0.18, 1.0, -0.2), "low", 1400)
    env = np.minimum(1, t / 0.25) * np.clip((dur - t) / 0.35, 0, 1)
    y = filt(body(lips * env, [(420, 1.0), (820, 0.7), (1250, 0.35)], q=4), "low", 2200) * 1.6
    y += filt(RNG.normal(size=n), "band", [300, 1500]) * env * 0.03
    tr.add(np.tanh(y * 1.3) * 0.6, t0, g, pan, 0.7)


def tambor(tr, t0, f0=60, g=0.2, pan=0.0, decay=5.0, slap=0.3):
    """tambor de pele: modos da membrana com queda de afinação + tapa na pele"""
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for r, a in ((1.0, 1.0), (1.59, 0.5), (2.14, 0.32), (2.30, 0.22), (2.65, 0.15), (2.92, 0.1)):
        fr = f0 * r * (1 + 0.25 * np.exp(-t * 30))
        y += a * np.sin(2 * np.pi * np.cumsum(fr) / SR + RNG.random() * 6) * np.exp(-t * decay * (0.7 + r * 0.6))
    y += filt(RNG.normal(size=n), "low", 1800) * np.exp(-t * 45) * slap
    tr.add(y, t0, g, pan, 0.45)


def chocalho(tr, t0, g=0.03, pan=0.4, dur=0.18):
    """chocalho de ossos e conchas: muitos estalinhos"""
    n = int(dur * SR)
    y = np.zeros(n)
    for k in range(18):
        i = int(RNG.uniform(0, n * 0.7))
        ln = int(0.006 * SR)
        y[i:i + ln] += filt(RNG.normal(size=ln), "band", [2500, 7000]) * RNG.uniform(0.3, 1.0)
    y *= np.exp(-np.arange(n) / SR * 12)
    tr.add(y, t0, g, pan, 0.4)


def gelo(tr, t0, m, g=0.04, pan=0.0):
    """bloco de gelo percutido: modos de barra livre, ataque seco"""
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    f = hz(m)
    y = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * (5 + r * 3)) for r, a in ((1, 1.0), (2.76, 0.45), (5.40, 0.25), (8.93, 0.1)))
    y += filt(RNG.normal(size=n), "high", 4000) * np.exp(-t * 200) * 0.4
    tr.add(y, t0, g, pan, 0.75)


def vento(tr, t0, dur, g=0.06):
    n = int(dur * SR)
    t = np.arange(n) / SR
    from scipy.signal import sosfilt
    x = RNG.normal(size=n)
    y = np.zeros(n)
    seg = 24
    for i in range(seg):
        a, b = i * n // seg, (i + 1) * n // seg
        c = 350 + 700 * (0.5 + 0.5 * np.sin(i / seg * 2 * np.pi * 1.5 + RNG.random()))
        sos = butter(2, [c, c * 1.6], "band", fs=SR, output="sos")
        y[a:b] = sosfilt(sos, x)[a:b]
    y += filt(x, "low", 220) * 0.6
    y *= (0.6 + 0.4 * np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.2)
    tr.add(y, t0, g, RNG.uniform(-0.6, 0.6), 0.9)


def estalo(tr, t0, g=0.05):
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    y = filt(RNG.normal(size=n), "high", 2000) * np.exp(-t * 90) + 0.5 * np.sin(2 * np.pi * 70 * t) * np.exp(-t * 18)
    tr.add(y, t0, g, RNG.uniform(-0.8, 0.8), 0.7)


# ---------------- a música ----------------
def goraida(dst):
    tr = Track(150, 32, beats=6, seed=3311, tail=6.0)
    B = tr.beat
    prog = [(47, [59, 62, 66]), (43, [55, 59, 62]), (45, [57, 61, 64]), (42, [54, 57, 61])]   # Sim - Sol - Lá - Fá#m
    for bar in range(0, tr.bars, 4):
        vento(tr, tr.T(bar), tr.bar * 4.3, 0.12 if bar < 8 or bar >= 28 else 0.06)
    gutural(tr, tr.T(0), tr.bar * 4, 35, 0.09)
    gutural(tr, tr.T(4), tr.bar * 4, 35, 0.08, ("a", "o"))
    gutural(tr, tr.T(28), tr.bar * 4, 35, 0.09)
    bordao(tr, tr.T(4), tr.bar * 5, 0.05)
    bordao(tr, tr.T(29), tr.bar * 3, 0.045)
    for bar in range(tr.bars):
        root, ch = prog[(bar // 2) % 4]
        sec = bar // 8
        warn = 20 <= bar <= 23
        aval = 24 <= bar <= 29
        calm = 16 <= bar <= 19
        tail = bar >= 30
        # gelo tilintando no planalto
        if bar < 4 or calm or tail:
            for i in range(2):
                gelo(tr, tr.T(bar, RNG.uniform(0, 6)), int(RNG.choice([83, 86, 88, 90, 95])), 0.025, RNG.uniform(-0.8, 0.8))
        if RNG.random() < (0.25 if not (warn or aval) else 0.9):
            estalo(tr, tr.T(bar, RNG.uniform(0, 6)), 0.04 if not (warn or aval) else 0.07)
        # tambor grande: o coração da tribo
        if bar < 8 or tail:
            tambor(tr, tr.T(bar, 0), 46, 0.22, 0.0, 3.0, 0.15)
            if bar >= 4:
                tambor(tr, tr.T(bar, 3), 46, 0.12, 0.0, 3.0, 0.15)
        # lira (cítara) dedilhada
        if 4 <= bar < 16 or calm or tail:
            pat = [0, 2, 1, 2, 0, 1] if not calm else [0, 2, 1, 2, 1, 0]
            for i, k in enumerate(pat):
                if bar >= 8 and not calm and i % 2 == 1:
                    continue
                lira(tr, tr.T(bar, i), ch[k] + (12 if i == 3 else 0), 0.11 * (1.2 if i in (0, 3) else 1.0), -0.4 + 0.15 * i)
            if bar % 2 == 0:
                lira(tr, tr.T(bar), root, 0.08, -0.5, 4.0)
        # o ritual: tambores de mão em 6/8 + chocalhos
        if 8 <= bar < 16 or calm or warn or aval:
            soft = 0.5 if calm else 1.0
            tambor(tr, tr.T(bar, 0), 52, 0.24 * soft, 0.0, 3.5, 0.2)
            tambor(tr, tr.T(bar, 3), 52, 0.17 * soft, 0.0, 3.5, 0.2)
            for b, f0, gg in ((1, 110, 0.07), (2, 125, 0.09), (4, 110, 0.07), (5, 140, 0.1)):
                tambor(tr, tr.T(bar, b), f0, gg * soft, -0.35 if f0 < 120 else 0.35, 9.0, 0.6)
            for b in (0.5, 1.5, 2.5, 3.5, 4.5, 5.5):
                chocalho(tr, tr.T(bar, b), 0.03 * soft, 0.5)
        # AVISO: tambores grandes acelerando + rabecas em tremolo subindo + gritos
        if warn:
            k = bar - 20
            hits = [[0, 3], [0, 2, 3, 5], [0, 1, 2, 3, 4, 5], [x * 0.5 for x in range(12)]][k]
            for b in hits:
                tambor(tr, tr.T(bar, b), 44, 0.15 + 0.03 * k, RNG.uniform(-0.3, 0.3), 3.0, 0.35)
            for m in ([59, 47], [60, 48], [62, 50], [65, 53])[k]:
                rabeca(tr, tr.T(bar), m, tr.bar, 0.07 + 0.02 * k, press=0.5 + 0.15 * k, tremolo=14, cresc=True)
            if k in (1, 3):
                grito(tr, tr.T(bar, 3), 0.08)
            if k == 3:
                grito(tr, tr.T(bar, 5), 0.1)
        # AVALANCHE: rabecas agressivas em ostinato, tambores em fúria
        if aval:
            ost = [59, 59, 60, 59, 62, 60]
            for i, m in enumerate(ost):
                acc = 1.35 if i in (0, 3) else 1.0
                rabeca(tr, tr.T(bar, i), m, B * 0.7, 0.08 * acc, press=0.95, pan=-0.35)
                rabeca(tr, tr.T(bar, i), m - 12, B * 0.7, 0.07 * acc, press=0.95, pan=0.35)
            tambor(tr, tr.T(bar, 0), 42, 0.3, 0.0, 2.5, 0.4)
            tambor(tr, tr.T(bar, 3), 42, 0.24, 0.0, 2.5, 0.4)
            for i in range(6):
                tambor(tr, tr.T(bar, 4.5 + i * 0.25), 90 + i * 6, 0.05 + 0.02 * i, 0.3, 8.0, 0.6)
            if bar % 2 == 0:
                grito(tr, tr.T(bar, 0), 0.07)
    # ---------- vozes e sopros ----------
    # gaita de fole: lamento (5-8)
    lamento = [(71, 3.0), (73, 1.5), (74, 1.5), (76, 4.5), (74, 1.5),
               (73, 3.0), (71, 3.0), (66, 6.0),
               (71, 3.0), (74, 1.5), (76, 1.5), (78, 4.5), (76, 1.5),
               (74, 3.0), (73, 3.0), (71, 6.0)]
    gaita(tr, lamento[:8], tr.T(4), B, 0.06)
    gaita(tr, lamento[8:], tr.T(6), B, 0.06)
    # o xamã canta, a tribo responde (9-16)
    frase = [(59, 3.0), (62, 1.5), (64, 1.5), (66, 4.5), (64, 1.5)]
    resp = [(64, 3.0), (62, 1.5), (61, 1.5), (59, 6.0)]
    vog = ["a", "o", "a", "e", "o"]
    for b0 in (8, 10, 12, 14):
        t = tr.T(b0)
        for i, (m, d) in enumerate(frase):
            voz(tr, t, m - 12, d * B * 0.95, vog[i], 0.09, False, -0.1, vib=0.01)
            t += d * B
        t = tr.T(b0 + 1)
        t += 0
        tt = tr.T(b0 + 1, 0)
        for m, d in resp:
            coro(tr, tt, m - 12, d * B * 0.95, "o", 0.08, False, 5)
            coro(tr, tt, m, d * B * 0.95, "a", 0.05, True, 4)
            tt += d * B
    for b0 in (9, 13):
        chifre(tr, tr.T(b0, 0), 47, B * 5, 0.09, -0.3)
    # calmaria: flauta de osso (17-20)
    flauta = [(78, 3.0), (76, 1.5), (74, 1.5), (73, 3.0), (71, 3.0), (74, 4.5), (73, 1.5), (71, 6.0),
              (78, 3.0), (81, 1.5), (78, 1.5), (76, 3.0), (74, 3.0)]
    flauta_osso(tr, flauta, tr.T(16), B, 0.08, 0.25)
    # aviso e avalanche: chifres e coro forte
    chifre(tr, tr.T(21, 0), 47, B * 5, 0.11, -0.2)
    chifre(tr, tr.T(23, 0), 48, B * 5, 0.12, 0.2)
    for b0 in (24, 26, 28):
        tt = tr.T(b0)
        for m, d in frase:
            coro(tr, tt, m - 12, d * B * 0.95, "a", 0.1, False, 6)
            coro(tr, tt, m, d * B * 0.95, "a", 0.06, True, 4)
            tt += d * B
        chifre(tr, tr.T(b0, 0), 47, B * 5, 0.1)
    # depois da avalanche: a gaita volta sozinha no vento
    gaita(tr, [(71, 3.0), (73, 1.5), (74, 1.5), (71, 6.0)], tr.T(30), B, 0.05)
    return tr.render(dst, 4.2, 0.5, 1.1)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "sounds/musica_goraida.ogg"
    print("goraida", round(goraida(out), 1), "s")
