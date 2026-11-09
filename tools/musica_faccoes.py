"""Hex Galaxies - trilhas sonoras das facções (sintetizadas, loops sem emenda).

Base comum: estratégia sci-fi instrumental, leitmotif marcante, ritmo de batalha, loop perfeito.
Cada facção tem instrumentos, ritmo e personalidade próprios:

  fau  Faurianos    aventura / safári espacial: percussão de mão sincopada, marimba, baixo groovy, metais
  aby  Abyssais     oceano alienígena vivo: baixo distorcido, pulsos de sonar, bolhas, coração, ritmo irregular (7/8)
  kri  Krieg        marcha militar industrial: caixas militares, guitarra pesada, metais, impactos de artilharia
  wac  Wächter      tribal tecnológico de caça: tambores de guerra, pedra e metal, trompa grave, 6/8
  zuk  Zukunft      tecnologia avançada: sintetizadores limpos, arpejos, glitch, batida progressiva
  lit  Lithari      invasão cristalina: percussão de vidro, quartzo, grãos, polirritmo 5 contra 4, frio
  ter  Valakianos   refugiados nas minas: violoncelo humano, picaretas, cristais e o drone sub-grave do Monstro do Túnel

Uso: python tools/musica_faccoes.py [pasta_sounds] [fau,aby,...]   (precisa de ffmpeg)
Gera sounds/musica_<id>.ogg (tema em loop) e sounds/entrada_<id>.ogg (música de entrada, ~8 s)
     python tools/musica_faccoes.py sounds fau,aby --entradas   (só as entradas)
"""
import os, sys, wave, subprocess
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt

SR = 32000


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def filt(x, kind, f, order=2):
    if kind == "band":
        sos = butter(order, f, "band", fs=SR, output="sos")
    else:
        sos = butter(order, min(f, SR / 2 * 0.95), kind, fs=SR, output="sos")
    return sosfilt(sos, x)


