extends Node3D
## OFICINA DE VFX — palco limpo para revisar os efeitos da Forja (data/vfx_receitas.json).
## Dois personagens a 3 casas, chão de hexágonos com fundo trocável, câmera de jogo,
## câmera lenta, laço e troca de lado. Abrir: Menu > Configurações > Oficina de VFX, ou --oficina.

const FUNDOS = {
	"Areia (Tarhut)": [Color("#f2a65a"), Color("#d9823e"), Color("#5a2a3a")],
	"Caverna (Valak)": [Color("#4a3a8c"), Color("#33286a"), Color("#120c2a")],
	"Neutro": [Color("#8c909e"), Color("#6c7080"), Color("#2a2c36")],
	"Claro": [Color("#e9e4d8"), Color("#cfc8b6"), Color("#7d8794")],
}
const LADOS = [["rhazur", "k_tank"], ["rayak", "k_tank"], ["strahl", "k_tank"], ["bayak", "k_tank"], ["sapturne", "k_tank"], ["balu", "k_tank"], ["sterina", "k_front"]]
const EXTRAS = ["k_front", "k_sniper"]     # inimigos vizinhos do alvo (descargas, áreas)

var vfx: Node3D
var cam: Camera3D
var env: Environment
var shake: float = 0.0          # a vfx.gd escreve aqui (finge ser o tabuleiro)
var tiles: Array = []
var figs: Array = []
var extras: Array = []
var pers: Dictionary = {}
var fundo_i: int = 0
var lado_i: int = 0
var trocado: bool = false
var sel: String = ""
var laco: bool = false
var vel: float = 1.0
var fac: String = "aby"
var ui: CanvasLayer
var lista: VBoxContainer
var info: Label
var painel: PanelContainer
var t_laco: float = 0.0
var font: Font = null
var on_exit: Callable


func _ready() -> void:
	if ResourceLoader.exists("res://ui/fonts/InterDisplay-BlackItalic.otf"):
		font = load("res://ui/fonts/InterDisplay-BlackItalic.otf")
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	cam = Camera3D.new()
	cam.environment = env
	cam.fov = 40
	add_child(cam)
	cam.current = true
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.8
	add_child(sun)
	_build_floor()
	vfx = Node3D.new()
	vfx.set_script(load("res://scripts/vfx.gd"))
	add_child(vfx)
	vfx.board = self
	var pf = FileAccess.open("res://data/vfx_personagens.json", FileAccess.READ)
	if pf != null:
		var pd = JSON.parse_string(pf.get_as_text())
		if typeof(pd) == TYPE_DICTIONARY:
			pers = pd
	_build_figs()
	_build_ui()
	_apply_fundo()
	_cam_place(0.0)


# ---------------- palco
func _hex_xz(q: int, r: int) -> Vector2:
	var s = 1.0
	return Vector2(s * sqrt(3.0) * (q + r * 0.5), s * 1.5 * r)


func _build_floor() -> void:
	for r in range(-3, 4):
		for q in range(-6, 7):
			var p = _hex_xz(q, r)
			if abs(p.x) > 7.5 or abs(p.y) > 4.6:
				continue
			var mi = MeshInstance3D.new()
			var cy = CylinderMesh.new()
			cy.top_radius = 0.97
			cy.bottom_radius = 0.97
			cy.height = 0.4
			cy.radial_segments = 6
			cy.rings = 1
			mi.mesh = cy
			mi.rotation_degrees.y = 30
			mi.position = Vector3(p.x, -0.2 - (0.12 if (q + r * 3) % 4 == 0 else 0.0), p.y)
			var m = StandardMaterial3D.new()
			m.roughness = 1.0
			mi.material_override = m
			add_child(mi)
			tiles.append([mi, (q + r) % 2 == 0])


func _apply_fundo() -> void:
	var k = FUNDOS.keys()[fundo_i]
	var c = FUNDOS[k]
	env.background_color = c[2]
	for t in tiles:
		t[0].material_override.albedo_color = c[0] if t[1] else c[1]
	if info != null:
		info.text = "Fundo: " + k


func _fig(cid: String) -> MeshInstance3D:
	var path = "res://art/%s.webp" % cid
	if not ResourceLoader.exists(path):
		return MeshInstance3D.new()
	var tex: Texture2D = load(path)
	var mi = MeshInstance3D.new()
	var q = QuadMesh.new()
	var h = 2.5
	var asp = float(tex.get_width()) / float(tex.get_height())
	q.size = Vector2(h * asp, h)
	q.center_offset = Vector3(0, h * 0.5, 0)
	mi.mesh = q
	var m = StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = m
	return mi


