// Copa de árvore pintada (guache do Aranhaverso): manchas planas de verdes diferentes, borda esfarelada de pincel,
// luz quente de um lado e sombra fria azul-violeta do outro, retícula fina na sombra.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec3 c_dark : source_color = vec3(0.17, 0.33, 0.27);
uniform vec3 c_mid : source_color = vec3(0.30, 0.50, 0.25);
uniform vec3 c_light : source_color = vec3(0.55, 0.68, 0.32);
uniform vec3 shadow_tint : source_color = vec3(0.30, 0.34, 0.62);
uniform float seed = 0.0;
uniform float edge = 1.0;     // 0 = borda lisa, 1 = bem esfarelada
uniform float patch_scale = 4.5;

varying vec3 wp;
varying vec3 lp;

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
}

void fragment() {
	// pinceladas: três ruídos em escalas diferentes escolhem o verde de cada mancha
	vec3 q = lp * patch_scale + seed;
	float n1 = vnoise(q.xy + q.z * 0.7);
	float n2 = vnoise(q.yz * 1.7 + vec2(seed, 3.1));
	float patch = n1 * 0.6 + n2 * 0.4;
	vec3 col = patch < 0.38 ? c_dark : (patch < 0.62 ? c_mid : c_light);
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
	float lit = smoothstep(-0.05, 0.12, nd) * mix(1.0, ATTENUATION, 0.6);
	// sombra fria (azul-violeta) em vez de só escurecer
	vec3 shade = mix(shadow_tint * 0.62, vec3(1.0), lit);
	// luz quente nas faces viradas pro sol
	vec3 warm = mix(vec3(1.0), vec3(1.14, 1.04, 0.78), smoothstep(0.35, 0.9, nd) * ATTENUATION);
	vec2 p = FRAGCOORD.xy;
	vec2 rp = vec2(p.x + p.y, p.x - p.y) * 0.70710678 / 5.0;
	float d = length(fract(rp) - 0.5);
	float sh = smoothstep(0.05, -0.3, nd);
	float r = 0.38 * sqrt(sh);
	shade *= 1.0 - (1.0 - smoothstep(r - 0.07, r + 0.07, d)) * sh * 0.35;
	DIFFUSE_LIGHT += LIGHT_COLOR * shade * warm / PI;
}
