// Água corrente em cores chapadas: faixas claras que deslizam na direção da correnteza, retícula nas áreas escuras.
shader_type spatial;
#include "res://shaders/hexdots.gdshaderinc"
render_mode unshaded, cull_disabled;

uniform vec2 flow = vec2(0.0, 1.0);          // direção no mundo (x, z)
uniform float speed = 0.9;
uniform vec3 deep : source_color = vec3(0.07, 0.2, 0.55);
uniform vec3 mid : source_color = vec3(0.14, 0.4, 0.88);
uniform vec3 light : source_color = vec3(0.62, 0.86, 1.0);

varying vec3 wp;
float h21w(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 f = normalize(flow);
	vec2 pr = vec2(-f.y, f.x);
	float u = dot(wp.xz, f);
	float v = dot(wp.xz, pr);
	float t = TIME * speed;
	// hexágonos de tamanhos diferentes deslizando com a correnteza
	vec2 q = vec2(u, v);
	vec2 sl = vec2(t * 0.9, 0.0);
	float c1 = h21w(hexid((q - sl) * 0.9));
	float c2 = h21w(hexid((q - sl * 1.6) * 1.9 + 5.0));
	float c3 = h21w(hexid((q - sl * 2.4) * 3.7 + 11.0));
	float w = c1 - 0.5;
	vec3 col = w > 0.0 ? mid : deep;
	col = mix(col, light, step(0.86, c2) * (1.0 - smoothstep(0.3, 0.5, hexd((q - sl * 1.6) * 1.9 + 5.0))) * 0.9);
	col = mix(col, light, step(0.9, c3) * (1.0 - smoothstep(0.25, 0.45, hexd((q - sl * 2.4) * 3.7 + 11.0))));
	// retícula nas áreas escuras
	vec2 p = FRAGCOORD.xy;
	float d = hexd(p / 9.0);
	float dots = (1.0 - smoothstep(0.28, 0.36, d)) * (w > 0.1 ? 0.0 : 1.0);
	col = mix(col, mid, dots * 0.6);
	ALBEDO = col;
}
