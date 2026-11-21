"""Hex Galaxies - sons dos especiais dos líderes (síntese, 44,1 kHz).

Gera sounds/esp_<nome>.ogg: camadas de grave (corpo), médio (textura) e agudo (detalhe),
com cauda de reverberação, para cada momento das cenas dos especiais.

Uso: python tools/sfx_especiais.py [pasta_saida]
"""
import os, sys, subprocess, wave, tempfile
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 44100
rng = np.random.default_rng(7)


def T(d):
    return np.arange(int(SR * d)) / SR


def N(d):
    return rng.uniform(-1, 1, int(SR * d))


def _f(kind, x, f, order=2):
    if kind == "band":
        lo, hi = f
        hi = min(hi, SR * 0.47)
        return sosfilt(butter(order, [max(20, lo), hi], "band", fs=SR, output="sos"), x)
    return sosfilt(butter(order, min(f, SR * 0.47), kind, fs=SR, output="sos"), x)


def lp(x, f, o=2): return _f("low", x, f, o)
def hp(x, f, o=2): return _f("high", x, f, o)
def bp(x, lo, hi, o=2): return _f("band", x, (lo, hi), o)


def env(d, a=0.005, k=6.0, hold=0.0):
    t = T(d)
    e = np.minimum(1.0, t / max(a, 1e-4))
    e *= np.where(t < a + hold, 1.0, np.exp(-(t - a - hold) * k))
    return e


def adsr(d, a, r):
    n = int(SR * d)
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return e


def tone(fr, d, wave_="sin"):
    """fr: frequência fixa ou array por amostra"""
    n = int(SR * d)
    if np.isscalar(fr):
        f = np.full(n, fr)
    else:
        fr = np.asarray(fr, float)
        f = fr if len(fr) == n else np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(fr)), fr)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave_ == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if wave_ == "sq":
        return np.sign(np.sin(ph))
    return np.sin(ph)


def glide(f0, f1, d, curve=1.0):
    t = np.linspace(0, 1, int(SR * d)) ** curve
    return f0 * (f1 / f0) ** t


def sweepf(x, f0, f1, curve=1.0):
    """filtro passa-baixa que varre de f0 a f1 (um polo, por amostra)"""
    n = len(x)
    cuts = f0 * (f1 / f0) ** (np.linspace(0, 1, n) ** curve)
    y = np.zeros(n)
    acc = 0.0
    a = np.exp(-2 * np.pi * cuts / SR)
    for i in range(n):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def mix(*parts):
    n = max(len(p) for p in parts)
    o = np.zeros(n)
    for p in parts:
        o[:len(p)] += p
    return o


def at(x, t0):
    return np.concatenate([np.zeros(int(t0 * SR)), x])


def reverb(x, size=1.2, wet=0.25, bright=4000):
    ir = N(size) * np.exp(-T(size) * (6.0 / size))
    ir = lp(ir, bright)
    w = fftconvolve(x, ir)[:len(x) + len(ir)]
    w /= (np.max(np.abs(w)) or 1)
    d = np.concatenate([x, np.zeros(len(w) - len(x))])
    return d * (1 - wet) + w * wet * (np.max(np.abs(x)) or 1)


def sat(x, k=2.0):
    return np.tanh(x * k) / np.tanh(k)


def crackles(d, rate=80, lo=1500):
    n = int(SR * d)
    o = np.zeros(n)
    for _ in range(int(d * rate)):
        s = int(rng.random() * max(1, n - 400))
        L = int(rng.uniform(40, 300))
        o[s:s + L] += rng.uniform(-1, 1, L) * np.exp(-np.arange(L) / (L / 4)) * rng.random()
    return hp(o, lo)


def debris(d, count=25, t0=0.05):
    """pedrinhas caindo: estalos curtos com pitch variado espalhados no tempo"""
    n = int(SR * d)
    o = np.zeros(n)
    for _ in range(count):
        s = int((t0 + rng.random() ** 1.6 * (d - t0 - 0.05)) * SR)
        L = int(SR * rng.uniform(0.01, 0.04))
        f = rng.uniform(900, 3500)
        g = np.sin(2 * np.pi * f * np.arange(L) / SR) * np.exp(-np.arange(L) / (L / 5))
        g += rng.uniform(-1, 1, L) * np.exp(-np.arange(L) / (L / 8)) * 0.6
        o[s:s + L] += g[:max(0, min(L, n - s))] * rng.uniform(0.2, 1.0)
    return bp(o, 600, 7000)


