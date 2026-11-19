// Personagem 3D com cara de quadrinho: a textura do modelo em 2 tons chapados,
// retícula hexagonal na passagem para a sombra, hachura na sombra funda,
// pontinhos claros no brilho e luzes próprias (visor) que acendem e pulsam.
shader_type spatial;
#include "res://shaders/hexdots.gdshaderinc"
render_mode unshaded;   // como a arte 2D: as cores do personagem não mudam com a luz de cada planeta

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 mod_col : source_color = vec4(1.0);        // escurece (já agiu) / avermelha (dano)
uniform vec3 shadow_tint : source_color = vec3(0.34, 0.30, 0.55);
uniform float shadow_level = 0.72;
uniform float dot_px = 6.0;
uniform float sat = 1.18;
uniform float bright = 1.18;                            // a textura do Tripo vem mais escura que a arte                               // cores um pouco mais vivas, como a arte
// visor: os pixels bem vermelhos da textura viram luz
uniform vec3 glow_col : source_color = vec3(1.0, 0.12, 0.08);
uniform float glow_amt = 2.6;
uniform float rim_amt = 0.35;
// luz "de desenho": vem do alto à esquerda, presa à câmera (todo personagem é sombreado do mesmo jeito)
uniform vec3 key_dir = vec3(-0.55, 0.7, 0.45);

void fragment() {
	vec3 c0 = texture(tex, UV).rgb;
	// máscara do visor: vermelho puro (no laranja das faixas o verde passa de ~45% do vermelho e fica de fora)
	float gr = c0.g / max(c0.r, 0.01);
	float br = c0.b / max(c0.r, 0.01);
	float glow_m = smoothstep(0.34, 0.22, gr) * smoothstep(0.45, 0.3, br) * smoothstep(0.35, 0.5, c0.r);
	float l0 = dot(c0, vec3(0.299, 0.587, 0.114));
	vec3 c = clamp(mix(vec3(l0), c0, sat) * bright, 0.0, 1.0);
	vec3 nrm = normalize(NORMAL);
	float nd = dot(nrm, normalize(key_dir));
	float l = smoothstep(-0.25, 0.35, nd);
	vec3 dark = shadow_tint * shadow_level;
	vec2 p = FRAGCOORD.xy;
	// retícula: o ponto hexagonal cresce conforme escurece
	float d = hexd(p / (dot_px * 1.15));
	float need = clamp((0.9 - l) / 0.9, 0.0, 1.0);
	float r = 0.55 * sqrt(need);
	float dotm = 1.0 - smoothstep(r - 0.05, r + 0.05, d);
	vec3 shade = mix(vec3(1.0), dark, dotm * 0.85);
	// sombra funda: escuro chapado com hachura diagonal
	float deep = smoothstep(0.22, 0.0, l);
	shade = mix(shade, dark, deep * 0.8);
	float hatch = step(0.8, fract((p.x - p.y) / 5.5));
	shade *= 1.0 - hatch * deep * 0.35;
	// brilho: pontinhos claros onde a luz bate de frente
	float hi = smoothstep(0.78, 0.95, nd);
	float hd = hexd(p / (dot_px * 0.9) + 0.37);
	float hdot = 1.0 - smoothstep(0.16, 0.22, hd);
	vec3 col = c * shade + vec3(0.3) * hi * hdot;
	// contraluz fininha (separa o boneco do chão)
	float fr = pow(1.0 - clamp(dot(nrm, VIEW), 0.0, 1.0), 3.0);
	col += c * fr * rim_amt;
	float pulse = 0.82 + 0.18 * sin(TIME * 3.2);
	col = mix(col, glow_col * (1.15 + 0.35 * pulse), glow_m);
	ALBEDO = col * mod_col.rgb;
}
