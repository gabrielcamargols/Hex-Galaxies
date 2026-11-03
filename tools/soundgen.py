"""Hex Galaxies - gerador de sons dos VFX e das vozes dos personagens.

Gera em sounds/:
  vfx_<efeito>.wav        um som para cada flipbook de tools/vfxgen.py
  v_<id>_atk.wav          grito/rugido do personagem ao atacar
  v_<id>_dor.wav          som do personagem ao sofrer dano
  v_<id>_fala.wav         fala amigável (balão de diálogo com aliado/entrada)
  v_<id>_prov.wav         fala de provocação (balão contra inimigo)

As vozes usam síntese de formantes (pulso glotal + ressonâncias de vogal),
com perfil por personagem: sexo, tamanho e o que ele é (humano, fera, ave,
réptil, robô, rádio de capacete, cristal, golem, aquático...).

Uso: python tools/soundgen.py [pasta_saida] [--only vfx|voz]
Para mudar uma voz, edite a linha do personagem em PERFIS.
"""
import os, sys, wave
import numpy as np
from scipy.signal import lfilter, butter, sosfilt

SR = 22050
rng = np.random.default_rng(21)

# ---------------- utilidades ----------------
def T(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.01, r=0.1, s=1.0):
    e = np.ones(n) * s
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    na = min(na, n)
    e[:na] = np.linspace(0, s, na)
    nr = min(nr, n)
    e[n - nr:] *= np.linspace(1, 0, nr)
    return e


def expdecay(n, k):
    return np.exp(-np.arange(n) / SR * k)


def noise(n):
    return rng.uniform(-1, 1, n)