def boom(d=2.2, f=48, punch=1.0):
    """explosão: pancada grave + estrondo de ruído + cauda longa"""
    sub = tone(glide(f * 2.2, f * 0.7, d, 0.35), d) * env(d, 0.002, 3.2)
    corpo = lp(N(d), 900, 4) * env(d, 0.003, 4.5)
    estalo = hp(N(0.08), 1800) * env(0.08, 0.0005, 45)
    rug = lp(N(d), 260, 2) * env(d, 0.05, 1.6) * 0.8
    return sat(mix(sub * 1.3 * punch, corpo * 0.9, estalo * 0.7, rug), 1.8)


def save(nome, x, pasta, peak=0.92, ogg=True):
    x = np.asarray(x, float)
    x -= np.mean(x)
    x = x / (np.max(np.abs(x)) or 1) * peak
    fo = min(len(x) // 4, int(0.02 * SR))
    x[-fo:] *= np.linspace(1, 0, fo)
    x[:16] *= np.linspace(0, 1, 16)
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False).name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    out = os.path.join(pasta, "esp_%s.ogg" % nome)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6", out], check=True)
    os.remove(tmp)
    print(out, round(len(x) / SR, 2), "s")


# ================== Comandante Krieg ==================
def krieg_radio():
    d = 1.1
    # bip de chamada, estática e uma "voz" de rádio ininteligível (formantes picotados)
    bip = mix(tone(1400, 0.07) * adsr(0.07, 0.003, 0.01), at(tone(1850, 0.09) * adsr(0.09, 0.003, 0.02), 0.09))
    est = bp(N(d), 1200, 3500) * (0.35 + 0.65 * (rng.random(int(SR * d)) > 0.97)) * 0.5
    sil = np.zeros(int(SR * d))
    t = T(0.8)
    gl = tone(110 + 25 * np.sin(2 * np.pi * 3.1 * t) + 15 * np.sin(2 * np.pi * 7.3 * t), 0.8, "saw")
    gate = (np.sin(2 * np.pi * 5.2 * t) > -0.2).astype(float)
    voz = bp(gl * gate, 500, 2600, 3) * adsr(0.8, 0.02, 0.1)
    x = mix(bip, at(voz, 0.24), est * env(d, 0.01, 1.0, 0.8))
    x = sat(bp(x, 300, 3400, 3), 2.5)
    return x


def krieg_assobio():
    d = 0.75
    # assobio do projétil descendo (Doppler: agudo caindo), com sopro
    f = glide(2600, 520, d, 1.6)
    x = tone(f, d) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * T(d)))
    x += bp(N(d), 1500, 5000) * 0.25
    x *= np.linspace(0.15, 1.0, int(SR * d)) ** 1.5
    return x


def krieg_explosao():
    d = 2.8
    x = mix(boom(d, 44, 1.2), debris(d, 40, 0.12) * 0.35, crackles(1.2, 120) * 0.25)
    return reverb(x, 1.6, 0.25, 2500)


def krieg_explosao_p():
    d = 1.6
    x = mix(boom(d, 62, 0.8), debris(d, 14, 0.08) * 0.3)
    return reverb(x, 1.0, 0.2, 3000)


# ================== Rhazur ==================
def rhazur_rugido():
    d = 1.9
    t = T(d)
    f0 = 70 * (1 + 0.35 * np.sin(np.pi * np.minimum(t / 1.3, 1))) * (1 + 0.04 * N(d))
    src = tone(f0, d, "saw") * 0.8 + N(d) * 0.6
    src *= 1 - 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * 27 * t))           # rosnado
    vog = bp(src, 250, 950, 2) * 1.0 + bp(src, 1100, 1900, 2) * 0.6 + bp(src, 2400, 3300, 2) * 0.25
    corpo = lp(src, 220, 3) * 1.2
    x = sat((vog + corpo) * adsr(d, 0.12, 0.7), 2.2)
    agua = bp(N(d), 300, 1400) * (0.5 + 0.5 * np.sin(2 * np.pi * 4 * t)) * 0.2 * adsr(d, 0.3, 0.5)
    return reverb(mix(x, agua), 1.8, 0.3, 2200)


