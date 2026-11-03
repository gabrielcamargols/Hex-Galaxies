extends Node
## Controlador: menu, interface (HUD), turnos do jogador e da CPU.

const TDESC = {
	"plano": "Terreno aberto.", "lama": "Terreno difícil: custa 2 de movimento.", "escombros": "Destroços: custa 2 de movimento.",
	"colina": "Altura 1. Sobe-se por qualquer lado (+1 de custo).", "plataforma": "Bordas são penhascos: só se sobe pela rampa. Dá para pular para baixo 1 nível.",
	"rampa": "Liga o chão à plataforma. Subir custa +1.", "floresta": "Custa 2. Bloqueia tiros que passam por ela; quem está dentro sofre -1 de tiros.",
	"rocha": "Intransponível. Bloqueia tiros e abriga quem está ao lado (-2), do lado da rocha.", "ruina": "Intransponível. Bloqueia tiros e abriga quem está ao lado (-2).",
	"galpao": "Intransponível e alto. Bloqueia tiros e abriga quem está ao lado (-2).",
	"areia": "Areia firme. Terreno aberto.", "duna": "Degrau de duna. Sobe-se 1 nível por vez (+1 de custo por nível). Dá vantagem de altura.",
	"movedica": "Armadilha: quem entra para na hora. Sair custa +2.", "instavel": "Areia instável: custa 2 de movimento.",
	"ossada": "Ossada baixa. Intransponível, abriga quem está ao lado (-2).", "ossada_c": "Ossada central. Dá para entrar; quem está dentro sofre -1 de tiros.",
	"buraco": "Buraco de verme. Intransponível enquanto estiver aberto (2 rounds).",
}
const RULES = "[b]Objetivo:[/b] derrotar o Comandante inimigo (ele entra no round 6). No fim do round 10 vence quem tiver mais Vida no Comandante; empate: soma da Vida dos aliados.\n\n[b]Turno:[/b] os lados se alternam ativando 1 peça por vez. Cada peça ativada tem [b]2 ações[/b], e cada tipo só pode ser usado [b]1 vez por turno[/b]: mover 1 vez, atacar 1 vez, usar habilidade ativa ou jogar uma carta (ex.: mover + atacar, mover + carta, atacar + carta). Habilidades passivas não gastam ação. Colocar uma reserva em campo gasta 1 ação.\n\n[b]Altura:[/b] atacar de cima +1 de dano, de baixo -1. Tiros (alcance 2+) de cima ganham +1 de alcance. Corpo a corpo só com até 1 nível de diferença.\n\n[b]Linha de tiro:[/b] uma casa no caminho bloqueia se o topo dela for mais alto que o atacante e o alvo.\n\n[b]Abrigo:[/b] -2 de dano se uma rocha/ruína/ossada vizinha ao alvo estiver do lado do atacante.\n\n[b]Tarhut:[/b] as dunas mudam a cada 5 rounds (aviso 1 round antes); vermes abrem buracos a cada 3 rounds (o \"!\" avisa antes).\n\n[b]Controles:[/b] clique numa peça sua e depois numa casa verde (mover) ou num inimigo vermelho (atacar), ou arraste a peça e solte. Confirme a prévia. Botão direito gira a câmera, arrastar o fundo move o mapa, a roda aproxima. Q/E giram. Enter confirma, Esc cancela.\n\n[b]Toque (tablet/celular):[/b] toque numa peça e numa casa para agir. 1 dedo arrasta o mapa; pinça com 2 dedos aproxima/afasta; girar os 2 dedos gira a câmera; arrastar os 2 dedos para cima/baixo inclina a visão. \"Tudo\" recentraliza."

var board
var game: Game = null
var ui: Control
var w: Dictionary = {}

# código de cores: o mesmo em botões, casas do tabuleiro e legenda
const C_MOVE = Color("#4cd964")     # andar
const C_ATK = Color("#ff4d4d")      # atacar / inimigo atacável
const C_ABIL = Color("#b06cff")     # habilidade / escolher alvo de efeito
const C_CARD = Color("#4da3ff")     # cartas táticas
const C_DEPLOY = Color("#22d3c5")   # colocar reserva em campo
const C_YOU = Color("#3d8bff")      # seu lado
const C_CPU = Color("#ff7a2f")      # lado da CPU
const C_GOLD = Color("#ffab40")     # títulos e destaque
const C_END = Color("#cfe9f5")      # encerrar / passar
const C_HUD = Color("#29d8ff")      # molduras da HUD
const C_TXT = Color("#dff6ff")      # texto principal
const C_DIM = Color("#8fb8cc")      # texto secundário
var font_title: Font = null
var font_btn: Font = null
var setup_cfg: Dictionary = {"map": "tarhut", "fac": "ABY", "cpu": "FAU"}
var army_picks: Array = []     # 5 ids escolhidos pelo jogador
var army_start: Array = []     # até 2 ids que começam em campo
var army_fac: String = ""
var card_hover: String = ""      # carta com o mouse em cima (destaca o que ela afeta)
var last_st: Dictionary = {}       # destaques atuais do tabuleiro (sem a carta)
var dlg: Dictionary = {}           # falas (data/dialogos.json)
var bubbles: Array = []            # balões de fala ativos
var last_banter_ms: int = -100000
var autotest: bool = false   # godot --headless -- --autotest fac=ABY cpu=FAU map=tarhut
var last_sides: Variant = null

var sel: int = -1
var dsel: int = -1
var pend: Variant = null
var am: String = ""
var ab: bool = false
var tip: Variant = null
var inspect: int = -1
var hex_info: Variant = null
var asking: Variant = null
var busy: bool = false
var running: bool = false
var panel_open: String = ""
var res_drag: Variant = null
var sfx = null
var vfx = null
var impact_delay: float = 0.0
var impact_until: int = 0


func _ready() -> void:
	randomize()
	board = Node3D.new()
	board.set_script(load("res://scripts/board.gd"))
	add_child(board)
	board.hex_tapped.connect(_on_hex_tapped)
	board.unit_dropped.connect(_on_unit_dropped)
	board.unit_drag_started.connect(_on_unit_drag_started)
	vfx = Node3D.new()
	vfx.set_script(load("res://scripts/vfx.gd"))
	board.add_child(vfx)
	vfx.board = board
	sfx = Node.new()
	sfx.set_script(load("res://scripts/sfx.gd"))
	add_child(sfx)
	vfx.sfx = sfx
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = _make_theme()
	layer.add_child(ui)
	if FileAccess.file_exists("res://data/dialogos.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos.json"))
		if parsed is Dictionary:
			dlg = parsed
	_show_menu()
	var args = OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shots="):
			_shots(a.substr(8))
			return
	if args.has("--autotest"):
		autotest = true
		for a in args:
			var kv = a.split("=")
			if kv.size() == 2 and setup_cfg.has(kv[0]):
				setup_cfg[kv[0]] = kv[1]
		Engine.time_scale = 25.0
		print("AUTOTESTE: ", setup_cfg)
		_start_match(null)


# ================= tema e ajudantes de interface =================
func _make_theme() -> Theme:
	var th = Theme.new()
	th.default_font_size = 17
	if ResourceLoader.exists("res://ui/fonts/Inter-SemiBold.otf"):
		var fv = FontVariation.new()
		fv.base_font = load("res://ui/fonts/Inter-SemiBold.otf")
		fv.spacing_glyph = 1
		th.default_font = fv
	# Orbitron (tecnológica) para títulos e botões; Inter para textos longos
	if ResourceLoader.exists("res://ui/fonts/Orbitron.woff2"):
		var orb = load("res://ui/fonts/Orbitron.woff2")
		# símbolos que a Orbitron não tem (·, ●, ★...) vêm da Inter (na web não há fontes do sistema)
		if ResourceLoader.exists("res://ui/fonts/Inter-SemiBold.otf"):
			orb.fallbacks = [load("res://ui/fonts/Inter-SemiBold.otf")]
		var ft = FontVariation.new()
		ft.base_font = orb
		ft.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
		ft.spacing_glyph = 2
		font_title = ft
		var fb = FontVariation.new()
		fb.base_font = orb
		fb.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
		fb.spacing_glyph = 1
		font_btn = fb
		th.set_font("font", "Button", fb)
		th.set_font_size("font_size", "Button", 15)
	elif ResourceLoader.exists("res://ui/fonts/InterDisplay-Bold.otf"):
		var ft2 = FontVariation.new()
		ft2.base_font = load("res://ui/fonts/InterDisplay-Bold.otf")
		ft2.spacing_glyph = 3
		font_title = ft2
	th.set_stylebox("panel", "PanelContainer", _tex_box("res://ui/panel.png", 30, C_HUD, 20, 16))
	th.set_stylebox("normal", "Button", _tex_box("res://ui/btn.png", 14, C_HUD, 16, 9))
	th.set_stylebox("hover", "Button", _tex_box("res://ui/btn_on.png", 14, C_HUD.darkened(0.25), 16, 9))
	th.set_stylebox("pressed", "Button", _tex_box("res://ui/btn_on.png", 14, C_HUD, 16, 9))
	th.set_stylebox("disabled", "Button", _tex_box("res://ui/btn.png", 14, Color(0.35, 0.42, 0.5), 16, 9))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", C_TXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.45, 0.52, 0.6))
	th.set_color("font_color", "Label", C_TXT)
	th.set_color("default_color", "RichTextLabel", C_TXT)
	th.set_color("font_color", "OptionButton", C_TXT)
	return th


# moldura tecnológica (9-slice gerado por tools/uigen.py), tingida com uma cor
func _tex_box(path: String, margin: int, tint: Color, pad_h: int = 14, pad_v: int = 8) -> StyleBox:
	if not ResourceLoader.exists(path):
		var f = StyleBoxFlat.new()
		f.bg_color = Color(0.05, 0.08, 0.15, 0.88)
		f.border_color = tint
		f.set_border_width_all(2)
		f.set_content_margin_all(pad_v)
		return f
	var s = StyleBoxTexture.new()
	s.texture = load(path)
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	s.modulate_color = tint
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


func _panel(parent: Control) -> PanelContainer:
	var p = PanelContainer.new()
	parent.add_child(p)
	return p


func _vbox(parent: Control, sep: int = 6) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v


func _hbox(parent: Control, sep: int = 6) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	parent.add_child(h)
	return h


func _label(parent: Control, text: String = "", size: int = 0, col = null) -> Label:
	var l = Label.new()
	l.text = text
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if size >= 22 and font_title != null:
		l.add_theme_font_override("font", font_title)
	if col != null:
		l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _rich(parent: Control, width: int = 0) -> RichTextLabel:
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	if width > 0:
		r.custom_minimum_size = Vector2(width, 0)
	parent.add_child(r)
	return r


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _style_btn(b: Button, col: Color, active: bool = false) -> void:
	b.add_theme_stylebox_override("normal", _tex_box("res://ui/btn_on.png" if active else "res://ui/btn.png", 14, col if active else col.darkened(0.05), 16, 9))
	b.add_theme_stylebox_override("hover", _tex_box("res://ui/btn_on.png", 14, col.darkened(0.3), 16, 9))
	b.add_theme_stylebox_override("pressed", _tex_box("res://ui/btn_on.png", 14, col, 16, 9))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", _tex_box("res://ui/btn.png", 14, Color(0.3, 0.36, 0.44), 16, 9))
	b.add_theme_color_override("font_color", Color.WHITE if active else col.lightened(0.55))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.42, 0.5, 0.58))
	b.add_theme_constant_override("outline_size", 0)


