// Letreiros de HQ: some dissolvendo numa retícula hexagonal (as células encolhem até sumir)
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float cell = 14.0;      // tamanho da célula em pixels da textura
uniform vec4 tinta : source_color = vec4(1.0);

float hex_dist(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.7320508))), p.x);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = UV / TEXTURE_PIXEL_SIZE / cell;
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(px, r) - h;
	vec2 b = mod(px - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	// as células de baixo somem antes, como tinta escorrendo
	float atraso = (1.0 - UV.y) * 0.25;
	float p = clamp((progress - atraso * progress) * 1.25, 0.0, 1.0);
	float raio = mix(0.62, 0.0, p);
	float dentro = 1.0 - smoothstep(raio - 0.04, raio + 0.02, hex_dist(gv));
	COLOR = c * tinta;
	COLOR.a *= progress <= 0.0 ? 1.0 : dentro;
}