def rhazur_redemoinho():
    d = 1.4
    t = T(d)
    # água girando: ruído filtrado cujo pico gira para cima, bolhas
    base = sweepf(N(d), 300, 1800, 0.8) * (0.6 + 0.4 * np.sin(2 * np.pi * (3 + 6 * t) * t))
    bol = np.zeros(int(SR * d))
    for _ in range(40):
        s = int(rng.random() * (len(bol) - 3000))
        L = int(SR * rng.uniform(0.02, 0.05))
        f = rng.uniform(300, 900)
        g = tone(glide(f, f * 2.2, L / SR), L / SR)
        bol[s:s + len(g)] += g * np.exp(-np.arange(len(g)) / (L / 3)) * 0.4
    sub = tone(glide(45, 80, d), d) * adsr(d, 0.3, 0.4) * 0.6
    return reverb(mix(base * adsr(d, 0.15, 0.4), bol, sub), 1.4, 0.3, 3000)


def rhazur_corrente():
    d = 1.0
    o = np.zeros(int(SR * d))
    # elos de corrente batendo (metal) enquanto arrasta, mais um puxão grave no fim
    for k in range(26):
        s = int((0.02 + k * 0.032 + rng.uniform(-0.008, 0.008)) * SR)
        L = int(SR * 0.08)
        tt = np.arange(L) / SR
        g = sum(np.sin(2 * np.pi * f * tt) for f in rng.uniform(1800, 5200, 3)) * np.exp(-tt * 55)
        o[s:s + L] += g[:max(0, min(L, len(o) - s))] * rng.uniform(0.3, 1.0)
    arrasto = bp(N(d), 200, 1200) * adsr(d, 0.1, 0.3) * 0.4
    puxao = at(tone(glide(140, 55, 0.35), 0.35) * env(0.35, 0.005, 9) * 1.2, 0.6)
    return reverb(mix(o * 0.5, arrasto, puxao), 0.8, 0.2)


# ================== Rei da Mina ==================
def rei_tremor():
    d = 2.2
    t = T(d)
    ronco = lp(N(d), 120, 4) * 4 * adsr(d, 0.4, 0.8)
    sub = tone(32 + 6 * np.sin(2 * np.pi * 0.7 * t), d) * adsr(d, 0.5, 0.8) * 0.8
    pedras = debris(d, 30, 0.3) * 0.25
    return reverb(sat(mix(ronco, sub, pedras), 1.5), 1.2, 0.2, 1800)


def rei_cristal():
    d = 1.6
    # terra rachando + cristal subindo (brilho que sobe) + tilintar no fim
    racha = mix(hp(N(0.25), 600) * env(0.25, 0.001, 18) * 0.8, crackles(0.5, 200, 800) * 0.6)
    grave = tone(glide(90, 45, 0.5), 0.5) * env(0.5, 0.002, 7)
    sobe = tone(glide(400, 1600, 0.45, 0.6), 0.45) * adsr(0.45, 0.05, 0.1) * 0.25
    t = T(1.3)
    sino = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) * a for f, k, a in
               [(1760, 3.5, 0.5), (2637, 4.5, 0.35), (3520, 6, 0.25), (4699, 8, 0.15), (2217, 3.0, 0.2)])
    return reverb(mix(racha, grave, at(sobe, 0.1), at(sino * 0.6, 0.45), debris(1.0, 10, 0.05) * 0.2), 1.6, 0.35, 6000)


# ================== Watcher Mamute ==================
def mamute_barrido():
    d = 1.6
    t = T(d)
    f0 = np.concatenate([glide(180, 420, 0.35, 0.7), np.full(int(SR * 0.9), 420.0) * (1 + 0.03 * np.sin(2 * np.pi * 6 * T(0.9))), glide(420, 300, d - 1.25)])
    f0 = f0[:int(SR * d)]
    src = tone(f0, d, "saw") * 0.7 + N(d) * 0.15
    trompa = sat(hp(bp(src, 400, 3200, 2), 300) * 2.5, 2.0)
    bufo = bp(N(d), 600, 2500) * 0.25
    x = mix(trompa, bufo) * adsr(d, 0.06, 0.4)
    return reverb(x, 1.6, 0.3, 3500)


