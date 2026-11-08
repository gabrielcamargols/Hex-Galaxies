// Hex Galaxies - contorno do personagem selecionado: desenha a silhueta da arte dilatada
// na cor da facção, um pouco atrás da figura (billboard igual ao da figura), pulsando.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 col : source_color = vec4(1.0, 0.3, 0.7, 1.0);
uniform float grow = 1.16;        // quanto o quadro cresce para caber o contorno
uniform float px = 0.012;         // espessura do contorno (em UV)
uniform float flip = 0.0;
uniform float center_y = 0.875;   // centro do quadro (metade da altura)
uniform float strength = 1.0;     // 0 = invisível

void vertex() {
	VERTEX.x *= grow;
	VERTEX.y = (VERTEX.y - center_y) * grow + center_y;
	UV = (UV - 0.5) * grow + 0.5;
	mat4 bb = mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	bb = bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	MODELVIEW_MATRIX[3].z -= 0.06;   // logo atrás da figura
}

float a_at(vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
	vec2 u = uv;
	if (flip > 0.5) u.x = 1.0 - u.x;
	return texture(tex, u).a;
}

void fragment() {
	// faixa interna na cor da facção, faixa externa em tinta (contorno de HQ)
	float a1 = 0.0;
	float a2 = 0.0;
	for (int i = 0; i < 16; i++) {
		float ang = 6.2831853 * float(i) / 16.0;
		vec2 d = vec2(cos(ang), sin(ang));
		a1 = max(a1, a_at(UV + d * px));
		a1 = max(a1, a_at(UV + d * px * 0.5));
		a2 = max(a2, a_at(UV + d * px * 1.45));
	}
	if (a2 * strength < 0.5) discard;
	ALBEDO = a1 > 0.5 ? col.rgb : vec3(0.04, 0.0, 0.07);
}
