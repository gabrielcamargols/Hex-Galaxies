// Sombreado de quadrinho (leve, sem ler a tela): cor por vértice, 2 tons chapados,
// retícula SÓ nas sombras (faces viradas contra o sol) e pontinhos claros SÓ no brilho.
// Os meios-tons ficam limpos.
shader_type spatial;
#include "res://shaders/hexdots.gdshaderinc"
render_mode cull_disabled, specular_disabled;

uniform vec3 shadow_tint : source_color = vec3(0.5, 0.4, 0.68);
uniform float shadow_level = 0.55;
uniform float dot_px = 7.0;
uniform float dot_amt = 0.62;     // força da retícula na sombra
uniform float hi_amt = 0.5;       // força dos pontinhos de brilho
uniform float tuft_scale = 2.2;   // tufos por unidade de mundo
uniform float gamma = 1.6;        // cores dos vértices: entre sRGB e linear (vivo sem escurecer)

varying vec3 wpos_t;
varying vec3 wnrm_t;

void vertex() {
	wpos_t = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm_t = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float h21t(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 base = COLOR.rgb;
	// grama/musgo: o chão verde vira tufos hexagonais (um tom por tufo, claro no meio e escuro na borda)
	float greenish = step(1.12, base.g / max(base.r, 0.02)) * step(1.05, base.g / max(base.b, 0.02)) * step(0.6, wnrm_t.y);
	// manchas de hexágonos de vários tamanhos em todo chão virado para cima
	if (wnrm_t.y > 0.6) {
		vec2 g1 = wpos_t.xz * 0.55;
		vec2 g2 = wpos_t.xz * 1.15 + 7.3;
		vec2 g3 = wpos_t.xz * 2.6 + 3.1;
		base *= 0.94 + h21t(hexid(g1)) * 0.12;
		base *= 0.96 + h21t(hexid(g2)) * 0.08;
		base *= 0.97 + h21t(hexid(g3)) * 0.06;
	}
	if (wnrm_t.y > 0.6) {
		// poucos tufos pequenos e espaçados, o resto do chão fica chapado
		vec2 uv = wpos_t.xz * tuft_scale;
		float cell = h21t(hexid(uv));
		float dd = hexd(uv) / 0.5;
		float pick = step(0.86, cell);
		float tuft = pick * (1.0 - smoothstep(0.30, 0.62, dd));
		base *= 1.0 - 0.12 * tuft;
		base += mix(vec3(0.0, 0.0, 0.03), vec3(0.03, 0.05, 0.0), greenish) * tuft * (1.0 - smoothstep(0.0, 0.3, dd));
	}
	ALBEDO = pow(clamp(base, 0.0, 1.0), vec3(gamma));
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 1.0;
}

void light() {
	float nd = dot(NORMAL, LIGHT);
	// quanta luz chega: 1 = claro, 0 = escuro (sombra projetada e faces viradas contra o sol)
	float l = smoothstep(-0.12, 0.55, nd) * mix(1.0, ATTENUATION, 0.9);
	vec3 dark = shadow_tint * shadow_level;
	vec2 p = FRAGCOORD.xy;
	// retícula diagonal: só na passagem entre a luz e a sombra (o ponto cresce conforme escurece)
	float d = hexd(p / (dot_px * 1.15));
	float need = clamp((0.85 - l) / 0.85, 0.0, 1.0);
	float r = 0.52 * sqrt(need);
	float dotm = 1.0 - smoothstep(r - 0.06, r + 0.06, d);
	vec3 shade = mix(vec3(1.0), dark, dotm);
	// sombra funda: tudo escuro, com hachuras (linhas diagonais) para dar detalhe
	float deep = smoothstep(0.38, 0.1, l);
	shade = mix(shade, dark, deep);
	float hatch = step(0.78, fract((p.x - p.y) / 6.5));
	float hatch2 = step(0.84, fract((p.x + p.y) / 6.5)) * smoothstep(0.2, 0.02, l);
	shade *= 1.0 - (hatch * deep * 0.38 + hatch2 * 0.3);
	DIFFUSE_LIGHT += LIGHT_COLOR * shade / PI;
}
