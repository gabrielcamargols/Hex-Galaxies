// Personagem 3D com cara de quadrinho: a textura do modelo em 2 tons chapados,
// sombra, padrão de tinta, brilho e contraluz nas cores da facção (data/vfx_paletas.json,
// Manual de VFX e Sombras) e luzes próprias (visor, rachaduras) que acendem e pulsam.
// Padrão de tinta por facção (pat): 0 retícula hexagonal (Abyssais) · 1 hachura (Krieg)
// 2 pixel (Zukunft) · 3 entalhe (Wächter) · 4 poeira (Valakianos) · 5 facetas (Lithari) · 6 pop (Faurianos)
shader_type spatial;
#include "res://shaders/hexdots.gdshaderinc"
render_mode unshaded;   // como a arte 2D: as cores do personagem não mudam com a luz de cada planeta

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 mod_col : source_color = vec4(1.0);        // escurece (já agiu) / avermelha (dano)
uniform vec3 shadow_tint : source_color = vec3(0.34, 0.30, 0.55);   // cor de sombra da facção
uniform vec3 hi_col : source_color = vec3(1.0, 0.9, 0.7);           // cor de brilho da facção
uniform int pat = 0;
uniform float shadow_level = 0.72;
uniform float dot_px = 6.0;
uniform float sat = 1.18;
uniform float bright = 1.18;                            // a textura do Tripo vem mais escura que a arte                               // cores um pouco mais vivas, como a arte
// visor: os pixels bem vermelhos da textura viram luz
uniform vec3 glow_col : source_color = vec3(1.0, 0.06, 0.04);
uniform float glow_amt = 2.6;
uniform float glow_mode = 0.0;   // 0 = vermelho puro (visor) | 1 = laranja vivo (rachaduras de magma)
uniform float cintila = 0.0;      // 1 = partes de cristal roxo cintilam (Rei da Mina)
uniform float glow_on = 1.0;                            // 0 = personagem sem visor/olhos acesos
uniform float rim_amt = 0.35;
// luz "de desenho": vem do alto à esquerda, presa à câmera (todo personagem é sombreado do mesmo jeito)
uniform vec3 key_dir = vec3(-0.55, 0.7, 0.45);

// cauda que balança: o peso vem na cor do vértice (COLOR.r: 0 na base, 1 na ponta),
// gravado no .glb por tools/glb_peso_cauda.py; quem não tem cauda fica com tail_on = 0
uniform float tail_on = 0.0;
uniform vec3 tail_base = vec3(-0.05, 0.45, 0.0);
uniform float tail_amp = 0.35;       // abertura do balanço (radianos na ponta)
uniform float tail_spd = 2.2;        // velocidade
uniform float tail_t = 0.0;          // relógio do personagem (cada um balança no seu tempo)

vec3 roda(vec3 v, vec3 c, vec3 ax, float a) {
	vec3 p = v - c;
	float cs = cos(a), sn = sin(a);
	return c + p * cs + cross(ax, p) * sn + ax * dot(ax, p) * (1.0 - cs);
}

void vertex() {
	if (tail_on > 0.5) {
		float w = COLOR.r;
		if (w > 0.001) {
			float tt = tail_t * tail_spd;
			// onda que corre da base para a ponta: a ponta atrasa e enrola
			float a1 = sin(tt - w * 2.4) * tail_amp * w;
			float a2 = sin(tt * 0.7 + 1.3 - w * 1.8) * tail_amp * 0.45 * w;
			vec3 v = roda(VERTEX, tail_base, vec3(0.0, 1.0, 0.0), a1);
			v = roda(v, tail_base, vec3(0.0, 0.0, 1.0), a2);
			NORMAL = normalize(roda(NORMAL, vec3(0.0), vec3(0.0, 1.0, 0.0), a1));
			VERTEX = v;
		}
	}
}

float h21(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}

// quanto de tinta cai neste pixel (0..1) para um tom que pede "need" de sombra (0 claro .. 1 escuro)
float padrao(vec2 p, float need) {
	float s = dot_px;
	if (pat == 1) {
		// hachura: traços diagonais que engrossam; no escuro cruzam
		float a = fract((p.x - p.y) / (s * 0.9));
		float t1 = step(1.0 - need * 0.55, a);
		float b = fract((p.x + p.y) / (s * 0.9));
		float t2 = step(1.0 - max(need - 0.55, 0.0) * 1.1, b);
		return max(t1, t2);
	} else if (pat == 2) {
		// pixel: quadradinhos numa grade, crescem com a sombra
		vec2 g = abs(fract(p / s) - 0.5);
		float r = 0.5 * sqrt(need);
		return step(max(g.x, g.y), r);
	} else if (pat == 3) {
		// entalhe: riscos curtos horizontais, como talho em madeira
		float row = floor(p.y / (s * 0.8));
		float lx = fract(p.x / (s * 2.2) + h21(vec2(row, 1.0)));
		float ly = fract(p.y / (s * 0.8));
		return step(ly, 0.18 + need * 0.3) * step(lx, 0.25 + need * 0.6);
	} else if (pat == 4) {
		// poeira: grãos soltos que se juntam no escuro
		vec2 cl = floor(p / (s * 0.45));
		return step(h21(cl), need * 0.75);
	} else if (pat == 5) {
		// facetas: lascas triangulares chapadas
		vec2 q = p / (s * 2.4);
		vec2 cl = floor(vec2(q.x + q.y * 0.5, q.y));
		float tri = step(fract(q.x + q.y * 0.5), fract(q.y));
		return step(h21(cl * 2.0 + tri), need * 0.95);
	} else if (pat == 6) {
		// pop: pontos redondos grandes (Ben-Day)
		vec2 q = p / (s * 1.5);
		vec2 g = fract(vec2(q.x + floor(q.y) * 0.5, q.y)) - 0.5;
		float r = 0.55 * sqrt(need);
		return 1.0 - smoothstep(r - 0.06, r + 0.06, length(g));
	}
	// retícula hexagonal
	float d = hexd(p / (s * 1.15));
	float r = 0.55 * sqrt(need);
	return 1.0 - smoothstep(r - 0.05, r + 0.05, d);
}

