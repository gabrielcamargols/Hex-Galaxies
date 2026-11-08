// Sombreado de quadrinho (leve, sem ler a tela): cor por vértice, 2 tons chapados,
// retícula SÓ nas sombras (faces viradas contra o sol) e pontinhos claros SÓ no brilho.
// Os meios-tons ficam limpos.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec3 shadow_tint : source_color = vec3(0.5, 0.4, 0.68);
uniform float shadow_level = 0.7;
uniform float dot_px = 9.0;
uniform float dot_amt = 0.62;     // força da retícula na sombra
uniform float hi_amt = 0.5;       // força dos pontinhos de brilho
uniform float gamma = 1.6;        // cores dos vértices: entre sRGB e linear (vivo sem escurecer)

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(gamma));
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
	vec2 rp = vec2(p.x + p.y, p.x - p.y) * 0.70710678 / dot_px;
	float d = length(fract(rp) - 0.5);
	// sombra de verdade (face contra o sol): pontos escuros
	float sh = smoothstep(0.02, -0.25, nd);
	float r = 0.4 * sqrt(sh);
	shade *= 1.0 - (1.0 - smoothstep(r - 0.07, r + 0.07, d)) * sh * dot_amt;
	// luz forte (face de frente para o sol): pontinhos claros
	float hl = smoothstep(0.5, 0.8, nd) * ATTENUATION;
	float r2 = 0.32 * sqrt(hl);
	float hd = (1.0 - smoothstep(r2 - 0.07, r2 + 0.07, d)) * hl;
	DIFFUSE_LIGHT += LIGHT_COLOR * (shade + hd * hi_amt) / PI;
}
