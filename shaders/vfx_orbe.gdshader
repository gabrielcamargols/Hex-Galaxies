// esfera do projétil (aula de projétil estilizado): ruído celular rolando + borda brilhante (fresnel),
// cor pela rampa; a borda de fora se desfaz em retícula.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, depth_test_disabled;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D ramp : source_color, filter_linear, repeat_disable;
uniform vec2 speed = vec2(0.9, -1.6);
uniform float boost = 1.3;
uniform float rim_pow = 2.2;
uniform float dot_px = 6.0;

void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_pow);
	float n = texture(noise, UV * vec2(2.0, 1.0) + TIME * speed).r;
	float n2 = texture(noise, UV * vec2(3.0, 1.5) - TIME * speed * 0.6).r;
	float v = clamp(n * 0.55 + n2 * 0.35 + fr * 0.9, 0.0, 1.0);
	ALBEDO = texture(ramp, vec2(v, 0.5)).rgb * boost;
	vec2 g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * (FRAGCOORD.xy / dot_px);
	float d = length(fract(g) - 0.5) * 1.41;
	float edge = 1.0 - smoothstep(0.55, 0.95, fr);
	ALPHA = mix(1.0 - smoothstep(0.3, 0.6, d), 1.0, edge);
}
