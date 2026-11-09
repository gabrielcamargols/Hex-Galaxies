// Desalinho de cor RGB (impressão fora de registro, como no Aranhaverso): só 3 leituras, sem contorno nem faixas.
shader_type canvas_item;

uniform sampler2D scr : hint_screen_texture, filter_linear;
uniform float shift = 4.5;   // pixels de separação no centro; cresce para as bordas

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float e = 0.65 + length(c) * 1.7;
	// nas sombras o desalinho cresce: o escuro "treme" em vermelho e ciano
	vec3 base = texture(scr, uv, 0.0).rgb;
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	float sh = 1.0 - smoothstep(0.12, 0.62, lum);
	vec2 o = normalize(c + vec2(0.0001, 0.0001)) * SCREEN_PIXEL_SIZE * shift * e * (1.0 + 1.9 * sh);
	float r = texture(scr, uv + o, 0.0).r;
	float g = texture(scr, uv, 0.0).g;
	float b = texture(scr, uv - o, 0.0).b;
	COLOR = vec4(r, g, b, 1.0);
}