func _cbtn(parent: Control, text: String, col: Color, cb: Callable, active: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(118, 46)
	b.add_theme_font_size_override("font_size", 15 if font_btn != null else 17)
	b.pressed.connect(cb)
	_style_btn(b, col, active)
	parent.add_child(b)
	return b


func _chip(parent: Control, col: Color, text: String) -> void:
	var hb = _hbox(parent, 5)
	var sw = ColorRect.new()
	sw.color = col
	sw.custom_minimum_size = Vector2(16, 16)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(sw)
	_label(hb, text, 13, C_TXT)


func _place(c: Control, preset: Control.LayoutPreset, margin: int = 10) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	if preset == Control.PRESET_CENTER_TOP:
		c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	elif preset == Control.PRESET_CENTER_BOTTOM:
		c.grow_horizontal = Control.GROW_DIRECTION_BOTH
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	elif preset == Control.PRESET_BOTTOM_LEFT:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	elif preset == Control.PRESET_BOTTOM_RIGHT:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif preset == Control.PRESET_TOP_RIGHT:
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif preset == Control.PRESET_CENTER_RIGHT:
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		c.grow_vertical = Control.GROW_DIRECTION_BOTH
	elif preset == Control.PRESET_CENTER_LEFT:
		c.grow_vertical = Control.GROW_DIRECTION_BOTH
	elif preset == Control.PRESET_CENTER:
		c.grow_horizontal = Control.GROW_DIRECTION_BOTH
		c.grow_vertical = Control.GROW_DIRECTION_BOTH


func _clear_ui() -> void:
	for c in ui.get_children():
		c.queue_free()
	w.clear()


# ================= menu =================
func _show_menu() -> void:
	if sfx != null:
		sfx.stop_all_loops()
	if vfx != null:
		vfx.setup_ambient("")
	_clear_ui()
	game = null
	board.g = null
	board.visible = false
	var bg = ColorRect.new()
	bg.color = Color("#060a16")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var p = _panel(ui)
	_place(p, Control.PRESET_CENTER)
	var v = _vbox(p, 12)
	_label(v, "HEX GALAXIES", 64, C_GOLD)
	_label(v, "Estratégia por turnos em hexágonos · protótipo Godot", 16, Color("#8fb8cc"))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	_label(grid, "Mapa")
	var om = OptionButton.new()
	for id in ["tarhut", "posto"]:
		om.add_item(DB.maps[id]["name"])
		om.set_item_metadata(om.item_count - 1, id)
	om.selected = 0 if setup_cfg["map"] == "tarhut" else 1
	om.item_selected.connect(func(i): setup_cfg["map"] = om.get_item_metadata(i))
	grid.add_child(om)
	var facs = DB.factions.keys()
	for row in [["Seu exército", "fac"], ["Exército da CPU", "cpu"]]:
		_label(grid, row[0])
		var of = OptionButton.new()
		for f in facs:
			of.add_item(DB.factions[f]["name"])
			of.set_item_metadata(of.item_count - 1, f)
		of.selected = facs.find(setup_cfg[row[1]])
		var key_name = row[1]
		of.item_selected.connect(func(i): setup_cfg[key_name] = of.get_item_metadata(i))
		grid.add_child(of)
	_label(v, "Você escolhe as 5 peças do seu exército; o Comandante é o da facção.\nO exército da CPU é sorteado.", 14, Color("#8fb8cc"))
	_button(v, "Montar exército", _show_army)


# ================= montar exército =================
func _army_pool() -> Array:
	return DB.card_list.filter(func(c): return c["f"] == setup_cfg["fac"] and not c.get("cmd", false))


func _show_army() -> void:
	if army_fac != setup_cfg["fac"]:
		army_fac = setup_cfg["fac"]
		army_picks = []
		army_start = []
	_clear_ui()
	var bg = ColorRect.new()
	bg.color = Color("#060a16")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var root = _vbox(ui, 10)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	# topo
	var top = _hbox(root, 14)
	var fac = DB.factions[setup_cfg["fac"]]
	var cmd_id = fac["cmd"]
	if DB.portraits.has(cmd_id):
		var ci = TextureRect.new()
		ci.texture = DB.portraits[cmd_id]
		ci.custom_minimum_size = Vector2(72, 72)
		ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top.add_child(ci)
	var tv = _vbox(top, 2)
	_label(tv, "Monte seu exército · %s" % fac["name"], 28, C_GOLD)
	var cname = DB.cards[cmd_id]["name"] if DB.cards.has(cmd_id) else cmd_id
	_label(tv, "Comandante: %s (entra no round 6). Escolha 5 peças e marque 2 para começar em campo." % cname, 15, Color("#8fb8cc"))
	# corpo: grade de peças + coluna do exército
	var body = _hbox(root, 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sc = ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	for c in _army_pool():
		grid.add_child(_army_tile(c))
	# coluna direita
	var side = _panel(body)
	side.custom_minimum_size = Vector2(360, 0)
	var sv = _vbox(side, 8)
	_label(sv, "Seu exército  %d/5" % army_picks.size(), 22, C_GOLD)
	_label(sv, "★ = começa em campo (%d/2)" % army_start.size(), 14, Color("#8fb8cc"))
	for id in army_picks:
		var c = DB.cards[id]
		var row = _hbox(sv, 8)
		if DB.portraits.has(id):
			var pi = TextureRect.new()
			pi.texture = DB.portraits[id]
			pi.custom_minimum_size = Vector2(44, 44)
			pi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(pi)
		var nl = _label(row, "%s\n%s" % [c["name"], c["role"]], 14)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var on = army_start.has(id)
		var sb = _button(row, "★ Em campo" if on else "☆ Reserva", _army_star.bind(id))
		if on:
			sb.add_theme_color_override("font_color", C_GOLD)
		_button(row, "✕", _army_toggle.bind(id))
	for i in range(5 - army_picks.size()):
		_label(sv, "— vaga livre —", 14, Color("#6f6458"))
	var sp = Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(sp)
	var ready_ok = army_picks.size() == 5 and army_start.size() == 2
	var hint = ""
	if army_picks.size() < 5:
		hint = "Escolha mais %d peça(s)." % (5 - army_picks.size())
	elif army_start.size() < 2:
		hint = "Marque mais %d peça(s) com ★ para começar em campo." % (2 - army_start.size())
	if hint != "":
		_label(sv, hint, 14, Color("#ff9a5a"))
	var br = _hbox(sv, 8)
	_button(br, "Voltar", _show_menu)
	_button(br, "Sortear", _army_random)
	_button(br, "Limpar", _army_clear)
	var go = _button(sv, "Começar partida", _army_go)
	go.disabled = not ready_ok
	go.add_theme_font_size_override("font_size", 22)


func _army_tile(c: Dictionary) -> Control:
	var id = c["id"]
	var chosen = army_picks.has(id)
	var b = Button.new()
	b.toggle_mode = true
	b.button_pressed = chosen
	b.custom_minimum_size = Vector2(250, 120)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "%s — %s\n%s" % [c["ab"]["name"], "ativa (1 ação)" if c["k"].has("action") else "passiva", c["ab"]["text"]]
	b.pressed.connect(_army_toggle.bind(id))
	if army_picks.size() >= 5 and not chosen:
		b.modulate = Color(1, 1, 1, 0.45)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	var pi = TextureRect.new()
	pi.custom_minimum_size = Vector2(96, 96)
	pi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DB.portraits.has(id):
		pi.texture = DB.portraits[id]
	hb.add_child(pi)
	var v = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	hb.add_child(v)
	var l1 = _label(v, ("✔ " if chosen else "") + c["name"], 16, C_GOLD if chosen else C_TXT)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l2 = _label(v, c["role"], 13, Color("#8fb8cc"))
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l3 = _label(v, "Vida %d  Atq %d\nMov %d  Alc %d" % [int(c["int"]), int(c["atk"]), int(c["mov"]), int(c["alc"])], 13)
	l3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l4 = _label(v, c["ab"]["name"], 12, Color("#9fc6c2"))
	l4.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _army_toggle(id: String) -> void:
	if army_picks.has(id):
		army_picks.erase(id)
		army_start.erase(id)
	elif army_picks.size() < 5:
		army_picks.append(id)
		if army_start.size() < 2:
			army_start.append(id)
	if sfx != null:
		sfx.play("clique", -8.0)
	_show_army()


func _army_star(id: String) -> void:
	if army_start.has(id):
		army_start.erase(id)
	elif army_start.size() < 2:
		army_start.append(id)
	else:
		army_start.pop_front()
		army_start.append(id)
	if sfx != null:
		sfx.play("clique", -8.0)
	_show_army()


func _army_random() -> void:
	var x = AI.setup(setup_cfg["fac"])["picks"]
	for id in x:
		if army_picks.size() < 5 and not army_picks.has(id):
			army_picks.append(id)
	var pool = _army_pool()
	pool.shuffle()
	for c in pool:
		if army_picks.size() < 5 and not army_picks.has(c["id"]):
			army_picks.append(c["id"])
	if army_start.size() < 2:
		var tough = army_picks.filter(func(i): return not army_start.has(i))
		tough.sort_custom(func(a, b): return int(DB.cards[a]["int"]) > int(DB.cards[b]["int"]))
		for i in tough:
			if army_start.size() < 2:
				army_start.append(i)
	_show_army()


func _army_clear() -> void:
	army_picks = []
	army_start = []
	_show_army()


func _army_go() -> void:
	if sfx != null:
		sfx.play("confirmar", -6.0)
	var spots = DB.entry[0]
	var mine = {"fac": setup_cfg["fac"], "picks": army_picks.duplicate(), "start": [{"id": army_start[0], "h": spots[0]}, {"id": army_start[1], "h": spots[spots.size() - 1]}]}
	_start_match([mine, _cpu_side(1, setup_cfg["cpu"])])


func _cpu_side(p: int, fac: String) -> Dictionary:
	var s = AI.setup(fac)
	var tough = s["picks"].duplicate()
	tough.sort_custom(func(a, b): return int(DB.cards[a]["int"]) > int(DB.cards[b]["int"]))
	var spots = DB.entry[p]
	s["start"] = [{"id": tough[0], "h": spots[0]}, {"id": tough[1], "h": spots[spots.size() - 1]}]
	return s


func _start_match(sides) -> void:
	if sides == null:
		sides = []
		for p in range(2):
			var fac = setup_cfg["fac"] if p == 0 else setup_cfg["cpu"]
			var s = AI.setup(fac)
			var tough = s["picks"].duplicate()
			tough.sort_custom(func(a, b): return int(DB.cards[a]["int"]) > int(DB.cards[b]["int"]))
			var spots = DB.entry[p]
			s["start"] = [{"id": tough[0], "h": spots[0]}, {"id": tough[1], "h": spots[spots.size() - 1]}]
			sides.append(s)
	last_sides = sides
	game = Game.new()
	game.tree = get_tree()
	game.cpu = [autotest, true]
	game.setup(sides, setup_cfg["map"])
	game.question.connect(_on_question)
	game.changed.connect(refresh)
	game.fx_event.connect(_on_fx)
	sel = -1
	dsel = -1
	pend = null
	am = ""
	ab = false
	tip = null
	inspect = -1
	hex_info = null
	asking = null
	busy = true
	running = false
	panel_open = ""
	_build_hud()
	board.visible = true
	board.build(game)
	vfx.setup_ambient(game.map_id)
	sfx.stop_all_loops()
	if game.map_id == "tarhut":
		sfx.loop("vento_loop", -15.0, 2.0)
		sfx.loop("musica_deserto", -9.0, 4.0)
	else:
		sfx.loop("ilha_loop", -10.0, 2.0)
	refresh()
	await game.begin_game()
	busy = false
	await after()


# ================= HUD da batalha =================
func _build_hud() -> void:
	_clear_ui()
	# coluna do alto: título, avisos de ação e perguntas
	var topcol = _vbox(ui, 4)
	_place(topcol, Control.PRESET_CENTER_TOP, 6)
	topcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top = _panel(topcol)
	var tv = _vbox(top, 2)
	w["title"] = _label(tv, "", 22, C_GOLD)
	w["title"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["events"] = _label(tv, "", 14, Color("#ffcf9a"))
	w["events"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# botões do canto
	var topr = _hbox(ui, 6)
	_place(topr, Control.PRESET_TOP_RIGHT, 8)
	_button(topr, "Cartas", func(): _toggle_panel("cards"))
	_button(topr, "Registro", func(): _toggle_panel("log"))
	_button(topr, "Regras", func(): _toggle_panel("rules"))
	_button(topr, "Menu", _show_menu)
	# câmera: linha compacta acima do painel de fim de turno
	var camv = _hbox(ui, 4)
	_place(camv, Control.PRESET_BOTTOM_RIGHT, 8)
	camv.offset_top -= 168
	camv.offset_bottom -= 168
	for cb in [["<", func(): board.rotate_cam(-1), "Girar a câmera"], [">", func(): board.rotate_cam(1), "Girar a câmera"], ["+", func(): board.zoom_cam(0.7), "Aproximar (roda do mouse)"], ["-", func(): board.zoom_cam(1.4), "Afastar (roda do mouse)"], ["Tudo", func(): board.fit_camera(false), "Ver o tabuleiro inteiro"]]:
		var bb = _button(camv, cb[0], cb[1])
		bb.tooltip_text = cb[2]
		bb.custom_minimum_size = Vector2(44, 40)
		# no toque (Android/tablet) a câmera é só por gestos; fica só o "Tudo"
		if _is_touch() and cb[0] != "Tudo":
			bb.visible = false
	# colunas de peças
	var left = _panel(ui)
	_place(left, Control.PRESET_CENTER_LEFT, 8)
	w["party0"] = _vbox(left, 4)
	# avisos de ação (no alto)
	var aw = _panel(topcol)
	aw.add_theme_stylebox_override("panel", _tex_box("res://ui/panel_soft.png", 22, C_HUD, 16, 8))
	var av = _vbox(aw, 4)
	w["note"] = _label(av, "", 16)
	w["note"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["why"] = _label(av, "", 13, Color("#ffcf9a"))
	w["why"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["why"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["why"].custom_minimum_size = Vector2(560, 0)
	var lg = _hbox(av, 14)
	lg.alignment = BoxContainer.ALIGNMENT_CENTER
	_chip(lg, C_MOVE, "Andar (nº = custo)")
	_chip(lg, C_ATK, "Atacar")
	_chip(lg, C_ABIL, "Habilidade / escolher")
	_chip(lg, C_DEPLOY, "Entrar em campo")
	_chip(lg, Color(0.12, 0.1, 0.08), "Fora de alcance (clique: por quê?)")
	w["legend"] = lg
	# perguntas e prévias (logo abaixo dos avisos)
	var pr = _panel(topcol)
	pr.custom_minimum_size = Vector2(560, 0)
	var pv = _vbox(pr, 8)
	w["prompt_text"] = _rich(pv, 540)
	w["prompt_btns"] = _hbox(pv, 8)
	w["prompt_btns"].alignment = BoxContainer.ALIGNMENT_END
	w["prompt"] = pr
	# ficha da peça
	var uc = _panel(ui)
	_place(uc, Control.PRESET_BOTTOM_LEFT, 8)
	w["ucard_text"] = _rich(uc, 320)
	w["ucard"] = uc
	# embaixo: mão de cartas + botões de ação
	var botcol = _vbox(ui, 6)
	_place(botcol, Control.PRESET_CENTER_BOTTOM, 8)
	botcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# prévia/perguntas logo acima das cartas
	w["prompt"].reparent(botcol)
	w["prompt"].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	w["hand"] = _hbox(botcol, 6)
	w["hand"].alignment = BoxContainer.ALIGNMENT_CENTER
	var ab_p = _panel(botcol)
	w["abp"] = ab_p
	var abv = _vbox(ab_p, 4)
	w["btns"] = _hbox(abv, 6)
	w["btns"].alignment = BoxContainer.ALIGNMENT_CENTER
	# camada dos balões de fala
	var bub = Control.new()
	bub.set_anchors_preset(Control.PRESET_FULL_RECT)
	bub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bub)
	w["bubbles"] = bub
	# fim de turno
	var eb = _panel(ui)
	_place(eb, Control.PRESET_BOTTOM_RIGHT, 8)
	var ev = _vbox(eb, 6)
	w["round"] = _label(ev, "", 28, C_GOLD)
	w["round"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["turn"] = _label(ev, "", 14)
	w["turn"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["end"] = _button(ev, "Passar", _on_end_pressed)
	w["end"].custom_minimum_size = Vector2(170, 52)
	# coluna da CPU (à direita, acima do fim de turno)
	var right = _panel(ui)
	_place(right, Control.PRESET_TOP_RIGHT, 8)
	right.offset_top = 64
	w["party1"] = _vbox(right, 4)
	# painel lateral (cartas / registro / regras)
	var side = _panel(ui)
	_place(side, Control.PRESET_CENTER, 0)
	side.custom_minimum_size = Vector2(620, 0)
	var sv = _vbox(side, 10)
	w["side_title"] = _label(sv, "", 26, C_GOLD)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 420)
	sv.add_child(scroll)
	w["side_body"] = _vbox(scroll, 8)
	w["side_body"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(sv, "Fechar", func(): _toggle_panel(""))
	w["side"] = side
	side.visible = false
	# arraste de reserva
	var dr = TextureRect.new()
	dr.custom_minimum_size = Vector2(70, 70)
	dr.size = Vector2(70, 70)
	dr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dr.visible = false
	ui.add_child(dr)
	w["drag_icon"] = dr
	# faixa de anúncios
	var bn = Label.new()
	bn.add_theme_font_size_override("font_size", 64)
	if font_title != null:
		bn.add_theme_font_override("font", font_title)
	bn.add_theme_constant_override("outline_size", 14)
	bn.add_theme_color_override("font_outline_color", Color.BLACK)
	bn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bn)
	_place(bn, Control.PRESET_CENTER, 0)
	bn.modulate.a = 0.0
	w["banner"] = bn


func banner(big: String, small: String = "") -> void:
	var bn: Label = w.get("banner", null)
	if bn == null:
		return
	bn.text = big + ("\n" + small if small != "" else "")
	bn.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(bn, "modulate:a", 0.0, 0.6)


func _toggle_panel(which: String) -> void:
	panel_open = "" if panel_open == which else which
	_refresh_side()


# ================= estado do jogador =================
func viewer() -> int:
	return 0


# ---- colocar reservas em campo: quando e onde ----
func can_deploy_now() -> bool:
	return my_turn() and game.act == null and not game.reserve_of(0).is_empty() and not game.deploy_hexes(0).is_empty()


func deploy_block_reason() -> String:
	if game.reserve_of(0).is_empty():
		return "Sem reservas: todas as suas peças já estão em campo."
	if game.winner != Game.NONE:
		return "Fim de jogo."
	if game.cpu[game.cur] or busy:
		return "Aguarde a sua vez para colocar reservas."
	if game.act != null:
		return "Termine a ativação de %s (botão Encerrar ativação) para colocar uma reserva." % game.nm(game.active_unit())
	if game.deploy_hexes(0).is_empty():
		return "Sua entrada está lotada: tire uma peça de lá para abrir espaço."
	return ""


func my_turn() -> bool:
	return game != null and game.winner == Game.NONE and not game.cpu[game.cur] and not busy and asking == null


func sel_unit() -> Variant:
	return game.by_uid(sel) if sel >= 0 else null


func act_unit() -> Variant:
	return game.active_unit() if game.act != null else null


func sel_or_act() -> Variant:
	var a = act_unit()
	if a != null:
		return a
	var u = sel_unit()
	if u != null and game.can_start(u):
		return u
	return null


func can_drag_unit(u) -> bool:
	return my_turn() and u.owner == game.cur and not u.barrier and (game.can_start(u) or game.is_live(u))


func highlights() -> Dictionary:
	var H = {"mv": [], "at": [], "pk": [], "ghost": null}
	if asking != null and asking["q"]["t"] == "hex":
		H["pk"] = asking["q"]["opts"]
		return H
	if not my_turn():
		return H
	if dsel >= 0:
		H["pk"] = game.deploy_hexes(game.cur)
		return H
	var u = sel_unit()
	if u == null or u.owner != game.cur or u.st != "field":
		return H
	var live = game.is_live(u)
	if not live and not game.can_start(u):
		return H
	if ab:
		if game.K(u).get("action", "") == "tunnel":
			H["pk"] = game.tunnel_opts(u)
		else:
			H["pk"] = [u.pos()]
			if not (live and game.act["moved"]):
				for m in game.move_opts(u, game.mov_of(u)):
					H["pk"].append(m["h"])
		if pend != null and pend["kind"] == "ab":
			H["ghost"] = pend["h"]
		return H
	var acts = game.act["actions"] if live else 2
	var can_atk = not live or (not game.act["attacked"] and not game.act["cant_attack"])
	if acts > 0 and not game.rooted(u) and not (live and game.act["moved"]):
		H["mv"] = game.move_opts(u, game.mov_of(u))
	var pm = _pend_move()
	if pm != null:
		H["ghost"] = pm["h"]
		if acts - 1 > 0 and can_atk:
			for t in game.attack_targets(u, pm["h"]):
				H["at"].append(t.pos())
	elif acts > 0 and can_atk:
		for t in game.attack_targets(u):
			H["at"].append(t.pos())
	if am == "mv":
		H["at"] = []
	if am == "at":
		H["mv"] = []
	return H


func _pend_move() -> Variant:
	if pend != null and (pend["kind"] == "move" or pend["kind"] == "moveatk"):
		return pend
	return null


# ================= redesenho =================
func refresh() -> void:
	if game == null or not w.has("title"):
		return
	var H = highlights()
	var st = {"hl": {}, "lit": null, "labels": {}, "label_colors": {}, "tags": {}, "sel_uid": -1, "ghost": null}
	for p in range(2):
		for h in DB.entry[p]:
			st["hl"][h] = "entry%d" % p
	if can_deploy_now() or dsel >= 0 or (res_drag != null and res_drag.get("on", false)):
		for h in game.deploy_hexes(0):
			st["hl"][h] = "deploy"
			st["labels"][h] = "+ ENTRAR"
			st["label_colors"][h] = C_DEPLOY.lightened(0.4)
	for h in game.tremors:
		st["hl"][h] = "trem"
		st["labels"][h] = "!"
		st["label_colors"][h] = Color("#ffe39a")
	if game.dune_next >= 0:
		var nd = game.dune_heights(game.dune_next)
		for h in nd.keys():
			st["hl"][h] = "dnext"
			st["labels"][h] = "vai p/ %d" % nd[h]
			st["label_colors"][h] = Color("#9ff0ff")
	var su = sel_unit()
	var focus = my_turn() and ((su != null and su.owner == game.cur and su.st == "field" and (game.can_start(su) or game.is_live(su))) or dsel >= 0)
	if focus:
		var lit = {}
		for m in H["mv"]:
			lit[m["h"]] = true
		for h in H["at"]:
			lit[h] = true
		for h in H["pk"]:
			lit[h] = true
		if su != null and dsel < 0:
			lit[su.pos()] = true
		if H["ghost"] != null:
			lit[H["ghost"]] = true
		st["lit"] = lit
	for m in H["mv"]:
		st["hl"][m["h"]] = "mv"
		if m["c"] > 0:
			st["labels"][m["h"]] = str(m["c"])
			st["label_colors"][m["h"]] = Color.WHITE
	for h in H["at"]:
		st["hl"][h] = "at"
	for h in H["pk"]:
		st["hl"][h] = "pk"
	if su != null and su.st == "field":
		st["hl"][su.pos()] = "prev" if H["ghost"] != null else "sel"
		st["sel_uid"] = su.uid
	if H["ghost"] != null:
		st["hl"][H["ghost"]] = "sel"
		st["ghost"] = H["ghost"]
	if pend != null and pend.has("tuid"):
		var tt = game.by_uid(pend["tuid"])
		if tt != null:
			st["hl"][tt.pos()] = "tgt"
	if tip != null:
		if tip.has("hex"):
			st["hl"][tip["hex"]] = "no"
		if tip.get("block", null) != null:
			st["hl"][tip["block"]] = "no"
	# etiquetas sobre os inimigos
	var att = su
	var foe_view = att != null and my_turn() and att.owner == game.cur and att.st == "field" and (game.can_start(att) or game.is_live(att))
	if foe_view:
		var fpos = H["ghost"] if (H["ghost"] != null and not ab) else null
		for t in game.field():
			if t.owner == att.owner or t.barrier:
				continue
			if H["at"].has(t.pos()):
				var pv = game.preview_damage(att, t, fpos)
				var tx = "-%d" % pv["dmg"]
				if pv["high"]:
					tx += " (do alto)"
				if pv["cover"]:
					tx += " (abrigado)"
				if pv["kills"]:
					tx += " DERRUBA"
				st["tags"][t.uid] = {"text": tx, "color": C_ATK.lightened(0.25)}
			else:
				var wn = game.why_no_attack(att, t, fpos)
				if wn != null:
					st["tags"][t.uid] = {"text": wn["s"], "color": Color("#ffd9b0")}
	last_st = st
	board.set_state(_with_card_hover(st))
	_refresh_top()
	_refresh_party()
	_refresh_ucard()
	_refresh_actbar()
	_refresh_hand()
	_refresh_prompt()
	_refresh_side()


func _refresh_top() -> void:
	var who = "Você" if game.cur == 0 else "CPU"
	var status = "Fim de jogo" if game.winner != Game.NONE else ("Sua vez" if game.cur == 0 else ("Vez da CPU" + (" (jogando...)" if busy else "")))
	w["title"].text = "%s  ·  Round %d/10  ·  %s" % [game.map_name, game.round_no, status]
	var tcol = C_GOLD if game.winner != Game.NONE else (C_YOU if game.cur == 0 else C_CPU)
	w["title"].add_theme_color_override("font_color", tcol)
	var ev = []
	var def = DB.maps[game.map_id]
	if def.has("dunes"):
		if game.dune_next >= 0:
			ev.append("DUNAS MUDAM NO PRÓXIMO ROUND")
		else:
			var nd = game.round_no + 1
			while (nd - 1) % Game.DUNE_EVERY != 0:
				nd += 1
			if nd <= 10:
				ev.append("Dunas mudam no round %d" % nd)
	if def.get("worms", false):
		if not game.tremors.is_empty():
			ev.append("TREMOR: VERMES NO PRÓXIMO ROUND")
		else:
			var wr = game.round_no + 1
			while wr % Game.WORM_EVERY != 0:
				wr += 1
			if wr <= 10:
				ev.append("Vermes no round %d" % wr)
	w["events"].text = "   ·   ".join(ev)
	w["round"].text = "Round %d/10" % game.round_no
	w["turn"].text = "SUA VEZ" if game.cur == 0 else "VEZ DA CPU"
	w["turn"].add_theme_color_override("font_color", C_YOU if game.cur == 0 else C_CPU)
	w["turn"].add_theme_font_size_override("font_size", 18)
	if font_title != null:
		w["turn"].add_theme_font_override("font", font_title)


func _refresh_party() -> void:
	for p in range(2):
		var box: VBoxContainer = w["party%d" % p]
		for c in box.get_children():
			c.queue_free()
		_label(box, ("VOCÊ · " if p == 0 else "CPU · ") + DB.factions[game.P[p]["fac"]]["short"], 13, Color("#4f9be0") if p == 0 else Color("#e0563f"))
		var dep_ok = p == 0 and can_deploy_now()
		var shown_res_head = false
		for u in game.units:
			if u.owner != p or u.barrier:
				continue
			if p == 0 and u.st == "reserve" and not shown_res_head:
				shown_res_head = true
				var hd = PanelContainer.new()
				var sbx = StyleBoxFlat.new()
				sbx.bg_color = C_DEPLOY.darkened(0.1) if dep_ok else Color(0.25, 0.22, 0.2, 0.9)
				sbx.set_corner_radius_all(6)
				sbx.set_content_margin_all(6)
				hd.add_theme_stylebox_override("panel", sbx)
				box.add_child(hd)
				var hl = Label.new()
				hl.autowrap_mode = TextServer.AUTOWRAP_WORD
				hl.custom_minimum_size = Vector2(190, 0)
				hl.add_theme_font_size_override("font_size", 12)
				if dep_ok:
					hl.text = "PODE COLOCAR EM CAMPO\nClique ou arraste um retrato até uma casa CIANO \"+ ENTRAR\" (1 ação)."
					hl.add_theme_color_override("font_color", Color("#06201e"))
				else:
					hl.text = "RESERVA\n" + deploy_block_reason()
					hl.add_theme_color_override("font_color", Color("#8fb8cc"))
				hd.add_child(hl)
			var stx = "caiu"
			if u.st == "field":
				stx = "usado" if u.activated else "pronto"
			elif u.st == "reserve":
				stx = "▶ pode entrar" if (p == 0 and dep_ok) else "reserva"
			elif u.st == "off":
				stx = "round 6"
			var b = Button.new()
			b.text = "%s\nVida %d/%d · %s" % [DB.cards[u.cid]["name"], max(0, u.hp), u.maxhp, stx]
			b.add_theme_font_size_override("font_size", 12)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(190, 52)
			if DB.portraits.has(u.cid):
				b.icon = DB.portraits[u.cid]
				b.expand_icon = true
			if u.st == "dead":
				b.modulate = Color(0.5, 0.5, 0.5)
			elif u.st == "reserve" and p == 0 and dep_ok:
				b.add_theme_color_override("font_color", C_DEPLOY.lightened(0.5))
				var gsb = StyleBoxFlat.new()
				gsb.bg_color = C_DEPLOY.darkened(0.7)
				gsb.border_color = C_DEPLOY
				gsb.set_border_width_all(3)
				gsb.set_corner_radius_all(6)
				b.add_theme_stylebox_override("normal", gsb)
				b.tooltip_text = "Clique e depois escolha uma casa ciano da sua entrada, ou arraste até ela. Gasta 1 ação."
			elif u.st == "reserve" or u.st == "off" or u.activated:
				b.modulate = Color(0.82, 0.82, 0.82)
				if u.st == "reserve" and p == 0:
					b.tooltip_text = deploy_block_reason()
			if u.uid == sel or u.uid == dsel or u.uid == inspect:
				b.modulate = Color(1.2, 1.1, 0.7)
			var uid = u.uid
			b.pressed.connect(func(): _on_roster(uid))
			if p == 0 and u.st == "reserve":
				b.button_down.connect(func(): _start_res_drag(uid))
			box.add_child(b)


func _refresh_ucard() -> void:
	var u = sel_unit()
	if u == null and inspect >= 0:
		u = game.by_uid(inspect)
	var txt = ""
	if u != null:
		if u.barrier:
			txt = "[b]Barreira[/b]\nVida %d/%d\nBloqueia passagem e tiros. Pode ser atacada." % [u.hp, u.maxhp]
		else:
			var c = DB.cards[u.cid]
			var fcol = DB.factions[c["f"]]["color"]
			txt = "[color=%s]%s[/color] · %s\n[font_size=24][b]%s[/b][/font_size]\n" % [fcol, DB.factions[c["f"]]["name"].to_upper(), "Você" if u.owner == 0 else "CPU", c["name"]]
			txt += "%s\n[b]Vida[/b] %d/%d   [b]Ataque[/b] %d   [b]Movimento[/b] %d   [b]Alcance[/b] %d\n" % [c["role"], max(0, u.hp), u.maxhp, game.atk_of(u, null), game.mov_of(u), game.alc_of(u)]
			if u.st == "field":
				txt += "[i]%s[/i]\n" % game.t_name(u.pos())
			elif u.st == "reserve":
				txt += "[i]Na reserva (arraste para a entrada)[/i]\n"
			elif u.st == "off":
				txt += "[i]Entra no round 6[/i]\n"
			if u.eq != "":
				txt += "Equipado: %s\n" % DB.tactics[u.eq]["name"]
			var passive = "ativa (gasta 1 ação)" if c["k"].has("action") else "passiva (não gasta ação)"
			txt += "[color=#ffab40][b]%s[/b][/color] [color=#8fb8cc](%s)[/color]\n%s" % [c["ab"]["name"], passive, c["ab"]["text"]]
			if c.has("ab2"):
				var a2 = c["ab2"]
				var kind2 = "passiva (não gasta ação)" if a2.get("kind", "") == "passiva" else ("ativa · 1 vez por partida · 1 ação" + (" · [color=#ff8a6a]JÁ USADA[/color]" if u.ult_used else ""))
				txt += "\n[color=#ffab40][b]★ %s[/b][/color] [color=#8fb8cc](%s)[/color]\n%s" % [a2["name"], kind2, a2["text"]]
			if game.imprisoned(u):
				txt += "\n[color=#9fdcff]Preso na Prisão de Cristal até o fim do próximo round.[/color]"
	elif hex_info != null:
		var t = game.terr(hex_info)
		var tt = game.tt_of(t["k"])
		txt = "[b]%s[/b]\nAltura %d · %s\n%s" % [tt["name"], t["h"], ("custo para andar %d" % tt["c"]) if tt.get("pass", 0) else "não dá para entrar", TDESC.get(t["k"], "")]
		var o = DB.obj_at(hex_info)
		if o != null:
			txt += "\n[color=#ffab40]Objetivo %s:[/color] %s" % [o["name"], o["text"]]
		if game.res.has(hex_info):
			var rr = DB.res[game.res[hex_info]]
			txt += "\n[color=#5ec8f0]Recurso %s:[/color] %s (coletar gasta 1 ação)" % [rr["name"], rr["text"]]
		if game.tremors.has(hex_info):
			txt += "\n[color=#ffb14a]A areia treme: um buraco de verme abre aqui no próximo round.[/color]"
	w["ucard"].visible = txt != ""
	w["ucard_text"].text = txt


func _refresh_actbar() -> void:
	var box: HBoxContainer = w["btns"]
	for c in box.get_children():
		c.queue_free()
	var mine = my_turn()
	var u = sel_or_act() if mine else null
	var note = ""
	var why = []
	if not mine:
		if game.winner != Game.NONE:
			note = "Fim de jogo"
		elif asking != null:
			note = "Responda à pergunta"
		else:
			note = "A CPU está jogando..." if game.cpu[game.cur] else "Aguarde"
	elif dsel >= 0:
		note = "Escolha uma casa CIANO da sua entrada (entrar gasta 1 ação)"
	elif u == null:
		if game.act != null:
			note = "Sem ações restantes: clique em Encerrar"
		elif can_deploy_now():
			note = "1) Clique numa peça sua  —  ou  —  coloque uma reserva numa casa CIANO \"+ ENTRAR\""
		else:
			note = "1) Clique numa peça sua para ativá-la"
	if u != null:
		var live = game.is_live(u)
		var left = game.act["actions"] if live else 2
		var attacked = live and game.act["attacked"]
		var cant = live and game.act["cant_attack"]
		var n_t = game.attack_targets(u).size()
		var moved = live and game.act["moved"]
		var can_mv = left > 0 and not moved and not game.rooted(u) and not game.move_opts(u, game.mov_of(u)).is_empty()
		var can_at = left > 0 and not attacked and not cant and n_t > 0
		note = "%s  ·  Ações: %s  ·  2) escolha o que fazer" % [DB.cards[u.cid]["name"], "●".repeat(left) + "○".repeat(max(0, 2 - left))]
		var bm = _cbtn(box, "Mover" + (" (feito)" if moved else ""), C_MOVE, func(): _set_am("mv"), am == "mv")
		bm.disabled = not can_mv
		bm.tooltip_text = "Mover: 1 ação, no máximo 1 vez por turno. Casas VERDES."
		var ba = _cbtn(box, "Atacar" + (" (feito)" if attacked else ""), C_ATK, func(): _set_am("at"), am == "at")
		ba.disabled = not can_at
		ba.tooltip_text = "Atacar: 1 ação, no máximo 1 vez por turno. Inimigos em VERMELHO."
		var k = game.K(u)
		if k.has("action"):
			var bab = _cbtn(box, DB.cards[u.cid]["ab"]["name"], C_ABIL, func(): _toggle_ab(), ab)
			bab.disabled = left <= 0 or (moved and k.get("action", "") == "tunnel")
			bab.tooltip_text = "Habilidade ativa: 1 ação. Casas ROXAS."
		if k.has("ult") and DB.cards[u.cid].has("ab2"):
			var ok_ult = (game.can_ult(u) if live else (game.can_start(u) and not u.ult_used and not game.ult_opts(u).is_empty()))
			var bu = _cbtn(box, "★ " + DB.cards[u.cid]["ab2"]["name"], C_ABIL, _on_ult)
			bu.disabled = not ok_ult or left <= 0
			bu.tooltip_text = "Ativa do comandante · 1 vez por partida · 1 ação\n" + DB.cards[u.cid]["ab2"]["text"]
			if u.ult_used:
				why.append("%s: já usada nesta partida." % DB.cards[u.cid]["ab2"]["name"])
		if game.res.has(u.pos()):
			var bc = _button(box, "Pegar " + DB.res[game.res[u.pos()]]["name"].split(" ")[0], _on_collect)
			bc.disabled = left <= 0
		var o = DB.obj_at(u.pos())
		if o != null:
			var bo = _button(box, o["name"], _on_interact)
			bo.disabled = left <= 0 or game.P[u.owner]["obj_used"].has(o["id"])
		if left < 1:
			why.append("Sem ações: o turno passa para o rival.")
		else:
			if not can_mv:
				why.append("Mover: já se moveu neste turno (máx. 1)." if moved else ("Mover: está preso." if game.rooted(u) else "Mover: nenhuma casa livre ao alcance."))
			if not can_at:
				why.append("Atacar: já atacou neste turno (máx. 1)." if attacked else ("Atacar: não pode neste turno." if cant else "Atacar: nenhum inimigo ao alcance. Clique num inimigo para ver o porquê."))
			if not k.has("action") and not u.barrier:
				why.append("%s é passiva: funciona sozinha." % DB.cards[u.cid]["ab"]["name"])
	if mine and game.act == null and can_deploy_now():
		var bres = _cbtn(box, "+ Colocar reserva (%d)" % game.reserve_of(0).size(), C_DEPLOY, _pick_first_reserve, dsel >= 0)
		bres.tooltip_text = "Escolhe a primeira reserva; depois clique numa casa ciano da entrada. Para escolher outra, clique no retrato dela à esquerda."
	var tac_ok = false
	if mine:
		tac_ok = _any_card_playable()
	if tac_ok:
		why.push_front("Há carta tática que dá para jogar agora (cartas embaixo).")
	w["note"].text = note
	if w.has("abp"):
		w["abp"].visible = u != null
	w["why"].text = "  ·  ".join(why)
	w["legend"].visible = mine and (u != null or dsel >= 0)
	var e = w["end"]
	e.text = "Encerrar ativação" if (game.act != null and mine) else "Passar o round"
	e.disabled = not mine
	var nothing_left = game.act != null and mine and game.act["actions"] <= 0
	_style_btn(e, C_GOLD if nothing_left else C_END, nothing_left)


func _refresh_prompt() -> void:
	var box: HBoxContainer = w["prompt_btns"]
	for c in box.get_children():
		c.queue_free()
	var text = ""
	if asking != null:
		var q = asking["q"]
		text = "[b]%s[/b]" % q.get("text", "")
		match q["t"]:
			"hex":
				text += "\n[color=#8fb8cc](clique numa casa [color=#b06cff][b]ROXA[/b][/color])[/color]"
				if q.get("optional", false):
					_button(box, "Pular", func(): _answer(null))
			"yesno":
				if q.has("show"):
					text += "\n" + _cards_text(q["show"])
				var mull = q.get("kind", "") == "mulligan"
				var ea = q.get("kind", "") == "earth"
				_button(box, "Manter a mão" if mull else ("▼ Descer" if ea else "Não"), func(): _answer(false))
				_button(box, "Trocar a mão" if mull else ("▲ Subir" if ea else "Sim"), func(): _answer(true))
			"card":
				for id in q["opts"]:
					var cid = id
					var bt = _button(box, DB.tactics[id]["name"], func(): _answer(cid))
					bt.tooltip_text = DB.tactics[id]["text"]
				if q.get("optional", false):
					_button(box, "Não usar", func(): _answer(null))
			"peek":
				text += "\n" + _cards_text([q["card"]])
				_button(box, "Mandar para o fundo", func(): _answer("bottom"))
				_button(box, "Manter no topo", func(): _answer("keep"))
			"show":
				text += "\n" + (_cards_text(q["cards"]) if not q["cards"].is_empty() else "A mão está vazia.")
				_button(box, "Fechar", func(): _answer(true))
			"unitlist":
				for uid in q["opts"]:
					var u2 = game.by_uid(uid)
					var id2 = uid
					_button(box, DB.cards[u2.cid]["name"], func(): _answer(id2))
	elif dsel >= 0 and my_turn():
		text = "Escolha uma casa [color=#22d3c5][b]CIANO[/b][/color] da sua entrada para [b]%s[/b]." % DB.cards[game.by_uid(dsel).cid]["name"]
		_button(box, "Cancelar", _cancel_dsel)
	elif pend != null and my_turn() and sel_unit() != null:
		var u = sel_unit()
		var nm_u = DB.cards[u.cid]["name"]
		if pend["kind"] == "move" or pend["kind"] == "moveatk":
			text = "Prévia: [b]%s[/b] vai para %s gastando %d de %d de movimento · 1 ação." % [nm_u, game.t_name(pend["h"]), pend["cost"], game.mov_of(u)]
		if pend["kind"] == "attack" or pend["kind"] == "moveatk":
			var t = game.by_uid(pend["tuid"])
			var pv = game.preview_damage(u, t, pend["h"] if pend["kind"] == "moveatk" else null)
			var res_txt = " (derrota o alvo)" if pv["kills"] else " (fica com %d de Vida)" % (t.hp - pv["dmg"])
			text += ("\nDepois ataca " if text != "" else "Prévia: [b]%s[/b] ataca " % nm_u) + "[b]%s[/b]: %s = [color=#ffb14a][b]%d de dano[/b][/color]%s. Reações do rival podem reduzir." % [game.nm(t), " ".join(pv["parts"]), pv["dmg"], res_txt]
		if pend["kind"] == "ab":
			text = "Prévia: [b]%s[/b] para a casa marcada · 1 ação." % DB.cards[u.cid]["ab"]["name"]
		var n = 2 if pend["kind"] == "moveatk" else 1
		_cbtn(box, "Cancelar", C_END, _cancel_pend)
		_cbtn(box, "3) Confirmar (%d %s)" % [n, "ações" if n > 1 else "ação"], C_GOLD, _confirm_pend, true)
	elif ab and my_turn() and sel_or_act() != null:
		text = "Túnel: escolha uma casa livre a até 3." if game.K(sel_or_act()).get("action", "") == "tunnel" else "Escolha para onde mover (ou a própria casa); depois escolha o alvo."
		_button(box, "Cancelar", _cancel_ab)
	elif tip != null and my_turn():
		text = "[color=#ffb08a][b]Por quê?[/b][/color] " + tip["l"]
		_button(box, "Ok", _clear_tip)
	w["prompt"].visible = text != ""
	w["prompt_text"].text = text


func _pick_first_reserve() -> void:
	var rs = game.reserve_of(0)
	if rs.is_empty() or not can_deploy_now():
		return
	dsel = rs[0].uid
	sel = -1
	pend = null
	am = ""
	ab = false
	refresh()


func _cancel_dsel() -> void:
	dsel = -1
	refresh()


func _cancel_pend() -> void:
	pend = null
	refresh()


func _cancel_ab() -> void:
	ab = false
	refresh()


func _clear_tip() -> void:
	tip = null
	refresh()


func _cards_text(ids: Array) -> String:
	var parts = []
	for id in ids:
		parts.append("[color=#ffab40]%s[/color] (%s): %s" % [DB.tactics[id]["name"], DB.tactics[id]["type"], DB.tactics[id]["text"]])
	return "\n".join(parts)


func _refresh_side() -> void:
	if not w.has("side"):
		return
	w["side"].visible = panel_open != ""
	if panel_open == "":
		return
	var body: VBoxContainer = w["side_body"]
	for c in body.get_children():
		c.queue_free()
	match panel_open:
		"cards":
			var pl = game.P[0]
			w["side_title"].text = "Suas cartas · %d na mão · baralho %d" % [pl["hand"].size(), pl["deck"].size()]
			_label(body, "Jogar uma carta gasta 1 ação (reações são oferecidas sozinhas no turno do rival).", 13, Color("#8fb8cc"))
			for id in pl["hand"]:
				var t = DB.tactics[id]
				var row = _hbox(body, 8)
				var r = _rich(row, 420)
				r.text = "[color=#ffab40][b]%s[/b][/color]  [color=#8fb8cc]%s · custo %d[/color]\n%s" % [t["name"], t["type"], t["cost"], t["text"]]
				var ok = _card_playable(id)
				var cid = id
				var b = _button(row, "Jogar", func(): _play_card(cid))
				b.disabled = not ok
		"log":
			w["side_title"].text = "Registro"
			var r2 = _rich(body, 580)
			var lines = []
			var start = max(0, game.logs.size() - 80)
			for i in range(start, game.logs.size()):
				var l = game.logs[i]
				var col = "#ffab40" if l["p"] < 0 else ("#7cc0ff" if l["p"] == 0 else "#ff8a6a")
				lines.append("[color=%s]•[/color] %s" % [col, l["text"]])
			r2.text = "\n".join(lines)
		"rules":
			w["side_title"].text = "Regras e controles"
			var r3 = _rich(body, 580)
			r3.text = RULES


# ================= cartas =================
const TYPE_COL = {"Manobra": Color("#4cd964"), "Comando": Color("#4da3ff"), "Equipamento": Color("#ffab40"), "Reação": Color("#ff6ad5")}


# o que a carta afeta: texto curto + casas para destacar no tabuleiro
func _card_targets(id: String) -> Dictionary:
	var u = sel_or_act() if game != null else null
	var hs = []
	var txt = ""
	match id:
		"flanquear":
			txt = "Mapa: o ativo anda 1 casa"
			if u != null:
				hs = game.step_free(u.pos())
		"retirada":
			txt = "Reação: após atacar, recua 1 casa"
			if u != null:
				hs = game.step_free(u.pos())
		"troca":
			txt = "Ativo + aliado ao lado trocam de lugar"
			if u != null:
				for x in game.allies_of(u):
					if DB.dist(x.pos(), u.pos()) == 1:
						hs.append(x.pos())
		"avanco":
			txt = "Até 2 aliados andam 1 casa"
			for x in game.field():
				if x.owner == 0 and not x.barrier:
					hs.append(x.pos())
		"cobertura":
			txt = "Reação: aliado atacado de longe sofre -3"
		"escudo":
			txt = "Reação: aliado atacado de perto sofre -2"
		"dispersao":
			txt = "Reação: aliado atacado recua 1 casa"
		"propulsor":
			txt = "Personagem ativo: +1 Movimento"
		"placas":
			txt = "Personagem ativo: -1 dano recebido"
		"lente":
			txt = "Personagem ativo: +1 Alcance"
		"reparo":
			txt = "Personagem ativo: +4 de Vida"
		"fogo":
			txt = "Personagem ativo: +2 dano no ataque"
		"dados":
			txt = "Sua mão: compra 2, descarta 1"
		"reforco":
			txt = "Reserva que entrar: chega com 2 ações"
			hs = game.deploy_hexes(0)
		"pulso":
			txt = "Inimigo a até 2 casas perde o equipamento"
			if u != null:
				for x in game.enemies_of(u):
					if x.eq != "" and DB.dist(x.pos(), u.pos()) <= 2:
						hs.append(x.pos())
	if hs.is_empty() and u != null and ["propulsor", "placas", "lente", "reparo", "fogo"].has(id):
		hs = [u.pos()]
	return {"txt": txt, "hexes": hs}


func _with_card_hover(st: Dictionary) -> Dictionary:
	if card_hover == "" or game == null:
		return st
	var st2 = st.duplicate(true)
	for h in _card_targets(card_hover)["hexes"]:
		st2["hl"][h] = "pk"
		st2["labels"][h] = "carta"
		st2["label_colors"][h] = Color("#e0c8ff")
	return st2


func _card_hover_set(id: String, card: Control, on: bool) -> void:
	card_hover = id if on else ""
	card.pivot_offset = Vector2(card.size.x / 2.0, card.size.y)
	var tw = create_tween()
	tw.tween_property(card, "scale", Vector2(1.35, 1.35) if on else Vector2.ONE, 0.12)
	card.z_index = 10 if on else 0
	if game != null:
		board.set_state(_with_card_hover(last_st))


func _refresh_hand() -> void:
	if not w.has("hand"):
		return
	var box: HBoxContainer = w["hand"]
	for c in box.get_children():
		c.queue_free()
	if game == null:
		return
	var pl = game.P[0]
	for id in pl["hand"]:
		box.add_child(_make_card(id))
	var info = _label(box, "  Baralho\n  %d" % pl["deck"].size(), 12, C_DIM)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_card(id: String) -> Control:
	var t = DB.tactics[id]
	var col: Color = TYPE_COL.get(t["type"], C_CARD)
	var ok = _card_playable(id)
	var react = t["type"] == "Reação" or id == "retirada" or id == "reforco"
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(128, 172)
	card.add_theme_stylebox_override("panel", _tex_box("res://ui/card.png", 20, col if (ok or react) else col.darkened(0.55), 9, 7))
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var cost = _label(v, "%s · %s" % [t["type"].to_upper(), ("%d AÇÃO" % int(t["cost"])) if int(t["cost"]) > 0 else "GRÁTIS"], 9, col.lightened(0.4))
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic = TextureRect.new()
	ic.custom_minimum_size = Vector2(0, 40)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ipath = "res://ui/icons/%s.png" % id
	if ResourceLoader.exists(ipath):
		ic.texture = load(ipath)
	ic.modulate = col
	v.add_child(ic)
	var nm = _label(v, t["name"], 11, Color.WHITE)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font_btn != null:
		nm.add_theme_font_override("font", font_btn)
	var tg = _card_targets(id)
	var af = _label(v, tg["txt"], 9, col.lightened(0.35))
	af.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	af.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	af.custom_minimum_size = Vector2(104, 0)
	af.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var why_not = ""
	if react:
		why_not = "Esta carta é usada sozinha no momento certo (o jogo pergunta)."
	elif not ok:
		why_not = "Agora não dá: selecione uma peça sua que ainda pode agir e tenha ação sobrando." if my_turn() else "Espere a sua vez."
	card.tooltip_text = "%s (%s · %s)\n%s\nAFETA: %s%s" % [t["name"], t["type"], ("custa %d ação" % int(t["cost"])) if int(t["cost"]) > 0 else "grátis", t["text"], tg["txt"], ("\n" + why_not) if why_not != "" else ""]
	if not ok and not react:
		card.modulate = Color(0.75, 0.75, 0.8)
	card.mouse_entered.connect(_card_hover_set.bind(id, card, true))
	card.mouse_exited.connect(_card_hover_set.bind(id, card, false))
	card.gui_input.connect(_card_input.bind(id))
	return card


func _card_input(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _card_playable(id):
			card_hover = ""
			_play_card(id)
		else:
			sfx.play("clique", -10.0, 0.7)
func _card_playable(id: String) -> bool:
	if not my_turn():
		return false
	if game.act != null:
		return game.tactic_playable(game.cur, id)
	var u = sel_unit()
	if u == null or not game.can_start(u):
		return false
	game.act = game._new_act(u, 2, false)
	var ok = game.tactic_playable(game.cur, id)
	game.act = null
	return ok


func _any_card_playable() -> bool:
	for id in game.P[0]["hand"]:
		if _card_playable(id):
			return true
	return false


func _play_card(id: String) -> void:
	if not _card_playable(id):
		return
	panel_open = ""
	if game.act == null:
		game.start_activation(sel_unit())
	busy = true
	refresh()
	await game.play_tactic(game.cur, id)
	busy = false
	await after()


# ================= ações do jogador =================
func _set_am(v: String) -> void:
	am = "" if am == v else v
	ab = false
	pend = null
	refresh()


func _toggle_ab() -> void:
	ab = not ab
	am = ""
	pend = null
	refresh()


func _on_ult() -> void:
	var u = sel_or_act()
	if u == null or not my_turn():
		return
	if game.act == null and game.can_start(u):
		game.start_activation(u)
	pend = null
	am = ""
	ab = false
	busy = true
	refresh()
	await game.act_ult(u)
	busy = false
	await after()


func _on_collect() -> void:
	var u = sel_or_act()
	if u == null or not my_turn():
		return
	if game.act == null and game.can_start(u):
		game.start_activation(u)
	pend = null
	busy = true
	await game.act_collect(u)
	busy = false
	await after()


func _on_interact() -> void:
	var u = sel_or_act()
	if u == null or not my_turn():
		return
	if game.act == null and game.can_start(u):
		game.start_activation(u)
	busy = true
	await game.act_interact(u)
	busy = false
	await after()


func _on_end_pressed() -> void:
	if not my_turn():
		return
	if game.act != null:
		ab = false
		pend = null
		busy = true
		await game.end_activation()
		busy = false
		sel = -1
		await after()
	else:
		sel = -1
		pend = null
		dsel = -1
		busy = true
		await game.pass_turn(game.cur)
		busy = false
		await after()


func _on_roster(uid: int) -> void:
	if res_drag != null and res_drag["on"]:
		return
	var u = game.by_uid(uid)
	if u == null:
		return
	pend = null
	tip = null
	if u.st == "reserve" and my_turn() and game.act == null and u.owner == game.cur and not game.deploy_hexes(game.cur).is_empty():
		dsel = u.uid
		sel = -1
	elif u.st == "field" and game.act == null and game.can_start(u):
		if sel != u.uid:
			am = ""
			ab = false
		sel = u.uid
		dsel = -1
		inspect = -1
	else:
		inspect = u.uid
		if game.act == null:
			sel = -1
		if u.st == "reserve" and my_turn() and u.owner == game.cur:
			if game.act != null:
				tip = {"l": "Uma peça por turno: termine as ações da peça atual antes de colocar uma reserva em campo."}
			else:
				tip = {"l": "Sua entrada está ocupada ou bloqueada. Tire uma peça das casas de entrada para abrir espaço."}
	refresh()


func _confirm_pend() -> void:
	if sfx != null:
		sfx.play("confirmar", -8.0, 1.0, 0.0)
	var p = pend
	var u = sel_unit()
	pend = null
	if p == null or u == null or not my_turn():
		refresh()
		return
	if not game.is_live(u):
		if not game.can_start(u):
			refresh()
			return
		game.start_activation(u)
	busy = true
	refresh()
	match p["kind"]:
		"move":
			await game.act_move(u, p["h"])
		"attack":
			await game.act_attack(u, game.by_uid(p["tuid"]))
		"moveatk":
			await game.act_move(u, p["h"])
			var t = game.by_uid(p["tuid"])
			if t != null and t.st == "field" and u.st == "field" and game.winner == Game.NONE:
				await game.act_attack(u, t)
		"ab":
			ab = false
			if game.K(u).get("action", "") == "tunnel":
				await game.act_tunnel(u, p["h"])
			else:
				await game.act_move_attack(u, p["h"], null)
	busy = false
	await after()


func after() -> void:
	if game == null:
		return
	pend = null
	am = ""
	tip = null
	if game.act != null and game.winner == Game.NONE and not game.cpu[game.act["p"]] and game.act["actions"] <= 0 and not _any_hand_playable_now():
		ab = false
		busy = true
		await get_tree().create_timer(0.35).timeout
		await game.end_activation()
		busy = false
		sel = -1
	refresh()
	if game.winner != Game.NONE:
		_game_over()
		return
	if running:
		return
	running = true
	while game != null and game.winner == Game.NONE and game.cpu[game.cur]:
		busy = true
		refresh()
		await get_tree().create_timer(0.5).timeout
		await AI.activation(game, game.cur)
	if game == null:
		return
	busy = false
	running = false
	refresh()
	if game.winner != Game.NONE:
		_game_over()


func _any_hand_playable_now() -> bool:
	for id in game.P[game.act["p"]]["hand"]:
		if game.tactic_playable(game.act["p"], id):
			return true
	return false


# ================= tabuleiro: toques e arraste =================
func _on_hex_tapped(h) -> void:
	if game == null:
		return
	if asking != null and asking["q"]["t"] == "hex":
		if asking["q"]["opts"].has(h):
			_answer(h)
		return
	tip = null
	var at = game.unit_at(h)
	if not my_turn():
		inspect = at.uid if at != null else -1
		hex_info = null if at != null else h
		refresh()
		return
	if dsel >= 0:
		if game.deploy_hexes(game.cur).has(h):
			var du = game.by_uid(dsel)
			dsel = -1
			busy = true
			refresh()
			await game.deploy(du, h)
			busy = false
			sel = du.uid
			await after()
		else:
			dsel = -1
			refresh()
		return
	var u = sel_unit()
	if u != null and u.owner == game.cur and u.st == "field":
		var live = game.is_live(u)
		if ab and (live or game.can_start(u)):
			var H0 = highlights()
			if H0["pk"].has(h):
				pend = {"kind": "ab", "h": h}
				refresh()
				return
			ab = false
			pend = null
			refresh()
			return
		if live or game.can_start(u):
			var H = highlights()
			var pm = _pend_move()
			if at != null and H["at"].has(h):
				if pm != null:
					pend = {"kind": "moveatk", "h": pm["h"], "cost": pm["cost"], "tuid": at.uid}
				else:
					pend = {"kind": "attack", "tuid": at.uid}
				refresh()
				return
			for m in H["mv"]:
				if m["h"] == h:
					pend = {"kind": "move", "h": h, "cost": m["c"]}
					refresh()
					return
			if pend != null and (h == u.pos() or (pm != null and h == pm["h"])):
				pend = null
				refresh()
				return
			if h != u.pos() and not (at != null and at.owner == u.owner):
				if at != null and at.owner != u.owner:
					var wn = game.why_no_attack(u, at, pm["h"] if pm != null else null)
					tip = wn
				else:
					tip = {"l": game.why_no_move(u, h), "hex": h}
				refresh()
				return
	pend = null
	if at != null and game.act == null and game.can_start(at):
		if sel != at.uid:
			am = ""
			ab = false
		sel = at.uid
		inspect = -1
	else:
		if game.act == null:
			sel = -1
		inspect = at.uid if at != null else -1
	hex_info = null if at != null else h
	refresh()


func _on_unit_drag_started(uid: int) -> void:
	if sel != uid:
		am = ""
		ab = false
	sel = uid
	dsel = -1
	inspect = -1
	pend = null
	tip = null
	refresh()


func _on_unit_dropped(uid: int, h) -> void:
	var u = game.by_uid(uid)
	if h == null or u == null or h == u.pos():
		pend = null
		refresh()
		return
	_on_hex_tapped(h)


func _start_res_drag(uid: int) -> void:
	var u = game.by_uid(uid)
	if u == null or not my_turn() or game.act != null or game.deploy_hexes(game.cur).is_empty():
		return
	res_drag = {"uid": uid, "start": get_viewport().get_mouse_position(), "on": false}


func _input(event: InputEvent) -> void:
	if game == null:
		return
	if res_drag != null:
		if event is InputEventMouseMotion:
			var pos = (event as InputEventMouseMotion).position
			if not res_drag["on"] and pos.distance_to(res_drag["start"]) > 8.0:
				res_drag["on"] = true
				dsel = res_drag["uid"]
				sel = -1
				var cid = game.by_uid(res_drag["uid"]).cid
				w["drag_icon"].texture = DB.portraits.get(cid, null)
				w["drag_icon"].visible = true
				refresh()
			if res_drag["on"]:
				w["drag_icon"].position = pos - Vector2(35, 45)
		elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var was_on = res_drag["on"]
			res_drag = null
			w["drag_icon"].visible = false
			if was_on:
				get_viewport().set_input_as_handled()
				var h = board.pick_hex((event as InputEventMouseButton).position)
				if h != null:
					_on_hex_tapped(h)
				else:
					dsel = -1
					refresh()
	if event is InputEventKey and event.pressed:
		var ke = event as InputEventKey
		if ke.keycode == KEY_ENTER and pend != null and asking == null:
			_confirm_pend()
		elif ke.keycode == KEY_ESCAPE:
			if pend != null:
				pend = null
			elif ab:
				ab = false
			elif dsel >= 0:
				dsel = -1
			elif panel_open != "":
				panel_open = ""
			tip = null
			refresh()


# ================= perguntas do motor =================
func _on_question(p: int, q: Dictionary) -> void:
	asking = {"p": p, "q": q}
	refresh()


func _answer(v) -> void:
	if asking == null:
		return
	asking = null
	refresh()
	game.answered.emit(v)


# ================= efeitos =================
func _unit_pos(uid: int, lift: float = 0.9) -> Variant:
	if board.unit_nodes.has(uid):
		return board.unit_nodes[uid]["node"].position + Vector3(0, lift, 0)
	var u: Variant = game.by_uid(uid) if game != null else null
	if u != null and u.st == "field":
		return _hex_pos(u.pos(), lift)
	return null


func _hex_pos(h: Vector2i, lift: float = 0.9) -> Vector3:
	var wp = board.world_xz(h)
	return Vector3(wp.x, board.top_y(h) + lift, wp.y)


func _unit_color(uid: int) -> Color:
	var u: Variant = game.by_uid(uid) if game != null else null
	if u == null or u.barrier:
		return Color("#d9c9a8")
	return Color(DB.factions[DB.cards[u.cid]["f"]]["color"])


func _shot_style(uid: int) -> String:
	var u: Variant = game.by_uid(uid)
	if u == null or u.barrier:
		return "energia"
	var c = DB.cards[u.cid]
	if c["f"] == "LIT":
		return "cristal"
	if c["f"] == "ZUK":
		return "laser"
	if c["f"] == "ABY" or c["f"] == "TER":
		return "energia"
	return "bala"


# atraso para o impacto chegar junto com o projétil
func _later(delay: float, cb: Callable) -> void:
	if delay <= 0.01:
		cb.call()
	else:
		get_tree().create_timer(delay).timeout.connect(cb)


func _fx_dmg(h: Vector2i, amt: int, uid: int) -> void:
	board.float_text(h, ("-%d" % amt) if amt > 0 else "0", Color("#ff6a4a") if amt > 0 else Color("#8fb8cc"))
	board.hurt(uid)
	var p: Variant = _unit_pos(uid, 0.9)
	if p == null:
		p = _hex_pos(h)
	if amt > 0:
		vfx.impact(p, Color("#ff9a5a"), clamp(amt / 4.0, 0.6, 1.8))
		vfx.flip("hit", p - Vector3(0, 0.75, 0), clamp(1.2 + amt * 0.12, 1.3, 2.4), 0.3)
		_voice(uid, "dor", -1.0, 0.06)
	else:
		vfx.block(p)
		vfx.flip("shield", p - Vector3(0, 0.9, 0), 1.6, 0.4, Color("#bfe8ff"))


# voz do personagem: v_<id>_atk (atacar) ou v_<id>_dor (sofrer dano)
func _voice(uid: int, kind: String, vol: float = 0.0, delay: float = 0.0, pitch: float = 1.0) -> void:
	if game == null or sfx == null:
		return
	var u: Variant = game.by_uid(uid)
	if u == null or u.barrier:
		return
	var n = "v_%s_%s" % [u.cid, kind]
	if delay > 0.0:
		sfx.play_later(n, delay, vol, pitch)
	else:
		sfx.play(n, vol, pitch, 0.05)


func _fx_die(p: Vector3, c: Color) -> void:
	vfx.death_fx(p, c)
	vfx.flip("smoke", p - Vector3(0, 0.2, 0), 2.4, 0.8)
	sfx.play("derrota", -3.0)


# efeitos 2.5D das habilidades: cada tipo tem seu desenho, cor e som
func _on_abfx(e: Dictionary) -> void:
	var g0 = _hex_pos(e["h"], 0.0)
	var fc = _unit_color(e["uid"]).lightened(0.35)
	var lit = false
	var uu: Variant = game.by_uid(e["uid"])
	if uu != null and not uu.barrier:
		lit = DB.cards[uu.cid]["f"] == "LIT"
	match e["k"]:
		"poison":
			vfx.flip("poison", g0, 1.9, 0.7)
		"glue", "root":
			vfx.flip("glue", g0, 2.0, 0.6)
		"splash":
			vfx.flip("crystal" if lit else "boom", g0, 2.6, 0.6, fc if lit else Color.WHITE)
			vfx.flip("ring", g0, 3.4, 0.5, fc, true)
		"nova":
			vfx.flip("crystal" if lit else "spikes", g0, 2.8, 0.6, fc if lit else Color.WHITE)
			vfx.flip("ring", g0, 3.6, 0.5, fc, true)
		"zap":
			vfx.flip("bolt", g0, 2.4, 0.4, Color("#fff07a"))
			vfx.flip("ring", g0, 3.4, 0.45, Color("#fff07a"), true)
		"bolt":
			vfx.flip("bolt", g0, 2.4, 0.4, Color("#bfe0ff"))
		"hook", "dash":
			vfx.flip("dash", g0, 2.0, 0.35, fc)
		"insight", "buff":
			vfx.flip("sparkle" if e["k"] == "insight" else "aura", g0, 2.2, 0.7, Color("#fff2a0"))
		"quake", "push":
			vfx.flip("ring", g0, 3.6, 0.5, Color("#e8c890"), true)
			vfx.flip("smoke", g0, 2.0, 0.6)
		"explode", "blast":
			vfx.flip("boom", g0, 2.6, 0.7)
		"sonic":
			vfx.flip("sonic", g0, 2.4, 0.5, fc)
		"debuff":
			vfx.flip("curse", g0, 2.0, 0.6)
		"silence":
			vfx.flip("ink", g0, 2.0, 0.6)
		"mark":
			vfx.flip("mark", g0, 2.0, 0.7)
		"heal":
			vfx.flip("heal", g0, 2.2, 0.8)
		"veil":
			vfx.flip("ink", g0, 2.4, 0.7)
		"mine":
			vfx.flip("spikes", g0, 1.6, 0.5, Color("#c8a0ff"))
		"barrier", "earth", "burrow":
			vfx.flip("rock", g0, 2.4, 0.6, fc if lit else Color.WHITE)
			vfx.flip("ring", g0, 3.0, 0.45, Color("#d8b888"), true)
		"portal":
			vfx.flip("portal", g0, 2.2, 0.6, fc)
		"abyss":
			vfx.flip("vortex", g0, 2.8, 0.8)
		"bombard":
			vfx.flip("beam", g0, 2.8, 0.45, Color("#ffd08a"))
			vfx.flip("boom", g0, 3.2, 0.8, Color.WHITE, false, 0.3)
			vfx.flip("ring", g0, 5.0, 0.6, Color("#ffb060"), true, 0.3)
		"prison":
			vfx.flip("prison", g0, 2.6, 0.7, Color("#c8f4ff"))
		"stomp":
			vfx.flip("ring", g0, 3.2, 0.4, Color("#e8d8b8"), true)
			vfx.flip("smoke", g0, 1.8, 0.5)
		"orbital":
			vfx.flip("beam", g0, 2.8, 0.5, fc)
			vfx.flip("ring", g0, 4.6, 0.6, fc, true, 0.35)
			vfx.flip("boom", g0, 2.6, 0.7, Color.WHITE, false, 0.35)


func _fx_shield(p: Vector3) -> void:
	vfx.shield_fx(p)
	vfx.flip("shield", p, 1.9, 0.5, Color("#bfe8ff"))


func _fx_phoenix(p: Vector3) -> void:
	vfx.phoenix_fx(p)
	vfx.flip("fire", p, 2.4, 0.9)


func _storm_end() -> void:
	if vfx != null:
		vfx.sandstorm(false)
	sfx.stop_loop("tempestade_loop", 3.0)


func _on_fx(e: Dictionary) -> void:
	var now = Time.get_ticks_msec()
	var d = impact_delay if now < impact_until else 0.0
	match e["t"]:
		"strike":
			board.lunge(e["from"])
			var a: Variant = _unit_pos(e["from"], 1.0)
			var tgt: Variant = _unit_pos(e["to"], 0.9)
			var col = _unit_color(e["from"])
			if a == null or tgt == null:
				return
			_voice(e["from"], "atk", -2.0)
			if e["ranged"]:
				var style = _shot_style(e["from"])
				impact_delay = vfx.projectile(a, tgt, col, "cristal" if style == "cristal" else "bola")
				impact_until = now + 120
				var snd = "projetil"
				if style == "cristal":
					snd = "tiro_cristal"
				elif style == "laser":
					snd = "tiro_laser"
				elif style == "energia":
					snd = "tiro_energia"
				sfx.play(snd, -3.0)
			else:
				impact_delay = 0.08
				impact_until = now + 120
				vfx.slash(tgt, a, col)
				vfx.flip("slash", tgt - Vector3(0, 0.9, 0), 2.2, 0.32, col.lightened(0.45))
		"dmg":
			var amt = e["amt"]
			var uid = e["uid"]
			var h = e["h"]
			_later(d, _fx_dmg.bind(h, amt, uid))
		"heal":
			board.float_text(e["h"], "+%d" % e["amt"], Color("#84d14f"))
			vfx.heal_fx(_hex_pos(e["h"], 0.1))
			sfx.play("cura", -4.0)
		"die":
			_banter_death(e["uid"])
			var hp = _hex_pos(e["h"], 0.2)
			var dc = _unit_color(e["uid"])
			_voice(e["uid"], "dor", 0.0, d + 0.1, 0.82)
			_later(d + 0.15, _fx_die.bind(hp, dc))
		"summon":
			_banter(e["uid"])
			vfx.summon_fx(_hex_pos(e["h"], 0.0), _unit_color(e["uid"]))
			vfx.flip("portal", _hex_pos(e["h"], 0.0), 2.2, 0.6, _unit_color(e["uid"]).lightened(0.4))
			sfx.play("invocar", -5.0)
		"move":
			sfx.play("passo", -10.0, 1.0, 0.2)
		"boom":
			board.boom(e["h"])
			vfx.explosion(_hex_pos(e["h"], 0.2))
			vfx.flip("boom", _hex_pos(e["h"], 0.0), 2.6, 0.7)
			sfx.play("explosao", -2.0)
		"passive":
			var pp: Variant = _unit_pos(e["uid"], 0.0)
			if pp == null:
				return
			match e["kind"]:
				"power", "ability":
					vfx.power_fx(pp)
					vfx.flip("aura" if e["kind"] == "power" else "sparkle", pp, 2.0, 0.6, Color("#ffe27a") if e["kind"] == "power" else _unit_color(e["uid"]).lightened(0.5))
				"shield":
					_later(d, _fx_shield.bind(pp))
				"curse":
					vfx.curse_fx(pp)
					vfx.flip("curse", pp, 1.9, 0.6)
				"phoenix":
					_later(d + 0.3, _fx_phoenix.bind(pp))
				"trap":
					vfx.trap_fx(pp)
					vfx.flip("spikes", pp, 1.8, 0.5)
		"card":
			sfx.play("carta", -4.0)
		"abfx":
			_on_abfx(e)
		"ult":
			banner("★ " + str(e["name"]), ("Você" if e["p"] == 0 else "CPU") + " · " + game.nm(game.by_uid(e["uid"])))
			sfx.play("poder", -1.0, 0.8)
		"wind":
			banner("O vento muda!", "tempestade de areia: as dunas vão se mover")
			vfx.sandstorm(true)
			sfx.loop("tempestade_loop", -6.0, 3.0)
		"dunes":
			banner("As dunas se movem!", "o relevo mudou")
			board.quake()
			sfx.play("dunas", 0.0)
			get_tree().create_timer(4.0).timeout.connect(_storm_end)
		"tremor":
			sfx.play("verme_rumor", -4.0)
			for th in e["hexes"]:
				vfx.dust_burst(_hex_pos(th, 0.0), false)
		"worm":
			banner("Vermes!", "buracos se abriram na areia")
			board.quake()
			sfx.play("verme_rumor", -2.0, 0.8)
			sfx.play_later("verme_ataque", 0.35, 0.0)
			var hs = []
			for b in game.holes:
				hs.append(b["h"])
				vfx.dust_burst(_hex_pos(b["h"], 0.0), true)
			board.worm_emerge(hs)
		"round":
			sfx.play("round", -6.0)
			banner("Round %d" % e["round"], "os comandantes entram" if e["round"] == 6 else ("Você começa" if game.first == 0 else "A CPU começa"))
	board.sync_units()


# ================= diálogos e balões de fala =================
func _short(cid: String) -> String:
	var n: String = DB.cards[cid]["name"]
	for pre in ["Krieg ", "Wächter ", "Zukunft ", "Lithari "]:
		if n.begins_with(pre):
			n = n.substr(pre.length())
	n = n.replace(" Zukunft", "")
	return n.split(" ")[0] if n.split(" ").size() > 2 else n


func _fac_of(u) -> String:
	return DB.cards[u.cid]["f"]


func _pick(arr) -> String:
	if arr == null or not (arr is Array) or arr.is_empty():
		return ""
	return str(arr[randi() % arr.size()])


func _line(kind: String, u, target = null) -> String:
	var txt = ""
	var pc = dlg.get("personagem", {}).get(u.cid, {})
	if pc.has(kind) and randf() < 0.65:
		txt = _pick(pc[kind])
	if txt == "":
		txt = _pick(dlg.get(kind, {}).get(_fac_of(u), []))
	if target != null:
		txt = txt.replace("{nome}", _short(target.cid))
	return txt


# quando alguém entra em campo: fala com um aliado ou provoca um inimigo, e recebe resposta
func _banter(uid: int) -> void:
	if dlg.is_empty() or game == null:
		return
	var u: Variant = game.by_uid(uid)
	if u == null or u.barrier:
		return
	var now = Time.get_ticks_msec()
	if now - last_banter_ms < 3500 and not u.is_cmd:
		return
	last_banter_ms = now
	var others = game.field().filter(func(x): return x != u and not x.barrier)
	# duplas com conversa própria
	for pr in dlg.get("pares", []):
		var other_id = ""
		if pr["a"] == u.cid:
			other_id = pr["b"]
		elif pr["b"] == u.cid:
			other_id = pr["a"]
		if other_id == "":
			continue
		var o = null
		for x in others:
			if x.cid == other_id:
				o = x
		if o == null:
			continue
		var t0 = 0.6
		for i in range(pr["fala"].size()):
			var who = (u if pr["a"] == u.cid else o) if i % 2 == 0 else (o if pr["a"] == u.cid else u)
			var other = o if who == u else u
			_say(who.uid, pr["fala"][i], t0, "prov" if other.owner != who.owner else "fala")
			t0 += 2.2
		return
	var enemies = others.filter(func(x): return x.owner != u.owner)
	var allies = others.filter(func(x): return x.owner == u.owner)
	var near = func(arr):
		var best = null
		for x in arr:
			if best == null or DB.dist(x.pos(), u.pos()) < DB.dist(best.pos(), u.pos()):
				best = x
		return best
	var tgt = null
	var mode = "entrada"
	if not enemies.is_empty() and (allies.is_empty() or randf() < 0.55):
		tgt = near.call(enemies)
		mode = "provoca"
	elif not allies.is_empty() and randf() < 0.8:
		tgt = near.call(allies)
		mode = "aliado"
	var l1 = _line(mode if tgt != null else "entrada", u, tgt)
	if l1 == "":
		return
	_say(u.uid, l1, 0.6, "prov" if mode == "provoca" else "fala")
	if tgt != null:
		var l2 = _pick(dlg.get("resp_inimigo" if mode == "provoca" else "resp_aliado", {}).get(_fac_of(tgt), []))
		if l2 != "":
			_say(tgt.uid, l2, 2.6, "prov" if mode == "provoca" else "fala")


func _banter_death(uid: int) -> void:
	if dlg.is_empty() or game == null:
		return
	var dead: Variant = game.by_uid(uid)
	if dead == null or dead.barrier:
		return
	var foes = game.field().filter(func(x): return x.owner != dead.owner and not x.barrier and x.st == "field")
	var friends = game.field().filter(func(x): return x.owner == dead.owner and not x.barrier and x.st == "field" and x != dead)
	if not foes.is_empty() and randf() < 0.5:
		var f = foes[randi() % foes.size()]
		_say(f.uid, _line("vitoria", f), 0.9, "prov")
	elif not friends.is_empty() and randf() < 0.45:
		var a = friends[randi() % friends.size()]
		_say(a.uid, _line("lamento", a), 0.9, "triste")


func _say(uid: int, text: String, delay: float = 0.0, mood: String = "fala") -> void:
	if text == "" or not w.has("bubbles"):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if game == null or not w.has("bubbles") or not board.unit_nodes.has(uid):
		return
	var u: Variant = game.by_uid(uid)
	if u == null:
		return
	_talk_voice(u, text, mood)
	# um balão por personagem
	for b in bubbles:
		if b["uid"] == uid and is_instance_valid(b["node"]):
			b["node"].queue_free()
	var col = _unit_color(uid)
	var p = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.15, 0.93)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 7
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v = _vbox(p, 1)
	var nl = _label(v, DB.cards[u.cid]["name"], 11, col.lightened(0.3))
	if font_btn != null:
		nl.add_theme_font_override("font", font_btn)
	var tl = _label(v, text, 14, C_TXT)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(min(260, 9 * text.length() + 20), 0)
	w["bubbles"].add_child(p)
	p.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_interval(2.0 + text.length() * 0.035)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.tween_callback(p.queue_free)
	bubbles.append({"uid": uid, "node": p})
	if sfx != null:
		sfx.play("clique", -12.0, 1.3, 0.2)


func _process(_delta: float) -> void:
	if bubbles.is_empty():
		return
	var keep = []
	for b in bubbles:
		var p = b["node"]
		if not is_instance_valid(p):
			continue
		if not board.unit_nodes.has(b["uid"]):
			p.queue_free()
			continue
		var wp = board.unit_nodes[b["uid"]]["node"].position + Vector3(0, 2.7, 0)
		if board.cam.is_position_behind(wp):
			p.visible = false
		else:
			p.visible = true
			var sp = board.cam.unproject_position(wp)
			p.position = sp - Vector2(p.size.x / 2.0, p.size.y)
		keep.append(b)
	bubbles = keep


# capturas automáticas para conferir o visual: godot -- --shots=/pasta
func _shots(dir: String) -> void:
	autotest = true
	var shot = func(n: String):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "/" + n + ".png")
	await get_tree().create_timer(0.5).timeout
	await shot.call("01_menu")
	_show_army()
	_army_random()
	await get_tree().create_timer(0.4).timeout
	await shot.call("02_exercito")
	autotest = false
	_army_go()
	game.cpu = [false, true]
	await get_tree().create_timer(2.5).timeout
	await shot.call("03_batalha")
	# cartas: passa o mouse na primeira e conversa entre personagens
	game.start_activation(game.field().filter(func(x): return x.owner == 0)[0])
	refresh()
	await get_tree().create_timer(0.3).timeout
	var c0 = w["hand"].get_child(0)
	_card_hover_set(game.P[0]["hand"][0], c0, true)
	var mine = game.field().filter(func(x): return x.owner == 0 and not x.barrier)
	last_banter_ms = -100000
	_banter(mine[0].uid)
	await get_tree().create_timer(3.4).timeout
	await shot.call("07_cartas_dialogo")
	_card_hover_set(game.P[0]["hand"][0], c0, false)
	board.cam_dist = 7.0
	await get_tree().create_timer(0.6).timeout
	await shot.call("04_zoom_perto")
	board.cam_dist = 140.0
	await get_tree().create_timer(0.6).timeout
	await shot.call("05_zoom_longe")
	board.cam_dist = 30.0
	board.cam_pitch = 0.5
	await get_tree().create_timer(0.6).timeout
	await shot.call("06_horizonte")
	get_tree().quit()


func _game_over() -> void:
	if autotest:
		print("AUTOTESTE FIM: vencedor=%d round=%d eventos=%d" % [game.winner, game.round_no, game.logs.size()])
		for l in game.logs:
			if "usou" in l["text"]:
				print("  [r%d p%d] %s" % [l["round"], l["p"], l["text"]])
		get_tree().quit()
		return
	if w.has("over"):
		return
	var win = game.winner
	var title = "Empate" if win == Game.DRAW else ("Vitória!" if win == 0 else "Derrota")
	var reason = ""
	if not game.final_score.is_empty():
		var f = game.final_score
		reason = "Fim do round 10. Vida dos comandantes %d x %d; aliados %d x %d." % [f["c"][0], f["c"][1], f["s"][0], f["s"][1]]
	elif win == Game.DRAW:
		reason = "Os dois comandantes caíram juntos."
	else:
		reason = "%s foi derrotado no round %d." % [DB.cards[game.commander(1 - win).cid]["name"], game.round_no]
	var p = _panel(ui)
	_place(p, Control.PRESET_CENTER)
	var v = _vbox(p, 12)
	_label(v, title, 56, C_GOLD)
	_label(v, reason, 18)
	var hb = _hbox(v, 10)
	_button(hb, "Revanche", func(): _start_match(last_sides))
	_button(hb, "Novos exércitos", _show_army)
	_button(hb, "Menu", _show_menu)
	_button(hb, "Ver o tabuleiro", func(): p.queue_free())
	w["over"] = p


func _is_touch() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return DisplayServer.is_touchscreen_available() and OS.has_feature("mobile")


# voz do personagem junto com o balão: "fala" (amigável), "prov" (provocação), "triste" (lamento)
func _talk_voice(u, text: String, mood: String) -> void:
	if sfx == null:
		return
	var n = "v_%s_%s" % [u.cid, "prov" if mood == "prov" else "fala"]
	var pitch = 0.84 if mood == "triste" else randf_range(0.96, 1.05)
	var vol = 2.0 if mood == "prov" else 0.0
	sfx.play(n, vol, pitch, 0.0)
	# frases longas: o personagem continua falando
	if text.length() > 55:
		sfx.play_later(n, 0.78 / pitch, vol - 2.0, pitch * 0.94)
