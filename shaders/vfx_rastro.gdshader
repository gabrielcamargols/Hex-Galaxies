// rastro em malha (língua de chama) atrás do projétil: textura rolando ao longo do comprimento,
// some na cauda por erosão; UV.x = 0 na cabeça, 1 na cauda.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, depth_test_disabled;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D ramp : source_color, filter_linear, repeat_disable;
uniform float speed = 2.2;
uniform float boost = 1.3;
uniform float halftone = 0.8;
uniform float dot_px = 6.0;

void fragment() {
	float n = texture(noise, vec2(UV.x * 1.5 - TIME * speed, UV.y)).r;
	float body = (1.0 - UV.x) * (1.0 - pow(abs(UV.y * 2.0 - 1.0), 2.0));
	float v = clamp(body * (0.55 + 0.7 * n), 0.0, 1.0);
	float a = smoothstep(0.12, 0.35, v);
	vec2 g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * (FRAGCOORD.xy / dot_px);
	float d = length(fract(g) - 0.5) * 1.41;
	float dots = 1.0 - smoothstep(sqrt(a) - 0.08, sqrt(a) + 0.08, d);
	a = mix(a, dots * step(0.02, a), halftone * (1.0 - smoothstep(0.6, 0.9, a)));
	ALBEDO = texture(ramp, vec2(v, 0.5)).rgb * boost;
	ALPHA = a;
}
