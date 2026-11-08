// Contorno de tinta (casco invertido): traço de espessura constante na tela, irregular como feito à mão.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform float gamma = 2.2;
varying vec3 base;
uniform float width_px = 2.4;

void vertex() {
	base = pow(COLOR.rgb, vec3(gamma));
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wob = 0.7 + 0.6 * (0.5 + 0.5 * sin(wp.x * 5.3 + wp.z * 3.7 + wp.y * 4.1));
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = (PROJECTION_MATRIX * vec4(nv, 0.0)).xy;
	dir = length(dir) > 0.0001 ? normalize(dir) : vec2(0.0);
	POSITION = clip;
	POSITION.xy += dir * (width_px * wob * 2.0 / VIEWPORT_SIZE) * clip.w;
}

void fragment() {
	float l = dot(base, vec3(0.299, 0.587, 0.114));
	// mesmo tom do objeto, mais escuro e mais saturado
	vec3 c = mix(vec3(l), base, 1.35) * 0.32;
	ALBEDO = clamp(c, 0.0, 1.0);
}
