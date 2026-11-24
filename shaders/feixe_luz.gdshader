// Feixe de lanterna: cone aditivo que some ao longe e nas bordas (sem textura). O cone é um CylinderMesh
// deitado: "comp" é o comprimento; a ponta estreita fica na lente.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 cor : source_color = vec3(1.0, 0.9, 0.6);
uniform float forca = 0.45;
uniform float comp = 1.6;
uniform float pisca = 1.0;
varying float ao_longe;

void vertex() {
	ao_longe = clamp((VERTEX.y + comp * 0.5) / comp, 0.0, 1.0);   // 0 na lente .. 1 na ponta larga
}

void fragment() {
	float borda = pow(abs(dot(normalize(NORMAL), VIEW)), 1.6);
	float some = pow(1.0 - ao_longe, 1.8);
	float poeira = 0.85 + 0.15 * sin(TIME * 2.3 + UV.x * 40.0 + ao_longe * 9.0);
	ALBEDO = cor * forca * borda * some * poeira * pisca;
}
