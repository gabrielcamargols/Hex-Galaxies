extends RefCounted
## MALHAS DE VFX: efeitos feitos de formas 3D + shader, sem desenho em PNG (nítidos em qualquer
## tamanho, com volume e orientados pelo golpe). Usado pela vfx.gd nas camadas com "malha".
## Camada: {"malha": arco|anel|cilindro|estrela|esfera|tubo, "dur", "y", "ramp", "blend" add|mix,
##  "escala":[ini,fim], "erode", "varre", "cauda", "rolagem", "ruido", "boost", "toward",
##  arco: "r","largura","angulo","inclina","roll","giro" (graus girados no golpe),"espelho"
##  anel: "r":[ini,fim],"largura"   cilindro: "r","altura","altura0","torcao","afina","giro"
##  estrela: "pontas","interno","r"   esfera: "r","fresnel"   tubo: "r","y_de" (até o alvo ou quem é puxado)}

const FORMAS = ["ponto", "faisca", "fumaca", "lasca", "gota"]
var _ruido_tex: Texture2D = null
var _cache: Dictionary = {}


func ruido() -> Texture2D:
	if _ruido_tex == null:
		var fn = FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.035
		fn.fractal_octaves = 3
		var img = fn.get_seamless_image(128, 128)
		img.generate_mipmaps()
		_ruido_tex = ImageTexture.create_from_image(img)
	return _ruido_tex


func _tri(st: SurfaceTool, vs: Array, n: Vector3 = Vector3.ZERO) -> void:
	for t in vs:
		st.set_uv(t[1])
		if n != Vector3.ZERO:
			st.set_normal(n)
		st.add_vertex(t[0])


# meia-lua (corte de garra/lâmina) no plano XY, centro na origem; UV.x ao longo, UV.y de dentro para fora
func _arco(raio: float, larg: float, ang: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg = 40
	var a0 = -deg_to_rad(ang) * 0.5
	var pts = []
	for i in seg + 1:
		var u = float(i) / seg
		var a = a0 + deg_to_rad(ang) * u
		var w = larg * pow(sin(PI * clamp(u * 0.92 + 0.04, 0.0, 1.0)), 0.6)
		var d = Vector3(cos(a), sin(a), 0)
		pts.append([d * (raio - w * 0.35), d * (raio + w * 0.65), u])
	for i in seg:
		var p0 = pts[i]
		var p1 = pts[i + 1]
		_tri(st, [[p0[0], Vector2(p0[2], 0)], [p1[0], Vector2(p1[2], 0)], [p1[1], Vector2(p1[2], 1)],
			[p0[0], Vector2(p0[2], 0)], [p1[1], Vector2(p1[2], 1)], [p0[1], Vector2(p0[2], 1)]], Vector3(0, 0, 1))
	return st.commit()


# anel deitado no chão, raio externo 1
func _anel(larg: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg = 48
	for i in seg:
		var d0 = Vector3(cos(TAU * i / seg), 0, sin(TAU * i / seg))
		var d1 = Vector3(cos(TAU * (i + 1) / seg), 0, sin(TAU * (i + 1) / seg))
		var u0 = float(i) / seg
		var u1 = float(i + 1) / seg
		_tri(st, [[d0 * (1.0 - larg), Vector2(u0, 0)], [d1 * (1.0 - larg), Vector2(u1, 0)], [d1, Vector2(u1, 1)],
			[d0 * (1.0 - larg), Vector2(u0, 0)], [d1, Vector2(u1, 1)], [d0, Vector2(u0, 1)]], Vector3.UP)
	return st.commit()


# cilindro aberto de 0 a 1 de altura, raio 1; torção (redemoinho) e afinamento no topo
func _cilindro(torcao: float, afina: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg = 28
	var an = 8
	for j in an:
		for i in seg:
			var q = []
			for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var v = float(c[1]) / an
				var a = TAU * c[0] / seg + torcao * v
				var r = lerp(1.0, afina, v)
				q.append([Vector3(cos(a) * r, v, sin(a) * r), Vector2(float(c[0]) / seg, v)])
			_tri(st, [q[0], q[1], q[2], q[0], q[2], q[3]])
	st.generate_normals()
	return st.commit()


# clarão com pontas irregulares (de frente para a câmera); UV.y 0 no centro, 1 na ponta
func _estrela(pontas: int, interno: float, semente: int) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng = RandomNumberGenerator.new()
	rng.seed = semente
	var n = pontas * 2
	var ext = []
	for i in n:
		var a = TAU * i / n + PI * 0.5
		var r = rng.randf_range(0.65, 1.0) if i % 2 == 0 else interno
		ext.append([Vector3(cos(a) * r, sin(a) * r, 0), 1.0 if i % 2 == 0 else 0.55])
	for i in n:
		var p0 = ext[i]
		var p1 = ext[(i + 1) % n]
		_tri(st, [[Vector3.ZERO, Vector2(0.5, 0)], [p0[0], Vector2(0.5, p0[1])], [p1[0], Vector2(0.5, p1[1])]], Vector3(0, 0, 1))
	return st.commit()


# tubo deitado no eixo Z de 0 a 1 (esticado entre dois pontos); UV.x ao longo
func _tubo() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg = 12
	var an = 16
	for j in an:
		for i in seg:
			var q = []
			for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var a = TAU * c[0] / seg
				var z = float(c[1]) / an
				q.append([Vector3(cos(a), sin(a), z), Vector2(z, float(c[0]) / seg)])
			_tri(st, [q[0], q[1], q[2], q[0], q[2], q[3]])
	st.generate_normals()
	return st.commit()


func malha(L: Dictionary) -> Mesh:
	var tipo = str(L["malha"])
	var key = tipo
	match tipo:
		"arco":
			key = "arco_%.2f_%.2f_%.0f" % [float(L.get("r", 1.0)), float(L.get("largura", 0.35)), float(L.get("angulo", 160))]
		"anel":
			key = "anel_%.2f" % float(L.get("largura", 0.25))
		"cilindro":
			key = "cil_%.2f_%.2f" % [float(L.get("torcao", 0.0)), float(L.get("afina", 1.0))]
		"estrela":
			key = "est_%d_%.2f_%d" % [int(L.get("pontas", 8)), float(L.get("interno", 0.3)), randi() % 4]
	if _cache.has(key):
		return _cache[key]
	var m: Mesh = null
	match tipo:
		"arco":
			m = _arco(float(L.get("r", 1.0)), float(L.get("largura", 0.35)), float(L.get("angulo", 160)))
		"anel":
			m = _anel(float(L.get("largura", 0.25)))
		"cilindro":
			m = _cilindro(float(L.get("torcao", 0.0)), float(L.get("afina", 1.0)))
		"estrela":
			m = _estrela(int(L.get("pontas", 8)), float(L.get("interno", 0.3)), key.hash())
		"esfera":
			var sm = SphereMesh.new()
			sm.radial_segments = 20
			sm.rings = 10
			m = sm
		"tubo":
			m = _tubo()
	if m != null:
		_cache[key] = m
	return m
