"""Ícones da HUD (ui/hud/*.svg) no estilo das referências: selo hexagonal em degradê vivo,
contorno de tinta grosso e o desenho em branco por cima. A cor do selo é a cor da função
(azul movimento, verde cura, laranja alcance, vermelho ataque, prata defesa, roxo habilidade,
dourado ação/entrar). python3 tools/icones_hud.py
"""
import math, os, re
OUT = os.path.join(os.path.dirname(__file__), "..", "ui", "hud")
O = "#120a1e"
W = 'stroke="%s" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"' % O
# nome: (cor clara, cor escura, desenho em 64x64 — sempre em branco)
def star(n, r1, r2, rot=-90):
    p = []
    for i in range(n * 2):
        a = math.radians(rot + 180.0 * i / n)
        r = r1 if i % 2 == 0 else r2
        p.append("%.1f %.1f" % (32 + r * math.cos(a), 32 + r * math.sin(a)))
    return "M " + " L ".join(p) + " Z"
def gear():
    p = []
    for i in range(16):
        a = math.pi * 2 * i / 16
        r = 26 if i % 2 == 0 else 19
        p.append("%.1f %.1f" % (32 + r * math.cos(a), 32 + r * math.sin(a)))
    return "M " + " L ".join(p) + " Z"
I = {
 "vida": ("#7dff8e", "#14a83c", '<path d="M32 54 C10 38 6 26 12 17 C18 9 28 11 32 19 C36 11 46 9 52 17 C58 26 54 38 32 54 Z" fill="#fff" %s/>' % W),
 "ataque": ("#ff6b6b", "#c4102c", '<path d="M46 8 L56 8 L56 18 L28 46 L18 36 Z" fill="#fff" %s/><path d="M14 34 L30 50" %s/><path d="M12 46 L18 52 L10 58 L6 54 Z" fill="#fff" %s/>' % (W, W, W)),
 "movimento": ("#6fb6ff", "#1d4fd8", '<path d="M8 14 L28 32 L8 50 L8 40 L18 32 L8 24 Z" fill="#fff" %s/><path d="M30 14 L50 32 L30 50 L30 40 L40 32 L30 24 Z" fill="#fff" %s/>' % (W, W)),
 "alcance": ("#ffc46b", "#e2620b", '<circle cx="32" cy="32" r="19" fill="none" stroke="%s" stroke-width="12"/><circle cx="32" cy="32" r="19" fill="none" stroke="#fff" stroke-width="5"/><circle cx="32" cy="32" r="6" fill="#fff" %s/><path d="M32 3 L32 15 M32 49 L32 61 M3 32 L15 32 M49 32 L61 32" stroke="%s" stroke-width="10" stroke-linecap="round"/><path d="M32 3 L32 15 M32 49 L32 61 M3 32 L15 32 M49 32 L61 32" stroke="#fff" stroke-width="4" stroke-linecap="round"/>' % (O, W, O)),
 "defesa": ("#eef3ff", "#7d8fb0", '<path d="M32 6 L54 14 L52 34 C50 46 42 54 32 58 C22 54 14 46 12 34 L10 14 Z" fill="#fff" %s/><path d="M32 14 L32 50" stroke="#9fb0cc" stroke-width="4"/>' % W),
 "acao": ("#ffe76a", "#f08a00", '<path d="M36 4 L12 36 L28 36 L24 60 L52 24 L34 24 Z" fill="#fff" %s/>' % W),
 "round": ("#d9ccff", "#6a4cd8", '<path d="M16 6 L48 6 L48 12 L36 30 L36 34 L48 52 L48 58 L16 58 L16 52 L28 34 L28 30 L16 12 Z" fill="#fff" %s/><path d="M22 50 L42 50 L36 42 L28 42 Z" fill="%s"/>' % (W, O)),
 "chuva": ("#a9e4ff", "#2a7ad8", '<path d="M16 34 C6 34 6 20 16 20 C18 10 32 8 36 16 C46 12 56 20 50 30 C50 34 46 34 44 34 Z" fill="#fff" %s/><path d="M20 42 L16 54 M32 42 L28 56 M44 42 L40 54" stroke="%s" stroke-width="9" stroke-linecap="round"/><path d="M20 42 L16 54 M32 42 L28 56 M44 42 L40 54" stroke="#fff" stroke-width="4" stroke-linecap="round"/>' % (W, O)),
 "tempestade": ("#ffd79a", "#b8741e", ''.join('<path d="%s" fill="none" stroke="%s" stroke-width="11" stroke-linecap="round"/><path d="%s" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round"/>' % (d, O, d) for d in ["M8 20 C30 20 46 20 50 14 C54 8 44 4 40 10", "M6 34 L52 34 C60 34 60 46 52 46", "M12 52 L36 52"])),
 "fogo": ("#ffb36b", "#e0300b", '<path d="M32 58 C16 58 10 46 14 34 C18 24 26 22 24 8 C36 14 40 24 38 32 C42 28 44 24 44 20 C54 30 56 44 48 52 C44 56 38 58 32 58 Z" fill="#fff" %s/>' % W),
 "hex": ("#e08bff", "#7a1fd8", '<path d="M32 6 L54 19 L54 45 L32 58 L10 45 L10 19 Z" fill="#fff" %s/><path d="M32 18 L43 24.5 L43 39.5 L32 46 L21 39.5 L21 24.5 Z" fill="#c070ff"/>' % W),
 "vermes": ("#e8b27a", "#8a4c1c", '<path d="M6 44 C14 28 22 28 28 40 C34 52 42 52 48 36 C52 26 58 24 60 28" fill="none" stroke="%s" stroke-width="14" stroke-linecap="round"/><path d="M6 44 C14 28 22 28 28 40 C34 52 42 52 48 36 C52 26 58 24 60 28" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round"/>' % O),
 "dunas": ("#ffd79a", "#b8741e", '<path d="M4 50 C14 30 26 26 36 40 C42 30 52 28 60 40 L60 56 L4 56 Z" fill="#fff" %s/>' % W),
 "cartas": ("#6fb6ff", "#1d4fd8", '<rect x="8" y="14" width="30" height="40" rx="4" fill="#dbe9ff" transform="rotate(-12 23 34)" %s/><rect x="24" y="10" width="30" height="40" rx="4" fill="#fff" transform="rotate(10 39 30)" %s/>' % (W, W)),
 "regras": ("#eef3ff", "#5a6c9c", '<path d="M6 14 C16 10 26 10 32 16 C38 10 48 10 58 14 L58 54 C48 50 38 50 32 56 C26 50 16 50 6 54 Z" fill="#fff" %s/><path d="M32 16 L32 56" %s/>' % (W, W)),
 "opcoes": ("#d9ccff", "#4a3a9c", '<path d="%s" fill="#fff" %s/><circle cx="32" cy="32" r="8" fill="%s"/>' % (gear(), W, O)),
 "passar": ("#ffe76a", "#f08a00", '<path d="M16 8 L52 32 L16 56 Z" fill="#fff" %s/>' % W),
 "estrela": ("#ffb3e6", "#d81f8a", '<path d="%s" fill="#fff" %s/>' % (star(6, 28, 15), W)),
 "habilidade": ("#d29bff", "#6a1fc8", '<path d="%s" fill="#fff" %s/>' % (star(8, 29, 16), W)),
 "escaravelho": ("#7dff8e", "#14a83c", '<ellipse cx="32" cy="36" rx="16" ry="20" fill="#fff" %s/><circle cx="32" cy="14" r="8" fill="#fff" %s/><path d="M32 18 L32 56" stroke="%s" stroke-width="3"/><path d="M16 30 L6 24 M16 42 L6 46 M48 30 L58 24 M48 42 L58 46" stroke="%s" stroke-width="5" stroke-linecap="round"/>' % (W, W, O, O)),
 "reserva": ("#ffe76a", "#f08a00", '<circle cx="32" cy="22" r="12" fill="#fff" %s/><path d="M10 58 C10 40 54 40 54 58 Z" fill="#fff" %s/>' % (W, W)),
 # ---- estados das peças (verde/azul = bom, vermelho/roxo = ruim) ----
 "st_atordoado": ("#ffe76a", "#c46a00", '<path d="%s" fill="#fff" %s/>' % (star(5, 16, 7), W) + '<circle cx="12" cy="14" r="5" fill="#fff" %s/><circle cx="52" cy="50" r="5" fill="#fff" %s/>' % (W, W)),
 "st_preso": ("#c9a0ff", "#5a2aa8", '<rect x="14" y="28" width="36" height="28" rx="5" fill="#fff" %s/><path d="M22 28 L22 20 C22 8 42 8 42 20 L42 28" fill="none" stroke="%s" stroke-width="12"/><path d="M22 28 L22 20 C22 8 42 8 42 20 L42 28" fill="none" stroke="#fff" stroke-width="5"/>' % (W, O)),
 "st_lento": ("#9ad0ff", "#3a5ca8", '<path d="M8 14 L28 32 L8 50 Z" fill="#fff" %s/><path d="M34 26 L56 26 L56 38 L34 38 Z" fill="#fff" %s/>' % (W, W)),
 "st_semcura": ("#ff8a8a", "#a8101c", '<path d="M32 54 C10 38 6 26 12 17 C18 9 28 11 32 19 C36 11 46 9 52 17 C58 26 54 38 32 54 Z" fill="#fff" %s/><path d="M8 8 L56 56" stroke="%s" stroke-width="12" stroke-linecap="round"/><path d="M8 8 L56 56" stroke="#ff3a3a" stroke-width="5" stroke-linecap="round"/>' % (W, O)),
 "st_escudo": ("#8ae6ff", "#1a6ad8", '<path d="M32 6 L54 14 L52 34 C50 46 42 54 32 58 C22 54 14 46 12 34 L10 14 Z" fill="#fff" %s/>' % W),
 "st_atk_mais": ("#7dff8e", "#14a83c", '<path d="M40 8 L50 8 L50 18 L28 40 L20 32 Z" fill="#fff" %s/><path d="M8 50 L22 50 M15 43 L15 57" stroke="%s" stroke-width="11" stroke-linecap="round"/><path d="M8 50 L22 50 M15 43 L15 57" stroke="#fff" stroke-width="5" stroke-linecap="round"/>' % (W, O, )),
 "st_atk_menos": ("#ff8a8a", "#a8101c", '<path d="M40 8 L50 8 L50 18 L28 40 L20 32 Z" fill="#fff" %s/><path d="M8 50 L22 50" stroke="%s" stroke-width="11" stroke-linecap="round"/><path d="M8 50 L22 50" stroke="#fff" stroke-width="5" stroke-linecap="round"/>' % (W, O)),
 "st_mov_mais": ("#7dff8e", "#14a83c", '<path d="M8 14 L28 32 L8 50 L8 40 L18 32 L8 24 Z" fill="#fff" %s/><path d="M36 32 L56 32 M46 22 L46 42" stroke="%s" stroke-width="11" stroke-linecap="round"/><path d="M36 32 L56 32 M46 22 L46 42" stroke="#fff" stroke-width="5" stroke-linecap="round"/>' % (W, O)),
 "st_veneno": ("#b6ff5a", "#4a8a10", '<path d="M32 6 C40 20 50 30 50 40 C50 52 42 58 32 58 C22 58 14 52 14 40 C14 30 24 20 32 6 Z" fill="#fff" %s/>' % W),
 "st_marcado": ("#ff8a8a", "#a8101c", '<circle cx="32" cy="32" r="20" fill="none" stroke="%s" stroke-width="12"/><circle cx="32" cy="32" r="20" fill="none" stroke="#fff" stroke-width="5"/><circle cx="32" cy="32" r="7" fill="#fff" %s/>' % (O, W)),
 "st_silencio": ("#c9a0ff", "#5a2aa8", '<path d="M10 24 L22 24 L36 12 L36 52 L22 40 L10 40 Z" fill="#fff" %s/><path d="M44 24 L56 40 M56 24 L44 40" stroke="%s" stroke-width="11" stroke-linecap="round"/><path d="M44 24 L56 40 M56 24 L44 40" stroke="#fff" stroke-width="5" stroke-linecap="round"/>' % (W, O)),
 "st_golpe": ("#ffe76a", "#c46a00", '<rect x="16" y="22" width="32" height="26" rx="8" fill="#fff" %s/><path d="M20 22 L20 14 M28 22 L28 12 M36 22 L36 12 M44 22 L44 14" stroke="%s" stroke-width="10" stroke-linecap="round"/><path d="M20 22 L20 14 M28 22 L28 12 M36 22 L36 12 M44 22 L44 14" stroke="#fff" stroke-width="4" stroke-linecap="round"/>' % (W, O)),
 "st_furia": ("#ff8a5a", "#c4200c", '<path d="M32 58 C16 58 10 46 14 34 C18 24 26 22 24 8 C36 14 40 24 38 32 C42 28 44 24 44 20 C54 30 56 44 48 52 C44 56 38 58 32 58 Z" fill="#fff" %s/>' % W),
 "st_oculto": ("#d9ccff", "#4a3a8a", '<path d="M4 32 C16 14 48 14 60 32 C48 50 16 50 4 32 Z" fill="#fff" %s/><circle cx="32" cy="32" r="8" fill="%s"/>' % (W, O)),
}
HEX = "M50 4 L93 28 L93 72 L50 96 L7 72 L7 28 Z"   # selo em 100x100
for nome, (c1, c2, corpo) in I.items():
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 100 100">'
           '<defs><linearGradient id="g" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs>'
           '<path d="%s" fill="%s" transform="translate(4 4)"/>'          # sombra dura
           '<path d="%s" fill="url(#g)" stroke="%s" stroke-width="6" stroke-linejoin="round"/>'
           '<path d="M50 10 L86 31 L86 40 L50 19 L14 40 L14 31 Z" fill="#fff" opacity="0.25"/>'   # brilho de cima
           '<g transform="translate(18 18) scale(1)">%s</g></svg>') % (c1, c2, HEX, O, HEX, O, corpo)
    open(os.path.join(OUT, nome + ".svg"), "w").write(svg)
print(len(I), "ícones")
