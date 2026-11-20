"""Hex Galaxies - vozes e passos dos Lithari, seres de cristal vivos.

Os Lithari não têm voz de garganta: eles se comunicam com sons que os próprios
cristais emitem. Aqui tudo é cristal:
  - "sílabas" de vidro cantante (como dedo molhado na borda de uma taça):
    tom de vidro com parciais inarmônicos, excitado por fricção (stick-slip),
    com a altura deslizando como uma entonação;
  - raspar e ranger de cristal contra cristal (ruído de fricção passando por
    um banco de ressonâncias de cristal);
  - estalos, rachaduras e tilintar de lascas.

Gera em sounds/:
  v_<id>_fala.wav  conversa amigável      v_<id>_prov.wav  provocação
  v_<id>_atk.wav   ataque                 v_<id>_dor.wav   dano
  passo_lit1..3.wav  passos de cristal (tocados quando um Lithari anda)

Cada personagem tem seu timbre (tamanho, registro, aspereza), sorteado de forma
fixa pelo id: rodar de novo gera os mesmos sons.

Uso: python tools/vozes_lithari.py [pasta_saida]
"""
import os, sys, wave, zlib
import numpy as np
from scipy.signal import lfilter, butter, sosfilt

SR = 44100

# tamanho 0 pequeno .. 3 colosso; registro F/M/N; "beast" = mais rangido e bruto
PERFIS = {
"l_lider": ("M", 1, ""), "l_tank": ("N", 3, ""),
    "l_atirador": ("N", 1, ""), "l_scout": ("N", 0, ""), "l_healer": ("F", 1, ""),
    "l_eng": ("N", 1, ""), "l_assassino": ("N", 1, "sharp"), "l_sniper": ("N", 1, "sharp"),
    "l_colosso": ("N", 3, ""), "l_fera": ("N", 2, "beast"), "l_invoc": ("F", 1, ""),
    "l_ladino": ("N", 1, "sharp"), "l_guardiao": ("N", 2, ""), "l_brawler": ("N", 2, "beast"),
    "l_leviathan": ("N", 3, "beast"), "l_behemot": ("N", 3, "beast"),
}

# parciais de uma peça de cristal/vidro (inarmônicos, como sino de vidro)
GLASS = [1.0, 2.32, 4.25, 6.63, 9.38]


def T(n):
    return np.arange(n) / SR


def ns(n, r):
    return r.standard_normal(n)


def expdecay(n, k):
    return np.exp(-k * T(n))


def fade(n, a, r):
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na) if na < n else e[:na]
    if nr < n:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def hp(x, f):
    return sosfilt(butter(2, f / (SR / 2), "high", output="sos"), x)


def lp(x, f):
    return sosfilt(butter(2, min(f, SR / 2 - 100) / (SR / 2), "low", output="sos"), x)


def reson(x, f, q):
    """ressonador de 2 polos (um modo de vibração do cristal)"""
    f = min(f, SR / 2 - 200)
    r = np.exp(-np.pi * f / q / SR)
    a = [1, -2 * r * np.cos(2 * np.pi * f / SR), r * r]
    return lfilter([1 - r], a, x)


def put(dst, src, t):
    s = int(t * SR)
    if s >= len(dst):
        return
    m = min(len(src), len(dst) - s)
    dst[s:s + m] += src[:m]


def ping(f, d, r, amp=1.0, decay=7.0, bright=1.0):
    """toque de cristal: parciais inarmônicos, os agudos morrem antes"""
    n = int(d * SR)
    t = T(n)
    y = np.zeros(n)
    for k, ratio in enumerate(GLASS):
        fk = f * ratio * (1 + r.uniform(-0.006, 0.006))
        if fk > SR / 2 - 500:
            break
        a = (0.55 ** k) * (bright if k else 1.0)
        y += a * np.sin(2 * np.pi * fk * t + r.uniform(0, 6.28)) * expdecay(n, decay * (1 + k * 0.9))
    y *= fade(n, 0.0015, 0.02)
    return y * amp