void fragment() {
	vec3 c0 = texture(tex, UV).rgb;
	// máscara do visor: vermelho puro (no laranja das faixas o verde passa de ~45% do vermelho e fica de fora)
	float gr = c0.g / max(c0.r, 0.01);
	float br = c0.b / max(c0.r, 0.01);
	float glow_m = smoothstep(0.4, 0.24, gr) * smoothstep(0.5, 0.32, br) * smoothstep(0.35, 0.5, c0.r);
	if (glow_mode > 1.5) {
		// ciano vivo (gemas e olhos Zukunft): azul e verde altos, vermelho baixo
		glow_m = smoothstep(0.55, 0.3, c0.r / max(c0.b, 0.01)) * smoothstep(0.65, 0.8, c0.g / max(c0.b, 0.01)) * smoothstep(0.65, 0.85, c0.b);
	} else if (glow_mode > 0.5) {
		// laranja vivo e claro (rachaduras); o dourado tem verde demais e fica de fora
		glow_m = smoothstep(0.62, 0.48, gr) * smoothstep(0.24, 0.42, gr) * smoothstep(0.35, 0.2, br) * smoothstep(0.62, 0.8, c0.r);
	}
	float l0 = dot(c0, vec3(0.299, 0.587, 0.114));
	vec3 c = clamp(mix(vec3(l0), c0, sat) * bright, 0.0, 1.0);
	vec3 nrm = normalize(NORMAL);
	float nd = dot(nrm, normalize(key_dir));
	float l = smoothstep(-0.25, 0.35, nd);
	// sombra na cor da facção: o tom é normalizado para escurecer sempre do mesmo tanto
	float sl = max(dot(shadow_tint, vec3(0.299, 0.587, 0.114)), 0.02);
	vec3 dark = clamp(shadow_tint / sl * 0.42, 0.0, 1.0) * shadow_level;
	vec2 p = FRAGCOORD.xy;
	float need = clamp((0.9 - l) / 0.9, 0.0, 1.0);
	float dotm = padrao(p, need);
	vec3 shade = mix(vec3(1.0), dark, dotm * 0.85);
	// sombra funda: chapada na cor de sombra, com o padrão mais denso por cima
	float deep = smoothstep(0.22, 0.0, l);
	shade = mix(shade, dark, deep * 0.8);
	shade *= 1.0 - padrao(p + 2.5, 1.0) * deep * 0.3;
	// brilho: o mesmo padrão, pequeno e claro, na cor de brilho da facção
	float hi = smoothstep(0.78, 0.95, nd);
	float hdot = padrao(p + vec2(3.1, 1.7), 0.22);
	vec3 col = c * shade + hi_col * 0.32 * hi * hdot;
	// contraluz fininha na cor de brilho (separa o boneco do chão)
	float fr = pow(1.0 - clamp(dot(nrm, VIEW), 0.0, 1.0), 3.0);
	col += mix(c, hi_col, 0.5) * fr * rim_amt;
	float pulse = 0.82 + 0.18 * sin(TIME * 3.2);
	// visor aceso: vermelho de luz (passa do 1.0) com miolo quente quase branco
	vec3 hot = glow_col * (2.0 + 0.6 * pulse) + vec3(1.0, 0.55, 0.45) * pow(glow_m, 4.0) * 0.22 * pulse;
	col = mix(col, hot, glow_m * glow_on);
	if (cintila > 0.5) {
		// cristal roxo: azul e vermelho bem acima do verde
		float cm = smoothstep(1.25, 1.6, c0.b / max(c0.g, 0.02)) * smoothstep(1.05, 1.3, c0.r / max(c0.g, 0.02)) * smoothstep(0.45, 0.6, c0.b);
		// brilho que corre devagar pelas facetas + estrelinhas que piscam em pontos soltos
		float onda = 0.5 + 0.5 * sin(TIME * 1.7 + dot(UV, vec2(31.0, 23.0)));
		vec2 cel = floor(UV * 90.0);
		float hs = h21(cel);
		float pisca = pow(max(0.0, sin(TIME * (1.5 + hs * 2.5) + hs * 40.0)), 24.0) * step(0.86, h21(cel + 7.1));
		vec3 lav = vec3(0.93, 0.78, 1.0);
		col += cm * (vec3(0.35, 0.12, 0.45) * onda * 0.5 + lav * pisca * 1.6);
	}
	ALBEDO = col * mod_col.rgb;
}