func _build_figs() -> void:
	for f in figs + extras:
		f.queue_free()
	figs.clear()
	extras.clear()
	var par = LADOS[lado_i]
	for i in range(2):
		var f = _fig(par[i])
		var x = -2.6 if (i == 0) != trocado else 2.6
		f.position = Vector3(x, 0.0, 0.0)
		var m: StandardMaterial3D = f.material_override
		if m != null and x > 0:
			m.uv1_scale = Vector3(-1, 1, 1)
			m.uv1_offset = Vector3(1, 0, 0)
		add_child(f)
		figs.append(f)
	var side = 1.0 if not trocado else -1.0
	for i in range(EXTRAS.size()):
		var e = _fig(EXTRAS[i])
		e.position = Vector3((2.6 + (-0.87 if i == 0 else 0.87)) * side, 0.0, -1.5)   # vizinhos do alvo, atrás dele
		var em: StandardMaterial3D = e.material_override
		if em != null and side > 0:
			em.uv1_scale = Vector3(-1, 1, 1)
			em.uv1_offset = Vector3(1, 0, 0)
		add_child(e)
		extras.append(e)


func _pa() -> Vector3:
	return figs[0].position
func _pb() -> Vector3:
	return figs[1].position


func _cam_place(delta: float) -> void:
	var tgt = Vector3(-1.1 if painel == null or painel.visible else 0.0, 0.7, 0)   # com painel, o palco vai para a direita
	if shake > 0.0:
		var t = Time.get_ticks_msec() / 1000.0
		tgt += Vector3(sin(t * 43.0), cos(t * 31.0) * 0.5, 0) * 0.18 * shake
		shake = max(0.0, shake - delta * 1.4)
	cam.position = tgt + (Vector3(0, 5.3, 8.2) if painel == null or painel.visible else Vector3(0, 4.3, 6.4))
	cam.look_at(tgt)


func _process(delta: float) -> void:
	_cam_place(delta / max(Engine.time_scale, 0.01))
	if laco and sel != "":
		t_laco -= delta
		if t_laco <= 0.0:
			tocar(sel)


