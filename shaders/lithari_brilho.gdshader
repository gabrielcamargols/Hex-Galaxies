// Hex Galaxies - Lithari são cristais vivos: camada de luz somada por cima da arte 2D
// (mesmo billboard da figura, logo à frente). Reflexo que varre o corpo, facetas que
// piscam, luz de dentro que respira e estrelinhas pelo corpo todo. Só onde há arte.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float flip = 0.0;
uniform vec3 hi_col : source_color = vec3(0.85, 0.95, 1.0);
uniform vec4 mod_col : source_color = vec4(1.0);
uniform float fase = 0.0;          // cada figura brilha no seu tempo

void vertex() {
	mat4 bb = mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	bb = bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	MODELVIEW_MATRIX[3].z += 0.01;   // logo à frente da figura
}

float h21(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 u = UV;
	if (flip > 0.5) u.x = 1.0 - u.x;
	vec4 t = texture(tex, u);
	float a = step(0.5, t.a);
	vec3 c = t.rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float tm = TIME + fase;
	// contorno preto da arte não brilha; o cristal claro brilha mais
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	float cris = smoothstep(0.12, 0.4, l) * a * mix(0.25, 1.0, smoothstep(0.08, 0.25, sat));   // pedra cinza brilha pouco
	// faixa de reflexo diagonal que sobe pelo corpo
	float f = fract(UV.y * 0.9 - UV.x * 0.5 + tm * 0.28);
	float faixa = smoothstep(0.0, 0.05, f) * smoothstep(0.12, 0.05, f);
	vec3 col = mix(c, vec3(1.0), 0.55) * faixa * 0.7;
	// facetas: retalhos da arte que acendem e apagam como faces virando para a luz
	vec2 q = UV * vec2(14.0, 22.0);
	vec2 fc = floor(vec2(q.x + q.y * 0.5, q.y));
	float tri = step(fract(q.x + q.y * 0.5), fract(q.y));
	float hf = h21(fc * 2.0 + tri);
	float vira = pow(max(0.0, sin(tm * (0.7 + hf * 1.2) + hf * 30.0)), 10.0);
	col += mix(c, hi_col, 0.5) * vira * 0.6;
	// luz de dentro que respira
	col += c * smoothstep(0.35, 0.9, l) * (0.12 + 0.1 * sin(tm * 1.8 + UV.y * 8.0));
	// estrelinhas
	vec2 cel = floor(UV * vec2(48.0, 80.0));
	float hs = h21(cel);
	float pisca = pow(max(0.0, sin(tm * (1.3 + hs * 3.0) + hs * 60.0)), 28.0) * step(0.82, h21(cel + 5.3));
	vec2 dc = fract(UV * vec2(48.0, 80.0)) - 0.5;
	float estrela = max(smoothstep(0.08, 0.0, abs(dc.x)) * smoothstep(0.5, 0.0, abs(dc.y)), smoothstep(0.08, 0.0, abs(dc.y)) * smoothstep(0.5, 0.0, abs(dc.x)));
	col += vec3(1.0, 0.98, 1.0) * pisca * (0.6 + estrela * 1.6);
	ALBEDO = col * cris * mod_col.rgb;
}
