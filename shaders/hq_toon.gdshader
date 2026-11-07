// Sombreado de quadrinho (leve, sem ler a tela): cor por vértice, 2 tons chapados,
// retícula de pontos na sombra e brilho chapado. Usado no chão, nas casas e nos objetos.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec3 shadow_tint : source_color = vec3(0.42, 0.3, 0.62);
uniform float shadow_level = 0.62;
uniform float dot_px = 6.0;
uniform float dot_amt = 0.45;
uniform float highlight = 0.12;
uniform bool use_vertex = true;
uniform vec4 base : source_color = vec4(1.0);

void fragment() {
	// as cores dos vértices vêm em sRGB (Color("#...")): converte para linear
	ALBEDO = use_vertex ? pow(COLOR.rgb, vec3(2.2)) : base.rgb;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 1.0;
}

void light() {
	float nd = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, 0.06, nd) * ATTENUATION;
	// retícula a 45° em espaço de tela: pontos maiores onde a sombra é mais forte
	vec2 p = FRAGCOORD.xy;
	vec2 rp = vec2(p.x + p.y, p.x - p.y) * 0.70710678 / dot_px;
	float d = length(fract(rp) - 0.5);
	float shade_k = 1.0 - lit;
	float r = 0.42 * sqrt(clamp(shade_k + (1.0 - nd) * 0.25, 0.0, 1.0));
	float dots = (1.0 - smoothstep(r - 0.07, r + 0.07, d)) * shade_k;
	vec3 shade = mix(shadow_tint * shadow_level, vec3(1.0), lit);
	shade *= 1.0 - dots * dot_amt;
	float hi = smoothstep(0.7, 0.76, nd) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * (shade + hi * highlight * vec3(1.0, 0.95, 0.8)) / PI;
}