class Track:
    def __init__(self, bpm, bars, beats=4, seed=1, tail=5.0):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.beats = beats
        self.bar = beats * self.beat
        self.bars = bars
        self.length = bars * self.bar
        self.N = int((self.length + tail) * SR)
        self.L = np.zeros(self.N)
        self.R = np.zeros(self.N)
        self.S = np.zeros(self.N)
        self.rng = np.random.default_rng(seed)

    def T(self, bar, beat=0.0):
        return bar * self.bar + beat * self.beat

    def add(self, sig, t0, gain=1.0, pan=0.0, rev=0.3):
        i = int(t0 * SR)
        if i >= self.N or i < 0:
            return
        j = min(self.N, i + len(sig))
        s = sig[:j - i] * gain
        self.L[i:j] += s * np.sqrt(0.5 * (1 - pan))
        self.R[i:j] += s * np.sqrt(0.5 * (1 + pan))
        self.S[i:j] += s * rev

    # ---------- osciladores ----------
    def saw(self, f, n, det=0.0):
        t = np.arange(n) / SR
        out = np.zeros(n)
        for d in ([-det, 0, det] if det else [0]):
            ff = f * 2 ** (d / 12)
            ph = 2 * np.pi * ff * t + self.rng.random() * 6.28
            k = 1
            while k * ff < SR / 2.2 and k < 40:
                out += np.sin(ph * k) / k
                k += 1
        return out / (3 if det else 1)

    def square(self, f, n):
        t = np.arange(n) / SR
        out = np.zeros(n)
        k = 1
        while k * f < SR / 2.2 and k < 30:
            out += np.sin(2 * np.pi * f * k * t) / k
            k += 2
        return out

    @staticmethod
    def env(n, a, r):
        t = np.arange(n) / SR
        d = n / SR
        return np.clip(t / max(a, 1e-4), 0, 1) * np.clip((d - t) / max(r, 1e-4), 0, 1)

    # ---------- instrumentos ----------
    def kick(self, t0, g=0.5, low=45):
        n = int(0.5 * SR); t = np.arange(n) / SR
        f = low + 90 * np.exp(-t * 28)
        y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7)
        self.add(np.tanh(y * 1.5), t0, g, 0, 0.1)

    def snare(self, t0, g=0.2, pan=0.1, tight=18):
        n = int(0.3 * SR); t = np.arange(n) / SR
        y = filt(self.rng.normal(size=n), "band", [1500, 7000]) * np.exp(-t * tight) + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * 0.6
        self.add(y, t0, g, pan, 0.35)

    def hat(self, t0, g=0.06, pan=0.3, open_=False):
        n = int((0.25 if open_ else 0.06) * SR); t = np.arange(n) / SR
        y = filt(self.rng.normal(size=n), "high", 7000) * np.exp(-t * (12 if open_ else 70))
        self.add(y, t0, g, pan, 0.1)

    def taiko(self, t0, g=0.3, big=False, pan=None):
        n = int(0.9 * SR); t = np.arange(n) / SR
        f = 52 + 90 * np.exp(-t * 18)
        body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * (4 if big else 6.5))
        skin = filt(self.rng.normal(size=n), "band", [200, 1800]) * np.exp(-t * 40) * 0.5
        self.add((body + skin) * (1.4 if big else 1.0), t0, g, self.rng.uniform(-0.2, 0.2) if pan is None else pan, 0.45)

    def conga(self, t0, g=0.15, pitch=1.0, pan=0.0, slap=False):
        n = int(0.35 * SR); t = np.arange(n) / SR
        f = (190 if not slap else 260) * pitch * (1 + 0.4 * np.exp(-t * 40))
        y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * (14 if not slap else 24))
        y += filt(self.rng.normal(size=n), "band", [800, 4000]) * np.exp(-t * 90) * (0.7 if slap else 0.3)
        self.add(y, t0, g, pan, 0.25)

    def shaker(self, t0, g=0.04, pan=0.4):
        n = int(0.09 * SR)
        y = filt(self.rng.normal(size=n), "band", [4000, 10000]) * np.sin(np.linspace(0, np.pi, n))
        self.add(y, t0, g, pan, 0.15)

    def anvil(self, t0, g=0.08, pitch=1.0, pan=None):
        n = int(1.0 * SR); t = np.arange(n) / SR
        y = np.zeros(n)
        for p, d, a in ((1.0, 5, 1.0), (2.76, 8, 0.6), (5.4, 13, 0.4), (8.93, 20, 0.25)):
            y += np.sin(2 * np.pi * 420 * pitch * p * t + self.rng.random() * 6) * np.exp(-t * d) * a
        y += filt(self.rng.normal(size=n), "band", [2000, 8000]) * np.exp(-t * 60) * 0.5
        self.add(y, t0, g, self.rng.uniform(-0.4, 0.4) if pan is None else pan, 0.45)

    def stone(self, t0, g=0.15, pan=0.0):
        n = int(0.25 * SR); t = np.arange(n) / SR
        y = filt(self.rng.normal(size=n), "band", [300, 2200]) * np.exp(-t * 35) + np.sin(2 * np.pi * 140 * t) * np.exp(-t * 30) * 0.6
        self.add(y, t0, g, pan, 0.4)

    def glass(self, t0, m, g=0.06, pan=0.0, decay=3.0):
        n = int(1.6 * SR); t = np.arange(n) / SR
        f = hz(m)
        y = np.zeros(n)
        for p, a in ((1.0, 1.0), (2.32, 0.5), (4.25, 0.35), (6.63, 0.2), (9.38, 0.12)):
            y += np.sin(2 * np.pi * f * p * t) * np.exp(-t * decay * (0.6 + p * 0.4)) * a
        self.add(y, t0, g, pan, 0.7)

    def grains(self, t0, dur, m, g=0.04, density=40):
        """nuvem de grãos curtos em volta de uma nota (síntese granular)"""
        n = int(dur * SR)
        out = np.zeros(n + int(0.1 * SR))
        for k in range(int(dur * density)):
            gl = int(self.rng.uniform(0.015, 0.05) * SR)
            s = int(self.rng.uniform(0, dur) * SR)
            f = hz(m + self.rng.choice([0, 12, 7, 19, -12])) * (1 + self.rng.normal(0, 0.004))
            tt = np.arange(gl) / SR
            out[s:s + gl] += np.sin(2 * np.pi * f * tt) * np.hanning(gl)
        self.add(out, t0, g, self.rng.uniform(-0.6, 0.6), 0.8)

    def marimba(self, t0, m, g=0.08, pan=0.0):
        n = int(1.2 * SR); t = np.arange(n) / SR
        f = hz(m)
        y = np.sin(2 * np.pi * f * t) * np.exp(-t * 3.5) + 0.35 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t * 12) + 0.15 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t * 30)
        self.add(y, t0, g, pan, 0.4)

    def bass(self, t0, m, dur, g=0.2, cut=420, dist=0.0, slide=0):
        n = int(dur * SR); t = np.arange(n) / SR
        f0 = hz(m)
        f = f0 * (2 ** (slide / 12 * np.clip(t / 0.08, 0, 1))) if slide else np.full(n, f0)
        ph = 2 * np.pi * np.cumsum(f) / SR
        y = sum(np.sin(ph * k) / k for k in range(1, 14)) * 0.6 + np.sin(ph) * 0.6
        y = filt(y, "low", cut)
        if dist > 0:
            y = np.tanh(y * (1 + dist * 6)) * 0.8
        self.add(y * self.env(n, 0.005, min(0.08, dur * 0.3)) * np.exp(-t * 1.5), t0, g, 0, 0.05)

    def pad(self, notes, t0, dur, g=0.05, cut=1500, det=0.1, att=0.8, rev=0.7, shimmer=0.0):
        n = int((dur + 1.0) * SR); t = np.arange(n) / SR
        y = np.zeros(n)
        for m in notes:
            y += self.saw(hz(m), n, det)
        y = filt(y, "low", cut)
        if shimmer:
            y *= 1 + shimmer * np.sin(2 * np.pi * t * 5.0)
        self.add(y * self.env(n, att, 1.0), t0, g, self.rng.uniform(-0.3, 0.3), rev)

    def brass(self, m, t0, dur, g=0.06, bright=3200):
        n = int((dur + 0.3) * SR); t = np.arange(n) / SR
        y = self.saw(hz(m), n, 0.09) + self.saw(hz(m - 12), n, 0.05) * 0.5
        op = np.clip(t / 0.1, 0, 1)
        y = filt(y, "low", 900) * (1 - op * 0.6) + filt(y, "low", bright) * op * 0.8
        self.add(np.tanh(y * 1.3) * self.env(n, 0.04, 0.25), t0, g, self.rng.uniform(-0.2, 0.2), 0.45)

    def horn(self, m, t0, dur, g=0.07):
        n = int((dur + 0.5) * SR); t = np.arange(n) / SR
        y = self.saw(hz(m), n, 0.05)
        y = filt(y, "low", 1100) * (1 + 0.04 * np.sin(2 * np.pi * 5 * t))
        self.add(np.tanh(y * 1.2) * self.env(n, 0.15, 0.5), t0, g, -0.15, 0.6)

    def guitar(self, chord_root, t0, dur, g=0.06, palm=False):
        """guitarra distorcida: power chord (tônica + quinta + oitava)"""
        n = int(dur * SR); t = np.arange(n) / SR
        y = self.saw(hz(chord_root), n, 0.06) + self.saw(hz(chord_root + 7), n, 0.06) * 0.8 + self.saw(hz(chord_root + 12), n, 0.04) * 0.5
        y = np.tanh(filt(y, "low", 2400) * 6.0)
        y = filt(y, "low", 3500) * (np.exp(-t * 10) if palm else self.env(n, 0.005, 0.1))
        self.add(y, t0, g, 0.35 if self.rng.random() < 0.5 else -0.35, 0.2)

    def arp(self, m, t0, g=0.04, pan=0.0, cut=2600, dec=9, echo=True):
        n = int(0.4 * SR); t = np.arange(n) / SR
        y = self.saw(hz(m), n, 0.05)
        y = filt(y, "low", cut) * np.exp(-t * dec)
        self.add(y, t0, g, pan, 0.35)
        if echo:
            self.add(y * 0.35, t0 + self.beat * 0.75, g, -pan, 0.5)

    def pluck(self, m, t0, g=0.05, pan=0.0):
        n = int(0.6 * SR); t = np.arange(n) / SR
        y = self.square(hz(m), n) * np.exp(-t * 7)
        self.add(filt(y, "low", 2400), t0, g, pan, 0.4)

    def lead(self, notes, t0, g=0.08, wave="saw", vib=0.008, glide=0.06, cut=3000, pan=0.0, rev=0.6, breath=0.0):
        total = sum(d for _, d in notes)
        n = int((total * self.beat + 0.8) * SR)
        f = np.zeros(n); amp = np.zeros(n)
        pos = 0
        prev = hz(next(m for m, _ in notes if m is not None))
        for m, d in notes:
            k = int(d * self.beat * SR)
            if m is not None:
                tgt = hz(m)
                gg = np.minimum(1, np.arange(k) / max(1, glide * SR))
                f[pos:pos + k] = prev + (tgt - prev) * gg
                amp[pos:pos + k] = np.minimum(1, np.arange(k) / (0.03 * SR)) * np.clip((k - np.arange(k)) / (0.06 * SR), 0, 1)
                prev = tgt
            else:
                f[pos:pos + k] = prev
            pos += k
        f[pos:] = prev
        t = np.arange(n) / SR
        ph = 2 * np.pi * np.cumsum(f * (1 + vib * np.sin(2 * np.pi * 5.2 * t))) / SR
        if wave == "sine":
            y = np.sin(ph) + 0.15 * np.sin(2 * ph)
        elif wave == "square":
            y = sum(np.sin(ph * k) / k for k in (1, 3, 5, 7, 9))
        else:
            y = sum(np.sin(ph * k) / k for k in range(1, 16))
        y = filt(y, "low", cut)
        if breath:
            y += filt(self.rng.normal(size=n), "band", [1500, 5000]) * breath
        self.add(y * amp, t0, g, pan, rev)

    def cello(self, notes, t0, g=0.09):
        self.lead(notes, t0, g, "saw", vib=0.012, glide=0.09, cut=1400, pan=-0.2, rev=0.6)

    def boom(self, t0, g=0.12):
        n = int(2.0 * SR); t = np.arange(n) / SR
        y = filt(self.rng.normal(size=n), "low", 220) * np.exp(-t * 2.4) * 2.0 + np.sin(2 * np.pi * 38 * t) * np.exp(-t * 3)
        self.add(y, t0, g, self.rng.uniform(-0.6, 0.6), 0.8)

    def riser(self, t0, dur, g=0.05):
        n = int(dur * SR); t = np.arange(n) / SR
        x = self.rng.normal(size=n); y = np.zeros(n)
        for i in range(8):
            a, b = i * n // 8, (i + 1) * n // 8
            c = 400 + 5000 * (i / 8) ** 2
            y[a:b] = filt(x, "band", [c, c * 1.6])[a:b]
        self.add(y * (t / dur) ** 2, t0, g, 0, 0.8)

    def sonar(self, t0, g=0.06, f=1500):
        n = int(1.5 * SR); t = np.arange(n) / SR
        y = np.sin(2 * np.pi * f * t) * np.exp(-t * 4)
        self.add(y, t0, g, self.rng.uniform(-0.7, 0.7), 1.0)

    def bubbles(self, t0, dur, g=0.04, amount=8):
        for k in range(amount):
            d = 0.04 + self.rng.random() * 0.05
            n = int(d * SR); t = np.arange(n) / SR
            f0 = 300 + self.rng.random() * 500
            y = np.sin(2 * np.pi * np.cumsum(np.linspace(f0, f0 * 2.5, n)) / SR) * self.env(n, 0.005, 0.03)
            self.add(y, t0 + self.rng.random() * dur, g, self.rng.uniform(-0.8, 0.8), 0.6)

    def heart(self, t0, g=0.3):
        for k, (dt, a) in enumerate(((0, 1.0), (0.18, 0.7))):
            n = int(0.25 * SR); t = np.arange(n) / SR
            y = np.sin(2 * np.pi * 50 * t) * np.exp(-t * 18)
            self.add(filt(y, "low", 200), t0 + dt, g * a, 0, 0.1)

    def click(self, t0, g=0.08, pan=0.0):
        n = int(0.02 * SR)
        y = filt(self.rng.normal(size=n), "band", [2500, 9000]) * np.exp(-np.arange(n) / SR * 300)
        self.add(y, t0, g, pan, 0.3)

    def glitch(self, t0, m, g=0.05):
        """trecho cortado e repetido (stutter) de uma nota quadrada"""
        sl = int(0.03 * SR)
        y = self.square(hz(m), sl) * np.hanning(sl)
        for k in range(6):
            self.add(y, t0 + k * 0.035, g * (1 - k * 0.12), self.rng.uniform(-0.8, 0.8), 0.2)

    def drill(self, t0, dur, g=0.04):
        n = int(dur * SR); t = np.arange(n) / SR
        f = 120 + 30 * np.sin(2 * np.pi * 3 * t)
        y = np.tanh(np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 1.5) * 0.5 + filt(self.rng.normal(size=n), "band", [1500, 4000]) * 0.25
        self.add(filt(y, "low", 3000) * self.env(n, 0.1, 0.3), t0, g, self.rng.uniform(-0.5, 0.5), 0.3)

    # ---------- mixagem ----------
    def render(self, dst, rev_len=3.0, rev_mix=0.5, drive=1.3):
        ir_n = int(rev_len * SR)
        irt = np.arange(ir_n) / SR
        ir = self.rng.normal(size=ir_n) * np.exp(-irt * (6.0 / rev_len))
        ir = filt(ir, "low", 5000)
        ir /= np.sqrt(np.sum(ir ** 2))
        wl = fftconvolve(self.S, ir)[:self.N]
        wr = fftconvolve(self.S, np.roll(ir, 113))[:self.N]
        outL = self.L + wl * rev_mix
        outR = self.R + wr * rev_mix
        n_loop = int(self.length * SR)
        st = []
        for ch in (outL, outR):
            y = ch[:n_loop].copy()
            tail = ch[n_loop:]
            y[:len(tail)] += tail
            st.append(y)
        st = np.stack(st, -1)
        st = filt(st.T, "high", 30).T if False else st
        st = np.tanh(st / np.max(np.abs(st)) * drive) * 0.85
        tmp = dst + ".tmp.wav"
        with wave.open(tmp, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((st * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
        os.remove(tmp)
        return self.length


# =====================================================================
# Faurianos: safári espacial, groove, aventura
# =====================================================================
def faurianos(dst):
    tr = Track(112, 24, seed=11)
    prog = [(43, [55, 59, 62]), (40, [55, 59, 64]), (36, [55, 60, 64]), (38, [54, 57, 62])]   # Sol - Mim - Dó - Ré
    for bar in range(tr.bars):
        root, ch = prog[bar % 4]
        sec = bar // 8
        # percussão de mão sincopada
        for b, p, sl in ((0, 1.0, False), (0.75, 1.3, False), (1.5, 1.0, True), (2.0, 0.9, False), (2.75, 1.3, True), (3.5, 1.0, False)):
            tr.conga(tr.T(bar, b), 0.16, p, -0.3 if p > 1 else 0.3, sl)
        for i in range(8):
            tr.shaker(tr.T(bar, i * 0.5 + 0.25), 0.035, 0.5)
        tr.kick(tr.T(bar, 0), 0.4)
        tr.kick(tr.T(bar, 2.5), 0.3)
        if sec >= 1:
            tr.snare(tr.T(bar, 1), 0.1); tr.snare(tr.T(bar, 3), 0.12)
        # baixo groovy (síncope)
        for b, d, o in ((0, 0.5, 0), (0.75, 0.25, 12), (1.5, 0.5, 0), (2.25, 0.25, 7), (2.5, 0.75, 0), (3.5, 0.5, 10)):
            tr.bass(tr.T(bar, b), root + o - 12 + 12, d * tr.beat, 0.22, cut=700, slide=(2 if o == 10 else 0))
        # marimba
        pat = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[1] + 12, ch[0] + 24, ch[2] + 12, ch[1] + 12, ch[2] + 12]
        for i in range(8):
            if sec == 0 and i % 2:
                continue
            tr.marimba(tr.T(bar, i * 0.5), pat[i], 0.07, -0.4 if i % 2 else 0.4)
        if bar % 2 == 0:
            tr.pad([n - 12 for n in ch], tr.T(bar), tr.bar * 2, 0.025, cut=1800)
    # riffs de metais (o tema)
    riff = [(67, 0.5), (None, 0.25), (67, 0.25), (69, 0.5), (71, 0.5), (74, 1.0), (71, 0.5), (69, 0.5),
            (67, 0.5), (None, 0.5), (64, 0.5), (66, 0.5), (67, 2.0)]
    for start in (8, 12, 16, 20):
        t = tr.T(start)
        for m, d in riff:
            if m is not None:
                tr.brass(m, t, d * tr.beat * 0.9, 0.065)
                tr.brass(m - 12, t, d * tr.beat * 0.9, 0.035)
            t += d * tr.beat
    # sintetizador colorido respondendo (lado brincalhão)
    tr.lead([(79, 0.25), (81, 0.25), (83, 0.25), (86, 0.75), (None, 1.0), (83, 0.25), (81, 0.25), (79, 1.0)], tr.T(18, 0), 0.04, "square", cut=4000, pan=0.4)
    tr.lead([(79, 0.25), (81, 0.25), (83, 0.25), (86, 0.75), (None, 1.0), (88, 0.5), (86, 1.0)], tr.T(22, 0), 0.04, "square", cut=4000, pan=0.4)
    tr.riser(tr.T(7), tr.bar, 0.04)
    return tr.render(dst, 2.2, 0.35, 1.4)


# =====================================================================
# Abyssais: oceano alienígena vivo e mutante (7/8)
# =====================================================================
def abyssais(dst):
    tr = Track(100, 28, beats=3.5, seed=22)      # 7/8 = 3,5 tempos de semínima
    prog = [(38, [62, 65, 69]), (37, [61, 64, 68]), (34, [62, 65, 70]), (36, [60, 63, 67])]
    for bar in range(tr.bars):
        root, ch = prog[(bar // 2) % 4]
        sec = bar // 7
        tr.heart(tr.T(bar, 0), 0.28)
        # baixo distorcido em grupos 2+2+3 (colcheias)
        for b, d in ((0, 0.9), (1.0, 0.9), (2.0, 1.4)):
            tr.bass(tr.T(bar, b), root, d * tr.beat, 0.24, cut=500, dist=0.6 if sec >= 1 else 0.3)
        # percussão orgânica (estalos de crustáceos) irregular
        for i in range(7):
            if tr.rng.random() < (0.5 if sec == 0 else 0.8):
                tr.click(tr.T(bar, i * 0.5 + tr.rng.uniform(0, 0.08)), 0.09, tr.rng.uniform(-0.7, 0.7))
        if sec >= 1:
            tr.taiko(tr.T(bar, 0), 0.22, True)
            tr.taiko(tr.T(bar, 2.0), 0.16)
        if sec >= 2:
            tr.snare(tr.T(bar, 1.0), 0.07, tight=30)
            tr.snare(tr.T(bar, 3.0), 0.07, tight=30)
        if bar % 2 == 0:
            tr.sonar(tr.T(bar, 0.5), 0.06, 1200 + 300 * ((bar // 2) % 3))
            tr.pad([n - 12 for n in ch], tr.T(bar), tr.bar * 2, 0.03, cut=900, det=0.2, shimmer=0.15)
        tr.bubbles(tr.T(bar), tr.bar, 0.035, 5)
    # chamado marinho (lead que desliza, processado)
    call = [(74, 1.5), (72, 0.5), (70, 1.0), (69, 0.5), (None, 1.5), (74, 1.0), (77, 1.0), (76, 1.0), (72, 0.5), (69, 2.0)]
    for start in (7, 14, 21):
        tr.lead(call, tr.T(start, 0.5), 0.07, "sine", vib=0.02, glide=0.18, cut=2500, pan=-0.3, rev=0.9)
    tr.riser(tr.T(13), tr.bar, 0.04)
    return tr.render(dst, 3.8, 0.6, 1.4)


# =====================================================================
# Krieg: marcha militar industrial
# =====================================================================
def krieg(dst):
    tr = Track(104, 24, seed=33)
    prog = [(40, 40), (40, 40), (43, 43), (38, 38), (40, 40), (36, 36), (38, 38), (35, 35)]
    for bar in range(tr.bars):
        root = prog[bar % 8][0]
        sec = bar // 8
        # caixas militares (marcha)
        for i, (b, g) in enumerate(((0, 0.12), (0.5, 0.06), (0.75, 0.05), (1, 0.12), (2, 0.12), (2.5, 0.06), (2.75, 0.05), (3, 0.12))):
            tr.snare(tr.T(bar, b), g + (0.03 if sec else 0), 0.15, tight=22)
        if bar % 4 == 3:
            for i in range(8):
                tr.snare(tr.T(bar, 2 + i * 0.25), 0.04 + i * 0.012, 0.1, tight=30)
        tr.kick(tr.T(bar, 0), 0.55, 40); tr.kick(tr.T(bar, 2), 0.5, 40)
        if sec >= 1:
            tr.kick(tr.T(bar, 1.5), 0.35, 40)
            # guitarra pesada: palm mute em colcheias e acorde aberto no tempo 1
            for i in range(8):
                tr.guitar(root, tr.T(bar, i * 0.5), tr.beat * 0.45, 0.05, palm=(i != 0))
        tr.anvil(tr.T(bar, 1), 0.05, 0.8); tr.anvil(tr.T(bar, 3), 0.05, 0.95)
        tr.bass(tr.T(bar, 0), root, tr.beat * 1.8, 0.24, cut=450, dist=0.3)
        tr.bass(tr.T(bar, 2), root, tr.beat * 1.8, 0.24, cut=450, dist=0.3)
        if bar % 4 == 1 and sec >= 1:
            tr.boom(tr.T(bar, 2.5), 0.12)
    # tema nos metais pesados
    theme = [(64, 1.0), (64, 0.5), (67, 0.5), (71, 1.5), (69, 0.5), (67, 1.0), (66, 1.0), (64, 2.0),
             (64, 1.0), (64, 0.5), (67, 0.5), (72, 1.5), (71, 0.5), (69, 1.0), (71, 1.0), (64, 2.0)]
    for start in (8, 16):
        t = tr.T(start)
        for m, d in theme:
            tr.brass(m, t, d * tr.beat * 0.92, 0.075, 2600)
            tr.brass(m - 12, t, d * tr.beat * 0.92, 0.05, 2000)
            t += d * tr.beat
    tr.riser(tr.T(7), tr.bar, 0.05); tr.riser(tr.T(15), tr.bar, 0.05)
    return tr.render(dst, 2.0, 0.3, 1.6)


# =====================================================================
# Wächter: tribal tecnológico, ritmo de caça (6/8)
# =====================================================================
def wachter(dst):
    tr = Track(96, 24, beats=3, seed=44)          # 6/8 = 2 tempos pontuados = 3 semínimas
    prog = [(45, [57, 60, 64]), (41, [57, 60, 65]), (43, [55, 59, 62]), (40, [55, 59, 64])]
    for bar in range(tr.bars):
        root, ch = prog[(bar // 2) % 4]
        sec = bar // 8
        # ritmo de caça: galope em colcheias (6 por compasso)
        for i in range(6):
            big = i in (0, 3)
            if big or sec >= 1:
                tr.taiko(tr.T(bar, i * 0.5), 0.26 if big else 0.13, big)
        # pedra e metal
        tr.stone(tr.T(bar, 1.0), 0.18, -0.4)
        tr.stone(tr.T(bar, 2.5), 0.14, 0.4)
        if sec >= 1:
            tr.anvil(tr.T(bar, 1.5), 0.04, 1.2)
        if sec == 2:
            tr.snare(tr.T(bar, 1.5), 0.08)
        tr.bass(tr.T(bar, 0), root - 12, tr.beat * 1.4, 0.24, cut=300)
        tr.bass(tr.T(bar, 1.5), root - 12, tr.beat * 1.4, 0.2, cut=300)
        if bar % 2 == 0:
            tr.pad([n - 12 for n in ch], tr.T(bar), tr.bar * 2, 0.035, cut=1000, det=0.08)
    # trompa grave (tema de caça)
    hunt = [(57, 1.5), (64, 1.0), (62, 0.5), (60, 1.5), (59, 1.5), (57, 3.0),
            (57, 1.5), (64, 1.0), (65, 0.5), (67, 1.5), (64, 1.5), (69, 3.0)]
    for start in (4, 12, 20):
        t = tr.T(start)
        for m, d in hunt:
            tr.horn(m, t, d * tr.beat * 0.95, 0.08)
            t += d * tr.beat
    tr.riser(tr.T(7), tr.bar, 0.04); tr.riser(tr.T(15), tr.bar, 0.04)
    return tr.render(dst, 3.0, 0.5, 1.4)


# =====================================================================
# Zukunft: sintetizadores limpos, arpejos, glitch, progressivo
# =====================================================================
def zukunft(dst):
    tr = Track(122, 32, seed=55)
    prog = [(45, [69, 72, 76]), (41, [69, 72, 77]), (48, [67, 72, 76]), (43, [67, 71, 74])]
    for bar in range(tr.bars):
        root, ch = prog[(bar // 2) % 4]
        sec = bar // 8
        # batida progressiva: entra camada a camada
        tr.kick(tr.T(bar, 0), 0.45); tr.kick(tr.T(bar, 2), 0.45)
        if sec >= 1:
            tr.kick(tr.T(bar, 1), 0.4); tr.kick(tr.T(bar, 3), 0.4)
            for i in range(8):
                tr.hat(tr.T(bar, i * 0.5 + 0.25), 0.05, 0.3, open_=(i % 4 == 3))
        if sec >= 2:
            tr.snare(tr.T(bar, 1), 0.1, tight=25); tr.snare(tr.T(bar, 3), 0.1, tight=25)
        # arpejo de 16 avos
        pat = [ch[0], ch[1], ch[2], ch[0] + 12, ch[2], ch[1], ch[0] + 12, ch[2] + 12]
        for i in range(16):
            cut = 1200 + 2600 * min(1.0, (bar % 8) / 7.0)        # filtro que abre
            tr.arp(pat[i % 8] - 12, tr.T(bar, i * 0.25), 0.035, -0.5 if i % 2 else 0.5, cut=cut, dec=12, echo=False)
        for i in range(4):
            tr.bass(tr.T(bar, i), root, tr.beat * 0.9, 0.2, cut=600)
        if bar % 2 == 0:
            tr.pad(ch, tr.T(bar), tr.bar * 2, 0.025, cut=3000, det=0.12, att=1.2)
        if sec >= 1 and tr.rng.random() < 0.5:
            tr.glitch(tr.T(bar, 3.5), ch[2] + 12, 0.05)
    lead = [(76, 0.75), (79, 0.75), (81, 0.5), (84, 1.5), (83, 0.5), (81, 1.0), (79, 1.0), (76, 2.0),
            (77, 0.75), (79, 0.75), (81, 0.5), (79, 1.0), (76, 1.0), (74, 4.0)]
    for start in (16, 24):
        tr.lead(lead, tr.T(start), 0.06, "square", vib=0.005, glide=0.03, cut=5000, pan=0.15)
    tr.riser(tr.T(15), tr.bar, 0.05); tr.riser(tr.T(31), tr.bar, 0.05)
    return tr.render(dst, 2.5, 0.4, 1.3)


# =====================================================================
# Lithari: invasão cristalina, vidro e quartzo, polirritmo 5 contra 4
# =====================================================================
def lithari(dst):
    tr = Track(90, 24, seed=66)
    scale = [62, 63, 66, 67, 69, 70, 73]          # Ré com 2ª menor e 4ª aumentada (frio, estranho)
    prog = [(38, [62, 66, 69]), (39, [63, 67, 70]), (36, [60, 63, 67]), (37, [61, 66, 69])]
    for bar in range(tr.bars):
        root, ch = prog[(bar // 2) % 4]
        sec = bar // 8
        # pulso parasita: 4 por compasso no grave
        for i in range(4):
            tr.bass(tr.T(bar, i), root - 12 + 12, tr.beat * 0.4, 0.17, cut=350)
        # vidro em 5 contra 4
        for i in range(5):
            m = ch[i % 3] + 24 + (12 if i == 4 else 0)
            tr.glass(tr.T(bar, i * 4 / 5), m, 0.05 + 0.02 * (sec >= 1), -0.6 + 0.3 * i, 4.0)
        # quartzo percutido (agudo, cortante) em pontos assimétricos
        for b in (0.0, 1.25, 2.75) if sec >= 1 else (0.0, 2.75):
            tr.click(tr.T(bar, b), 0.1, tr.rng.uniform(-0.5, 0.5))
            tr.glass(tr.T(bar, b), scale[tr.rng.integers(len(scale))] + 36, 0.025, tr.rng.uniform(-0.8, 0.8), 9.0)
        if sec >= 1:
            tr.kick(tr.T(bar, 0), 0.35, 38)
            tr.stone(tr.T(bar, 2.5), 0.1)
        if sec == 2:
            tr.taiko(tr.T(bar, 1.5), 0.12)
        # grãos: a tensão cresce
        tr.grains(tr.T(bar), tr.bar, ch[0] + 12, 0.012 + 0.008 * sec, 25 + 15 * sec)
        if bar % 2 == 0:
            tr.pad([n - 12 for n in ch], tr.T(bar), tr.bar * 2, 0.025, cut=700, det=0.25)
    motif = [(74, 1.0), (75, 0.5), (78, 1.5), (None, 1.0), (74, 0.5), (73, 0.5), (70, 2.0), (None, 1.0),
             (81, 1.0), (82, 0.5), (78, 1.5), (75, 1.0), (74, 3.0)]
    for start in (8, 16):
        tr.lead(motif, tr.T(start), 0.05, "sine", vib=0.0, glide=0.01, cut=6000, pan=0.3, rev=0.9)
    tr.riser(tr.T(15), tr.bar, 0.03)
    return tr.render(dst, 4.0, 0.6, 1.3)


# =====================================================================
# Terramorfos: mineração, máquinas e violoncelo humano
# =====================================================================
def valakianos(dst):
    """Valakianos, Refugiados de Valak: Ré menor, 76 BPM, 32 compassos.
    1-8   Refúgio: violoncelo humano, marimba, pedra batida, pad quente (a comunidade abrigada)
    9-16  A mina trabalha: picaretas, taiko, trompa e cristais tilintando (esperança, riqueza)
    17-24 O pacto: drone sub-grave do Monstro do Túnel, broca, coração, tritono e cristais frios (o segredo do Rei)
    25-32 Volta ao refúgio, mas o drone continua por baixo; termina em suspensão e reentra no começo"""
    tr = Track(76, 32, seed=2026)
    prog = [(38, [62, 65, 69]), (34, [58, 62, 65]), (43, [55, 58, 62]), (45, [57, 61, 64])]   # Rém - Si♭ - Solm - Lá
    sinis = [(38, [62, 65, 69]), (39, [63, 67, 70]), (38, [62, 65, 68]), (37, [61, 65, 68])]   # Ré m - Mi♭ - Ré dim - Dó♯ (tensão)
    theme = [(62, 1.5), (65, 0.5), (69, 1.0), (67, 1.0), (65, 2.0), (64, 1.0), (62, 1.0),
             (58, 1.5), (60, 0.5), (62, 1.0), (65, 1.0), (64, 3.0), (None, 1.0)]
    dark = [(62, 1.5), (63, 0.5), (69, 1.0), (68, 1.0), (65, 2.0), (63, 1.0), (62, 1.0),
            (58, 1.5), (57, 0.5), (56, 1.0), (62, 1.0), (61, 3.0), (None, 1.0)]
    for bar in range(tr.bars):
        sec = bar // 8
        root, ch = (sinis if sec == 2 else prog)[(bar // 2) % 4]
        # marimba: arpejo manso do refúgio
        pat = [ch[0], ch[2], ch[1] + 12, ch[2]]
        if sec != 2:
            for i in range(4):
                tr.marimba(tr.T(bar, i), pat[i] + (0 if sec != 1 else 12), 0.05 if sec != 1 else 0.04, -0.4 if i % 2 else 0.4)
        # pedra batida: pulso suave
        tr.stone(tr.T(bar, 0), 0.07, -0.3)
        if sec in (1, 3):
            tr.stone(tr.T(bar, 2.5), 0.05, 0.3)
        # pad quente
        if bar % 2 == 0:
            tr.pad([n - 12 for n in ch], tr.T(bar), tr.bar * 2, 0.045 if sec != 2 else 0.035, cut=900 if sec != 2 else 600, det=0.06 if sec != 2 else 0.14)
        # baixo
        if sec != 2:
            tr.bass(tr.T(bar, 0), root, tr.beat * 3.2, 0.2, cut=330, dist=0.1)
        if sec == 1:
            # mina trabalhando
            tr.anvil(tr.T(bar, 0.5), 0.05, 0.85, -0.5)
            tr.anvil(tr.T(bar, 2), 0.04, 1.0, 0.5)
            tr.anvil(tr.T(bar, 3.5), 0.04, 0.85, -0.2)
            tr.taiko(tr.T(bar, 0), 0.2, True)
            tr.taiko(tr.T(bar, 2), 0.14)
            tr.kick(tr.T(bar, 0), 0.3, 40)
            for i, m in enumerate([ch[2] + 24, ch[0] + 24, ch[1] + 24]):
                tr.glass(tr.T(bar, i * 4 / 3), m, 0.035, -0.5 + 0.5 * i, 4.0)
            if bar % 4 == 3:
                tr.horn(ch[0] - 12, tr.T(bar, 0), tr.bar, 0.05)
        if sec == 2:
            # o monstro: drone sub-grave, respiração, coração, broca distante
            tr.bass(tr.T(bar, 0), 26 if bar % 4 < 2 else 25, tr.bar * 1.05, 0.3, cut=140, dist=0.35, slide=-1 if bar % 2 else 0)
            tr.heart(tr.T(bar, 0), 0.2)
            tr.heart(tr.T(bar, 1.5), 0.12)
            tr.grains(tr.T(bar, 0), tr.bar, 36 + (bar % 3), 0.025, 25)
            if bar % 2 == 1:
                tr.drill(tr.T(bar, 1), tr.beat * 2.5, 0.03)
            tr.glass(tr.T(bar, 1), ch[1] + 24, 0.03, -0.7, 6.0)
            tr.glass(tr.T(bar, 3), ch[0] + 30, 0.025, 0.7, 7.0)   # tritono frio sobre a raiz
            if bar % 4 == 3:
                tr.boom(tr.T(bar, 3.5), 0.08)
        if sec == 3:
            # o drone ainda respira por baixo
            tr.bass(tr.T(bar, 0), 26, tr.bar * 1.0, 0.1, cut=120, dist=0.2)
            if bar % 4 == 2:
                tr.heart(tr.T(bar, 0), 0.1)
    # violoncelo: o lado humano
    tr.cello(theme, tr.T(0), 0.09)
    tr.cello(theme, tr.T(4), 0.1)
    tr.cello([(n + 12 if n else n, d) for n, d in theme], tr.T(12), 0.06)
    tr.cello(dark, tr.T(16), 0.1)
    tr.cello([(n - 12 if n else n, d) for n, d in dark], tr.T(20), 0.08)
    tr.cello(theme, tr.T(24), 0.09)
    tr.cello([(62, 2.0), (65, 1.0), (69, 1.0), (70, 4.0), (70, 4.0)], tr.T(28), 0.07)   # termina em Si♭ suspenso, volta ao Ré
    tr.riser(tr.T(15), tr.bar, 0.03)
    tr.riser(tr.T(23), tr.bar, 0.04)
    return tr.render(dst, 3.5, 0.45, 1.4)


TRACKS = {"fau": faurianos, "aby": abyssais, "kri": krieg, "wac": wachter, "zuk": zukunft, "lit": lithari, "ter": valakianos}



# =====================================================================
# Músicas de ENTRADA (cerca de 8 s): o exército chegando ao campo
# viradas de tambor + tema da facção + golpe final que segura
# =====================================================================
def _ending_hit(tr, bar, root, chord, brassy=True):
    t = tr.T(bar)
    tr.boom(t, 0.18)
    tr.taiko(t, 0.4, True, 0)
    tr.kick(t, 0.6)
    tr.pad([n - 12 for n in chord] + [root], t, tr.bar * 1.5, 0.08, cut=2500, att=0.02, rev=0.9)
    if brassy:
        for m in chord:
            tr.brass(m, t, tr.bar * 1.2, 0.05)


def _entry_render(tr, dst):
    # sem emenda de loop: a cauda fica no fim
    tr.length = tr.N / SR - 0.01
    return tr.render(dst, 2.5, 0.45, 1.5)


def e_faurianos(dst):
    tr = Track(112, 4, seed=111, tail=4)
    for bar in range(3):
        for b, p, sl in ((0, 1.0, False), (0.75, 1.3, False), (1.5, 1.0, True), (2.0, 0.9, False), (2.75, 1.3, True), (3.5, 1.0, False)):
            tr.conga(tr.T(bar, b), 0.17, p, -0.3 if p > 1 else 0.3, sl)
        tr.kick(tr.T(bar, 0), 0.45)
        for b, o in ((0, 0), (0.75, 12), (1.5, 0), (2.5, 7)):
            tr.bass(tr.T(bar, b), 43 + o, 0.4 * tr.beat, 0.22, cut=700)
    for i in range(8):
        tr.conga(tr.T(2, 2 + i * 0.25), 0.1 + i * 0.015, 1.0 + i * 0.05, 0, i % 2 == 0)
    t = tr.T(0, 1)
    for m, d in [(67, 0.5), (None, 0.25), (67, 0.25), (69, 0.5), (71, 0.5), (74, 1.0), (71, 0.5), (69, 0.5), (67, 0.5), (71, 0.5), (74, 0.5), (79, 2.0)]:
        if m is not None:
            tr.brass(m, t, d * tr.beat * 0.9, 0.08)
            tr.brass(m - 12, t, d * tr.beat * 0.9, 0.04)
        t += d * tr.beat
    _ending_hit(tr, 3, 43, [67, 71, 74])
    return _entry_render(tr, dst)


def e_abyssais(dst):
    tr = Track(100, 4, beats=3.5, seed=222, tail=4)
    for bar in range(3):
        tr.heart(tr.T(bar, 0), 0.32)
        for b, d in ((0, 0.9), (1.0, 0.9), (2.0, 1.4)):
            tr.bass(tr.T(bar, b), 38, d * tr.beat, 0.26, cut=500, dist=0.6)
        tr.sonar(tr.T(bar, 0.5), 0.07, 1200 + 200 * bar)
        tr.bubbles(tr.T(bar), tr.bar, 0.05, 10)
        for i in range(7):
            tr.click(tr.T(bar, i * 0.5), 0.08, tr.rng.uniform(-0.7, 0.7))
    tr.lead([(62, 1.0), (69, 1.0), (70, 0.5), (69, 1.0), (74, 3.5)], tr.T(0, 1), 0.09, "sine", vib=0.025, glide=0.2, cut=2500, rev=0.9)
    tr.riser(tr.T(2), tr.bar, 0.06)
    _ending_hit(tr, 3, 38, [62, 65, 69], brassy=False)
    tr.lead([(74, 3.0)], tr.T(3), 0.06, "sine", vib=0.03, glide=0.3, cut=2000, rev=1.0)
    return _entry_render(tr, dst)


def e_krieg(dst):
    tr = Track(104, 4, seed=333, tail=4)
    for bar in range(3):
        for b, g in ((0, 0.13), (0.5, 0.07), (0.75, 0.06), (1, 0.13), (2, 0.13), (2.5, 0.07), (2.75, 0.06), (3, 0.13)):
            tr.snare(tr.T(bar, b), g, 0.15, tight=22)
        tr.kick(tr.T(bar, 0), 0.55, 40); tr.kick(tr.T(bar, 2), 0.5, 40)
        for i in range(8):
            tr.guitar(40, tr.T(bar, i * 0.5), tr.beat * 0.45, 0.05, palm=(i != 0))
    for i in range(16):
        tr.snare(tr.T(2, i * 0.25), 0.04 + i * 0.008, 0.1, tight=30)
    t = tr.T(0, 0)
    for m, d in [(64, 1.0), (64, 0.5), (67, 0.5), (71, 1.5), (69, 0.5), (67, 1.0), (66, 1.0), (64, 1.0), (67, 1.0), (71, 2.0)]:
        tr.brass(m, t, d * tr.beat * 0.92, 0.08, 2600)
        tr.brass(m - 12, t, d * tr.beat * 0.92, 0.05, 2000)
        t += d * tr.beat
    tr.boom(tr.T(1, 2), 0.12)
    _ending_hit(tr, 3, 40, [64, 67, 71])
    tr.guitar(40, tr.T(3), tr.bar, 0.08)
    return _entry_render(tr, dst)


def e_wachter(dst):
    tr = Track(96, 4, beats=3, seed=444, tail=4)
    for bar in range(3):
        for i in range(6):
            tr.taiko(tr.T(bar, i * 0.5), 0.28 if i in (0, 3) else 0.15, i in (0, 3))
        tr.stone(tr.T(bar, 1.0), 0.2, -0.4); tr.stone(tr.T(bar, 2.5), 0.16, 0.4)
        tr.bass(tr.T(bar, 0), 33, tr.beat * 1.4, 0.26, cut=300)
    t = tr.T(0, 0)
    for m, d in [(57, 1.5), (64, 1.0), (62, 0.5), (60, 1.5), (59, 1.5), (64, 1.5), (69, 1.5)]:
        tr.horn(m, t, d * tr.beat * 0.95, 0.1)
        tr.horn(m - 12, t, d * tr.beat * 0.95, 0.05)
        t += d * tr.beat
    _ending_hit(tr, 3, 45, [57, 60, 64])
    tr.horn(69, tr.T(3), tr.bar * 1.2, 0.1)
    return _entry_render(tr, dst)


def e_zukunft(dst):
    tr = Track(122, 4, seed=555, tail=4)
    ch = [69, 72, 76]
    for bar in range(3):
        for i in range(4):
            tr.kick(tr.T(bar, i), 0.45)
        for i in range(16):
            tr.arp([ch[0], ch[1], ch[2], ch[0] + 12][i % 4] - 12, tr.T(bar, i * 0.25), 0.04, -0.5 if i % 2 else 0.5, cut=1500 + 900 * bar + 60 * i, dec=12, echo=False)
            if bar == 2:
                tr.hat(tr.T(bar, i * 0.25), 0.04 + i * 0.004)
        tr.bass(tr.T(bar, 0), 45, tr.bar * 0.9, 0.2, cut=600)
    tr.glitch(tr.T(1, 3.5), 88, 0.06)
    tr.glitch(tr.T(2, 3.5), 91, 0.07)
    tr.lead([(76, 0.75), (79, 0.75), (81, 0.5), (84, 2.0), (83, 0.5), (81, 0.5), (84, 1.0), (88, 2.0)], tr.T(1, 0), 0.07, "square", vib=0.005, glide=0.03, cut=5000)
    tr.riser(tr.T(2), tr.bar, 0.06)
    _ending_hit(tr, 3, 45, [69, 72, 76], brassy=False)
    tr.lead([(81, 3.0)], tr.T(3), 0.06, "square", cut=4000)
    return _entry_render(tr, dst)


def e_lithari(dst):
    tr = Track(90, 4, seed=666, tail=4)
    ch = [62, 66, 69]
    for bar in range(3):
        for i in range(5):
            tr.glass(tr.T(bar, i * 4 / 5), ch[i % 3] + 24 + (12 if i == 4 else 0), 0.07, -0.6 + 0.3 * i, 4.0)
        for i in range(4):
            tr.bass(tr.T(bar, i), 38, tr.beat * 0.4, 0.18, cut=350)
        tr.grains(tr.T(bar), tr.bar, 74, 0.02 + 0.01 * bar, 40 + 20 * bar)
        tr.click(tr.T(bar, 1.25), 0.1); tr.click(tr.T(bar, 2.75), 0.1)
    tr.lead([(74, 1.0), (75, 0.5), (78, 1.5), (81, 1.0), (82, 0.5), (78, 1.5), (86, 2.0)], tr.T(0, 2), 0.06, "sine", vib=0.0, glide=0.01, cut=6000, rev=0.9)
    tr.riser(tr.T(2), tr.bar, 0.05)
    t = tr.T(3)
    tr.boom(t, 0.15)
    for k, m in enumerate([86, 81, 78, 74, 69]):
        tr.glass(t + k * 0.05, m, 0.08, -0.6 + 0.3 * k, 1.5)
    tr.pad([50, 54, 57, 62], t, tr.bar * 1.5, 0.06, cut=900, att=0.02, det=0.25, rev=1.0)
    return _entry_render(tr, dst)


def e_valakianos(dst):
    tr = Track(88, 4, seed=7777, tail=4)
    for bar in range(3):
        tr.stone(tr.T(bar, 0), 0.09, -0.3); tr.stone(tr.T(bar, 2), 0.07, 0.3)
        tr.anvil(tr.T(bar, 1.5), 0.05, 0.85, 0.4)
        tr.taiko(tr.T(bar, 0), 0.22, True)
        tr.bass(tr.T(bar, 0), 38, tr.beat * 3.4, 0.24, cut=320, dist=0.15)
        tr.glass(tr.T(bar, 1), 74 + 3 * bar, 0.04, -0.4 + 0.4 * bar, 4.0)
    tr.bass(tr.T(1, 0), 26, tr.bar * 2, 0.18, cut=130, dist=0.3)
    tr.cello([(62, 1.5), (65, 0.5), (69, 1.0), (67, 1.0), (65, 2.0), (64, 1.0), (62, 1.0), (62, 4.0)], tr.T(0, 0), 0.12)
    tr.heart(tr.T(2, 2), 0.15)
    _ending_hit(tr, 3, 38, [62, 65, 69])
    tr.cello([(62, 3.5)], tr.T(3), 0.1)
    return _entry_render(tr, dst)


ENTRIES = {"fau": e_faurianos, "aby": e_abyssais, "kri": e_krieg, "wac": e_wachter, "zuk": e_zukunft, "lit": e_lithari, "ter": e_valakianos}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "sounds"
    only = sys.argv[2].split(",") if len(sys.argv) > 2 else list(TRACKS)
    entries = "--entradas" in sys.argv or len(sys.argv) <= 2
    themes = "--entradas" not in sys.argv
    for k in only:
        if themes and k in TRACKS:
            L = TRACKS[k](os.path.join(out, "musica_%s.ogg" % k))
            print(k, "tema ok", round(L, 1), "s")
        if entries and k in ENTRIES:
            L = ENTRIES[k](os.path.join(out, "entrada_%s.ogg" % k))
            print(k, "entrada ok", round(L, 1), "s")
