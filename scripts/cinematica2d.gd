extends CanvasLayer
## Cutscene 2D do round 6, estilo quadrinho animado: o comandante entra em cena.
## Arte em res://art/cutscenes/<cid>/: fundo.jpg (cenário), nave.png (opcional), heroi.png e balao.png.
## A composição é feita no espaço da arte de referência (REF) e escalada para cobrir a tela.
## Entra saindo de uma retícula hexagonal e some dissolvendo nela.

const REF = Vector2(1672, 941)
const DUR = 6.6

# onde cada camada fica na arte de referência (centro em REF, largura em REF)
const LAYOUT = {
	"k_cmd": {"nave": {"c": Vector2(520, 410), "w": 1040}, "heroi": {"c": Vector2(1000, 548), "w": 880, "de": 0.5},
		"balao": {"c": Vector2(1340, 200), "w": 620}, "passos": 4},
}

var main
var root: Node2D
var fade: ColorRect
var skip := false
var t := 0.0
var sprites: Array = []
var shake := 0.0
var cam_off := Vector2.ZERO


static func has_art(cid: String) -> bool:
	return ResourceLoader.exists("res://art/cutscenes/%s/fundo.jpg" % cid) and ResourceLoader.exists("res://art/cutscenes/%s/heroi.png" % cid)


func run(m, cmds: Array) -> void:
	main = m
	layer = 50
	fade = ColorRect.new()
	fade.color = Color(0.03, 0.01, 0.08, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	for c in cmds:
		if skip:
			break
		await _scene(c)
	var tf = create_tween()
	tf.tween_property(fade, "color:a", 0.0, 0.35)
	await tf.finished


func _input(e: InputEvent) -> void:
	if (e is InputEventKey and e.pressed and e.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]) or (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		skip = true


func _tex(cid: String, n: String) -> Texture2D:
	var p = "res://art/cutscenes/%s/%s" % [cid, n]
	return load(p) if ResourceLoader.exists(p) else null


func _hexmat(progress: float, cell: float = 14.0) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/hex_fade.gdshader")
	m.set_shader_parameter("progress", progress)
	m.set_shader_parameter("cell", cell)
	return m


func _sprite(tex: Texture2D, center: Vector2, width: float, z: int) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = tex
	s.position = center
	s.scale = Vector2.ONE * width / float(tex.get_width())
	s.z_index = z
	s.material = _hexmat(1.0)
	s.set_meta("base_scale", s.scale)
	s.set_meta("base_pos", center)
	root.add_child(s)
	sprites.append(s)
	return s


# retícula: progress 1 = invisível, 0 = inteiro
func _hex_in(s: CanvasItem, dur: float, delay: float = 0.0) -> void:
	var tw = create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v): s.material.set_shader_parameter("progress", v), 1.0, 0.0, dur)


func _hex_out(s: CanvasItem, dur: float) -> Tween:
	var tw = create_tween()
	tw.tween_method(func(v): s.material.set_shader_parameter("progress", v), 0.0, 1.0, dur)
	return tw


func _process(dt: float) -> void:
	t += dt
	if root == null:
		return
	var vs = get_viewport().get_visible_rect().size
	var k = max(vs.x / REF.x, vs.y / REF.y) * 1.04
	var sh = Vector2.ZERO
	if shake > 0.0:
		sh = Vector2(sin(t * 53.0), cos(t * 47.0)) * shake * 9.0
		shake = max(0.0, shake - dt * 3.0)
	root.scale = Vector2.ONE * k
	root.position = vs * 0.5 - REF * 0.5 * k + sh + cam_off * k