def stickslip(n, rate, r, jit=0.35, rate_curve=None):
    """trem de micro-impulsos de fricção (cristal agarrando e soltando)"""
    x = np.zeros(n)
    t = 0.0
    while True:
        rr = rate if rate_curve is None else rate * rate_curve[min(int(t * SR), n - 1)]
        t += (1.0 / max(rr, 1.0)) * (1 + r.uniform(-jit, jit))
        i = int(t * SR)
        if i >= n:
            break
        x[i] += r.uniform(0.4, 1.0) * (1 if r.random() < 0.5 else -1)
    return x


def sing(f0, f1, d, r, rough=0.0, vib=0.0, curve=None):
    """sílaba de vidro cantante: tom de taça friccionada com a altura deslizando de f0 a f1"""
    n = int(d * SR)
    t = T(n)
    u = np.linspace(0, 1, n)
    if curve is None:
        curve = u
    f = f0 * (f1 / f0) ** curve
    f = f * (1 + vib * np.sin(2 * np.pi * r.uniform(4.5, 7.0) * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = np.sin(ph) + 0.32 * np.sin(ph * 2.32 + 1.1) + 0.14 * np.sin(ph * 4.25 + 0.4)
    # batimento de duas faces do cristal levemente desafinadas
    y += 0.45 * np.sin(ph * 1.0035 + 2.0)
    e = np.sin(np.pi * np.clip(u, 0, 1)) ** 0.6
    e *= fade(n, 0.012, 0.03)
    y *= e
    # fricção que excita o tom (o "raspado" dentro da sílaba)
    fr = stickslip(n, f0 * 0.18 + 40, r, 0.5)
    fr = reson(fr, f0 * 2.32, 30) * 0.6 + reson(fr, f0 * 4.25, 40) * 0.4
    fr = hp(fr, 900) * e * (0.25 + rough * 0.9)
    return y * 0.75 + fr * 2.2


def scrape(d, fc, r, amp=1.0, rate=180, rough=0.3, rise=0.0):
    """cristal raspando em cristal: fricção passando por modos de cristal"""
    n = int(d * SR)
    curve = np.linspace(1, 1 + rise, n)
    x = stickslip(n, rate, r, 0.6, curve) + ns(n, r) * 0.05
    y = np.zeros(n)
    for k, ratio in enumerate([1.0, 1.47, 2.13, 3.05, 4.4]):
        y += reson(x, fc * ratio * (1 + rise * 0.3 * np.mean(curve - 1)), 22 + k * 8) * (0.7 ** k)
    y += hp(ns(n, r), 3000) * rough * 0.08
    y *= np.sin(np.pi * np.linspace(0, 1, n)) ** 0.8
    return hp(y, 250) * amp


def grind(d, fc, r, amp=1.0):
    """rangido grave de massa de cristal (os grandes)"""
    n = int(d * SR)
    x = stickslip(n, 55, r, 0.7)
    y = reson(x, fc, 14) + reson(x, fc * 1.61, 18) * 0.6 + reson(x, fc * 2.7, 20) * 0.35
    y *= np.sin(np.pi * np.linspace(0, 1, n)) ** 0.5
    return y * amp


def crack(r, amp=1.0, fhi=4200):
    """rachadura: estalo seco + lascas que tilintam"""
    n = int(0.09 * SR)
    c = hp(ns(n, r), 1800) * expdecay(n, 70)
    c = c + reson(c, fhi, 25) * 0.6
    y = np.zeros(int(0.5 * SR))
    put(y, c * 1.6, 0)
    for _ in range(7):
        put(y, ping(r.uniform(2800, 7000), 0.25, r, r.uniform(0.08, 0.25), 18), r.uniform(0.01, 0.3))
    return y * amp


def tinkle(d, r, dens=14, lo=2500, hi=8000, amp=0.2):
    """brilho: lasquinhas e reflexos que piscam"""
    n = int(d * SR)
    y = np.zeros(n)
    for _ in range(int(dens * d)):
        put(y, ping(r.uniform(lo, hi), 0.3, r, r.uniform(0.3, 1.0) * amp, r.uniform(12, 25)), r.uniform(0, d * 0.95))
    return y


def finish(y, peak=0.85):
    # corta o silêncio do fim
    a = np.abs(y)
    lim = np.max(a) * 0.002
    idx = np.nonzero(a > lim)[0]
    if len(idx):
        y = y[:min(len(y), idx[-1] + int(0.02 * SR))]
    y = y - np.mean(y)
    y = np.tanh(y / (np.max(np.abs(y)) + 1e-9) * 1.4)
    y = y / (np.max(np.abs(y)) + 1e-9) * peak
    tail = int(0.006 * SR)
    y[-tail:] *= np.linspace(1, 0, tail)
    return y


def save(path, y):
    d = (np.clip(y, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(d.tobytes())


# ---------------- timbre de cada um ----------------
def perfil(cid):
    sex, size, extra = PERFIS[cid]
    r = np.random.default_rng(zlib.crc32(cid.encode()))
    base = {0: 1350, 1: 980, 2: 700, 3: 430}[size] * {"M": 0.88, "F": 1.28, "N": 1.0}[sex]
    base *= r.uniform(0.92, 1.08)
    p = {
        "f": base,
        "size": size,
        "rough": {"beast": 0.85, "sharp": 0.35}.get(extra, 0.15) + r.uniform(0, 0.15),
        "vib": r.uniform(0.002, 0.012),
        "speed": {0: 1.25, 1: 1.0, 2: 0.88, 3: 0.72}[size] * r.uniform(0.92, 1.1),
        "sharp": extra == "sharp",
        "beast": extra == "beast",
        # escala própria de "entonação" (intervalos em semitons)
        "modo": r.choice([[0, 3, 5, 7, 10], [0, 2, 5, 7, 9], [0, 2, 3, 7, 8], [0, 4, 6, 7, 11]]),
    }
    return p, r


def st(f, s):
    return f * 2 ** (s / 12)


def frase(p, r, n_sil, contorno, d_sil, gap, cauda=True, alt=0):
    """sequência de sílabas de vidro com uma linha melódica"""
    f = p["f"]
    total = n_sil * (d_sil + gap) + 0.6
    y = np.zeros(int(total * SR))
    t = 0.02
    for i in range(n_sil):
        u = i / max(1, n_sil - 1)
        grau = contorno(u)
        a = st(f, p["modo"][int(grau) % 5] + 12 * (int(grau) // 5) + alt)
        b = st(a, r.choice([-2, -1, 1, 2, 3]) * (1 if r.random() < 0.6 else -1))
        dd = d_sil * r.uniform(0.75, 1.25)
        put(y, sing(a, b, dd, r, p["rough"], p["vib"]), t)
        # consoante de cristal: tique/raspadinha entre as sílabas
        if r.random() < 0.6:
            put(y, ping(st(a, 19), 0.08, r, 0.25, 40), t)
        if p["rough"] > 0.5 and r.random() < 0.7:
            put(y, scrape(dd * 0.6, a * 0.9, r, 0.6, 140, p["rough"]), t + dd * 0.3)
        t += dd + gap * r.uniform(0.6, 1.4)
    if p["size"] >= 2:
        put(y, grind(t, f * 0.32, r, 0.35 + 0.25 * p["beast"]), 0)
    if cauda:
        put(y, tinkle(t + 0.3, r, 10, st(f, 24), min(9000, st(f, 40)), 0.12), 0)
    return y[:int((t + 0.45) * SR)], t


def v_fala(p, r):
    n = int(r.integers(4, 7) * p["speed"]) + 1
    d = 0.17 / p["speed"]
    y, _ = frase(p, r, n, lambda u: 2 + 2 * np.sin(u * 3.1 + 0.6), d, 0.04 / p["speed"])
    return finish(y, 0.8)


def v_prov(p, r):
    n = int(r.integers(4, 6) * p["speed"]) + 1
    d = 0.11 / p["speed"]
    y, t = frase(p, r, n, lambda u: 1 + u * 4.5, d, 0.025, cauda=False, alt=2)
    out = np.zeros(int((t + 0.7) * SR))
    put(out, y, 0)
    # final de provocação: raspada que sobe e um toque agudo que fica soando
    put(out, scrape(0.28, p["f"] * 1.4, r, 0.9, 260, p["rough"], rise=1.4), t - 0.12)
    put(out, ping(st(p["f"], 24), 0.6, r, 0.9, 4.5), t + 0.12)
    put(out, tinkle(0.5, r, 16, st(p["f"], 24), 9000, 0.15), t + 0.12)
    return finish(out, 0.85)


def v_atk(p, r):
    f = p["f"]
    d = 0.75
    y = np.zeros(int(d * SR))
    # investida: raspada que acelera e sobe
    put(y, scrape(0.3, f * 1.1, r, 1.0, 200 if not p["sharp"] else 320, p["rough"], rise=1.8), 0)
    # golpe: rachadura + grito de vidro agudo que desce um pouco
    put(y, crack(r, 1.0, st(f, 36)), 0.24)
    put(y, sing(st(f, 19), st(f, 15), 0.32, r, p["rough"] * 0.8, 0.02), 0.24)
    if p["size"] >= 2:
        put(y, grind(0.4, f * 0.3, r, 0.9 if p["beast"] else 0.5), 0.2)
    if p["sharp"]:
        put(y, ping(st(f, 31), 0.35, r, 0.8, 9), 0.26)
    return finish(y, 0.9)


def v_dor(p, r):
    f = p["f"]
    d = 0.95
    y = np.zeros(int(d * SR))
    put(y, crack(r, 1.2, st(f, 30)), 0)
    # lamento: tom de vidro desafinando e caindo, como cristal trincado vibrando
    s = sing(st(f, 12), st(f, 2), 0.6, r, p["rough"] + 0.3, 0.03, curve=np.linspace(0, 1, int(0.6 * SR)) ** 0.6)
    put(y, s, 0.06)
    put(y, sing(st(f, 12.6), st(f, 2.4), 0.6, r, 0.0, 0.03) * 0.4, 0.06)
    put(y, tinkle(0.6, r, 22, 2500, 8500, 0.2), 0.05)
    if p["size"] >= 2:
        put(y, grind(0.5, f * 0.28, r, 0.7), 0.05)
    return finish(y, 0.85)


def passo(i):
    r = np.random.default_rng(900 + i)
    y = np.zeros(int(0.42 * SR))
    f = [520, 610, 470][i]
    # pisada: toque grave de cristal + raspadinha + lascas
    put(y, ping(f, 0.35, r, 0.9, 11, 0.7), 0)
    put(y, hp(ns(int(0.03 * SR), r), 1500) * expdecay(int(0.03 * SR), 90) * 0.5, 0)
    put(y, scrape(0.12, f * 2.3, r, 0.35, 220, 0.3), 0.01)
    put(y, tinkle(0.3, r, 18, 3000, 8500, 0.16), 0.02)
    return finish(y, 0.7)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "sounds")
    for cid in PERFIS:
        for kind, fn in (("fala", v_fala), ("prov", v_prov), ("atk", v_atk), ("dor", v_dor)):
            p, r = perfil(cid)
            r = np.random.default_rng(zlib.crc32((cid + kind).encode()))
            save(os.path.join(out, "v_%s_%s.wav" % (cid, kind)), fn(p, r))
    for i in range(3):
        save(os.path.join(out, "passo_lit%d.wav" % (i + 1)), passo(i))
    print("ok: %d vozes + 3 passos" % (len(PERFIS) * 4))


if __name__ == "__main__":
    main()