def bp(x, lo, hi, order=2):
    hi = min(hi, SR / 2 * 0.95)
    lo = max(20, min(lo, hi * 0.9))
    return sosfilt(butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


def lp(x, f, order=2):
    return sosfilt(butter(order, min(f, SR / 2 * 0.95), "low", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, "high", fs=SR, output="sos"), x)


def sweep(f0, f1, d, shape="sin"):
    t = T(d)
    f = f0 * (f1 / f0) ** (t / max(d, 1e-6))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "saw":
        return lp(2 * ((ph / (2 * np.pi)) % 1) - 1, 5000, 4)
    return np.sin(ph)


def mix(*parts):
    n = max(len(p) for p in parts)
    o = np.zeros(n)
    for p in parts:
        o[:len(p)] += p
    return o


def msum(parts):
    return mix(*list(parts))


def at(x, t0):
    return np.concatenate([np.zeros(int(t0 * SR)), x])


def save(path, x, peak=0.85):
    x = np.asarray(x, float)
    x = x - np.mean(x)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    f = min(len(x) // 4, int(0.012 * SR))
    if f > 0:
        x[-f:] *= np.linspace(1, 0, f)
        x[:3] *= np.linspace(0, 1, 3)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


# ---------------- síntese de voz ----------------
VOW = {  # F1, F2, F3 (voz masculina adulta)
    "a": (730, 1090, 2440), "o": (570, 840, 2410), "u": (300, 870, 2240),
    "e": (530, 1840, 2480), "i": (300, 2200, 2950), "ae": (660, 1720, 2410),
}


def resonate(x, f, bw):
    r = np.exp(-np.pi * bw / SR)
    a = [1, -2 * r * np.cos(2 * np.pi * f / SR), r * r]
    return lfilter([1 - r], a, x)


def glottal(f0):
    """f0: array de frequência por amostra -> pulso com harmônicos decrescentes"""
    ph = 2 * np.pi * np.cumsum(f0) / SR
    out = np.zeros(len(f0))
    fmax = np.max(f0)
    K = int(min(60, (SR / 2) / max(fmax, 40)))
    for k in range(1, K + 1):
        out += np.sin(k * ph) / k ** 1.25
    return out


def formant(src, vowel, fs):
    F = VOW[vowel]
    y = resonate(src, F[0] * fs, 90 * fs) * 1.0
    y += resonate(src, F[1] * fs, 120 * fs) * 0.55
    y += resonate(src, F[2] * fs, 170 * fs) * 0.3
    y += resonate(src, 3500 * min(fs, 1.2), 250) * 0.12
    return y


def voice(d, f_start, f_peak, f_end, v1, v2, fs, breath=0.15, growl=0.0, jitter=0.02, peak_at=0.25, onset="h"):
    n = int(SR * d)
    t = np.linspace(0, 1, n)
    f0 = np.where(t < peak_at, f_start + (f_peak - f_start) * (t / peak_at),
                  f_peak + (f_end - f_peak) * ((t - peak_at) / (1 - peak_at)))
    f0 = f0 * (1 + jitter * lp(noise(n), 18) * 4)
    src = glottal(f0)
    if growl > 0:
        am = 1 - growl * 0.7 * (0.5 + 0.5 * np.sin(2 * np.pi * (28 + 20 * growl) * T(d)))
        src = src * am + growl * 0.6 * glottal(f0 * 0.5)
    src += breath * noise(n) * 1.5
    # vogal 1 -> vogal 2 com transição suave
    y1 = formant(src, v1, fs)
    y2 = formant(src, v2, fs)
    w = np.clip((t - 0.25) / 0.4, 0, 1)
    y = y1 * (1 - w) + y2 * w
    e = env(n, 0.025, d * 0.45)
    if onset == "h":
        hn = int(0.05 * SR)
        y[:hn] += bp(noise(hn), 800 * fs, 3500 * fs) * np.linspace(0.6, 0.2, hn)
    elif onset == "k":
        y[:int(0.012 * SR)] += noise(int(0.012 * SR)) * 1.2
    y = np.tanh(y * 2.2) * e
    return y


def shout(p, hurt):
    """grito de ataque / gemido de dor a partir do perfil"""
    f = p["f0"]
    fs = p["fs"]
    if not hurt:
        return voice(0.42, f * 1.1, f * 1.55, f * 1.15, "a", "a" if p["vow"] == "a" else p["vow"], fs,
                     p["breath"], p["growl"], 0.015, 0.3, "h")
    return voice(0.38, f * 1.7, f * 1.75, f * 1.0, "u" if p["vow"] != "i" else "e", "a", fs,
                 p["breath"] + 0.15, p["growl"] * 0.8, 0.05, 0.12, "k")


# ---------------- camadas extras por tipo ----------------
def radio(y):
    """voz abafada pelo capacete (rádio): banda estreita + saturação + estalo"""
    y = bp(y, 380, 3000, 3)
    y = np.tanh(y * 3.5)
    click = np.zeros(len(y))
    c = int(0.008 * SR)
    click[:c] = noise(c)
    static = bp(noise(len(y)), 2000, 6000) * 0.05
    return y + click * 0.4 + static


def robot(y, f=70):
    """voz robótica: modulação em anel + redução de bits + zumbido de servo"""
    t = T(len(y) / SR)
    y = y * np.sin(2 * np.pi * f * t) * 1.6 + y * 0.4
    y = np.round(y * 12) / 12
    servo = sweep(900, 1600, len(y) / SR, "saw") * 0.04 * env(len(y), 0.02, 0.2)
    return y + servo


def crystal(y, f0, hurt):
    """corpo de cristal: ressonância de sino por cima da voz; dor = estalo de rachadura"""
    n = len(y)
    t = np.arange(n) / SR
    bell = sum(np.sin(2 * np.pi * f0 * 4 * k * t) * expdecay(n, 6 + k * 3) / k for k, k2 in zip([1, 2.76, 5.4], range(3)))
    out = y * 0.55 + bell * 0.5
    if hurt:
        c = noise(int(0.05 * SR)) * expdecay(int(0.05 * SR), 60)
        out = mix(out, hp(c, 2500) * 1.4, at(hp(noise(int(0.03 * SR)), 3000) * expdecay(int(0.03 * SR), 80), 0.08))
    return out


def golem(y, hurt):
    """pedra: ronco grave + rocha triturando"""
    n = len(y)
    grind = lp(noise(n), 400) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * T(n / SR)))
    crunch = np.zeros(n)
    for k in range(5 if hurt else 3):
        s = int(rng.random() * n * 0.6)
        m = int(0.03 * SR)
        crunch[s:s + m] += bp(noise(m), 300, 2500) * expdecay(m, 50)[:len(crunch[s:s + m])]
    return lp(y, 900) * 0.8 + grind * 0.7 + crunch


def bubbles(n, amount=6):
    out = np.zeros(n)
    for k in range(amount):
        d = 0.04 + rng.random() * 0.05
        b = sweep(300 + rng.random() * 500, 900 + rng.random() * 900, d) * env(int(SR * d), 0.005, 0.03)
        s = int(rng.random() * max(1, n - len(b)))
        out[s:s + len(b)] += b * 0.35
    return out


def screech(d, f0, f1):
    t = T(d)
    fm = 1 + np.sin(2 * np.pi * 38 * t) * 0.06
    f = f0 * (f1 / f0) ** (t / d) * fm
    return lp(np.tanh(glottal(f) * 1.5), 7000, 4) * env(len(t), 0.01, d * 0.5)


def croak(d, f):
    n = int(SR * d)
    pulses = (np.sin(2 * np.pi * 18 * T(d)) > 0.3).astype(float)
    src = glottal(np.full(n, f)) * pulses
    return formant(src, "o", 0.7) * env(n, 0.01, 0.1)


def chitter(d, rate=38):
    n = int(SR * d)
    out = np.zeros(n)
    k = 0
    while k < n:
        m = int(0.006 * SR)
        out[k:k + m] += bp(noise(m), 2500, 7000)[:len(out[k:k + m])] * 0.9
        k += int(SR / rate * (0.7 + rng.random() * 0.6))
    return out * env(n, 0.005, 0.08)


