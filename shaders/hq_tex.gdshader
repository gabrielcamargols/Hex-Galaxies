// Hex Galaxies - o mesmo sombreado de quadrinho do resto do jogo, para modelos com textura própria
// (fóssil, flor do deserto e outros modelos novos): a cor vem da textura, achatada em 3 tons,
// com retícula só na sombra e pontinhos claros no brilho. O contorno preto vem do material de contorno.
shader_type spatial;
#include "res://shaders/hexdots.gdshaderinc"
render_mode cull_disabled, specular_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 shadow_tint : source_color = vec3(0.5, 0.4, 0.68);
uniform float shadow_level = 0.66;
uniform float posterize = 6.0;    // achata a textura em poucas cores (cara de pintura)
uniform float sat = 1.18;
uniform float dot_px = 7.0;
uniform float dot_amt = 0.32;
uniform float hi_amt = 0.2;

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sat);
	c = floor(c * posterize + 0.5) / posterize;
	ALBEDO = c;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 1.0;
}

void light() {
	float nd = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, 0.06, nd) * mix(1.0, ATTENUATION, 0.6);
	vec3 shade = mix(shadow_tint * shadow_level, vec3(1.0), lit);
	vec2 p = FRAGCOORD.xy;
	float d = hexd(p / (dot_px * 1.15));
	float sh = smoothstep(0.02, -0.25, nd);
	float r = 0.4 * sqrt(sh);
	shade *= 1.0 - (1.0 - smoothstep(r - 0.07, r + 0.07, d)) * sh * dot_amt;
	float hl = smoothstep(0.78, 0.92, nd) * ATTENUATION;
	float r2 = 0.24 * sqrt(hl);
	float hd = (1.0 - smoothstep(r2 - 0.07, r2 + 0.07, d)) * hl;
	DIFFUSE_LIGHT += LIGHT_COLOR * (shade + hd * hi_amt) / PI;
}
