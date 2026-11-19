// Contorno de tinta de quadrinho para personagens 3D (casca invertida).
// A espessura é medida na tela, então o traço fica igual perto ou longe da câmera.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 ink : source_color = vec4(0.04, 0.016, 0.063, 1.0);
uniform float px = 2.2;          // espessura em pixels
uniform vec4 mod_col : source_color = vec4(1.0);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 vn = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 off = normalize((PROJECTION_MATRIX * vec4(vn, 0.0)).xy + vec2(1e-5));
	clip.xy += off * px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink.rgb * mod_col.rgb;
}
