// Musgo em camadas (shell texturing, como a grama do tutorial): cada camada empurra a malha para fora
// e só mantém os tufos hexagonais cuja altura chega até ela. Base escura, ponta clara e quente.
shader_type spatial;
#include "res://shaders/hexdots.gdshaderinc"
render_mode cull_disabled, specular_disabled;

uniform float layer = 0.0;        // 0 = base, 1 = ponta dos tufos
uniform float height = 0.07;      // altura total do musgo (metros)
uniform float tuft = 7.0;         // tufos por unidade de comprimento
uniform vec3 c_base : source_color = vec3(0.10, 0.28, 0.16);
uniform vec3 c_tip : source_color = vec3(0.62, 0.80, 0.28);
uniform vec3 shadow_tint : source_color = vec3(0.30, 0.34, 0.62);

varying vec3 wp;
varying vec3 nrm;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	VERTEX += NORMAL * layer * height;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nrm = NORMAL;
}

void fragment() {
	// o tufo é uma célula hexagonal; a altura varia de tufo para tufo e afina para a borda dele
	vec2 uv = wp.xz * tuft + wp.y * tuft * 0.55;
	vec2 id = hexid(uv);
	float hgt = 0.45 + 0.55 * h21(id);
	float d = hexd(uv) / 0.5;               // 0 no centro, 1 na borda
	float reach = hgt * (1.0 - d * 0.75);
	if (layer > 0.01 && layer > reach) {
		discard;
	}
	vec3 col = mix(c_base, c_tip, layer);
	// tufos mais claros e outros mais escuros, em manchas
	col = mix(col, col * vec3(1.12, 1.08, 0.7), step(0.7, h21(id + 7.0)) * layer);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}

void light() {
	float nd = dot(NORMAL, LIGHT);
	float l = smoothstep(-0.12, 0.55, nd) * mix(1.0, ATTENUATION, 0.9);
	vec3 shade = mix(shadow_tint * 0.7, vec3(1.0), l);
	DIFFUSE_LIGHT += LIGHT_COLOR * shade / PI;
}
