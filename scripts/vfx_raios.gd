extends RefCounted
## RAIOS ELÉTRICOS em malha (sem PNG): linhas quebradas que tremem, trocando o desenho a cada "flick",
## viradas para a câmera, com halo colorido + miolo branco e galhos. Usado pela vfx.gd:
##   arco(de, para, dur, opts)            de/para: Vector3 ou Callable -> Vector3 (seguem quem se move)
##   coroa(centro, raio, dur, opts)       estalos em volta de um ponto (bola elétrica, dedos)
##   espalha(centro, dur, opts)           o choque correndo pelo chão e pelo ar a partir do acerto
##   eletrocuta(fig, dur, opts)           arcos pulando entre os ossos do corpo de quem levou o choque
## opts: "cor" (halo), "miolo" (núcleo), "largura" (m), "tremor" (0..1 do comprimento), "flick" (s),
##       "galhos" (n), "n" (arcos ao mesmo tempo)

var host: Node3D
var _mat_halo: StandardMaterial3D
var _mat_miolo: StandardMaterial3D
var _mat_halo_f: StandardMaterial3D      # "frente": por cima de tudo (arcos sobre o corpo de quem levou o choque)
var _mat_miolo_f: StandardMaterial3D


func _init(h: Node3D) -> void:
	host = h


func _mat(miolo: bool, frente: bool = false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.no_depth_test = frente
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.render_priority = 30 if miolo else 29
	return m


func _cam() -> Camera3D:
	return host.get_viewport().get_camera_3d() if host.is_inside_tree() else null


static func _v(p: Variant) -> Vector3:
	return p.call() if p is Callable else p


# pontos de um raio: deslocamento do ponto médio (fica com cara de relâmpago, não de zigue-zague regular)
static func _quebra(a: Vector3, b: Vector3, tremor: float, niveis: int) -> PackedVector3Array:
	var pts = PackedVector3Array([a, b])
	var amp = a.distance_to(b) * tremor
	for _n in niveis:
		var novo = PackedVector3Array()
		for i in range(pts.size() - 1):
			novo.append(pts[i])
			var m = (pts[i] + pts[i + 1]) * 0.5
			m += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * amp
			novo.append(m)
		novo.append(pts[pts.size() - 1])
		pts = novo
		amp *= 0.55
	return pts


# faixa virada para a câmera ao longo dos pontos (afina nas pontas)
static func _faixa(im: ImmediateMesh, pts: PackedVector3Array, larg: float, cor: Color, cam_pos: Vector3) -> void:
	var n = pts.size()
	if n < 2:
		return
	var lados: Array = []
	for i in n:
		var d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
		var v = (cam_pos - pts[i]).normalized()
		var s = d.cross(v)
		if s.length() < 0.001:
			s = Vector3.UP.cross(d)
		var u = float(i) / (n - 1)
		var w = larg * (0.35 + 0.65 * sin(PI * clamp(u * 0.9 + 0.05, 0.0, 1.0)))
		lados.append(s.normalized() * w * 0.5)
	for i in range(n - 1):
		var a0 = pts[i] - lados[i]
		var a1 = pts[i] + lados[i]
		var b0 = pts[i + 1] - lados[i + 1]
		var b1 = pts[i + 1] + lados[i + 1]
		for p in [a0, b0, b1, a0, b1, a1]:
			im.surface_set_color(cor)
			im.surface_add_vertex(p)


func _desenha(im: ImmediateMesh, linhas: Array, O: Dictionary) -> void:
	im.clear_surfaces()
	var cam = _cam()
	var cp = cam.global_position if cam != null else Vector3(0, 10, 10)
	var halo: Color = O.get("cor", Color("#4cd4bd"))
	var miolo: Color = O.get("miolo", Color("#f2fff8"))
	var larg = float(O.get("largura", 0.07))
	var fade = float(O.get("_fade", 1.0))
	var fr = bool(O.get("frente", false))
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat_halo_f if fr else _mat_halo)
	for L in linhas:
		_faixa(im, L[0], larg * 3.0 * L[1], Color(halo, 0.6 * fade), cp)
	im.surface_end()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat_miolo_f if fr else _mat_miolo)
	for L in linhas:
		_faixa(im, L[0], larg * L[1], Color(miolo, fade), cp)
	im.surface_end()


func _no() -> MeshInstance3D:
	if _mat_halo == null:
		_mat_halo = _mat(false)
		_mat_miolo = _mat(true)
		_mat_halo_f = _mat(false, true)
		_mat_miolo_f = _mat(true, true)
	var mi = MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	host.add_child(mi)
	return mi