# ---------------- tocar
func tocar(id: String) -> void:
	sel = id
	t_laco = 2.2
	var r: Dictionary = vfx.receitas.get(id, {})
	var alvo = str(r.get("alvo", "outro"))
	if r.has("personagem"):
		# efeito próprio de um personagem: ele vira o atacante no palco
		for i in range(LADOS.size()):
			if LADOS[i][0] == str(r["personagem"]) and i != lado_i:
				lado_i = i
				_build_figs()
	var atk = LADOS[lado_i][0]
	var ctx = {"extras": extras.map(func(e): return e.position)}
	if pers.has(atk) and pers[atk].has("nucleo"):
		ctx["nucleo"] = Color(str(pers[atk]["nucleo"]))
	if alvo == "self":
		vfx.play_fx(id, _pa(), null, Color.WHITE, null, ctx)
	elif alvo == "meio":
		vfx.play_fx(id, Vector3(0, 0, 0), _pa(), Color.WHITE, null, ctx)
	elif alvo == "aliado":
		var side = 1.0 if not trocado else -1.0
		vfx.play_fx(id, _pa() + Vector3(0.87 * side, 0, 1.5), _pa(), Color.WHITE, null, ctx)
	elif r.has("puxa"):
		# puxões: o alvo é arrastado (até o lado do atacante, ou N casas) e depois volta ao lugar
		var fig: Node3D = figs[1]
		var ini = _pb()
		var pz = r["puxa"]
		var dest = _pa() + (ini - _pa()).normalized() * 1.73
		if pz.has("casas"):
			dest = ini + (_pa() - ini).normalized() * min(1.73 * float(pz["casas"]), ini.distance_to(_pa()) - 1.73)
		var voo = vfx.play_fx(id, ini, _pa(), Color.WHITE, fig, ctx)
		var tw = fig.create_tween()
		tw.tween_interval(float(pz.get("inicio", 0.4)) + (voo if bool(pz.get("apos_voo", false)) else 0.0))
		tw.tween_property(fig, "position", dest, float(pz.get("dur", 0.4))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_interval(1.1)
		tw.tween_property(fig, "position", ini, 0.01)
	else:
		vfx.play_fx(id, _pb(), _pa(), Color.WHITE, null, ctx)
	if info != null:
		info.text = "%s   ·   velocidade %sx   ·   fundo %s" % [id, str(vel), FUNDOS.keys()[fundo_i]]


# ---------------- interface
func _btn(parent: Control, txt: String, col: Color, f: Callable) -> Button:
	var b = Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	if font != null:
		b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 15)
	for st in ["normal", "hover", "pressed"]:
		var sb = StyleBoxFlat.new()
		sb.bg_color = col.darkened(0.55 if st == "normal" else (0.35 if st == "hover" else 0.15))
		sb.border_color = col
		sb.set_border_width_all(2)
		sb.set_content_margin_all(7)
		sb.skew = Vector2(-0.12, 0)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color("#F8FAFF"))
	b.pressed.connect(f)
	parent.add_child(b)
	return b


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var pan = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("#10145A", 0.88)
	sb.border_color = Color("#F438A9")
	sb.set_border_width_all(3)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color("#F438A9", 0.6)
	sb.shadow_offset = Vector2(6, 6)
	pan.add_theme_stylebox_override("panel", sb)
	pan.position = Vector2(16, 16)
	ui.add_child(pan)
	painel = pan
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pan.add_child(v)
	var tl = Label.new()
	tl.text = "OFICINA DE VFX"
	if font != null:
		tl.add_theme_font_override("font", font)
	tl.add_theme_font_size_override("font_size", 24)
	tl.add_theme_color_override("font_color", Color("#FFD12E"))
	v.add_child(tl)
	lista = VBoxContainer.new()
	v.add_child(lista)
	_fill_list()
	var row = HBoxContainer.new()
	v.add_child(row)
	for sp in [1.0, 0.5, 0.25]:
		_btn(row, "%sx" % str(sp), Color("#27DDF4"), func():
			vel = sp
			Engine.time_scale = sp)
	var row2 = HBoxContainer.new()
	v.add_child(row2)
	var lb = _btn(row2, "Laço: não", Color("#A957EC"), func(): pass)
	lb.pressed.connect(func():
		laco = not laco
		lb.text = "Laço: " + ("sim" if laco else "não"))
	_btn(row2, "Fundo", Color("#A957EC"), func():
		fundo_i = (fundo_i + 1) % FUNDOS.size()
		_apply_fundo())
	_btn(row2, "Lados", Color("#A957EC"), func():
		trocado = not trocado
		_build_figs())
	_btn(row2, "Bonecos", Color("#A957EC"), func():
		lado_i = (lado_i + 1) % LADOS.size()
		_build_figs())
	_btn(v, "Voltar", Color("#FFD12E"), func():
		Engine.time_scale = 1.0
		if on_exit.is_valid():
			on_exit.call()
		else:
			get_tree().reload_current_scene())
	info = Label.new()
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color("#F8FAFF"))
	info.add_theme_color_override("font_outline_color", Color("#12061c"))
	info.add_theme_constant_override("outline_size", 6)
	info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	info.position = Vector2(20, -44)
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(info)


func _fill_list() -> void:
	for c in lista.get_children():
		c.queue_free()
	vfx._receitas_load()
	var ids = vfx.receitas.keys()
	ids.sort()
	for id in ids:
		if not str(id).begins_with(fac + "_"):
			continue
		var nome = str(vfx.receitas[id].get("nome", id))
		_btn(lista, nome, Color("#F438A9"), tocar.bind(id))


var legenda_lb: Label = null


## legenda grande no alto da tela (para vídeos de revisão)
func legenda(txt: String, sub: String = "") -> void:
	if legenda_lb == null:
		legenda_lb = Label.new()
		if font != null:
			legenda_lb.add_theme_font_override("font", font)
		legenda_lb.add_theme_font_size_override("font_size", 38)
		legenda_lb.add_theme_color_override("font_color", Color("#FFD12E"))
		legenda_lb.add_theme_color_override("font_outline_color", Color("#12061c"))
		legenda_lb.add_theme_constant_override("outline_size", 12)
		legenda_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		legenda_lb.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		legenda_lb.offset_top = 18
		legenda_lb.offset_left = 380 if painel == null or painel.visible else 0
		ui.add_child(legenda_lb)
	legenda_lb.text = txt + ("\n" + sub if sub != "" else "")


## roteiro automático (revisão/gravação): toca cada receita da facção n vezes
func auto(n: int = 2, pausa: float = 2.2, fundos: Array = [0, 1]) -> void:
	var ids = []
	for id in vfx.receitas.keys():
		if str(id).begins_with(fac + "_") and not str(id).contains("_z_"):
			ids.append(id)
	ids.sort()
	for fi in fundos:
		fundo_i = fi
		_apply_fundo()
		for id in ids:
			for i in range(n):
				tocar(id)
				await get_tree().create_timer(pausa).timeout
