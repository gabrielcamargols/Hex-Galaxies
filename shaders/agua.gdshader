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

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 f = normalize(flow);
	vec2 pr = vec2(-f.y, f.x);
	float u = dot(wp.xz, f);
	float v = dot(wp.xz, pr);
	float t = TIME * speed;
	// ondas lentas de duas cores chapadas
	float w = sin(u * 2.2 - t * 2.0 + sin(v * 2.6) * 1.1);
	vec3 col = w > 0.1 ? mid : deep;
	// faixas claras correndo
	float s = sin(u * 5.0 - t * 5.5 + sin(v * 3.4 + t * 0.4) * 1.6);
	float streak = step(0.9, s) * step(0.15, fract(v * 1.3 + floor((u * 5.0 - t * 5.5) / 6.2831) * 0.37));
	col = mix(col, light, streak);
	// retícula nas áreas escuras
	vec2 p = FRAGCOORD.xy;
	float d = hexd(p / 9.0);
	float dots = (1.0 - smoothstep(0.28, 0.36, d)) * (w > 0.1 ? 0.0 : 1.0);
	col = mix(col, mid, dots * 0.6);
	ALBEDO = col;
}