def mamute_pisao():
    d = 1.5
    pancada = mix(tone(glide(85, 32, 0.6, 0.5), 0.6) * env(0.6, 0.002, 6) * 1.5, lp(N(0.4), 400, 4) * env(0.4, 0.002, 10) * 1.2)
    x = mix(sat(pancada, 2.0), debris(d, 26, 0.04) * 0.35, lp(N(d), 300) * env(d, 0.02, 2.5) * 0.4)
    return reverb(x, 1.3, 0.25, 2000)


def mamute_manada():
    d = 2.8
    o = np.zeros(int(SR * d))
    # galope pesado de vários animais (passos com jitter) + trovão contínuo
    for animal in range(4):
        per = rng.uniform(0.26, 0.32)
        t0 = rng.uniform(0, per)
        k = 0
        while t0 + k * per < d - 0.2:
            for sub_t in (0.0, 0.07):
                s = int((t0 + k * per + sub_t + rng.uniform(-0.01, 0.01)) * SR)
                L = int(SR * 0.25)
                g = tone(glide(rng.uniform(70, 95), 40, 0.25), 0.25) * env(0.25, 0.002, 14)
                g += lp(N(0.25), 500) * env(0.25, 0.001, 25) * 0.6
                o[s:s + L] += g[:max(0, min(L, len(o) - s))] * rng.uniform(0.5, 1.0)
            k += 1
    trovao = lp(N(d), 180, 3) * 3 * adsr(d, 0.3, 0.8)
    poeira = bp(N(d), 1500, 5000) * 0.08 * adsr(d, 0.4, 0.8)
    return reverb(sat(mix(o, trovao, poeira) * adsr(d, 0.2, 0.6), 1.6), 1.0, 0.2, 2200)


# ================== Líder Lithari ==================
def lit_carga():
    d = 0.9
    t = T(d)
    # energia cristalina carregando: acorde que sobe e treme
    x = sum(tone(glide(f, f * 2.0, d, 1.4), d) * a for f, a in [(440, 0.5), (660, 0.35), (880, 0.3), (1320, 0.2)])
    x *= (0.7 + 0.3 * np.sin(2 * np.pi * (8 + 20 * t) * t)) * np.linspace(0.1, 1, int(SR * d)) ** 1.3
    brilho = hp(N(d), 6000) * 0.08 * np.linspace(0, 1, int(SR * d))
    return reverb(mix(x, brilho), 1.2, 0.35, 8000)


def lit_disparo():
    d = 0.7
    # lanças de cristal cortando o ar: zunido + tilintar rápido
    zuni = sweepf(N(d), 6000, 800, 0.7) * env(d, 0.005, 4)
    sh = sum(tone(f, 0.25) * env(0.25, 0.001, 20) * 0.3 for f in (2794, 3729, 4186))
    return reverb(mix(zuni, sh, at(sh * 0.7, 0.06), at(sh * 0.5, 0.12), at(sh * 0.4, 0.18)), 0.9, 0.3, 9000)


def lit_prisao():
    d = 2.4
    t = T(d)
    # a gaiola fecha: vários cristais travando em sequência + acorde que fica no ar
    o = np.zeros(int(SR * d))
    for k in range(7):
        s = int((0.0 + k * 0.06) * SR)
        L = int(SR * 0.3)
        tt = np.arange(L) / SR
        f = rng.uniform(1500, 4200)
        g = (np.sin(2 * np.pi * f * tt) + 0.5 * np.sin(2 * np.pi * f * 1.51 * tt)) * np.exp(-tt * 22)
        g += rng.uniform(-1, 1, L) * np.exp(-tt * 120) * 0.5
        o[s:s + L] += g * rng.uniform(0.5, 1.0)
    trava = tone(glide(220, 110, 0.3), 0.3) * env(0.3, 0.001, 12) * 1.2
    acorde = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(523, 0.3), (784, 0.25), (1047, 0.2), (1568, 0.12)]) * np.exp(-t * 1.4) * adsr(d, 0.05, 0.5)
    return reverb(mix(o * 0.6, at(trava, 0.38), at(acorde, 0.38)), 1.8, 0.4, 9000)


