// Hex Galaxies - sombreado "pintado" para o cenário (tools/cenario.py)
// 3 tons (sombra quente, base, brilho), borda dos tons com pinceladas e luz de contorno.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec3 shadow_tint : source_color = vec3(0.55, 0.42, 0.58);
uniform float shadow_level = 0.58;
uniform float highlight = 0.14;
uniform float brush = 0.18;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2));   // cores do arquivo estão em sRGB
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 1.0;
}

float strokes(vec3 p) {
	return sin(p.x * 9.0 + p.y * 13.0) * sin(p.z * 11.0 - p.y * 6.0 + p.x * 3.0);
}

void light() {
	float nd = dot(NORMAL, LIGHT);
	float b = strokes(wpos) * brush;
	float lit = smoothstep(-0.05, 0.08, nd + b) * ATTENUATION;
	float hi = smoothstep(0.62, 0.7, nd + b * 0.7) * ATTENUATION;
	vec3 shade = mix(shadow_tint * shadow_level, vec3(1.0), lit);
	DIFFUSE_LIGHT += LIGHT_COLOR * (shade + hi * highlight * vec3(1.0, 0.92, 0.7));
}
