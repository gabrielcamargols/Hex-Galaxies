// Filtro de quadrinho (HQ) aplicado sobre o 3D: cores vivas, sombras em faixas,
// retícula de pontos nas áreas escuras, contorno de tinta e um leve desalinho de cor (impressão).
shader_type canvas_item;

uniform sampler2D scr : hint_screen_texture, filter_linear;
uniform float sat = 1.3;          // saturação
uniform float contrast = 1.06;
uniform float bands = 5.0;        // faixas de luz (sombreado de desenho)
uniform float band_mix = 0.25;
uniform float dot_px = 6.0;       // tamanho da célula da retícula (pixels)
uniform float dot_amt = 0.55;     // quanto os pontos escurecem
uniform float ink = 1.0;          // força do contorno
uniform float ink_lo = 0.32;
uniform float ink_hi = 0.6;
uniform vec3 ink_col : source_color = vec3(0.06, 0.0, 0.12);
uniform float misprint = 1.4;     // desalinho de cor (pixels) nas bordas da tela

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 grab(vec2 uv) {
	return texture(scr, uv, 0.0).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	// desalinho de impressão: vermelho e azul levemente deslocados, mais forte nas bordas
	vec2 off = (uv - 0.5) * px * misprint * 2.0;
	vec3 c = vec3(texture(scr, uv + off, 0.0).r, grab(uv).g, texture(scr, uv - off, 0.0).b);

	// contorno: Sobel na luminância
	float s = 1.5;
	float tl = lum(grab(uv + px * vec2(-s, -s)));
	float tc = lum(grab(uv + px * vec2(0.0, -s)));
	float tr = lum(grab(uv + px * vec2(s, -s)));
	float ml = lum(grab(uv + px * vec2(-s, 0.0)));
	float mr = lum(grab(uv + px * vec2(s, 0.0)));
	float bl = lum(grab(uv + px * vec2(-s, s)));
	float bc = lum(grab(uv + px * vec2(0.0, s)));
	float br = lum(grab(uv + px * vec2(s, s)));
	float gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
	float gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;
	float edge = smoothstep(ink_lo, ink_hi, sqrt(gx * gx + gy * gy)) * ink;

	// cores vivas
	float l = lum(c);
	c = mix(vec3(l), c, sat);
	c = (c - 0.5) * contrast + 0.5;
	c = clamp(c, 0.0, 1.0);
	// sombreado em faixas (cel)
	vec3 q = floor(c * bands + 0.5) / bands;
	c = mix(c, q, band_mix);

	// retícula: pontos a 45° que crescem nas sombras
	vec2 p = FRAGCOORD.xy;
	vec2 rp = vec2(p.x + p.y, p.x - p.y) * 0.70710678 / dot_px;
	vec2 cell = fract(rp) - 0.5;
	float d = length(cell);
	float dark = 1.0 - smoothstep(0.12, 0.6, l);
	float r = 0.5 * sqrt(dark);
	float dotm = 1.0 - smoothstep(r - 0.08, r + 0.08, d);
	c *= 1.0 - dotm * dot_amt * dark;
	// brilho: pontinhos claros nas áreas muito iluminadas
	float lit = smoothstep(0.78, 0.95, l);
	float r2 = 0.22 * lit;
	float dot2 = 1.0 - smoothstep(r2 - 0.08, r2 + 0.08, d);
	c = mix(c, vec3(1.0), dot2 * 0.35);

	c = mix(c, ink_col, edge);
	COLOR = vec4(c, 1.0);
}
