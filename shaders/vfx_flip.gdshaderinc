// corpo comum dos efeitos pintados (Forja de VFX): quadro da tira, giro na tela, billboard
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float hframes = 16.0;
uniform float frame = 0.0;
uniform float loop_fps = 0.0;        // > 0: anima sozinho em laço (projétil, gota)
uniform float roll = 0.0;            // giro no plano da tela (rad)
uniform float flip_x = 0.0;
uniform int mode = 0;                // 0 de frente p/ câmera, 1 de pé (eixo Y), 2 deitado no chão
uniform vec4 tint : source_color = vec4(1.0);
uniform float base_lift = 0.0;       // sobe o quad metade da altura (âncora na base)
uniform float fade = 1.0;
varying float vframe;

void vertex() {
	vec3 v = VERTEX;
	v.y += base_lift;
	float c = cos(roll), s = sin(roll);
	if (mode != 2) {
		v.xy = vec2(v.x * c - v.y * s, v.x * s + v.y * c);
	} else {
		v = vec3(v.x * c - v.y * s, 0.0, -(v.x * s + v.y * c));
	}
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v *= sc;
	if (mode == 0) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	} else if (mode == 1) {
		vec3 up = vec3(0.0, 1.0, 0.0);
		vec3 cd = normalize(INV_VIEW_MATRIX[2].xyz * vec3(1.0, 0.0, 1.0) + vec3(0.0001));
		vec3 right = normalize(cross(up, cd));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(cross(right, up), 0.0), MODEL_MATRIX[3]);
	} else {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(1, 0, 0, 0), vec4(0, 1, 0, 0), vec4(0, 0, 1, 0), MODEL_MATRIX[3]);
	}
	VERTEX = v;
	vframe = loop_fps > 0.0 ? mod(floor(TIME * loop_fps + frame), hframes) : floor(frame);
}

void fragment() {
	vec2 uv = UV;
	if (flip_x > 0.5) { uv.x = 1.0 - uv.x; }
	uv.x = (uv.x + vframe) / hframes;
	vec4 t = texture(tex, uv);
	ALBEDO = t.rgb * tint.rgb;
	ALPHA = t.a * tint.a * fade;
}
