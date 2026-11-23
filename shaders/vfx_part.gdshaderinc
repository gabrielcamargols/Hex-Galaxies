#include "res://shaders/hexdots.gdshaderinc"
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
uniform int forma = 0;            // 0 textura PNG; formas desenhadas no shader: 1 ponto, 2 faísca, 3 fumaça, 4 lasca, 5 gota
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
varying float age;
varying float giro_v;
varying vec4 pcol;

void vertex() {
	age = INSTANCE_CUSTOM.y;
	giro_v = INSTANCE_CUSTOM.x;
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

float forma_v(vec2 uv) {
	vec2 p = uv * 2.0 - 1.0;
	if (forma == 1) {                    // ponto: disco macio
		return clamp(1.0 - length(p), 0.0, 1.0) * 1.4;
	} else if (forma == 2) {             // faísca: losango comprido (esticado na velocidade)
		return clamp(1.0 - (abs(p.x) * 2.6 + abs(p.y)), 0.0, 1.0) * 1.5;
	} else if (forma == 3) {             // fumaça: bola com borda comida por ruído
		float n = texture(ruido, uv * 0.8 + giro_v * 0.37).r;
		return clamp((1.0 - length(p)) * (0.7 + 0.8 * n), 0.0, 1.0) * 1.3;
	} else if (forma == 4) {             // lasca: triângulo afiado
		float t = max(abs(p.x) * 1.8 + p.y * 0.9, -p.y * 1.1);
		return clamp(1.0 - t, 0.0, 1.0) * 1.6;
	} else {                             // gota: bola com ponta para cima
		vec2 q = vec2(p.x * (1.0 + max(p.y, 0.0) * 1.2), p.y);
		return clamp(1.0 - length(q), 0.0, 1.0) * 1.4;
	}
}

void fragment() {
	float v = forma == 0 ? texture(tex, UV).r : clamp(forma_v(UV), 0.0, 1.0);
	float thr = max(pow(age, erode_pow) * erode, cut);
	float a = smoothstep(thr, thr + soft, v);
	if (halftone > 0.0) {
		vec2 g = FRAGCOORD.xy / dot_px;
		g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * g;
		float d = hexd(g) * 2.0;
		float dots = 1.0 - smoothstep(sqrt(a) - 0.08, sqrt(a) + 0.08, d);
		a = mix(a, dots * step(0.02, a), halftone * (1.0 - smoothstep(0.75, 0.95, a)));
	}
	vec3 c = texture(ramp, vec2(clamp(v * (1.0 - thr * 0.5), 0.0, 1.0), 0.5)).rgb;
	ALBEDO = c * pcol.rgb * boost;
	ALPHA = clamp(a * pcol.a, 0.0, 1.0);
}
