#include "res://shaders/hexdots.gdshaderinc"
// corrente/feixe entre dois pontos: o nó tem o eixo X = vetor do início ao fim (comprimento real);
// a largura vira de frente para a câmera em volta desse eixo. UV.x repete a textura a cada "tile" metros.
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ramp : source_color, filter_linear, repeat_disable;
uniform float width = 0.35;
uniform float tile = 0.6;
uniform float scroll = 0.0;
uniform float boost = 1.0;
uniform float halftone = 0.0;
uniform float dot_px = 6.0;
uniform float fade = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
varying float len;

void vertex() {
	vec3 axis = MODEL_MATRIX[0].xyz;
	len = length(axis);
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 mid = o + axis * 0.5;
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - mid);
	vec3 side = normalize(cross(normalize(axis), to_cam));
	float u = VERTEX.x + 0.5;            // QuadMesh 1x1 centrado: x de -0.5 a 0.5
	vec3 w = o + axis * u + side * VERTEX.y * width;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	UV = vec2(u * len / tile + scroll, UV.y);
}

void fragment() {
	float v = texture(tex, UV).r;
	float a = v;
	if (halftone > 0.0) {
		vec2 g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * (FRAGCOORD.xy / dot_px);
		float d = hexd(g) * 2.0;
		float dots = 1.0 - smoothstep(sqrt(a) - 0.08, sqrt(a) + 0.08, d);
		a = mix(a, dots * step(0.02, a), halftone * (1.0 - smoothstep(0.7, 0.95, a)));
	}
	ALBEDO = texture(ramp, vec2(v, 0.5)).rgb * tint.rgb * boost;
	ALPHA = clamp(a * fade * tint.a, 0.0, 1.0);
}
