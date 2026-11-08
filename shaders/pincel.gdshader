// Copa de árvore pintada (guache do Aranhaverso): manchas planas de verdes diferentes, borda esfarelada de pincel,
// luz quente de um lado e sombra fria azul-violeta do outro, retícula fina na sombra.
shader_type spatial;
#include "res://shaders/hexdots.gdshaderinc"
render_mode cull_disabled, specular_disabled;

uniform vec3 c_dark : source_color = vec3(0.17, 0.33, 0.27);
uniform vec3 c_mid : source_color = vec3(0.30, 0.50, 0.25);
uniform vec3 c_light : source_color = vec3(0.55, 0.68, 0.32);
uniform vec3 shadow_tint : source_color = vec3(0.30, 0.34, 0.62);
uniform float seed = 0.0;
uniform float edge = 1.0;     // 0 = borda lisa, 1 = bem esfarelada
uniform float patch_scale = 4.5;
uniform float moss_top = 0.0;   // 1 = faces voltadas pra cima ganham musgo em tufos hexagonais

varying vec3 wp;
varying vec3 lp;
varying vec3 wn;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lp = VERTEX;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// pinceladas em tufos hexagonais: cada célula escolhe um dos três tons, claro no meio e escuro na borda
	vec3 q = lp * patch_scale + seed;
	vec2 uv = vec2(q.x + q.z * 0.6, q.y + q.z * 0.35);
	float cell = h21(hexid(uv));
	float dd = hexd(uv) / 0.5;
	float patch = clamp(cell * 0.85 + (0.55 - dd) * 0.3, 0.0, 1.0);
	vec3 col = patch < 0.36 ? c_dark : (patch < 0.66 ? c_mid : c_light);
	if (moss_top > 0.5 && wn.y > 0.55) {
		vec2 mu = wp.xz * 7.0 + wp.y * 3.0;
		float mc = h21(hexid(mu));
		float md = hexd(mu) / 0.5;
		vec3 mcol = mix(vec3(0.12, 0.32, 0.18), vec3(0.58, 0.78, 0.28), clamp(mc * 0.8 + (0.6 - md) * 0.5, 0.0, 1.0));
		// musgo só em manchas: o resto é pedra nua
		float mp = vnoise(wp.xz * 1.8 + wp.y * 2.0 + seed);
		col = mix(col, mcol, step(0.58, mp));
	}
	ALBEDO = col;
	// borda esfarelada: perto do contorno da silhueta o pincel "falha"
	float rim = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float dab = vnoise(wp.xz * 5.0 + wp.y * 4.0 + seed * 3.0);
	if (dab < rim * 1.05 * edge - 0.42 * edge) {
		discard;
	}
	ROUGHNESS = 1.0;
}

void light() {
	float nd = dot(NORMAL, LIGHT);
	float l = smoothstep(-0.12, 0.55, nd) * mix(1.0, ATTENUATION, 0.9);
	vec3 dark = shadow_tint * 0.62;
	vec2 p = FRAGCOORD.xy;
	float d = hexd(p / 7.0);
	float need = clamp((0.85 - l) / 0.85, 0.0, 1.0);
	float r = 0.52 * sqrt(need);
	vec3 shade = mix(vec3(1.0), dark, 1.0 - smoothstep(r - 0.06, r + 0.06, d));
	float deep = smoothstep(0.38, 0.1, l);
	shade = mix(shade, dark, deep);
	float hatch = step(0.78, fract((p.x - p.y) / 6.0));
	shade *= 1.0 - hatch * deep * 0.38;
	// luz quente só onde está bem iluminado
	vec3 warm = mix(vec3(1.0), vec3(1.12, 1.03, 0.8), smoothstep(0.6, 1.0, l));
	DIFFUSE_LIGHT += LIGHT_COLOR * shade * warm / PI;
}