def roar(d, f, fs):
    n = int(SR * d)
    src = glottal(np.linspace(f * 1.2, f * 0.8, n)) * 0.6 + noise(n) * 0.9
    src *= 1 - 0.5 * (0.5 + 0.5 * np.sin(2 * np.pi * 31 * T(d)))
    return np.tanh(formant(src, "a", fs) * 2.5) * env(n, 0.04, d * 0.5)


def hiss(d):
    n = int(SR * d)
    return bp(noise(n), 2500, 8000) * env(n, 0.02, d * 0.6)


def trumpet(d, f):
    n = int(SR * d)
    f0 = np.concatenate([np.linspace(f, f * 1.5, n // 3), np.full(n - n // 3, f * 1.5)])
    x = glottal(f0) * (1 + 0.1 * np.sin(2 * np.pi * 7 * T(d)))
    return np.tanh(hp(x, 300) * 2) * env(n, 0.05, 0.2)


def hoot(d, f):
    n = int(SR * d)
    return np.sin(2 * np.pi * np.cumsum(np.linspace(f * 1.1, f * 0.9, n)) / SR) * env(n, 0.04, 0.15)


def squeak(d, f0, f1):
    n = int(SR * d)
    return sweep(f0, f1, d) * env(n, 0.005, d * 0.5) * (1 + 0.3 * np.sin(2 * np.pi * 30 * T(d)))


def crackle(d):
    n = int(SR * d)
    out = np.zeros(n)
    for k in range(int(d * 60)):
        s = int(rng.random() * (n - 60))
        out[s:s + 40] += noise(40) * expdecay(40, 300) * rng.random()
    return hp(out, 1500)


def drill(d):
    n = int(SR * d)
    return np.tanh(sweep(180, 260, d, "saw") * 2) * 0.5 * env(n, 0.02, 0.1) + bp(noise(n), 1500, 4000) * 0.2


def zap(d):
    n = int(SR * d)
    return np.sign(np.sin(2 * np.pi * np.cumsum(900 + 700 * noise(n)) / SR)) * expdecay(n, 14) * 0.5


def warble(d, f):
    n = int(SR * d)
    return np.sin(2 * np.pi * np.cumsum(f * (1 + 0.4 * np.sin(2 * np.pi * 14 * T(d)))) / SR) * env(n, 0.01, 0.1)


def metal_clank(d=0.2):
    n = int(SR * d)
    t = T(d)
    return sum(np.sin(2 * np.pi * f * t) * expdecay(n, 18) for f in (1830, 2470, 3120)) * 0.15


def whoosh(d, f0=400, f1=3000):
    n = int(SR * d)
    cuts = np.linspace(f0, f1, n)
    y = np.zeros(n)
    acc = 0.0
    x = noise(n)
    for i in range(n):
        a = np.exp(-2 * np.pi * cuts[i] / SR)
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y * np.sin(np.linspace(0, np.pi, n))


# ---------------- perfis dos personagens ----------------
# tipo, sexo (M/F/N), tamanho (0 pequeno, 1 normal, 2 grande, 3 gigante), espécie/extra
PERFIS = {
    # Faurianos (animais antropomórficos)
    "karo": ("anthro", "M", 1, "ape"), "karu": ("anthro", "M", 1, "ape"), "vexa": ("anthro", "F", 1, "fox"),
    "rhombo": ("anthro", "M", 3, "rhino"), "gorun": ("anthro", "M", 2, "ape"), "mantis": ("insect", "M", 1, "mantis"),
    "zaboo": ("anthro", "M", 1, "horse"), "caninus_black": ("anthro", "M", 1, "wolf"), "brazucao": ("anthro", "M", 1, "fox"),
    "tork": ("anthro", "M", 2, "turtle"), "astrax": ("bird", "M", 2, "eagle"), "nokka": ("anthro", "F", 1, "hyena"),
    "caninus_white": ("anthro", "M", 1, "wolf"), "rappy": ("anthro", "M", 0, "rabbit"), "cameo": ("reptile", "M", 1, "chameleon"),
    "pipa": ("anthro", "M", 1, "capybara"), "tupi": ("anthro", "M", 1, "anteater"), "luna": ("anthro", "F", 1, "deer"),
    "skarp": ("anthro", "M", 1, "porcupine"), "brakka": ("bird", "M", 1, "parrot"), "muggo": ("frog", "M", 2, "frog"),
    "boro": ("anthro", "M", 1, "armadillo"), "drako": ("reptile", "M", 2, "croc"),
    # Abyssais (criaturas do fundo do mar)
    "rhazur": ("aqua", "M", 2, "shark"), "bayak": ("small", "N", 0, "puffer"), "strahl": ("reptile", "M", 1, "eel"),
    "sapturne": ("orb", "N", 1, "mine"), "rayak": ("aqua", "F", 1, "manta"), "balu": ("aqua", "M", 3, "whaleshark"),
    "oncus": ("aqua", "M", 2, "narwhal"), "moby": ("whale", "N", 3, "whale"), "sterina": ("aqua", "F", 1, "starfish"),
    "klang": ("insect", "M", 1, "lobster"), "kling": ("insect", "M", 0, "crab"), "inkshadow": ("aqua", "F", 1, "octopus"),
    "banker": ("aqua", "M", 3, "shark"),
    # Krieg (soldados de armadura com capacete: voz pelo rádio)
    "k_cmd": ("radio", "M", 1, "cmd"), "k_front": ("radio", "M", 1, ""), "k_tank": ("radio", "M", 2, ""),
    "k_sniper": ("radio", "M", 1, ""), "k_brawler": ("radio", "M", 2, ""), "k_demol": ("radio", "M", 1, ""),
    "k_medico": ("radio", "M", 1, ""), "k_eng": ("radio", "M", 1, ""), "k_incend": ("radio", "M", 1, ""),
    "k_assalt": ("radio", "M", 1, ""),
    # Wächter (guerreiros humanos com armaduras inspiradas em animais: voz humana + metal)
    "w_lobo": ("human", "M", 1, "armor"), "w_tric": ("human", "M", 2, "armor"), "w_mamute": ("human", "M", 2, "armor"),
    "w_croc": ("human", "M", 2, "armor"), "w_sabre": ("human", "M", 1, "armor"), "w_axolote": ("human", "F", 1, "armor"),
    "w_coruja": ("human", "M", 1, "armor"), "w_raposa": ("human", "F", 1, "armor"), "w_castor": ("human", "M", 1, "armor"),
    "w_aguia": ("human", "M", 1, "armor"),
    # Zukunft (humanos tecnológicos, mechas e criaturas cibernéticas)
    "z_vang": ("human", "M", 1, ""), "z_tank": ("robot", "N", 2, ""), "z_brawler": ("human", "M", 1, "holo"),
    "z_piloto": ("human", "M", 1, ""), "z_naves": ("human", "M", 0, "young"), "z_diplo": ("human", "M", 1, "calm"),
    "z_duel": ("human", "M", 1, ""), "z_bio": ("human", "M", 1, ""), "z_hacker": ("human", "M", 0, "young"),
    "z_real": ("human", "M", 1, "old"), "z_cao": ("robot", "N", 1, "dog"), "z_dragao": ("robot", "N", 3, "dragon"),
    "z_meca": ("robot", "N", 3, ""), "z_fenix": ("bird", "N", 2, "phoenix"), "z_infect": ("human", "M", 1, "corrupt"),
    "z_drone": ("robot", "N", 0, ""), "z_escudo": ("human", "F", 1, "calm"),
    # Lithari (seres de cristal)
    "l_general": ("crystal", "M", 2, ""), "l_lider": ("crystal", "M", 1, ""), "l_tank": ("crystal", "N", 3, ""),
    "l_atirador": ("crystal", "N", 1, ""), "l_scout": ("crystal", "N", 0, ""), "l_healer": ("crystal", "F", 1, ""),
    "l_eng": ("crystal", "N", 1, ""), "l_assassino": ("crystal", "N", 1, ""), "l_sniper": ("crystal", "N", 1, ""),
    "l_colosso": ("crystal", "N", 3, ""), "l_fera": ("crystal", "N", 2, "beast"), "l_invoc": ("crystal", "F", 1, ""),
    "l_ladino": ("crystal", "N", 1, ""), "l_guardiao": ("crystal", "N", 2, ""), "l_brawler": ("crystal", "N", 2, "beast"),
    "l_leviathan": ("crystal", "N", 3, "beast"), "l_behemot": ("crystal", "N", 3, "beast"),
    # Terramorfos (mineiros e golens de pedra)
    "rei_mina": ("human", "M", 2, "deep"), "golk": ("golem", "N", 3, ""), "perfurador": ("human", "M", 1, "drill"),
    "sismico": ("golem", "N", 3, "core"), "t_pontes": ("human", "M", 1, "deep"), "t_estacas": ("human", "M", 1, ""),
    "t_medico": ("human", "F", 1, "old"), "t_fendas": ("human", "M", 2, "drill"), "t_cartografo": ("human", "M", 0, "young"),
    "t_raiz": ("robot", "N", 2, ""),
}


def profile(kind, sex, size, extra):
    f0 = {"M": 118, "F": 215, "N": 150}[sex]
    fs = {"M": 1.0, "F": 1.17, "N": 1.05}[sex]
    mul = {0: (1.45, 1.15), 1: (1.0, 1.0), 2: (0.78, 0.9), 3: (0.6, 0.8)}[size]
    f0 *= mul[0]
    fs *= mul[1]
    p = {"f0": f0, "fs": fs, "breath": 0.12, "growl": 0.0, "vow": "a"}
    if kind in ("anthro", "beast"):
        p["growl"] = 0.35 if kind == "anthro" else 0.6
        p["breath"] = 0.2
    if extra in ("young",):
        p["f0"] *= 1.2
    if extra in ("old",):
        p["breath"] = 0.25
        p["f0"] *= 0.92
    if extra in ("deep",):
        p["f0"] *= 0.82
        p["fs"] *= 0.92
    if extra == "calm":
        p["vow"] = "e"
    return p


def char_sound(cid, hurt):
    kind, sex, size, extra = PERFIS[cid]
    p = profile(kind, sex, size, extra)
    rng.bit_generator.state = np.random.default_rng(__import__("zlib").crc32((cid + str(hurt)).encode())).bit_generator.state
    if kind == "whale":
        d = 0.9
        y = mix(hoot(d, 90 if not hurt else 140) * 0.8, lp(noise(int(SR * d)), 300) * env(int(SR * d), 0.1, 0.4) * 0.4, bubbles(int(SR * d), 10))
        return y
    if kind == "golem":
        base = voice(0.5, p["f0"] * 0.9, p["f0"] * 1.1, p["f0"] * 0.7, "o", "u", 0.7, 0.3, 0.5)
        y = golem(base, hurt)
        if extra == "core":
            y = mix(y, warble(0.4, 220) * 0.3)
        if extra == "root":
            y = mix(y, lp(noise(len(y)), 1200) * expdecay(len(y), 6) * 0.4)
        return y
    if kind == "orb":
        y = mix(warble(0.35, 520 if not hurt else 380), zap(0.3) * 0.5)
        return y
    if kind == "insect":
        y = mix(chitter(0.32, 45 if not hurt else 70), squeak(0.25, 1800, 2600 if not hurt else 1200) * 0.4)
        if extra == "mantis" and not hurt:
            y = mix(y, whoosh(0.25, 1500, 5000) * 0.7)
        if extra in ("lobster", "crab"):
            y = mix(y, bubbles(len(y), 4))
        return y
    if kind == "frog":
        return mix(croak(0.45, 70 if not hurt else 95), shout(p, hurt) * 0.35)
    if kind == "small":
        y = mix(squeak(0.25, 900, 1500) if not hurt else squeak(0.3, 1700, 700), shout(p, hurt) * 0.3)
        if extra == "puffer":
            y = mix(y, bubbles(len(y), 8))
        return y
    if kind == "bird":
        if extra == "owl":
            return mix(hoot(0.35, 420 if not hurt else 520), hoot(0.3, 380) * 0.5 if not hurt else squeak(0.2, 1400, 800) * 0.4)
        if extra == "phoenix":
            return mix(screech(0.5, 1500, 2600) if not hurt else screech(0.45, 2400, 1300), crackle(0.5) * 0.7)
        hi = {"eagle": (1600, 2400), "parrot": (1200, 2000)}.get(extra, (1400, 2200))
        y = screech(0.4, hi[0], hi[1]) if not hurt else screech(0.35, hi[1], hi[0] * 0.7)
        return mix(y * 0.75, shout(p, hurt) * 0.3)
    if kind == "reptile":
        if extra == "eel":
            return mix(hiss(0.35), zap(0.3) * 0.6, shout(p, hurt) * 0.25)
        if extra == "chameleon":
            return mix(hiss(0.3) * 0.8, shout(p, hurt) * 0.5)
        return mix(hiss(0.45) * 0.7, roar(0.45, p["f0"] * 0.7, p["fs"] * 0.8) * 0.8)
    if kind == "robot":
        if extra == "dog":
            bark = voice(0.22, 300, 420, 260, "a", "o", 1.2, 0.2, 0.6, 0.02, 0.2, "k")
            y = robot(mix(bark, at(bark * 0.7, 0.16)) if not hurt else squeak(0.35, 1300, 500), 90)
            return y
        if extra == "dragon":
            r = roar(0.7, 90 if not hurt else 130, 0.75)
            return mix(robot(r, 55), metal_clank(0.4))
        return mix(robot(shout(p, hurt), 60), metal_clank() * (1.5 if hurt else 0.6))
    if kind == "radio":
        y = radio(shout(p, hurt))
        if extra == "cmd" and not hurt:
            y = mix(y, at(radio(voice(0.25, 130, 150, 120, "o", "u", 1.0, 0.1, 0.0)) * 0.6, 0.38))
        return mix(y, metal_clank() * (1.0 if hurt else 0.4))
    if kind == "crystal":
        base = shout(p, hurt)
        if extra == "beast":
            base = roar(0.55, p["f0"] * 0.8, p["fs"] * 0.85)
        return crystal(base, p["f0"], hurt)
    if kind == "aqua":
        y = shout(p, hurt)
        if extra in ("shark", "whaleshark", "narwhal"):
            y = mix(y, roar(0.45, p["f0"] * 0.7, p["fs"] * 0.85) * 0.5)
        if extra == "octopus":
            y = mix(lp(y, 2500) * 0.6, hiss(0.3) * 0.4)
        if extra == "starfish":
            y = mix(y, crystal(np.zeros(len(y)), 400, False) * 0.25)
        return mix(y, bubbles(len(y), 6))
    if kind in ("anthro", "beast"):
        y = shout(p, hurt)
        if extra in ("wolf", "fox", "hyena") and not hurt:
            y = mix(roar(0.25, p["f0"] * 1.2, p["fs"] * 1.1) * 0.6, at(y, 0.12))
        if extra in ("wolf", "fox") and hurt:
            y = mix(squeak(0.3, 1400 if extra == "fox" else 1100, 600) * 0.5, y * 0.7)
        if extra == "hyena" and hurt:
            y = mix(y, at(squeak(0.12, 900, 1300) * 0.4, 0.05), at(squeak(0.12, 900, 1300) * 0.4, 0.2))
        if extra == "ape" and not hurt:
            y = mix(y, at(voice(0.2, p["f0"] * 1.8, p["f0"] * 2.3, p["f0"] * 2.0, "o", "u", p["fs"], 0.1, 0.2), 0.3) * 0.6)
        if extra in ("rhino", "dino") or (kind == "beast" and size >= 3 and extra != "mammoth"):
            y = mix(y * 0.5, roar(0.6, p["f0"] * 0.8, p["fs"] * 0.8))
        if extra == "mammoth":
            y = mix(trumpet(0.6, 330 if not hurt else 420), y * 0.4)
        if extra == "cat":
            y = mix(roar(0.5, p["f0"], p["fs"]) * 0.9, hiss(0.4) * 0.3)
        if extra == "horse" and not hurt:
            y = mix(y, at(screech(0.3, 700, 900) * 0.25, 0.05))
        if extra == "turtle":
            y = lp(y, 1800)
        if extra == "rabbit":
            y = mix(y * 0.6, squeak(0.2, 1300, 1900) * 0.4)
        if kind == "beast":
            y = mix(y, metal_clank() * 0.6)
        return y
    # humanos
    y = shout(p, hurt)
    if extra == "holo":
        y = mix(y, at(y * 0.4, 0.035), warble(0.3, 880) * 0.1)
    if extra == "corrupt":
        y = mix(y, robot(y, 40) * 0.5)
    if extra == "drill" and not hurt:
        y = mix(y * 0.8, drill(0.45))
    if extra == "armor":
        y = mix(lp(y, 3200), metal_clank(0.25) * (0.9 if hurt else 0.45))
    return y



# ---------------- falas (balões de diálogo) ----------------
def syllables(p, mood, count):
    """frase em 'idioma inventado': sílabas com consoante + vogal e entonação.
    mood 'fala' = amigável (sobe no fim); 'prov' = provocação (mais alto, rápido, termina em risada)"""
    f = p["f0"]
    fs = p["fs"]
    vows = list(VOW.keys())
    parts = []
    t0 = 0.0
    for i in range(count):
        k = i / max(1, count - 1)
        if mood == "prov":
            fk = f * (1.35 + 0.25 * np.sin(k * 5.0) + rng.random() * 0.15)
            d = 0.075 + rng.random() * 0.05
        else:
            fk = f * (1.12 + 0.12 * np.sin(k * 3.2 + 0.5) + (0.25 * k * k if i >= count - 2 else 0) + rng.random() * 0.08)
            d = 0.095 + rng.random() * 0.06
        v1 = vows[int(rng.random() * len(vows))]
        v2 = vows[int(rng.random() * len(vows))]
        ons = "k" if rng.random() < 0.55 else "h"
        syl = voice(d, fk * 0.95, fk * 1.05, fk * 0.92, v1, v2, fs, p["breath"], p["growl"] * 0.8, 0.02, 0.3, ons)
        parts.append(at(syl, t0))
        t0 += d * (0.82 + rng.random() * 0.2)
        if rng.random() < 0.18 and i < count - 2:
            t0 += 0.06  # pausa entre "palavras"
    if mood == "prov":  # risadinha no fim: ha-ha
        for j in range(2):
            d = 0.08
            fk = f * (1.6 - 0.15 * j)
            parts.append(at(voice(d, fk, fk * 1.05, fk * 0.9, "a", "a", fs, p["breath"] + 0.2, p["growl"], 0.02, 0.2, "h") * 0.9, t0 + 0.04))
            t0 += 0.13
    return msum(parts)


def char_talk(cid, mood):
    kind, sex, size, extra = PERFIS[cid]
    p = profile(kind, sex, size, extra)
    rng.bit_generator.state = np.random.default_rng(__import__("zlib").crc32((cid + mood).encode())).bit_generator.state
    count = 7 if mood == "fala" else 6
    if size >= 3:
        count -= 2  # gigantes falam devagar e pouco
    if kind == "whale":
        y = msum([at(hoot(0.22, 110 + 40 * np.sin(i * 1.7)) * 0.8, i * 0.25) for i in range(4)])
        return mix(y, bubbles(len(y), 10))
    if kind == "orb":
        return msum([at(warble(0.12, 480 + 160 * np.sin(i * 2.1)), i * 0.13) for i in range(6)])
    if kind == "insect":
        y = syllables(p, mood, count) * 0.45
        y = mix(y, chitter(len(y) / SR, 55 if mood == "prov" else 40))
        if extra in ("lobster", "crab"):
            y = mix(y, bubbles(len(y), 4))
        return y
    if kind == "golem":
        p["f0"] *= 0.9
        return golem(syllables(p, mood, count), mood == "prov")
    if kind == "frog":
        y = syllables(p, mood, count)
        return mix(y * 0.7, croak(len(y) / SR, 75) * 0.5)
    if kind == "small":
        p["f0"] *= 1.35
        y = syllables(p, mood, count)
        return mix(y, bubbles(len(y), 6)) if extra in ("puffer", "axolotl") else y
    if kind == "bird":
        if extra == "owl":
            p["vow"] = "u"
        y = syllables(p, mood, count)
        if extra == "phoenix":
            return mix(y * 0.7, crackle(len(y) / SR) * 0.6)
        return mix(y, screech(0.18, 1500, 2300) * 0.35)
    if kind == "reptile":
        y = syllables(p, mood, count)
        return mix(y, hiss(len(y) / SR) * 0.25)
    if kind == "robot":
        if extra == "dog":
            return robot(msum([at(voice(0.14, 320, 420, 300, "a", "o", 1.2, 0.2, 0.5, 0.02, 0.2, "k"), i * 0.2) for i in range(3)]), 90)
        if extra == "dragon":
            y = syllables(p, mood, count)
            return mix(robot(y, 55), roar(len(y) / SR, 95, 0.75) * 0.35)
        return robot(syllables(p, mood, count), 60)
    if kind == "radio":
        return radio(syllables(p, mood, count))
    if kind == "crystal":
        y = syllables(p, mood, count)
        return crystal(y, p["f0"], False)
    if kind == "aqua":
        y = syllables(p, mood, count)
        if extra == "octopus":
            y = lp(y, 2500)
        return mix(y, bubbles(len(y), 7))
    if kind in ("anthro", "beast"):
        y = syllables(p, mood, count)
        if extra == "mammoth":
            y = mix(y, at(trumpet(0.35, 330), len(y) / SR * 0.6) * 0.5)
        if extra == "turtle":
            y = lp(y, 1800)
        if kind == "beast":
            y = mix(y, metal_clank(0.12) * 0.3)
        return y
    y = syllables(p, mood, count)
    if extra == "holo":
        y = mix(y, at(y * 0.4, 0.035))
    if extra == "corrupt":
        y = mix(y, robot(y, 40) * 0.5)
    if extra == "armor":
        y = lp(y, 3400)
    return y


# ---------------- sons dos VFX ----------------
def vfx_sounds():
    S = {}
    S["slash"] = whoosh(0.28, 600, 6000) * 1.2
    n = int(0.3 * SR)
    S["hit"] = mix(sweep(160, 50, 0.3) * expdecay(n, 14), bp(noise(n), 800, 5000) * expdecay(n, 40) * 0.8)
    n = int(1.1 * SR)
    S["boom"] = mix(sweep(90, 28, 1.1) * expdecay(n, 3.5), lp(noise(n), 1600) * expdecay(n, 4) * 1.1)
    S["smoke"] = lp(noise(int(0.5 * SR)), 900) * env(int(0.5 * SR), 0.03, 0.4) * 0.8
    n = int(0.6 * SR)
    S["ring"] = mix(sweep(110, 45, 0.6) * expdecay(n, 6), lp(noise(n), 500) * expdecay(n, 5) * 0.6)
    t = T(0.9)
    S["heal"] = msum(at(np.sin(2 * np.pi * f * T(0.5)) * expdecay(int(0.5 * SR), 7) * env(int(0.5 * SR), 0.005, 0.15), i * 0.08) for i, f in enumerate([784, 988, 1175, 1568]))
    S["shield"] = mix(sum(np.sin(2 * np.pi * f * t[:int(0.6 * SR)] + 2 * np.sin(2 * np.pi * 7 * t[:int(0.6 * SR)])) for f in (520, 780)) * env(int(0.6 * SR), 0.03, 0.4) * 0.4,
                      hp(noise(int(0.08 * SR)), 3000) * expdecay(int(0.08 * SR), 40) * 0.5)
    S["aura"] = mix(sweep(200, 900, 0.7, "saw") * env(int(0.7 * SR), 0.15, 0.3) * 0.3, whoosh(0.7, 300, 4000) * 0.6)
    n = int(0.8 * SR)
    S["curse"] = mix(sweep(240, 80, 0.8) * (1 + 0.5 * np.sin(2 * np.pi * 6 * T(0.8))) * env(n, 0.05, 0.4) * 0.6, lp(noise(n), 700) * env(n, 0.1, 0.4) * 0.5)
    n = int(0.6 * SR)
    S["crystal"] = mix(sum(np.sin(2 * np.pi * f * T(0.6)) * expdecay(n, 7 + i * 3) / (i + 1) for i, f in enumerate([1760, 2637, 3520, 4186])),
                       hp(noise(int(0.06 * SR)), 3500) * expdecay(int(0.06 * SR), 50))
    S["bolt"] = mix(zap(0.4), hp(noise(int(0.4 * SR)), 2000) * expdecay(int(0.4 * SR), 10) * 0.6)
    S["poison"] = mix(bubbles(int(0.7 * SR), 14), lp(noise(int(0.7 * SR)), 500) * env(int(0.7 * SR), 0.05, 0.4) * 0.3)
    n = int(0.9 * SR)
    S["fire"] = mix(lp(noise(n), 2500) * env(n, 0.1, 0.5) * 0.7, crackle(0.9) * 1.2)
    n = int(0.35 * SR)
    S["spikes"] = mix(sweep(2600, 4200, 0.35) * expdecay(n, 12) * 0.4, hp(noise(n), 3000) * expdecay(n, 20) * 0.6, sweep(200, 90, 0.35) * expdecay(n, 15) * 0.5)
    n = int(1.0 * SR)
    S["vortex"] = mix(whoosh(1.0, 200, 1200) * 1.1, sweep(80, 40, 1.0) * env(n, 0.1, 0.5) * 0.6)
    n = int(0.8 * SR)
    S["portal"] = mix(sweep(300, 1400, 0.8) * (1 + 0.6 * np.sin(2 * np.pi * 9 * T(0.8))) * env(n, 0.1, 0.3) * 0.4, whoosh(0.8, 500, 5000) * 0.5)
    S["mark"] = mix(np.sin(2 * np.pi * 1800 * T(0.07)) * 0.5, at(np.sin(2 * np.pi * 1800 * T(0.07)) * 0.5, 0.12), at(np.sin(2 * np.pi * 2400 * T(0.15)) * env(int(0.15 * SR), 0.005, 0.1) * 0.6, 0.24))
    n = int(0.45 * SR)
    S["glue"] = mix(lp(noise(n), 1200) * expdecay(n, 9), sweep(400, 120, 0.45) * expdecay(n, 8) * 0.6, bubbles(n, 5))
    n = int(0.9 * SR)
    rumble = lp(np.cumsum(noise(n)) / 60, 250)
    crack = np.zeros(n)
    for k in range(7):
        s = int(rng.random() * n * 0.7)
        m = int(0.03 * SR)
        crack[s:s + m] += bp(noise(m), 400, 3000) * expdecay(m, 40)
    S["rock"] = mix(rumble * env(n, 0.05, 0.4), crack)
    n = int(0.6 * SR)
    S["ink"] = mix(lp(noise(n), 900) * expdecay(n, 8) * 0.8, bubbles(n, 6), sweep(300, 100, 0.6) * expdecay(n, 10) * 0.4)
    n = int(0.6 * SR)
    S["sonic"] = msum(at(sweep(500, 200, 0.25) * env(int(0.25 * SR), 0.01, 0.15) * (0.7 - k * 0.2), k * 0.12) for k in range(3))
    S["sparkle"] = msum(at(np.sin(2 * np.pi * (2000 + 400 * k) * T(0.18)) * expdecay(int(0.18 * SR), 25) * env(int(0.18 * SR), 0.003, 0.06) * 0.4, k * 0.07) for k in range(6))
    n = int(0.9 * SR)
    S["prison"] = mix(sweep(600, 1600, 0.9) * env(n, 0.05, 0.3) * 0.3, msum(at(hp(noise(int(0.05 * SR)), 2500) * expdecay(int(0.05 * SR), 50), k * 0.11) for k in range(6)),
                      sum(np.sin(2 * np.pi * f * T(0.9)) * expdecay(n, 4) for f in (1320, 1980)) * 0.3)
    n = int(0.6 * SR)
    S["beam"] = mix(sweep(3000, 400, 0.6, "saw") * env(n, 0.01, 0.3) * 0.25, lp(noise(n), 3000) * env(n, 0.02, 0.4) * 0.5)
    S["dash"] = whoosh(0.3, 800, 7000)
    return S


# ---------------- principal ----------------
if __name__ == "__main__":
    out = "sounds"
    only = None
    a = sys.argv[1:]
    if "--only" in a:
        i = a.index("--only")
        only = a[i + 1]
        a = a[:i] + a[i + 2:]
    if a:
        out = a[0]
    os.makedirs(out, exist_ok=True)
    if only in (None, "vfx"):
        for k, v in vfx_sounds().items():
            save(os.path.join(out, "vfx_%s.wav" % k), v, 0.8)
        print("vfx ok")
    if only in (None, "voz"):
        for cid in PERFIS:
            save(os.path.join(out, "v_%s_atk.wav" % cid), char_sound(cid, False), 0.8)
            save(os.path.join(out, "v_%s_dor.wav" % cid), char_sound(cid, True), 0.75)
            save(os.path.join(out, "v_%s_fala.wav" % cid), char_talk(cid, "fala"), 0.7)
            save(os.path.join(out, "v_%s_prov.wav" % cid), char_talk(cid, "prov"), 0.75)
        print("vozes ok:", len(PERFIS))