func _scene(c: Dictionary) -> void:
	var cid = str(c["cid"])
	var lay = LAYOUT.get(cid, {"heroi": {"c": Vector2(900, 560), "w": 900, "de": 0.5}, "balao": {"c": Vector2(1300, 200), "w": 600}, "passos": 4})
	sprites.clear()
	t = 0.0
	root = Node2D.new()
	add_child(root)
	fade.move_to_front()
	_process(0.0)
	# ---- cenário: surge da retícula e desliza devagar (câmera de quadrinho)
	var fundo = _sprite(_tex(cid, "fundo.jpg"), REF * 0.5, REF.x * 1.08, 0)
	var tf = create_tween().set_parallel(true)
	tf.tween_property(fade, "color:a", 0.0, 0.25)
	_hex_in(fundo, 0.5)
	tf.tween_property(fundo, "position", REF * 0.5 + Vector2(-50, 0), DUR).set_trans(Tween.TRANS_SINE)
	tf.tween_property(fundo, "scale", fundo.scale * 1.05, DUR)
	# ---- nave: entra deslizando do alto e balança no ar
	var nave: Sprite2D = null
	var nt = _tex(cid, "nave.png")
	if nt != null and lay.has("nave"):
		var nc: Vector2 = lay["nave"]["c"]
		nave = _sprite(nt, nc + Vector2(-260, -220), lay["nave"]["w"], 1)
		nave.rotation = -0.05
		_hex_in(nave, 0.35, 0.15)
		var tn = create_tween()
		tn.tween_interval(0.15)
		tn.tween_property(nave, "position", nc, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tn.parallel().tween_property(nave, "rotation", 0.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tn.tween_callback(func(): shake = max(shake, 0.6))
		var tb = create_tween().set_loops()
		tb.tween_interval(1.1)
		tb.tween_property(nave, "offset:y", -6.0, 1.2).set_trans(Tween.TRANS_SINE)
		tb.tween_property(nave, "offset:y", 4.0, 1.2).set_trans(Tween.TRANS_SINE)
	# ---- comandante: desce a rampa e caminha para a câmera, passo a passo
	var hc: Vector2 = lay["heroi"]["c"]
	var hw: float = lay["heroi"]["w"]
	var heroi = _sprite(_tex(cid, "heroi.png"), hc, hw, 3)
	var bs: Vector2 = heroi.scale
	var de: float = float(lay["heroi"].get("de", 0.5))
	heroi.scale = bs * de
	heroi.position = hc + Vector2(-230, -170)
	heroi.modulate = Color(0.55, 0.5, 0.7)
	_hex_in(heroi, 0.3, 0.75)
	var passos = int(lay.get("passos", 4))
	var andar = 2.0
	var th = create_tween()
	th.tween_interval(0.85)
	th.tween_property(heroi, "scale", bs, andar).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	th.parallel().tween_property(heroi, "position", hc, andar).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	th.parallel().tween_property(heroi, "modulate", Color.WHITE, andar * 0.7)
	# balanço de cada passo (sobe e desce, gira de leve) + poeira e tremor ao pisar
	var tp = create_tween()
	tp.tween_interval(0.85)
	for i in range(passos):
		var lado = 1.0 if i % 2 == 0 else -1.0
		var dp = andar / passos
		tp.tween_property(heroi, "offset:y", -18.0, dp * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tp.parallel().tween_property(heroi, "rotation", 0.035 * lado, dp * 0.45)
		tp.tween_property(heroi, "offset:y", 0.0, dp * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tp.tween_callback(_passo.bind(heroi, i == passos - 1))
	tp.tween_property(heroi, "rotation", 0.0, 0.2)
	# capa/respiração depois de parar
	var tr = create_tween()
	tr.tween_interval(0.85 + andar + 0.2)
	tr.tween_property(heroi, "scale", bs * 1.015, 0.9).set_trans(Tween.TRANS_SINE)
	tr.tween_property(heroi, "scale", bs, 0.9).set_trans(Tween.TRANS_SINE)
	# ---- linhas de velocidade quando ele chega
	if ResourceLoader.exists("res://ui/splash/linhas.png"):
		var ln = Sprite2D.new()
		ln.texture = load("res://ui/splash/linhas.png")
		ln.position = hc + Vector2(0, -120)
		ln.scale = Vector2.ONE * REF.length() * 1.6 / 1024.0
		ln.modulate = Color(1, 0.75, 0.4, 0.0)
		ln.z_index = 2
		root.add_child(ln)
		var tl = create_tween()
		tl.tween_interval(0.85 + andar - 0.1)
		tl.tween_property(ln, "modulate:a", 0.75, 0.08)
		tl.parallel().tween_property(ln, "scale", ln.scale * 0.8, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tl.tween_property(ln, "modulate:a", 0.0, 0.6)
	# ---- balão de fala: estoura de repente, treme e fica
	var bt = _tex(cid, "balao.png")
	var balao: Sprite2D = null
	var t_fala = 0.85 + andar + 0.05
	if bt != null:
		var bc: Vector2 = lay["balao"]["c"]
		balao = _sprite(bt, bc, lay["balao"]["w"], 5)
		var bsc: Vector2 = balao.scale
		balao.visible = false
		var tbl = create_tween()
		tbl.tween_interval(t_fala)
		tbl.tween_callback(func():
			balao.visible = true
			balao.material.set_shader_parameter("progress", 0.0)
			balao.scale = bsc * 1.3
			balao.rotation = -0.06)
		tbl.tween_property(balao, "scale", bsc, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tbl.parallel().tween_property(balao, "rotation", 0.0, 0.1)
		for i in range(3):
			var a = 6.0 * (1.0 - i * 0.3)
			tbl.tween_property(balao, "position", bc + Vector2(randf_range(-a, a), randf_range(-a, a)), 0.03)
		tbl.tween_property(balao, "position", bc, 0.03)
	main.sfx.play_later("v_%s_fala" % cid, t_fala, 2.0)
	# ---- espera (ou pulo) e sai dissolvendo na retícula hexagonal
	while t < DUR and not skip:
		await get_tree().process_frame
	var ultimo: Tween = null
	for s in sprites:
		if is_instance_valid(s) and s.visible:
			ultimo = _hex_out(s, 0.25 if skip else 0.5)
	var tfo = create_tween()
	tfo.tween_interval(0.15 if skip else 0.3)
	tfo.tween_property(fade, "color:a", 1.0, 0.2 if skip else 0.3)
	await tfo.finished
	if ultimo != null and ultimo.is_running():
		await ultimo.finished
	root.queue_free()
	root = null
	sprites.clear()


# pisada: tremor, poeira saindo dos pés
func _passo(heroi: Sprite2D, forte: bool) -> void:
	shake = max(shake, 0.9 if forte else 0.45)
	if main.sfx != null:
		main.sfx.play("passo", -2.0 if forte else -6.0, 0.8, 0.1)
	var tex: Texture2D = heroi.texture
	var pe = heroi.position + Vector2(0, tex.get_height() * heroi.scale.y * 0.47)
	for i in range(6 if forte else 4):
		var d = Polygon2D.new()
		var pts = PackedVector2Array()
		for k in range(10):
			var a = TAU * k / 10.0
			pts.append(Vector2(cos(a), sin(a) * 0.6) * randf_range(16.0, 26.0))
		d.polygon = pts
		d.color = Color(0.98, 0.78, 0.55, 0.85)
		d.position = pe + Vector2(randf_range(-120, 120), randf_range(-10, 10))
		d.z_index = 4
		root.add_child(d)
		var dir = Vector2(sign(d.position.x - pe.x) * randf_range(40, 110), randf_range(-60, -20))
		var tw = d.create_tween().set_parallel(true)
		tw.tween_property(d, "position", d.position + dir, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "scale", Vector2.ONE * randf_range(1.6, 2.4), 0.55)
		tw.tween_property(d, "color:a", 0.0, 0.55)
		tw.chain().tween_callback(d.queue_free)