# laço comum: a cada "flick" refaz o desenho chamando gera() -> Array de [pontos, espessura]
func _anima(dur: float, O: Dictionary, gera: Callable) -> void:
	var mi = _no()
	var im: ImmediateMesh = mi.mesh
	var flick = float(O.get("flick", 0.045))
	var tw = mi.create_tween()
	var st = {"ultimo": -1}          # lambdas copiam variáveis locais: o estado mora num dicionário
	tw.tween_method(func(t: float):
		var passo = int(floor(t / flick))
		if passo == st["ultimo"]:
			return
		st["ultimo"] = passo
		var O2 = O.duplicate()
		O2["_fade"] = 1.0 - clamp((t - dur * 0.65) / (dur * 0.35), 0.0, 1.0)
		var linhas: Array = gera.call(t / dur)
		_desenha(im, linhas, O2), 0.0, dur, dur)
	tw.tween_callback(mi.queue_free)


func _com_galhos(a: Vector3, b: Vector3, O: Dictionary, esp: float = 1.0) -> Array:
	var tremor = float(O.get("tremor", 0.22))
	var pts = _quebra(a, b, tremor, int(O.get("niveis", 4)))
	var out = [[pts, esp]]
	for _g in int(O.get("galhos", 1)):
		if pts.size() < 4:
			break
		var i = randi_range(1, pts.size() - 3)
		var base = pts[i]
		var dir = (b - a)
		var fim = base + (dir.normalized() * randf_range(0.2, 0.45) + Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized() * 0.35) * dir.length() * 0.6
		out.append([_quebra(base, fim, tremor, 3), esp * 0.55])
	return out


func arco(de: Variant, para: Variant, dur: float, O: Dictionary = {}) -> void:
	_anima(dur, O, func(_u):
		return _com_galhos(_v(de), _v(para), O))


func coroa(centro: Variant, raio: float, dur: float, O: Dictionary = {}) -> void:
	var n = int(O.get("n", 3))
	_anima(dur, O, func(_u):
		var c = _v(centro)
		var linhas = []
		for _i in n:
			var a = c + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * raio * 0.35
			var b = c + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * raio * randf_range(0.8, 1.4)
			linhas.append_array(_com_galhos(a, b, O, randf_range(0.6, 1.0)))
		return linhas)


# o choque se espalha a partir do acerto: arcos crescendo para fora, rentes ao chão e pelo ar
func espalha(centro: Vector3, chao_y: float, dur: float, O: Dictionary = {}) -> void:
	var n = int(O.get("n", 7))
	var alcance = float(O.get("alcance", 1.6))
	var dirs: Array = []
	for i in n:
		var a = TAU * (float(i) + randf_range(-0.3, 0.3)) / n
		dirs.append(Vector3(cos(a), 0, sin(a)))
	_anima(dur, O, func(u):
		var linhas = []
		var cresce = clamp(u / 0.35, 0.0, 1.0)
		for i in n:
			var d: Vector3 = dirs[i]
			var chao = i % 2 == 0
			var a = centro if not chao else Vector3(centro.x, chao_y + 0.06, centro.z)
			var b = a + d * alcance * cresce * randf_range(0.75, 1.1)
			if chao:
				b.y = chao_y + 0.04
			else:
				b.y += randf_range(-0.5, 0.35) * cresce
			if a.distance_to(b) > 0.05:
				linhas.append_array(_com_galhos(a, b, O, 0.8 if chao else 1.0))
		return linhas)


# arcos saltando entre pontos do corpo (ossos do esqueleto, ou um cilindro em volta da peça)
func eletrocuta(pontos_f: Callable, dur: float, O: Dictionary = {}) -> void:
	var n = int(O.get("n", 3))
	_anima(dur, O, func(_u):
		var pts0: Array = pontos_f.call()
		var linhas = []
		if pts0.size() < 2:
			return linhas
		# afasta os pontos do eixo do corpo: os arcos correm por fora da roupa/armadura
		var eixo = Vector3.ZERO
		for p0 in pts0:
			eixo += p0
		eixo /= pts0.size()
		var pts: Array = []
		for p0 in pts0:
			var off = Vector3(p0.x - eixo.x, 0, p0.z - eixo.z)
			off = off.normalized() if off.length() > 0.01 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			pts.append(p0 + off * float(O.get("fora", 0.12)))
		for _i in n:
			var a: Vector3 = pts[randi() % pts.size()]
			var b: Vector3 = pts[randi() % pts.size()]
			if a.distance_to(b) < 0.12:
				b = a + Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized() * 0.45
			linhas.append_array(_com_galhos(a, b, O, randf_range(0.6, 1.0)))
		return linhas)
