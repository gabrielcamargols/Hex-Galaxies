// Retícula de hexágonos: distância "hexagonal" até o centro do hexágono mais próximo de uma grade triangular.
// p em unidades de célula (passo horizontal = 1). Devolve 0 no centro e ~0.5 na borda da célula.
float hexd(vec2 p) {
	vec2 s = vec2(1.0, 1.7320508);
	vec2 a = mod(p, s) - s * 0.5;
	vec2 b = mod(p - s * 0.5, s) - s * 0.5;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	g = abs(g);
	return max(g.x, g.x * 0.5 + g.y * 0.8660254);
}

// id (inteiro aproximado) da célula hexagonal, para sortear altura/cor por tufo
vec2 hexid(vec2 p) {
	vec2 s = vec2(1.0, 1.7320508);
	vec2 a = mod(p, s) - s * 0.5;
	vec2 b = mod(p - s * 0.5, s) - s * 0.5;
	return dot(a, a) < dot(b, b) ? floor(p / s) + 0.25 : floor((p - s * 0.5) / s) + 0.75;
}
