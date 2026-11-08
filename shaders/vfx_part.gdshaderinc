// partículas da Forja (estilo Hits & Impacts): rampa de cor pela intensidade, erosão pela idade,
// borda em retícula de HQ. INSTANCE_CUSTOM.x = giro, .y = idade (0..1) — vindos do CPUParticles3D.
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D ramp : source_color, filter_linear, repeat_disable;   // cor por intensidade (0 borda .. 1 miolo)
uniform int mode = 0;            // 0 de frente, 1 esticada na velocidade, 2 deitada (chão)
uniform float boost = 1.0;       // > 1 estoura para o branco (brilho)
uniform float erode = 0.0;       // 0 sem erosão .. 1 some tudo no fim da vida
uniform float erode_pow = 1.5;
uniform float soft = 0.12;
uniform float cut = 0.0;          // intensidade mínima (evita o quadrado das mipmaps em chão visto de lado)
uniform float halftone = 0.0;    // 0 liso .. 1 borda vira pontos de retícula
uniform float dot_px = 7.0;
uniform float stretch = 1.0;     // modo 1: alonga no sentido da velocidade
varying float age;
varying vec4 pcol;

void vertex() {
	age = INSTANCE_CUSTOM.y;
	pcol = COLOR;
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	if (mode == 0) {
		float c = cos(INSTANCE_CUSTOM.x), s = sin(INSTANCE_CUSTOM.x);
		VERTEX.xy = vec2(VERTEX.x * c - VERTEX.y * s, VERTEX.x * s + VERTEX.y * c);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc.x, INV_VIEW_MATRIX[1] * sc.x, INV_VIEW_MATRIX[2] * sc.x, MODEL_MATRIX[3]);
	} else if (mode == 1) {
		vec3 y = normalize(MODEL_MATRIX[1].xyz);
		vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz);
		vec3 x = normalize(cross(y, to_cam));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(x * sc.x, 0.0), vec4(y * sc.y * stretch, 0.0), vec4(cross(x, y) * sc.z, 0.0), MODEL_MATRIX[3]);
	}
}

void fragment() {
	float v = texture(tex, UV).r;
	float thr = max(pow(age, erode_pow) * erode, cut);
	float a = smoothstep(thr, thr + soft, v);
	if (halftone > 0.0) {
		vec2 g = FRAGCOORD.xy / dot_px;
		g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * g;
		float d = length(fract(g) - 0.5) * 1.41;
		float dots = 1.0 - smoothstep(sqrt(a) - 0.08, sqrt(a) + 0.08, d);
		a = mix(a, dots * step(0.02, a), halftone * (1.0 - smoothstep(0.75, 0.95, a)));
	}
	vec3 c = texture(ramp, vec2(clamp(v * (1.0 - thr * 0.5), 0.0, 1.0), 0.5)).rgb;
	ALBEDO = c * pcol.rgb * boost;
	ALPHA = clamp(a * pcol.a, 0.0, 1.0);
}
