// Contorno de tinta de quadrinho para personagens 3D (casca invertida).
// A espessura é medida na tela, então o traço fica igual perto ou longe da câmera.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 ink : source_color = vec4(0.04, 0.016, 0.063, 1.0);
uniform float px = 2.2;          // espessura em pixels
uniform vec4 mod_col : source_color = vec4(1.0);

// cauda: mesmo balanço do hq_personagem (o contorno acompanha a cauda)
uniform float tail_on = 0.0;
uniform vec3 tail_base = vec3(-0.05, 0.45, 0.0);
uniform float tail_amp = 0.35;
uniform float tail_spd = 2.2;
uniform float tail_t = 0.0;

// recorte: some tudo abaixo desta altura do mundo (o Verme saindo da areia sem aparecer por baixo do mapa)
uniform float clip_y = -100000.0;
varying float mundo_y;

vec3 roda(vec3 v, vec3 c, vec3 ax, float a) {
	vec3 p = v - c;
	float cs = cos(a), sn = sin(a);
	return c + p * cs + cross(ax, p) * sn + ax * dot(ax, p) * (1.0 - cs);
}

void vertex() {
	vec3 vx = VERTEX;
	vec3 nr = NORMAL;
	if (tail_on > 0.5 && COLOR.r > 0.001) {
		float w = COLOR.r;
		float tt = tail_t * tail_spd;
		float a1 = sin(tt - w * 2.4) * tail_amp * w;
		float a2 = sin(tt * 0.7 + 1.3 - w * 1.8) * tail_amp * 0.45 * w;
		vx = roda(roda(vx, tail_base, vec3(0.0, 1.0, 0.0), a1), tail_base, vec3(0.0, 0.0, 1.0), a2);
		nr = roda(nr, vec3(0.0), vec3(0.0, 1.0, 0.0), a1);
	}
	mundo_y = (MODEL_MATRIX * vec4(vx, 1.0)).y;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(vx, 1.0);
	vec3 vn = normalize((MODELVIEW_MATRIX * vec4(nr, 0.0)).xyz);
	vec2 off = normalize((PROJECTION_MATRIX * vec4(vn, 0.0)).xy + vec2(1e-5));
	clip.xy += off * px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	if (mundo_y < clip_y) {
		discard;
	}
	ALBEDO = ink.rgb * mod_col.rgb;
}