# ================== Karo ==================
def karo_arremesso():
    d = 0.35
    return sweepf(N(d), 500, 4000, 0.6) * adsr(d, 0.05, 0.2) * 0.8


def karo_plop():
    d = 0.4
    pl = tone(glide(220, 560, 0.12, 0.5), 0.12) * env(0.12, 0.002, 18)
    sq = tone(glide(900, 1400, 0.15), 0.15) * env(0.15, 0.002, 25) * 0.4
    return mix(pl, at(sq, 0.05), lp(N(0.1), 1200) * env(0.1, 0.001, 50) * 0.5)


# ================== Dragão Zukunft ==================
def dragao_decolagem():
    d = 1.3
    t = T(d)
    # batidas de asa (golpes de ar graves) acelerando + feixe holográfico subindo
    o = np.zeros(int(SR * d))
    tb = 0.0
    k = 0
    while tb < d - 0.3:
        L = int(SR * 0.3)
        g = lp(N(0.3), 350, 3) * env(0.3, 0.02, 9) * 2.5
        s = int(tb * SR)
        o[s:s + L] += g[:max(0, min(L, len(o) - s))]
        tb += 0.32 * (0.85 ** k)
        k += 1
    feixe = tone(glide(200, 1800, d, 1.2), d, "saw")
    feixe = bp(feixe, 300, 5000) * 0.18 * adsr(d, 0.05, 0.3)
    glitch = (rng.random(int(SR * d)) > 0.995).astype(float) * bp(N(d), 2000, 8000) * 2
    return reverb(mix(o, feixe, glitch * 0.3), 1.3, 0.3, 5000)


def dragao_meteoro():
    d = 0.8
    # rasante: rugido de fogo/ar descendo e crescendo
    x = sweepf(N(d), 4000, 300, 0.8) * np.linspace(0.2, 1, int(SR * d)) ** 1.5
    zumb = tone(glide(900, 180, d, 1.4), d, "saw")
    zumb = lp(zumb, 2000) * 0.25 * np.linspace(0.2, 1, int(SR * d))
    return mix(x, zumb)


def dragao_impacto():
    d = 3.2
    x = mix(boom(d, 36, 1.5), debris(d, 50, 0.1) * 0.35, at(crackles(1.6, 160, 2500) * 0.3, 0.05))
    holo = tone(glide(1600, 200, 0.6), 0.6, "sq") * env(0.6, 0.002, 6) * 0.15
    return reverb(mix(x, holo), 2.0, 0.3, 3000)


def dragao_baforada():
    d = 0.9
    t = T(d)
    # sopro de energia: ruído rugindo + zumbido holográfico pulsante
    sopro = bp(N(d), 400, 3500) * adsr(d, 0.04, 0.35) * (0.8 + 0.2 * np.sin(2 * np.pi * 18 * t))
    zum = tone(glide(320, 180, d), d, "saw") * 0.3 * adsr(d, 0.02, 0.4)
    zum = lp(zum, 2200) * (0.6 + 0.4 * (np.sin(2 * np.pi * 38 * t) > 0))
    return reverb(sat(mix(sopro, zum), 1.5), 0.9, 0.25, 6000)


SONS = {
    "krieg_radio": krieg_radio, "krieg_assobio": krieg_assobio, "krieg_explosao": krieg_explosao, "krieg_explosao_p": krieg_explosao_p,
    "rhazur_rugido": rhazur_rugido, "rhazur_redemoinho": rhazur_redemoinho, "rhazur_corrente": rhazur_corrente,
    "rei_tremor": rei_tremor, "rei_cristal": rei_cristal,
    "mamute_barrido": mamute_barrido, "mamute_pisao": mamute_pisao, "mamute_manada": mamute_manada,
    "lit_carga": lit_carga, "lit_disparo": lit_disparo, "lit_prisao": lit_prisao,
    "karo_arremesso": karo_arremesso, "karo_plop": karo_plop,
    "dragao_decolagem": dragao_decolagem, "dragao_meteoro": dragao_meteoro, "dragao_impacto": dragao_impacto, "dragao_baforada": dragao_baforada,
}

if __name__ == "__main__":
    pasta = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "sounds")
    so = sys.argv[2].split(",") if len(sys.argv) > 2 else list(SONS)
    for k in so:
        save(k, SONS[k](), pasta)
