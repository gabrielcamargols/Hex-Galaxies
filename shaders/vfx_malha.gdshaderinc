// MALHAS DE VFX (sem desenho em PNG): arco de golpe, anel de onda, cilindro, estrela, esfera, tubo.
// A forma vem da malha; a cor vem da rampa pela "intensidade" (miolo claro, borda num tom escuro da
// própria cor); um ruído de tinta desfaz a borda e dissolve tudo no fim. "idade" vai de 0 a 1 (tween).
uniform sampler2D ramp : source_color, filter_linear, repeat_disable;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform float idade = 0.0;
uniform int perfil = 0;          // 0 faixa (miolo em UV.y = 0.5), 1 do centro para fora (UV.y 0..1), 2 miolo (esfera/tubo), 3 casca (onda de choque: só a borda)
uniform int frente = 0;          // 1 = sempre de frente para a câmera (estrela)
uniform float varre = 0.0;       // > 0: a forma aparece correndo pelo UV.x (cabeça clara, cauda que some)
uniform float cauda = 0.55;      // comprimento da cauda da varrida (em UV.x)
uniform float erode = 1.0;       // 0 sem dissolver .. 1 some tudo no fim
uniform float erode_pow = 1.6;
uniform float suave = 0.07;
uniform float ruido_k = 0.45;    // quanto o ruído mexe na borda
uniform vec2 ruido_esc = vec2(3.0, 1.0);
uniform float rolagem = 1.5;     // o ruído corre pelo UV.x (energia andando)
uniform float boost = 1.0;
uniform float fresnel_pow = 1.4;
uniform vec4 tint : source_color = vec4(1.0);
uniform float nucleo_a = 0.0;    // casca: miolo escuro e opaco (orbe do abismo: centro escuro, borda acesa)
uniform float degraus = 0.0;     // > 0: cor em faixas chapadas (visual de anime), ex. 4
uniform float redemoinho = 0.0;  // espiral: o ruído gira em volta (anel, esfera, cilindro) — orbe e portal

void vertex() {
	if (frente == 1) {
		vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc.x, INV_VIEW_MATRIX[1] * sc.y, INV_VIEW_MATRIX[2] * sc.z, MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(1.0);
	}
}

void fragment() {
	float prof;
	if (perfil == 0) {
		prof = 1.0 - abs(UV.y * 2.0 - 1.0);
	} else if (perfil == 1) {
		prof = 1.0 - UV.y;
	} else if (perfil == 2) {
		prof = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), fresnel_pow);
	} else {
		prof = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), fresnel_pow);
	}
	vec2 uvr = UV;
	if (redemoinho != 0.0) {
		// UV.x já dá a volta (anel, esfera, cilindro): desloca a volta conforme UV.y = espiral girando
		uvr.x += redemoinho * UV.y + idade * rolagem * 0.6;
	}
	vec2 ru = uvr * ruido_esc + vec2(-idade * rolagem, idade * 0.3);
	float n = texture(ruido, ru).r;
	float v = clamp(prof * (1.0 - ruido_k * 0.5 + ruido_k * n), 0.0, 1.0);
	float thr = pow(idade, erode_pow) * erode;
	float a = smoothstep(thr, thr + suave, v);
	if (nucleo_a > 0.0 && perfil == 3) {
		a = max(a, nucleo_a * (1.0 - smoothstep(0.85, 1.0, pow(idade, 3.0) * 1.15)));
	}
	if (varre > 0.0) {
		float cab = idade * varre * (1.0 + cauda);       // cabeça passa do fim para a cauda também sair
		float dentro = step(UV.x, cab);
		float k = clamp((UV.x - (cab - cauda)) / cauda, 0.0, 1.0);
		a *= dentro * smoothstep(0.0, 0.35, k);
		v = clamp(v + (k - 0.6) * 0.5, 0.0, 1.0);       // a cabeça fica mais clara
	}
	if (degraus > 0.0) {
		v = floor(v * degraus + 0.5) / degraus;
	}
	vec3 c = texture(ramp, vec2(v, 0.5)).rgb;
	ALBEDO = c * tint.rgb * boost;
	ALPHA = clamp(a * tint.a, 0.0, 1.0);
}
