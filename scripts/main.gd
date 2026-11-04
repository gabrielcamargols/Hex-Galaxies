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
const RULES = "[b]Objetivo:[/b] derrotar o Comandante inimigo (ele entra no round 6). No fim do round 10 vence quem tiver mais Vida no Comandante; empate: soma da Vida dos aliados.\n\n[b]Turno:[/b] os lados se alternam ativando 1 peça por vez. Cada peça ativada tem [b]2 ações[/b], e cada tipo só pode ser usado [b]1 vez por turno[/b]: mover 1 vez, atacar 1 vez, usar habilidade ativa (ex.: mover + atacar). [b]Táticas não gastam ação:[/b] cada peça ativada pode jogar 1 carta de graça. Arraste a carta e solte no personagem (ou na casa) destacado para escolher quem recebe o efeito. Habilidades passivas não gastam ação. Colocar uma reserva em campo gasta 1 ação. [b]A área de entrada cresce:[/b] nos rounds 1 a 3 ela vai até 1 casa da sua base, nos rounds 4 a 6 até 2 casas, nos rounds 7 a 9 até 3 casas e no round 10 até 4 casas (sempre na sua metade do mapa).\n\n[b]Altura:[/b] atacar de cima +1 de dano, de baixo -1. Tiros (alcance 2+) de cima ganham +1 de alcance. Corpo a corpo só com até 1 nível de diferença.\n\n[b]Linha de tiro:[/b] uma casa no caminho bloqueia se o topo dela for mais alto que o atacante e o alvo.\n\n[b]Abrigo:[/b] -2 de dano se uma rocha/ruína/ossada vizinha ao alvo estiver do lado do atacante.\n\n[b]Tarhut:[/b] as dunas mudam a cada 5 rounds (aviso 1 round antes); a cada 3 rounds o [color=#ff6a4a]Verme Gigante[/color] sai da areia (o \"!\" avisa 1 round antes): quem estiver no buraco sofre 4 de dano e quem estiver ao lado, 1. Fuja das casas marcadas!\n\n[b]Controles:[/b] clique numa peça sua e depois numa casa verde (mover) ou num inimigo vermelho (atacar), ou arraste a peça e solte. Confirme a prévia. Botão direito gira a câmera, arrastar o fundo move o mapa, a roda aproxima. Q/E giram. Enter confirma, Esc cancela.\n\n[b]Toque (tablet/celular):[/b] toque numa peça e numa casa para agir. 1 dedo arrasta o mapa; pinça com 2 dedos aproxima/afasta; girar os 2 dedos gira a câmera; arrastar os 2 dedos para cima/baixo inclina a visão. \"Tudo\" recentraliza."

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
var mix: bool = false          # modo Mix: tropas e comandante de qualquer facção
var mix_cmd: String = ""
var mix_filter: String = ""    # filtro de facção na grade do Mix ("" = todas)
var army_start: Array = []     # até 2 ids que começam em campo
var army_fac: String = ""
var army_detail: String = ""   # peça mostrada no painel de detalhes
var galaxy = null              # galáxia do menu (scripts/galaxy.gd)
var fader: ColorRect           # cortina de transição (cor do planeta / preto)
var stage: String = ""         # title, select, army, dive, battle
var planet_id: String = "tarhut"
var intro: bool = false        # próxima partida começa com o zoom no planeta
var card_hover: String = ""      # carta com o mouse em cima (destaca o que ela afeta)
var last_st: Dictionary = {}       # destaques atuais do tabuleiro (sem a carta)
var dlg: Dictionary = {}           # falas (data/dialogos.json)
var bubbles: Array = []            # balões de fala ativos
var plates: Dictionary = {}        # uid -> placa de vida 2D (estilo da HUD)
var ui_pref: String = "auto"       # tamanho da interface: auto, 100, 125, 150, 175
var compact: bool = false          # tela pequena (celular): HUD enxuta e letras maiores
var cpu_open: bool = false         # painel da CPU aberto no modo compacto
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
var card_drag: Variant = null   # carta de tática sendo arrastada: {id, start, on}
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
	board.worm_roar.connect(_on_worm_roar)
	board.worm_bite.connect(_on_worm_bite)
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
	board._setup_sky()
	board.visible = false
	galaxy = Node3D.new()
	galaxy.set_script(load("res://scripts/galaxy.gd"))
	add_child(galaxy)
	galaxy.env = board.env
	galaxy.planet_hover.connect(_on_planet_hover)
	galaxy.planet_click.connect(_choose_planet)
	var top_layer = CanvasLayer.new()
	top_layer.layer = 20
	add_child(top_layer)
	fader = ColorRect.new()
	fader.color = Color(0.012, 0.02, 0.045, 1.0)
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_STOP
	top_layer.add_child(fader)
	if FileAccess.file_exists("res://data/dialogos.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos.json"))
		if parsed is Dictionary:
			dlg = parsed
	_load_prefs()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--uiscale="):
			ui_pref = a.substr(10)
	_apply_ui_scale()
	get_window().size_changed.connect(_apply_ui_scale)
	_show_menu()
	var args = OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shots="):
			_shots(a.substr(8))
			return
	for a in args:
		if a.begins_with("--cenario="):
			board.visible = true
			galaxy.deactivate()
			fader.visible = false
			ui.visible = false
			var pv = Node3D.new()
			pv.set_script(load("res://scripts/cenario_preview.gd"))
			add_child(pv)
			await pv.run(a.substr(10), board)
			get_tree().quit()
			return
		if a.begins_with("--balance="):
			var n = int(a.substr(10))
			var outp = "user://balance.json"
			var mps = ["tarhut", "posto"]
			var only = ""
			for b in args:
				if b.begins_with("only="):
					only = b.substr(5)
				if b.begins_with("out="):
					outp = b.substr(4)
				if b.begins_with("maps="):
					mps = Array(b.substr(5).split(","))
			var bal = Node.new()
			bal.set_script(load("res://scripts/balance.gd"))
			add_child(bal)
			await bal.run(n, outp, mps, only)
			get_tree().quit()
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
	if compact and size > 0 and size < 13:
		size = 13
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


# ================= transições (sem tela de loading) =================
func _fade(to_a: float, dur: float, col = null) -> void:
	if col != null:
		fader.color = Color(col.r, col.g, col.b, fader.color.a)
	fader.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw = create_tween()
	tw.tween_property(fader, "color:a", to_a, dur)
	await tw.finished
	if to_a < 0.01:
		fader.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ui_fade(to_a: float, dur: float) -> void:
	var tw = create_tween()
	tw.tween_property(ui, "modulate:a", to_a, dur)
	await tw.finished


func _vignette() -> void:
	var tr = TextureRect.new()
	var gt = GradientTexture2D.new()
	var gr = Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0))
	gr.set_color(1, Color(0.0, 0.01, 0.04, 0.78))
	gr.set_offset(0, 0.45)
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 256
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(tr)


func _planet_of_map(m: String) -> String:
	for p in galaxy.PLANETS:
		if p.get("map", "") == m:
			return p["id"]
	return "tarhut"


func _stop_battle_loops() -> void:
	for n in ["vento_loop", "musica_deserto", "ilha_loop", "tempestade_loop", "musica_valak"]:
		sfx.stop_loop(n, 0.8)
	_fac_music("")


# trilha de cada facção (tools/musica_faccoes.py): toca na montagem do exército
const FAC_MUSIC = {"FAU": ["musica_fau", -9.0], "ABY": ["musica_aby", -8.0], "KRI": ["musica_kri", -9.0], "WAC": ["musica_wac", -9.0],
	"ZUK": ["musica_zuk", -9.5], "LIT": ["musica_lit", -6.0], "TER": ["musica_ter", -6.5]}
var fac_music_on: String = ""


func _fac_music(fac: String) -> void:
	if fac == fac_music_on:
		return
	if fac_music_on != "" and FAC_MUSIC.has(fac_music_on):
		sfx.stop_loop(FAC_MUSIC[fac_music_on][0], 1.2)
	fac_music_on = fac
	if fac != "" and FAC_MUSIC.has(fac):
		sfx.loop(FAC_MUSIC[fac][0], FAC_MUSIC[fac][1], 1.5)


# sai da batalha (se houver) e volta para a galáxia
func _leave_battle() -> void:
	if vfx != null:
		vfx.setup_ambient("")
	_clear_ui()
	game = null
	board.g = null
	board.visible = false
	bubbles.clear()
	_stop_battle_loops()
	sfx.loop("musica_galaxia", -9.0, 2.5)
	galaxy.activate()


# ================= menu: galáxia =================
func _show_menu() -> void:
	var from_battle = board.visible
	if from_battle:
		await _fade(1.0, 0.35, Color("#03050b"))
	_leave_battle()
	stage = "title"
	galaxy.set_mode("title")
	if from_battle or fader.color.a > 0.5:
		galaxy.snap_camera()
	ui.modulate.a = 0.0
	_vignette()
	var col = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	ui.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = get_viewport().get_visible_rect().size.y * 0.42
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k = _label(col, "U M A   G A L Á X I A   E M   G U E R R A", 13, C_HUD)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t = _label(col, "HEX GALAXIES", 62 if compact else 86, C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", Color(1.0, 0.45, 0.1, 0.45))
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 4)
	t.add_theme_constant_override("shadow_outline_size", 18)
	var s = _label(col, "Estratégia por turnos em hexágonos", 16, C_DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sp = Control.new()
	sp.custom_minimum_size = Vector2(0, 26)
	col.add_child(sp)
	var row = _hbox(col, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var play = _cbtn(row, "JOGAR", C_GOLD, _on_play, true)
	_primary(play)
	play.custom_minimum_size = Vector2(280, 66)
	play.add_theme_font_size_override("font_size", 26)
	var row2 = _hbox(col, 10)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	var rb = _cbtn(row2, "Como jogar", C_HUD, _rules_popup)
	rb.custom_minimum_size = Vector2(180, 40)
	var sb = _cbtn(row2, _ui_scale_label(), C_HUD, _cycle_ui_scale)
	sb.custom_minimum_size = Vector2(240, 40)
	var ver = _label(ui, "protótipo · Godot 4.7", 12, C_DIM)
	_place(ver, Control.PRESET_BOTTOM_RIGHT, 12)
	_ui_fade(1.0, 0.9)
	if fader.color.a > 0.0:
		_fade(0.0, 0.7)


func _rules_popup() -> void:
	if w.has("rules_pop") and is_instance_valid(w["rules_pop"]):
		w["rules_pop"].queue_free()
		w.erase("rules_pop")
		return
	var p = _panel(ui)
	p.custom_minimum_size = Vector2(760, 0)
	_place(p, Control.PRESET_CENTER)
	var v = _vbox(p, 10)
	_label(v, "COMO JOGAR", 24, C_GOLD)
	var r = _rich(v, 720)
	r.text = RULES
	_cbtn(v, "Fechar", C_HUD, _rules_popup)
	w["rules_pop"] = p


func _on_play() -> void:
	if stage != "title":
		return
	stage = "to_select"
	sfx.play("confirmar", -6.0)
	sfx.play("vfx_dash", -12.0)
	await _ui_fade(0.0, 0.45)
	_show_select()


func _show_select() -> void:
	stage = "select"
	_clear_ui()
	galaxy.set_mode("select")
	ui.modulate.a = 0.0
	_vignette()
	var top = VBoxContainer.new()
	top.add_theme_constant_override("separation", 2)
	ui.add_child(top)
	_place(top, Control.PRESET_CENTER_TOP, 26)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l1 = _label(top, "ESCOLHA O PLANETA DA BATALHA", 26, C_GOLD)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l2 = _label(top, "Toque num planeta para ver as tropas e montar seu exército", 14, C_DIM)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var back = _cbtn(ui, "◀  Voltar", C_HUD, _back_title)
	_place(back, Control.PRESET_BOTTOM_LEFT, 22)
	w["tags"] = {}
	for id in galaxy.pickable():
		var d = galaxy.data(id)
		var tag = PanelContainer.new()
		tag.add_theme_stylebox_override("panel", _tex_box("res://ui/panel.png", 30, d["atm"].lightened(0.1), 18, 12))
		ui.add_child(tag)
		var v = _vbox(tag, 3)
		_label(v, d["name"].to_upper(), 26, C_GOLD)
		_label(v, d["sub"].to_upper(), 12, d["atm"].lightened(0.2))
		var dl = _label(v, d["desc"], 13, C_DIM)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(250, 0)
		dl.visible = not compact
		var b = _cbtn(v, "BATALHAR AQUI", C_GOLD, _choose_planet.bind(id))
		_primary(b)
		b.custom_minimum_size = Vector2(0, 40)
		tag.custom_minimum_size = Vector2(230 if compact else 286, 0)
		tag.position = Vector2(-1000, -1000)
		w["tags"][id] = tag
	await get_tree().create_timer(0.55).timeout
	if stage == "select":
		_ui_fade(1.0, 0.6)


func _back_title() -> void:
	if stage != "select":
		return
	stage = "to_title"
	sfx.play("clique", -8.0)
	await _ui_fade(0.0, 0.35)
	_show_menu()


func _on_planet_hover(id: String) -> void:
	if not w.has("tags"):
		return
	for k in w["tags"].keys():
		var tg = w["tags"][k]
		if is_instance_valid(tg):
			tg.modulate = Color(1, 1, 1, 1) if (id == "" or id == k) else Color(1, 1, 1, 0.55)
	if id != "":
		sfx.play("clique", -14.0, 1.4)


func _update_tags() -> void:
	if not w.has("tags"):
		return
	var vp = get_viewport().get_visible_rect().size
	var placed = []
	for id in w["tags"].keys():
		var tg: Control = w["tags"][id]
		if not is_instance_valid(tg):
			continue
		var sp: Variant = galaxy.screen_pos(id)
		if sp == null:
			tg.visible = false
			continue
		tg.visible = true
		var r = galaxy.screen_radius(id)
		var pos = sp + Vector2(r * 1.5 + 18.0, -tg.size.y * 0.5)
		if pos.x + tg.size.x > vp.x - 12.0:
			pos.x = sp.x - r * 1.5 - 18.0 - tg.size.x
		pos.y = clamp(pos.y, 90.0, vp.y - tg.size.y - 80.0)
		# não deixa uma etiqueta cobrir a outra
		for other in placed:
			var ra = Rect2(pos, tg.size)
			if ra.intersects(other):
				pos.y = other.position.y + other.size.y + 8.0 if pos.y >= other.position.y else other.position.y - tg.size.y - 8.0
		placed.append(Rect2(pos, tg.size))
		tg.position = tg.position.lerp(pos, 0.35) if tg.position.x > -900.0 else pos


func _choose_planet(id: String) -> void:
	if stage != "select":
		return
	stage = "to_army"
	planet_id = id
	setup_cfg["map"] = galaxy.data(id)["map"]
	sfx.play("confirmar", -6.0)
	sfx.play("vfx_portal", -12.0)
	_ui_fade(0.0, 0.35)
	galaxy.set_mode("focus", id)
	await get_tree().create_timer(0.75).timeout
	_show_army()
	ui.modulate.a = 0.0
	_ui_fade(1.0, 0.6)


# volta da batalha direto para a montagem do exército
func _to_army() -> void:
	await _fade(1.0, 0.35, Color("#03050b"))
	_leave_battle()
	planet_id = _planet_of_map(setup_cfg["map"])
	galaxy.set_mode("focus", planet_id)
	galaxy.snap_camera()
	_show_army()
	ui.modulate.a = 0.0
	_ui_fade(1.0, 0.6)
	_fade(0.0, 0.6)


# ================= montar exército =================
func _army_pool() -> Array:
	if mix:
		return DB.card_list.filter(func(c): return not c.get("cmd", false) and (mix_filter == "" or c["f"] == mix_filter))
	return DB.card_list.filter(func(c): return c["f"] == setup_cfg["fac"] and not c.get("cmd", false))


func _cur_cmd() -> String:
	if mix and mix_cmd != "":
		return mix_cmd
	return DB.factions[setup_cfg["fac"]]["cmd"]


func _mix_cmd_step(d: int) -> void:
	var cmds = []
	for f in DB.factions.keys():
		cmds.append(DB.factions[f]["cmd"])
	var i = cmds.find(mix_cmd)
	mix_cmd = cmds[(i + d + cmds.size()) % cmds.size()]
	setup_cfg["fac"] = DB.cards[mix_cmd]["f"]
	army_detail = mix_cmd
	sfx.play("clique", -8.0)
	_fac_music(setup_cfg["fac"])
	_army_refresh()


func _mix_filter_pick(f: String) -> void:
	mix_filter = f
	sfx.play("clique", -8.0)
	_army_refresh_rest()


func _fac_col(f: String) -> Color:
	return Color(DB.factions[f]["color"])


func _flat(bg: Color, border: Color, bw: int = 2, rad: int = 10, pad: int = 10) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(rad)
	s.set_content_margin_all(pad)
	return s


func _tex_rect(tex: Texture2D, size: Vector2) -> TextureRect:
	var t = TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# tipo da habilidade (como ela é usada)
func _ab_kind(c: Dictionary) -> Array:
	var k = c.get("k", {})
	if k.has("action"):
		return ["ATIVA · GASTA 1 AÇÃO", C_ABIL]
	if k.has("entry"):
		return ["AO ENTRAR EM CAMPO", C_DEPLOY]
	if k.has("after"):
		return ["AO ATACAR", C_ATK]
	return ["PASSIVA · SEMPRE LIGADA", C_CARD]


# o que a peça faz no jogo: etiquetas e um resumo
func _impact(c: Dictionary) -> Dictionary:
	var tags = []
	var k = c.get("k", {})
	var txt = (c["ab"]["text"] + " " + c.get("ab2", {}).get("text", "")).to_lower()
	var hp = int(c["int"])
	var atk = int(c["atk"])
	var mov = int(c["mov"])
	var alc = int(c["alc"])
	if alc >= 3:
		tags.append(["Ataque à distância", C_CARD])
	else:
		tags.append(["Corpo a corpo", C_ATK])
	if hp >= 12:
		tags.append(["Muito resistente", Color("#ff5a6a")])
	elif hp <= 5:
		tags.append(["Frágil", Color("#ff9a5a")])
	if atk >= 5:
		tags.append(["Dano alto", C_GOLD])
	if mov >= 3 or k.has("after") and str(k["after"]) == "freeMove" or k.has("action") and str(k["action"]) in ["moveAttack", "tunnel"]:
		tags.append(["Mobilidade", C_MOVE])
	if "restaure" in txt or "cura" in txt or k.has("endHeal"):
		tags.append(["Cura aliados", Color("#5ee08a")])
	if "empurr" in txt or "puxa" in txt or "não pode se mover" in txt or "perde sua habilidade" in txt or "atq até" in txt or "mova o alvo" in txt:
		tags.append(["Controle do inimigo", C_ABIL])
	if "barreira" in txt or "terreno" in txt or "buraco" in txt or "duna" in txt or "rocha" in txt or "ponte" in txt or "fenda" in txt or "estaca" in txt or "casa livre adjacente" in txt or k.has("terra"):
		tags.append(["Mexe no terreno", Color("#e0925a")])
	if k.has("auraAtk") or k.has("auraRed") or k.has("guard") or k.has("guardClan") or k.has("taunt") or "aliado" in txt:
		tags.append(["Apoia aliados", C_DEPLOY])
	if k.has("selfRed") or k.has("firstHitRed") or k.has("selfRedHome") or "reduz" in txt or "não pode ser alvo" in txt:
		tags.append(["Defesa", C_YOU])
	if "dano a cada" in txt or "dano a todas" in txt or "splash" in str(k.get("after", "")):
		tags.append(["Dano em área", Color("#ff6a3a")])
	var parts = []
	if hp >= 12:
		parts.append("segura a linha de frente")
	elif alc >= 3:
		parts.append("ataca de longe, protegido atrás dos aliados")
	elif mov >= 3:
		parts.append("chega rápido onde precisa")
	else:
		parts.append("luta de perto")
	var kd = _ab_kind(c)[0]
	if kd.begins_with("AO ENTRAR"):
		parts.append("o efeito acontece no momento em que entra em campo — escolha bem quando colocá-lo")
	elif kd.begins_with("ATIVA"):
		parts.append("a habilidade gasta 1 ação da ativação")
	elif kd.begins_with("AO ATACAR"):
		parts.append("fica mais forte a cada ataque")
	else:
		parts.append("a habilidade funciona sozinha, sem gastar ação")
	var resumo = parts[0].substr(0, 1).to_upper() + parts[0].substr(1) + "; " + parts[1] + "."
	return {"tags": tags, "resumo": resumo}


func _show_army() -> void:
	stage = "army"
	sfx.stop_loop("musica_galaxia", 1.5)
	_fac_music(setup_cfg["fac"])
	var akey = "MIX" if mix else setup_cfg["fac"]
	if army_fac != akey:
		army_fac = akey
		army_picks = []
		army_start = []
	_clear_ui()
	_vignette()
	var pd = galaxy.data(planet_id)
	# --- barra do alto: planeta, facções, adversário ---
	var topbar = _hbox(ui, 14)
	topbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	topbar.offset_left = 22
	topbar.offset_right = -22
	topbar.offset_top = 14
	var pv = _vbox(topbar, 0)
	_label(pv, pd.get("name", "").to_upper(), 30, C_GOLD)
	_label(pv, pd.get("sub", "").to_upper(), 12, pd.get("atm", C_HUD).lightened(0.2))
	var sp1 = Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(sp1)
	var tabs = _hbox(topbar, 6)
	w["tabs"] = tabs
	var sp2 = Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(sp2)
	var ov = _vbox(topbar, 2)
	_label(ov, "ADVERSÁRIO (CPU)", 11, C_DIM)
	var ob = OptionButton.new()
	ob.add_item("Aleatório")
	ob.set_item_metadata(0, "RND")
	for f in DB.factions.keys():
		ob.add_item(DB.factions[f]["short"])
		ob.set_item_metadata(ob.item_count - 1, f)
	ob.add_item("Mix (misturado)")
	ob.set_item_metadata(ob.item_count - 1, "MIX")
	for i in range(ob.item_count):
		if ob.get_item_metadata(i) == setup_cfg["cpu"]:
			ob.selected = i
	ob.item_selected.connect(_army_cpu.bind(ob))
	ob.custom_minimum_size = Vector2(170, 38)
	ov.add_child(ob)
	# --- comandante (embaixo à esquerda, o planeta aparece acima) ---
	var cmdp = PanelContainer.new()
	ui.add_child(cmdp)
	cmdp.anchor_left = 0.0
	cmdp.anchor_right = 0.3
	cmdp.anchor_top = 1.0
	cmdp.anchor_bottom = 1.0
	cmdp.offset_left = 18
	cmdp.offset_right = -6
	cmdp.offset_bottom = -16
	cmdp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	w["cmdp"] = cmdp
	# --- grade de tropas (meio) ---
	var mid = VBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	ui.add_child(mid)
	mid.anchor_left = 0.305
	mid.anchor_right = 0.655
	mid.anchor_top = 0.15 if compact else 0.125
	mid.anchor_bottom = 0.785
	var mh = _hbox(mid, 8)
	_label(mh, "TROPAS", 22, C_TXT)
	var mt = _label(mh, "toque para pôr ou tirar do exército", 12, C_DIM)
	mt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mixbar = HFlowContainer.new()
	mixbar.add_theme_constant_override("h_separation", 5)
	mixbar.add_theme_constant_override("v_separation", 5)
	mid.add_child(mixbar)
	w["mixbar"] = mixbar
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(sc)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	w["grid"] = grid
	w["grid_sc"] = sc
	# --- detalhe (direita) ---
	var det = PanelContainer.new()
	ui.add_child(det)
	det.anchor_left = 0.665
	det.anchor_right = 1.0
	det.anchor_top = 0.125
	det.anchor_bottom = 0.785
	det.offset_right = -18
	w["det"] = det
	# --- barra de baixo: exército escolhido ---
	var bot = PanelContainer.new()
	ui.add_child(bot)
	bot.anchor_left = 0.305
	bot.anchor_right = 1.0
	bot.anchor_top = 0.8
	bot.anchor_bottom = 1.0
	bot.offset_right = -18
	bot.offset_bottom = -16
	var bh = _hbox(bot, 10)
	var slots = _hbox(bh, 6)
	w["slots"] = slots
	var bv = _vbox(bh, 6)
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint = _label(bv, "", 13, C_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["army_hint"] = hint
	if compact:
		hint.add_theme_font_size_override("font_size", 12)
	var br = _hbox(bv, 6)
	if compact:
		# celular: "voltar" vai para o alto, embaixo de nome do planeta
		var b1c = _cbtn(pv, "◀ Planetas", C_HUD, _army_back)
		b1c.custom_minimum_size = Vector2(0, 34)
		b1c.add_theme_font_size_override("font_size", 12)
		b1c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		var b1 = _cbtn(br, "◀ Planetas", C_HUD, _army_back)
		b1.custom_minimum_size = Vector2(0, 38)
	var b2 = _cbtn(br, "Sortear", C_HUD, _army_random)
	b2.custom_minimum_size = Vector2(0, 38)
	var b3 = _cbtn(br, "Limpar", C_HUD, _army_clear)
	b3.custom_minimum_size = Vector2(0, 38)
	if compact:
		for bb in [b2, b3]:
			bb.add_theme_font_size_override("font_size", 12)
	var go = _cbtn(bh, "BATALHAR", C_GOLD, _army_go, true)
	_primary(go)
	go.custom_minimum_size = Vector2(130 if compact else 190, 0)
	go.add_theme_font_size_override("font_size", 17 if compact else 22)
	w["go"] = go
	if army_detail == "" or not DB.cards.has(army_detail) or (not mix and DB.cards[army_detail]["f"] != setup_cfg["fac"]):
		army_detail = _cur_cmd()
	_army_refresh()


func _army_refresh() -> void:
	if stage != "army" or not w.has("grid"):
		return
	var fac = setup_cfg["fac"]
	var fc = _fac_col(fac)
	# abas de facção
	for c in w["tabs"].get_children():
		c.queue_free()
	for f in DB.factions.keys() + ["MIX"]:
		var on = (f == fac and not mix) if f != "MIX" else mix
		var b = Button.new()
		b.custom_minimum_size = Vector2(56, 54) if compact else Vector2(52 + (DB.factions[f]["short"].length() if f != "MIX" else 4) * 9, 54)
		b.tooltip_text = DB.factions[f]["short"] if f != "MIX" else "Mix: misture todas as facções"
		var col = _fac_col(f) if f != "MIX" else Color("#e8e0ff")
		b.add_theme_stylebox_override("normal", _flat(Color(col.darkened(0.55), 0.92) if on else Color(0.03, 0.05, 0.1, 0.85), col if on else col.darkened(0.35), 2 if on else 1, 8, 4))
		b.add_theme_stylebox_override("hover", _flat(Color(col.darkened(0.5), 0.95), col.lightened(0.2), 2, 8, 4))
		b.add_theme_stylebox_override("pressed", _flat(Color(col.darkened(0.4), 0.95), col.lightened(0.3), 2, 8, 4))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_army_fac_pick.bind(f))
		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 5)
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		if f == "MIX":
			var ml = _label(hb, "✦", 24, Color.WHITE if on else col)
			ml.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ml.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			var cid = DB.factions[f]["cmd"]
			if DB.portraits.has(cid):
				hb.add_child(_tex_rect(DB.portraits[cid], Vector2(38, 42)))
		var tl = _label(hb, DB.factions[f]["short"] if f != "MIX" else "Mix", 11, Color.WHITE if on else col.lightened(0.45))
		tl.visible = not compact
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not on:
			b.modulate = Color(1, 1, 1, 0.8)
		w["tabs"].add_child(b)
	# comandante
	for c in w["cmdp"].get_children():
		c.queue_free()
	w["cmdp"].add_theme_stylebox_override("panel", _flat(Color(0.03, 0.05, 0.11, 0.86), fc, 2, 12, 12))
	var cid2 = _cur_cmd()
	var cc = DB.cards[cid2]
	var cv = _vbox(w["cmdp"], 6)
	var ch = _hbox(cv, 10)
	if DB.portraits.has(cid2):
		ch.add_child(_tex_rect(DB.portraits[cid2], Vector2(76, 76)))
	var cnv = _vbox(ch, 1)
	_label(cnv, ("COMANDANTE · %s" % DB.factions[fac]["short"].to_upper()) if not mix else ("MIX · COMANDANTE (%s)" % DB.factions[fac]["short"].to_upper()), 11, fc.lightened(0.35))
	_label(cnv, cc["name"], 22, C_GOLD)
	_label(cnv, "Vida %d · Atq %d · Mov %d · entra no round 6" % [int(cc["int"]), int(cc["atk"]), int(cc["mov"])], 12, C_DIM)
	var cb = Button.new()
	cb.flat = true
	cb.text = "ver detalhes ▶"
	cb.add_theme_font_size_override("font_size", 11)
	cb.pressed.connect(_army_show.bind(cid2))
	cnv.add_child(cb)
	if mix:
		var sw = _hbox(cnv, 6)
		var pb = _cbtn(sw, "◀", C_HUD, _mix_cmd_step.bind(-1))
		pb.custom_minimum_size = Vector2(44, 32)
		_label(sw, "trocar comandante", 11, C_DIM).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nb = _cbtn(sw, "▶", C_HUD, _mix_cmd_step.bind(1))
		nb.custom_minimum_size = Vector2(44, 32)
	if compact:
		_army_refresh_rest()
		return
	_ab_box(cv, "PASSIVA", C_CARD, cc["ab"]["name"], cc["ab"]["text"], 380)
	if cc.has("ab2"):
		var k2 = cc["ab2"].get("kind", "ativa")
		_ab_box(cv, "ATIVA · 1 VEZ POR PARTIDA" if k2 != "passiva" else "PASSIVA", C_GOLD if k2 != "passiva" else C_CARD, cc["ab2"]["name"], cc["ab2"]["text"], 380)
	_army_refresh_rest()


func _army_refresh_rest() -> void:
	# filtro de facção (só no Mix)
	for c in w["mixbar"].get_children():
		c.queue_free()
	w["mixbar"].visible = mix
	if mix:
		for f in [""] + DB.factions.keys():
			var col = Color("#e8e0ff") if f == "" else _fac_col(f)
			var on = mix_filter == f
			var fb = Button.new()
			fb.text = "Todas" if f == "" else DB.factions[f]["short"]
			fb.add_theme_font_size_override("font_size", 11 if compact else 12)
			fb.add_theme_stylebox_override("normal", _flat(Color(col.darkened(0.55), 0.92) if on else Color(0.03, 0.05, 0.1, 0.85), col if on else col.darkened(0.35), 2 if on else 1, 6, 5))
			fb.add_theme_stylebox_override("hover", _flat(Color(col.darkened(0.5), 0.95), col.lightened(0.2), 2, 6, 5))
			fb.add_theme_stylebox_override("pressed", _flat(Color(col.darkened(0.4), 0.95), col, 2, 6, 5))
			fb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			fb.add_theme_color_override("font_color", Color.WHITE if on else col.lightened(0.4))
			fb.pressed.connect(_mix_filter_pick.bind(f))
			w["mixbar"].add_child(fb)
	# grade
	for c in w["grid"].get_children():
		c.queue_free()
	for c in _army_pool():
		w["grid"].add_child(_army_card(c))
	# vagas
	for c in w["slots"].get_children():
		c.queue_free()
	for i in range(5):
		w["slots"].add_child(_army_slot(army_picks[i] if i < army_picks.size() else ""))
	var ready_ok = army_picks.size() == 5 and army_start.size() == 2
	w["go"].disabled = not ready_ok
	var hint = "Exército %d/5 · ★ começa em campo (%d/2). Os outros ficam na reserva." % [army_picks.size(), army_start.size()]
	if army_picks.size() < 5:
		hint = "Escolha mais %d tropa(s). ★ = começa em campo (%d/2)." % [5 - army_picks.size(), army_start.size()]
	elif army_start.size() < 2:
		hint = "Marque mais %d tropa(s) com ★ para começar em campo." % (2 - army_start.size())
	if compact:
		hint = "%d/5 tropas · ★ em campo %d/2" % [army_picks.size(), army_start.size()]
	w["army_hint"].text = hint
	w["army_hint"].add_theme_color_override("font_color", C_DIM if ready_ok else Color("#ffb070"))
	_army_detail_build()


func _ab_box(parent: Control, kind: String, col: Color, nm: String, text: String, width: int) -> void:
	var p = PanelContainer.new()
	var s = _flat(Color(0.06, 0.09, 0.17, 0.92), col.darkened(0.2), 0, 8, 8)
	s.border_width_left = 3
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	var v = _vbox(p, 2)
	var h = _hbox(v, 8)
	var kl = _label(h, kind, 10, col)
	kl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label(h, nm, 15, C_TXT)
	var t = _label(v, text, 13, C_DIM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(width, 0)


func _stat_mini(parent: Control, col: Color, v: int) -> void:
	var h = _hbox(parent, 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sw = ColorRect.new()
	sw.color = col
	sw.custom_minimum_size = Vector2(7, 7)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sw)
	var l = _label(h, str(v), 13, C_TXT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


# botão principal: dourado cheio, texto escuro
func _primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _flat(Color("#ffab40"), Color("#ffe0a0"), 2, 8, 10))
	b.add_theme_stylebox_override("hover", _flat(Color("#ffc060"), Color.WHITE, 2, 8, 10))
	b.add_theme_stylebox_override("pressed", _flat(Color("#e08a20"), Color("#ffe0a0"), 2, 8, 10))
	b.add_theme_stylebox_override("disabled", _flat(Color(0.2, 0.22, 0.28, 0.9), Color(0.35, 0.4, 0.48), 1, 8, 10))
	b.add_theme_color_override("font_color", Color("#1c1006"))
	b.add_theme_color_override("font_hover_color", Color("#1c1006"))
	b.add_theme_color_override("font_pressed_color", Color("#1c1006"))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.6, 0.66))


const ST_COL = [Color("#ff5a6a"), Color("#ffab40"), Color("#4cd964"), Color("#4da3ff")]


func _army_card(c: Dictionary) -> Control:
	var id = c["id"]
	var chosen = army_picks.has(id)
	var fc = _fac_col(c["f"])
	var b = Button.new()
	b.custom_minimum_size = Vector2(0, 168 if compact else 196)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border = C_GOLD if chosen else (C_HUD if id == army_detail else fc.darkened(0.15))
	b.add_theme_stylebox_override("normal", _flat(Color(0.035, 0.06, 0.12, 0.97), border, 3 if chosen else 2, 10, 6))
	b.add_theme_stylebox_override("hover", _flat(Color(0.07, 0.11, 0.2, 0.95), C_HUD, 2, 10, 6))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.07, 0.11, 0.2, 0.95), C_GOLD, 3, 10, 6))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_army_toggle.bind(id))
	b.mouse_entered.connect(_army_show.bind(id))
	if army_picks.size() >= 5 and not chosen:
		b.modulate = Color(0.5, 0.52, 0.58, 1.0)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var pic = PanelContainer.new()
	pic.add_theme_stylebox_override("panel", _flat(fc.darkened(0.55), fc.darkened(0.3), 0, 8, 2))
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)
	var tex = DB.portraits.get(id, DB.art.get(id, null))
	pic.add_child(_tex_rect(tex, Vector2(0, 70 if compact else 92)))
	if chosen:
		var badge = _label(pic, "★ EM CAMPO" if army_start.has(id) else "✓ NO EXÉRCITO", 10, C_GOLD)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_END
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl = _label(v, c["name"], 14, C_GOLD if chosen else C_TXT)
	nl.clip_text = true
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rl = _label(v, c["role"], 11, C_DIM)
	rl.clip_text = true
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sr = _hbox(v, 8)
	sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vals = [int(c["int"]), int(c["atk"]), int(c["mov"]), int(c["alc"])]
	for i in range(4):
		_stat_mini(sr, ST_COL[i], vals[i])
	var kd = _ab_kind(c)
	var al = _label(v, kd[0].split(" ·")[0], 10, kd[1])
	al.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _army_slot(id: String) -> Control:
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(76 if compact else 104, 0)
	if id == "":
		p.add_theme_stylebox_override("panel", _flat(Color(0.03, 0.05, 0.1, 0.6), Color(0.3, 0.42, 0.55, 0.6), 1, 8, 6))
		var l = _label(p, "vaga\nlivre", 12, Color(0.4, 0.5, 0.6))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return p
	var on = army_start.has(id)
	p.add_theme_stylebox_override("panel", _flat(Color(0.05, 0.08, 0.16, 0.92), C_GOLD if on else _fac_col(DB.cards[id]["f"]), 2, 8, 5))
	var v = _vbox(p, 2)
	var tex = DB.portraits.get(id, null)
	v.add_child(_tex_rect(tex, Vector2(0, 36 if compact else 50)))
	var nl = _label(v, _short(id), 11, C_TXT)
	nl.clip_text = true
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var h = _hbox(v, 3)
	var sb = Button.new()
	sb.text = "★" if on else "☆"
	sb.tooltip_text = "Começa em campo" if on else "Fica na reserva (toque para começar em campo)"
	sb.custom_minimum_size = Vector2(36, 26) if compact else Vector2(46, 28)
	_style_btn(sb, C_GOLD, on)
	sb.pressed.connect(_army_star.bind(id))
	h.add_child(sb)
	var xb = Button.new()
	xb.text = "×"
	xb.custom_minimum_size = Vector2(30, 26) if compact else Vector2(40, 28)
	_style_btn(xb, C_ATK)
	xb.pressed.connect(_army_toggle.bind(id))
	h.add_child(xb)
	xb.visible = not compact   # no celular: toque na carta da tropa para tirar
	return p


func _army_show(id: String) -> void:
	if army_detail == id:
		return
	army_detail = id
	_army_detail_build()


func _army_detail_build() -> void:
	if not w.has("det") or not is_instance_valid(w["det"]):
		return
	var id = army_detail
	if not DB.cards.has(id):
		return
	var c = DB.cards[id]
	var fc = _fac_col(c["f"])
	var det: PanelContainer = w["det"]
	for ch in det.get_children():
		ch.queue_free()
	det.add_theme_stylebox_override("panel", _flat(Color(0.03, 0.05, 0.11, 0.9), fc, 2, 12, 12))
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	det.add_child(sc)
	var v = _vbox(sc, 7)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# arte com fundo na cor da facção
	var art = PanelContainer.new()
	var gs = StyleBoxTexture.new()
	var gt = GradientTexture2D.new()
	var gr = Gradient.new()
	gr.set_color(0, fc.darkened(0.25))
	gr.set_color(1, Color(fc.darkened(0.7), 0.0))
	gt.gradient = gr
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gs.texture = gt
	art.add_theme_stylebox_override("panel", gs)
	v.add_child(art)
	art.add_child(_tex_rect(DB.art.get(id, DB.portraits.get(id, null)), Vector2(0, 165)))
	_label(v, c["name"], 26, C_GOLD)
	_label(v, "%s · %s" % [c["role"], DB.factions[c["f"]]["short"]], 13, fc.lightened(0.35))
	# barras de atributos
	var names = ["VIDA", "ATAQUE", "MOVIMENTO", "ALCANCE"]
	var vals = [int(c["int"]), int(c["atk"]), int(c["mov"]), int(c["alc"])]
	var maxs = [14.0, 6.0, 4.0, 6.0]
	for i in range(4):
		var h = _hbox(v, 8)
		var nl = _label(h, names[i], 11, C_DIM)
		nl.custom_minimum_size = Vector2(88, 0)
		var bar = Control.new()
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar)
		var bg = ColorRect.new()
		bg.color = Color(1, 1, 1, 0.08)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar.add_child(bg)
		var fill = ColorRect.new()
		fill.color = ST_COL[i]
		fill.anchor_bottom = 1.0
		fill.anchor_right = clamp(vals[i] / maxs[i], 0.05, 1.0)
		bar.add_child(fill)
		var vl = _label(h, str(vals[i]), 14, ST_COL[i].lightened(0.2))
		vl.custom_minimum_size = Vector2(24, 0)
	# habilidades
	var kd = _ab_kind(c)
	if c.get("cmd", false):
		kd = ["PASSIVA", C_CARD]
	var dw = int(clamp(get_viewport().get_visible_rect().size.x * 0.335 - 60.0, 220.0, 420.0))
	_ab_box(v, kd[0], kd[1], c["ab"]["name"], c["ab"]["text"], dw)
	if c.has("ab2"):
		var k2 = c["ab2"].get("kind", "ativa")
		_ab_box(v, "ATIVA · 1 VEZ POR PARTIDA" if k2 != "passiva" else "PASSIVA", C_GOLD if k2 != "passiva" else C_CARD, c["ab2"]["name"], c["ab2"]["text"], dw)
	# impacto no jogo
	var im = _impact(c)
	_label(v, "IMPACTO NO JOGO", 12, C_HUD)
	var flow = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	for t in im["tags"]:
		var tp = PanelContainer.new()
		tp.add_theme_stylebox_override("panel", _flat(Color(t[1], 0.16), t[1], 1, 10, 4))
		flow.add_child(tp)
		var tl = _label(tp, t[0], 12, t[1].lightened(0.3))
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rs = _label(v, im["resumo"], 13, C_TXT)
	rs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rs.custom_minimum_size = Vector2(dw, 0)
	if not c.get("cmd", false):
		var chosen = army_picks.has(id)
		var h2 = _hbox(v, 8)
		var ab = _cbtn(h2, "REMOVER" if chosen else "+ ADICIONAR", C_ATK if chosen else C_MOVE, _army_toggle.bind(id), not chosen)
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ab.disabled = not chosen and army_picks.size() >= 5
		if chosen:
			_cbtn(h2, "★ EM CAMPO" if army_start.has(id) else "☆ RESERVA", C_GOLD, _army_star.bind(id), army_start.has(id))


func _army_fac_pick(f: String) -> void:
	if f == "MIX":
		if mix:
			return
		# entra no Mix mantendo as tropas já escolhidas
		mix = true
		mix_cmd = DB.factions[setup_cfg["fac"]]["cmd"]
		mix_filter = ""
		army_fac = "MIX"
		army_detail = mix_cmd
		sfx.play("clique", -8.0)
		_army_refresh()
		return
	if f == setup_cfg["fac"] and not mix:
		return
	mix = false
	setup_cfg["fac"] = f
	army_fac = f
	army_picks = []
	army_start = []
	army_detail = DB.factions[f]["cmd"]
	sfx.play("clique", -8.0)
	_fac_music(f)
	_army_refresh()


func _army_cpu(i: int, ob: OptionButton) -> void:
	setup_cfg["cpu"] = ob.get_item_metadata(i)


func _army_back() -> void:
	if stage != "army":
		return
	stage = "to_select"
	sfx.play("clique", -8.0)
	_fac_music("")
	sfx.loop("musica_galaxia", -9.0, 2.0)
	await _ui_fade(0.0, 0.35)
	_show_select()


func _army_toggle(id: String) -> void:
	army_detail = id
	if army_picks.has(id):
		army_picks.erase(id)
		army_start.erase(id)
	elif army_picks.size() < 5:
		army_picks.append(id)
		if army_start.size() < 2:
			army_start.append(id)
	if sfx != null:
		sfx.play("clique", -8.0)
	_army_refresh()


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
	_army_refresh()


func _army_random() -> void:
	var x = AI.setup_mix()["picks"] if mix else AI.setup(setup_cfg["fac"])["picks"]
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
	_army_refresh()


func _army_clear() -> void:
	army_picks = []
	army_start = []
	_army_refresh()


func _cpu_fac() -> String:
	if setup_cfg["cpu"] == "MIX" or (setup_cfg["cpu"] != "RND" and DB.factions.has(setup_cfg["cpu"])):
		return setup_cfg["cpu"]
	var fs = DB.factions.keys().filter(func(f): return f != setup_cfg["fac"])
	return fs[randi() % fs.size()]


func _army_go() -> void:
	if army_picks.size() != 5 or army_start.size() != 2 or stage != "army":
		return
	stage = "dive"
	sfx.play("confirmar", -6.0)
	DB.set_map(setup_cfg["map"])
	var spots = DB.entry[0]
	var mine = {"fac": setup_cfg["fac"], "cmd": _cur_cmd(), "mix": mix, "picks": army_picks.duplicate(), "start": [{"id": army_start[0], "h": spots[0]}, {"id": army_start[1], "h": spots[spots.size() - 1]}]}
	var sides = [mine, _cpu_side(1, _cpu_fac())]
	await _ui_fade(0.0, 0.4)
	sfx.play("vfx_portal", -6.0)
	sfx.play("vfx_dash", -8.0)
	sfx.stop_loop("musica_galaxia", 2.5)
	_fac_music("")
	galaxy.set_mode("dive")
	await get_tree().create_timer(1.15).timeout
	await _fade(1.0, 0.55, galaxy.data(planet_id).get("dive", Color("#e0b070")))
	intro = true
	_start_match(sides)


func _cpu_side(p: int, fac: String) -> Dictionary:
	DB.set_map(setup_cfg["map"])
	var s = AI.setup_mix() if fac == "MIX" else AI.setup(fac)
	var tough = s["picks"].duplicate()
	tough.sort_custom(func(a, b): return int(DB.cards[a]["int"]) > int(DB.cards[b]["int"]))
	var spots = DB.entry[p]
	s["start"] = [{"id": tough[0], "h": spots[0]}, {"id": tough[1], "h": spots[spots.size() - 1]}]
	return s


func _start_match(sides) -> void:
	DB.set_map(setup_cfg["map"])
	if sides == null:
		sides = []
		for p in range(2):
			var fac = setup_cfg["fac"] if p == 0 else setup_cfg["cpu"]
			var s = AI.setup_mix() if fac == "MIX" else AI.setup(fac)
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
	stage = "battle"
	_build_hud()
	galaxy.deactivate()
	board.visible = true
	board.build(game)
	board.cam.make_current()
	if intro:
		intro = false
		# chegada: a câmera desce do alto do planeta até o tabuleiro
		var gy = board.cam_yaw
		board.cam_dist = 120.0
		board.cam_pitch = 1.42
		board.cam_yaw = gy + 0.9
		board.cam_speed = 1.7
		board.fit_camera(false)
		ui.modulate.a = 0.0
		_fade(0.0, 0.8)
		_later(1.2, func(): _ui_fade(1.0, 0.7))
		_later(3.0, func(): board.cam_speed = 8.0)
	else:
		ui.modulate.a = 1.0
		if fader.color.a > 0.0:
			_fade(0.0, 0.4)
	vfx.setup_ambient(game.map_id)
	sfx.stop_all_loops()
	if game.map_id == "tarhut":
		sfx.loop("vento_loop", -15.0, 2.0)
	else:
		sfx.loop("ilha_loop", -14.0, 2.0)
	if autotest:
		_map_music()
	refresh()
	if not autotest:
		await _entrance()
	await game.begin_game()
	busy = false
	await after()


# ================= HUD da batalha =================
func _build_hud() -> void:
	_clear_ui()
	plates.clear()
	var plr = Control.new()
	plr.set_anchors_preset(Control.PRESET_FULL_RECT)
	plr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(plr)
	w["plates"] = plr
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
	if compact:
		_button(topr, "CPU", _toggle_cpu)
	_button(topr, "Cartas", func(): _toggle_panel("cards"))
	if not compact:
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
	var vw = get_viewport().get_visible_rect().size
	w["why"].custom_minimum_size = Vector2(min(560.0, vw.x * 0.45), 0)
	var lg = _hbox(av, 14)
	lg.alignment = BoxContainer.ALIGNMENT_CENTER
	_chip(lg, C_MOVE, "Andar (nº = custo)")
	_chip(lg, C_ATK, "Atacar")
	_chip(lg, C_ABIL, "Habilidade / escolher")
	_chip(lg, C_DEPLOY, "Entrar em campo")
	_chip(lg, Color(0.12, 0.1, 0.08), "Fora de alcance (clique: por quê?)")
	w["legend"] = lg
	if compact:
		lg.visible = false
	# perguntas e prévias (logo abaixo dos avisos)
	var pr = _panel(topcol)
	pr.custom_minimum_size = Vector2(min(560.0, vw.x * 0.48), 0)
	var pv = _vbox(pr, 8)
	w["prompt_text"] = _rich(pv, int(min(540.0, vw.x * 0.46)))
	w["prompt_btns"] = _hbox(pv, 8)
	w["prompt_btns"].alignment = BoxContainer.ALIGNMENT_END
	w["prompt"] = pr
	# ficha da peça
	var uc = _panel(ui)
	_place(uc, Control.PRESET_BOTTOM_LEFT, 8)
	w["ucard_text"] = _rich(uc, 260 if compact else 320)
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
	w["end"].custom_minimum_size = Vector2(150 if compact else 170, 52)
	if compact:
		w["round"].add_theme_font_size_override("font_size", 22)
	# coluna da CPU (à direita, acima do fim de turno)
	var right = _panel(ui)
	_place(right, Control.PRESET_TOP_RIGHT, 8)
	right.offset_top = 64
	w["party1"] = _vbox(right, 4)
	w["party1_panel"] = right
	right.visible = cpu_open or not compact
	# painel lateral (cartas / registro / regras)
	var side = _panel(ui)
	_place(side, Control.PRESET_CENTER, 0)
	side.custom_minimum_size = Vector2(min(620.0, vw.x - 40.0), 0)
	var sv = _vbox(side, 10)
	w["side_title"] = _label(sv, "", 26, C_GOLD)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(min(600.0, vw.x - 60.0), min(420.0, vw.y - 190.0))
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
	bn.remove_theme_color_override("font_color")
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
		for h in game.entry_zone(p):
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
		_label(box, ("VOCÊ · " if p == 0 else "CPU · ") + ("Mix" if game.P[p].get("mix", false) else DB.factions[game.P[p]["fac"]]["short"]), 13, Color("#4f9be0") if p == 0 else Color("#e0563f"))
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
				hl.custom_minimum_size = Vector2(176 if compact else 190, 0)
				hl.add_theme_font_size_override("font_size", 12)
				if compact:
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
			if compact:
				b.text = "%s  %d/%d\n%s" % [_short(u.cid), max(0, u.hp), u.maxhp, stx]
				b.add_theme_font_size_override("font_size", 13)
				b.custom_minimum_size = Vector2(176, 44)
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
	var is_mull = asking != null and asking["q"].get("kind", "") == "mulligan"
	if is_mull:
		_show_mull(asking["q"]["show"])
	else:
		_hide_mull()
	if asking != null and not is_mull:
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
			txt = "Seu personagem (arraste): +1 Movimento"
		"placas":
			txt = "Seu personagem (arraste): -1 dano recebido"
		"lente":
			txt = "Seu personagem (arraste): +1 Alcance"
		"reparo":
			txt = "Seu personagem (arraste): +4 de Vida"
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
		"granada":
			txt = "Inimigos numa área: 1 de dano cada"
			if u != null:
				hs = game.granada_opts(u)
		"sinalizador":
			txt = "Inimigo marcado: +1 dano contra ele"
			if u != null:
				for x in game.enemies_of(u):
					if DB.dist(x.pos(), u.pos()) <= 4 and game.los(u.pos(), x.pos()):
						hs.append(x.pos())
		"adrenalina":
			txt = "Ativo: -1 Vida, +1 ação"
		"barreira":
			txt = "Casa ao lado: barreira de 3 Vida"
			if u != null:
				hs = game.adj_free(u.pos())
		"gancho":
			txt = "Inimigo a até 3: puxado 1 casa"
			if u != null:
				for x in game.gancho_targets(u):
					hs.append(x.pos())
		"camuflagem":
			txt = "Seu personagem (arraste): não pode ser atacado no round"
		"onda":
			txt = "Inimigos ao lado: empurrados 1 casa"
			if u != null:
				for x in game.enemies_of(u):
					if DB.dist(x.pos(), u.pos()) == 1:
						hs.append(x.pos())
		"orbital":
			txt = "Inimigo a até 5: 3 de dano"
			if u != null:
				for x in game.enemies_of(u):
					if DB.dist(x.pos(), u.pos()) <= 5:
						hs.append(x.pos())
		"kit":
			txt = "Ativo e aliados a até 2: +2 Vida"
			if u != null:
				for x in game.allies_of(u, true):
					if DB.dist(x.pos(), u.pos()) <= 2:
						hs.append(x.pos())
		"ultimo":
			txt = "Ativo ferido (metade da Vida): +3 dano no ataque"
		"revide":
			txt = "Reação: aliado atacado de perto devolve 2 de dano"
		"resgate":
			txt = "Ativo troca de lugar com aliado a até 4"
			if u != null:
				for x in game.allies_of(u):
					if not x.barrier and DB.dist(x.pos(), u.pos()) <= 4:
						hs.append(x.pos())
		"quantica":
			txt = "Um aliado e um inimigo a até 3 trocam de lugar"
			if u != null:
				for x in game.quantica_allies(u) + game.quantica_enemies(u):
					hs.append(x.pos())
		"interceptar":
			txt = "Rouba 1 carta aleatória do oponente"
		"grito":
			txt = "Todos os seus em campo: +1 ATQ no round"
			if u != null:
				for x in game.allies_of(u, true):
					if not x.barrier:
						hs.append(x.pos())
		"evacuacao":
			txt = "Último aliado derrotado volta à reserva"
		"execucao":
			txt = "Inimigo ao lado com até 3 de Vida cai na hora"
			if u != null:
				for x in game.execucao_targets(u):
					hs.append(x.pos())
		"contra":
			txt = "Se estiver em desvantagem: +1 ação e 1 carta"
		"rede":
			txt = "Inimigo a até 3 não se move até o próximo round"
			if u != null:
				for x in game.rede_targets(u):
					hs.append(x.pos())
	if hs.is_empty() and u != null and ["propulsor", "placas", "lente", "reparo", "fogo", "adrenalina", "camuflagem", "ultimo", "contra"].has(id):
		hs = [u.pos()]
	return {"txt": txt, "hexes": hs}


func _with_card_hover(st: Dictionary) -> Dictionary:
	if card_hover == "" or game == null:
		return st
	var st2 = st.duplicate(true)
	var dragging = card_drag != null and card_drag["on"]
	var hs = _drop_hexes(card_hover) if dragging else _card_targets(card_hover)["hexes"]
	var col: Color = TYPE_COL.get(DB.tactics[card_hover]["type"], Color("#e0c8ff"))
	for h in hs:
		st2["hl"][h] = "pk"
		st2["labels"][h] = "solte aqui" if dragging else "carta"
		st2["label_colors"][h] = col.lightened(0.3)
	return st2


# casas onde a carta pode ser solta agora (calcula com a peça selecionada se ainda não há ativação)
func _drop_hexes(id: String) -> Array:
	if game == null or not my_turn():
		return []
	if game.act != null:
		return game.drop_opts(game.cur, id)
	var u = sel_unit()
	if u == null or not game.can_start(u):
		return []
	game.act = game._new_act(u, 2, false)
	var hs = game.drop_opts(game.cur, id)
	if hs.is_empty():
		hs = [u.pos()]
	game.act = null
	return hs


func _card_hover_set(id: String, card: Control, on: bool) -> void:
	if card_drag != null and card_drag["on"]:
		return
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
	card.custom_minimum_size = Vector2(118, 150) if compact else Vector2(128, 172)
	card.add_theme_stylebox_override("panel", _tex_box("res://ui/card.png", 20, col if (ok or react) else col.darkened(0.55), 9, 7))
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var cost = _label(v, "%s · %s" % [t["type"].to_upper(), ("%d AÇÃO" % int(t["cost"])) if int(t["cost"]) > 0 else "GRÁTIS"], 9, col.lightened(0.4))
	if compact:
		cost.add_theme_font_size_override("font_size", 10)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic = TextureRect.new()
	ic.custom_minimum_size = Vector2(0, 30 if compact else 40)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ipath = "res://ui/icons/%s.png" % id
	if ResourceLoader.exists(ipath):
		ic.texture = load(ipath)
	ic.modulate = col
	v.add_child(ic)
	var nm = _label(v, t["name"], 13 if compact else 11, Color.WHITE)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font_btn != null:
		nm.add_theme_font_override("font", font_btn)
	var tg = _card_targets(id)
	var af = _label(v, tg["txt"], 9, col.lightened(0.35))
	if compact:
		af.add_theme_font_size_override("font_size", 11)
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
			# segurar e arrastar: solta no personagem; só tocar: usa como antes
			card_drag = {"id": id, "start": get_viewport().get_mouse_position(), "on": false}
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


func _play_card(id: String, drop: Variant = null) -> void:
	if not _card_playable(id):
		return
	panel_open = ""
	if game.act == null:
		game.start_activation(sel_unit())
	busy = true
	refresh()
	await game.play_tactic(game.cur, id, drop)
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
	if card_drag != null:
		if event is InputEventMouseMotion:
			var mp = (event as InputEventMouseMotion).position
			if not card_drag["on"] and mp.distance_to(card_drag["start"]) > 10.0:
				card_drag["on"] = true
				card_hover = card_drag["id"]
				var ipath = "res://ui/icons/%s.png" % card_drag["id"]
				w["drag_icon"].texture = load(ipath) if ResourceLoader.exists(ipath) else null
				w["drag_icon"].modulate = TYPE_COL.get(DB.tactics[card_drag["id"]]["type"], C_CARD)
				w["drag_icon"].visible = true
				w["drag_icon"].size = Vector2(96, 96)
				w["drag_icon"].z_index = 50
				for cc in w["hand"].get_children():
					cc.scale = Vector2.ONE
					cc.z_index = 0
				board.set_state(_with_card_hover(last_st))
			if card_drag["on"]:
				w["drag_icon"].position = mp - Vector2(48, 48)
		elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var cd = card_drag
			card_drag = null
			w["drag_icon"].visible = false
			w["drag_icon"].modulate = Color.WHITE
			w["drag_icon"].size = Vector2(70, 70)
			card_hover = ""
			if not cd["on"]:
				_play_card(cd["id"])
			else:
				get_viewport().set_input_as_handled()
				var h = board.pick_hex((event as InputEventMouseButton).position)
				if h != null and _drop_hexes(cd["id"]).has(h):
					_play_card(cd["id"], h)
				else:
					sfx.play("clique", -8.0, 0.7)
					board.set_state(last_st)
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
	var k = _fx_scale()
	if amt > 0:
		vfx.impact(p, Color("#ff9a5a"), clamp(amt / 4.0, 0.6, 1.8) * k)
		vfx.flip("hit", p - Vector3(0, 0.75, 0), clamp(2.1 + amt * 0.22, 2.3, 3.8), 0.6)
		vfx.flip("ring", _hex_pos(h, 0.0), 2.4, 0.5, Color("#ff8a3a"), true)
		if amt >= 4:
			vfx.flip("boom", _hex_pos(h, 0.0), 2.0, 0.6, Color(1, 0.85, 0.7))
		board.shake = max(board.shake, clamp(amt * 0.08, 0.15, 0.5))
		_voice(uid, "dor", -1.0, 0.06)
	else:
		vfx.block(p)
		vfx.flip("shield", p - Vector3(0, 0.9, 0), 1.9, 0.55, Color("#bfe8ff"))


# efeitos maiores quando a câmera está longe (tabuleiro grande)
func _fx_scale() -> float:
	return clamp(board.cam_dist / 26.0, 1.0, 2.0)


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
			var k = _fx_scale()
			_voice(e["from"], "atk", -2.0)
			if e["ranged"]:
				var style = _shot_style(e["from"])
				# disparo: clarão na arma do atacante
				var muzzle = {"cristal": "crystal", "laser": "beam", "energia": "bolt"}.get(style, "hit")
				vfx.flip(muzzle, a - Vector3(0, 0.8, 0), 2.0, 0.5, col.lightened(0.3))
				impact_delay = vfx.projectile(a, tgt, col, style, k)
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
				impact_delay = 0.16
				impact_until = now + 160
				vfx.flip("dash", a - Vector3(0, 0.8, 0), 2.0, 0.5, col.lightened(0.2))
				vfx.slash(tgt, a, col, k)
				vfx.flip("slash", tgt - Vector3(0, 0.9, 0), 3.4, 0.65, col.lightened(0.25), false, 0.06)
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
		"zone_grow":
			_later(2.2, banner.bind("ÁREA DE ENTRADA MAIOR", "Agora dá para colocar personagens até %d casas da sua base" % int(e["r"])))
			for pz in range(2):
				var ew = board.world_xz(DB.entry_c[pz])
				vfx.flip("ring", Vector3(ew.x, 0.3, ew.y), 3.0 + 2.6 * int(e["r"]), 0.9, C_DEPLOY if pz == 0 else C_CPU, true)
			sfx.play("vfx_portal", -8.0)
		"tactic_on":
			var tcol: Color = TYPE_COL.get(DB.tactics[e["id"]]["type"], C_CARD)
			var tp = _hex_pos(e["h"], 0.05)
			vfx.flip("ring", tp, 3.4, 0.55, tcol, true)
			vfx.flip("aura", tp + Vector3(0, 0.9, 0), 2.6, 0.75, tcol.lightened(0.25))
			vfx.flip("sparkle", tp + Vector3(0, 1.4, 0), 1.8, 0.6, tcol.lightened(0.5), false, 0.12)
			board.float_text(e["h"], DB.tactics[e["id"]]["name"], tcol.lightened(0.35))
			sfx.play("vfx_aura", -9.0)
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
			sfx.play("verme_rumor", -2.0, 0.7)
			board.shake = max(board.shake, 0.35)
			banner("A AREIA TREME", "saia das casas marcadas: o verme vem no próximo round")
			if w.has("banner"):
				w["banner"].add_theme_color_override("font_color", Color("#ff9a5a"))
			for th in e["hexes"]:
				vfx.dust_burst(_hex_pos(th, 0.0), false)
		"worm":
			banner("VERME GIGANTE!", "quem estiver nos buracos é devorado")
			if w.has("banner"):
				w["banner"].add_theme_color_override("font_color", Color("#ff4a3a"))
			board.quake()
			sfx.play("verme_rumor", 2.0, 0.6)
			sfx.play_later("verme_rumor", 0.5, 0.0, 0.5)
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
	if stage == "select":
		_update_tags()
	if game != null and board.visible:
		_update_plates(_delta)
		_tremor_omen(_delta)
		vfx.cam_k = _fx_scale()
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
		var wp = board.unit_nodes[b["uid"]]["node"].position + Vector3(0, board.unit_nodes[b["uid"]].get("top", 1.75) + 2.0, 0)
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
	await get_tree().create_timer(2.0).timeout
	await shot.call("01_menu")
	_on_play()
	await get_tree().create_timer(2.6).timeout
	await shot.call("02a_planetas")
	_choose_planet("tarhut")
	await get_tree().create_timer(2.2).timeout
	_army_random()
	await get_tree().create_timer(0.6).timeout
	await shot.call("02_exercito")
	autotest = false
	_army_go()
	await get_tree().create_timer(2.0).timeout
	await shot.call("02b_mergulho")
	while game == null:
		await get_tree().process_frame
	game.cpu = [false, true]
	await get_tree().create_timer(0.5).timeout
	await shot.call("02c_chegada")
	await get_tree().create_timer(3.0).timeout
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
	_button(hb, "Novos exércitos", _to_army)
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


# ================= placas de vida (estilo da HUD) =================
func _make_plate(u) -> Dictionary:
	var col = C_YOU if u.owner == 0 else C_CPU
	var border = C_GOLD if u.is_cmd else col
	var W = 128.0
	var H = 40.0
	# placa com layout fixo (sem contêineres): fundo, nome, número e barra segmentada
	var p = Panel.new()
	p.size = Vector2(W, H)
	p.add_theme_stylebox_override("panel", _flat(Color(0.025, 0.045, 0.1, 0.92), border, 2, 5, 0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w["plates"].add_child(p)
	var strip = ColorRect.new()
	strip.color = border
	strip.position = Vector2(0, 0)
	strip.size = Vector2(5, H)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(strip)
	var nl = Label.new()
	nl.text = "Barreira" if u.barrier else (("★ " if u.is_cmd else "") + _short(u.cid))
	nl.add_theme_font_size_override("font_size", 12)
	if font_btn != null:
		nl.add_theme_font_override("font", font_btn)
	nl.add_theme_color_override("font_color", border.lightened(0.5))
	nl.position = Vector2(10, 1)
	nl.size = Vector2(W - 44, 18)
	nl.clip_text = true
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(nl)
	var hl = Label.new()
	hl.add_theme_font_size_override("font_size", 18)
	if font_title != null:
		hl.add_theme_font_override("font", font_title)
	hl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hl.add_theme_constant_override("outline_size", 4)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hl.position = Vector2(W - 40, -2)
	hl.size = Vector2(34, 22)
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hl)
	var bar = Control.new()
	bar.position = Vector2(10, 23)
	bar.size = Vector2(W - 16, 11)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bar)
	var bg = ColorRect.new()
	bg.color = Color(1, 1, 1, 0.12)
	bg.size = bar.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bg)
	var ghost = ColorRect.new()
	ghost.color = Color(1, 0.95, 0.85, 0.95)
	ghost.size = Vector2(bar.size.x, bar.size.y)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(ghost)
	var fill = ColorRect.new()
	fill.size = Vector2(bar.size.x, bar.size.y)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	for i in range(1, u.maxhp):
		var t = ColorRect.new()
		t.color = Color(0.02, 0.03, 0.07, 0.9)
		t.position = Vector2(bar.size.x * i / u.maxhp - 1.0, 0)
		t.size = Vector2(2, bar.size.y)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(t)
	var fl = Label.new()
	fl.add_theme_font_size_override("font_size", 11)
	fl.add_theme_color_override("font_color", Color("#ffcf6a"))
	fl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	fl.add_theme_constant_override("outline_size", 4)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl.position = Vector2(0, -18)
	fl.size = Vector2(W, 16)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.visible = false
	p.add_child(fl)
	return {"panel": p, "hp": hl, "fill": fill, "ghost": ghost, "flags": fl, "bw": bar.size.x, "shown": float(u.hp), "ghost_v": float(u.hp), "last": u.hp, "flash": 0.0}


func _update_plates(delta: float) -> void:
	if not w.has("plates") or not is_instance_valid(w["plates"]):
		return
	var seen = {}
	var sc = clamp(40.0 / max(board.cam_dist, 1.0), 0.85, 1.15)
	for uid in board.unit_nodes.keys():
		var u: Variant = game.by_uid(uid)
		if u == null:
			continue
		seen[uid] = true
		if not plates.has(uid) or not is_instance_valid(plates[uid]["panel"]):
			plates[uid] = _make_plate(u)
		var pl = plates[uid]
		var d = board.unit_nodes[uid]
		var wp = d["node"].position + Vector3(0, d.get("top", 1.75) * d["node"].scale.y + 0.25, 0)
		var p: Panel = pl["panel"]
		if board.cam.is_position_behind(wp) or d["node"].scale.y < 0.3:
			p.visible = false
			continue
		p.visible = true
		# vida: a barra desce suave e um rastro claro mostra o dano levado
		if u.hp < pl["last"]:
			pl["flash"] = 1.0
		pl["last"] = u.hp
		pl["shown"] = lerp(pl["shown"], float(u.hp), min(1.0, delta * 10.0))
		if pl["ghost_v"] > pl["shown"]:
			pl["ghost_v"] = max(pl["shown"], pl["ghost_v"] - delta * 2.5)
		else:
			pl["ghost_v"] = pl["shown"]
		var frac = clamp(pl["shown"] / max(1.0, float(u.maxhp)), 0.0, 1.0)
		pl["fill"].size.x = pl["bw"] * frac
		pl["ghost"].size.x = pl["bw"] * clamp(pl["ghost_v"] / max(1.0, float(u.maxhp)), 0.0, 1.0)
		var hc = Color("#4cd964") if frac > 0.6 else (Color("#ffcf3a") if frac > 0.34 else Color("#ff3b3b"))
		pl["flash"] = max(0.0, pl["flash"] - delta * 3.0)
		pl["fill"].color = hc.lerp(Color.WHITE, pl["flash"] * 0.8)
		pl["hp"].text = str(u.hp)
		pl["hp"].add_theme_color_override("font_color", hc.lightened(0.25))
		var fl = []
		if u.eq != "":
			fl.append(u.eq.to_upper())
		if game.rooted(u):
			fl.append("PRESO")
		if game.silenced(u):
			fl.append("SEM HAB.")
		if game.has_fx(u, "mark"):
			fl.append("ALVO")
		pl["flags"].text = " · ".join(fl)
		pl["flags"].visible = not fl.is_empty()
		var shake = Vector2(sin(Time.get_ticks_msec() * 0.09) * 3.0 * pl["flash"], 0)
		p.scale = Vector2.ONE * sc * (1.0 + pl["flash"] * 0.12)
		p.pivot_offset = Vector2(p.size.x * 0.5, p.size.y)
		var spos = board.cam.unproject_position(wp)
		p.position = spos - Vector2(p.size.x * 0.5, p.size.y) + shake
		# quem está agindo fica por cima
		p.modulate = Color(1, 1, 1, 1.0)
	for uid in plates.keys():
		if not seen.has(uid):
			if is_instance_valid(plates[uid]["panel"]):
				plates[uid]["panel"].queue_free()
			plates.erase(uid)


# ================= tamanho da interface (celular / tablet / PC) =================
func _load_prefs() -> void:
	var cf = ConfigFile.new()
	if cf.load("user://prefs.cfg") == OK:
		ui_pref = str(cf.get_value("ui", "scale", "auto"))


func _save_prefs() -> void:
	var cf = ConfigFile.new()
	cf.set_value("ui", "scale", ui_pref)
	cf.save("user://prefs.cfg")


func _auto_scale() -> float:
	# tamanho real da tela em "pixels de navegador": celular deitado tem ~360-430 de altura
	var win = get_window()
	var dpr = max(1.0, DisplayServer.screen_get_scale())
	var short = min(float(win.size.x), float(win.size.y)) / dpr
	var want_h = clamp(short * 1.45, 560.0, 900.0)
	return clamp(900.0 / want_h, 1.0, 1.75)


func _apply_ui_scale() -> void:
	var f = _auto_scale() if ui_pref == "auto" else float(ui_pref) / 100.0
	if abs(get_tree().root.content_scale_factor - f) > 0.01:
		get_tree().root.content_scale_factor = f
	var was = compact
	compact = get_viewport().get_visible_rect().size.y < 720.0
	if was != compact and stage == "battle" and game != null:
		_build_hud()
		refresh()


func _cycle_ui_scale() -> void:
	var opts = ["auto", "100", "125", "150", "175"]
	ui_pref = opts[(opts.find(ui_pref) + 1) % opts.size()]
	_save_prefs()
	_apply_ui_scale()
	_show_menu()


func _ui_scale_label() -> String:
	return "Interface: " + ("automática" if ui_pref == "auto" else ui_pref + "%")


func _toggle_cpu() -> void:
	cpu_open = not cpu_open
	if w.has("party1_panel"):
		w["party1_panel"].visible = cpu_open or not compact


# ================= mão inicial: cartas grandes no centro =================
func _show_mull(ids: Array) -> void:
	if w.has("mull") and is_instance_valid(w["mull"]):
		return
	if w.has("hand"):
		w["hand"].visible = false
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(root)
	w["mull"] = root
	var dim = ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var col = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	var tl = _label(col, "SUA MÃO INICIAL", 26, C_GOLD)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var vh = get_viewport().get_visible_rect().size.y
	var k = clamp((vh - 260.0) / 172.0, 1.0, 1.8)
	for id in ids:
		var holder = Control.new()
		var base = Vector2(118, 150) if compact else Vector2(128, 172)
		holder.custom_minimum_size = base * k
		holder.tooltip_text = "%s (%s)\n%s" % [DB.tactics[id]["name"], DB.tactics[id]["type"], DB.tactics[id]["text"]]
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(holder)
		var card = _make_card(id)
		card.modulate = Color.WHITE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in card.get_children():
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.scale = Vector2(k, k)
		holder.add_child(card)
		# entra deslizando de baixo
		holder.modulate.a = 0.0
		var tw = holder.create_tween()
		tw.tween_interval(0.08 * ids.find(id))
		tw.tween_property(holder, "modulate:a", 1.0, 0.25)
	var br = HBoxContainer.new()
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	br.add_theme_constant_override("separation", 18)
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(br)
	var b1 = _cbtn(br, "MANTER A MÃO", C_HUD, func(): _answer(false))
	b1.custom_minimum_size = Vector2(230, 54)
	var b2 = _cbtn(br, "TROCAR A MÃO", C_GOLD, func(): _answer(true))
	_primary(b2)
	b2.custom_minimum_size = Vector2(230, 54)


func _hide_mull() -> void:
	if w.has("hand") and is_instance_valid(w["hand"]):
		w["hand"].visible = true
	if w.has("mull"):
		if is_instance_valid(w["mull"]):
			w["mull"].queue_free()
		w.erase("mull")


# ================= verme gigante =================
var omen_t: float = 0.0


# enquanto há casas marcadas: a areia ronca, levanta poeira e o chão treme de leve
func _tremor_omen(delta: float) -> void:
	if game.tremors.is_empty():
		return
	omen_t -= delta
	if omen_t > 0.0:
		return
	omen_t = randf_range(2.2, 3.6)
	sfx.play("verme_rumor", -9.0, randf_range(0.55, 0.75), 0.1)
	board.shake = max(board.shake, 0.18)
	for h in game.tremors:
		vfx.dust_burst(_hex_pos(h, 0.0), false)


func _on_worm_roar(pos: Vector3) -> void:
	board.shake = 1.4
	sfx.play("verme_ataque", 4.0, 0.62, 0.05)
	sfx.play_later("verme_ataque", 0.12, 0.0, 0.48)
	sfx.play("verme_rumor", 2.0, 0.5)
	vfx.dust_burst(pos, true)
	vfx.flip("sonic", pos + Vector3(0, 8.0, 0), 6.0, 0.9, Color("#ffcf9a"))
	vfx.flip("ring", pos, 7.0, 0.8, Color("#ff7a3a"), true)
	_flash_screen(Color(0.6, 0.02, 0.0, 0.35), 0.6)


func _on_worm_bite(pos: Vector3) -> void:
	board.shake = max(board.shake, 1.0)
	sfx.play("explosao", 0.0, 0.6)
	vfx.dust_burst(pos, true)
	vfx.flip("boom", pos, 5.0, 0.8, Color(1, 0.8, 0.6))
	vfx.flip("rock", pos, 4.0, 0.7)


func _flash_screen(col: Color, dur: float) -> void:
	var r = ColorRect.new()
	r.color = col
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(r)
	var tw = r.create_tween()
	tw.tween_property(r, "color:a", 0.0, dur)
	tw.tween_callback(r.queue_free)


# ================= entrada dos exércitos =================
const FAC_ENTRY = {"FAU": "entrada_fau", "ABY": "entrada_aby", "KRI": "entrada_kri", "WAC": "entrada_wac", "ZUK": "entrada_zuk", "LIT": "entrada_lit", "TER": "entrada_ter"}
var skip_entry: bool = false


func _map_music() -> void:
	if game == null:
		return
	if game.map_id == "tarhut":
		sfx.loop("musica_deserto", -9.0, 3.0)
	else:
		sfx.loop("musica_valak", -7.0, 3.0)


func _wait(sec: float) -> void:
	var t = 0.0
	while t < sec and not skip_entry:
		await get_tree().process_frame
		t += get_process_delta_time()


# cada exército chega ao campo com a sua música-tema: primeiro o seu, depois o da CPU
func _entrance() -> void:
	skip_entry = false
	busy = true
	for u in game.field():
		board.hidden_uids[u.uid] = true
	# esconde a HUD (fica só a camada da cena)
	for c in ui.get_children():
		if c == w.get("bubbles") or c == w.get("plates"):
			continue
		c.set_meta("was_vis", c.visible)
		c.visible = false
	var layer = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(layer)
	var skip = _cbtn(layer, "Pular  ▶", C_HUD, func(): skip_entry = true)
	skip.custom_minimum_size = Vector2(150, 44)
	_place(skip, Control.PRESET_BOTTOM_RIGHT, 18)
	if ui.modulate.a < 1.0:
		_ui_fade(1.0, 0.6)
	await _wait(1.6)
	for p in [0, 1]:
		if skip_entry:
			break
		await _entrance_side(p, layer)
	for uid in board.hidden_uids.keys():
		var u: Variant = game.by_uid(uid)
		if u != null:
			vfx.summon_fx(_hex_pos(u.pos(), 0.0), _unit_color(uid))
	board.hidden_uids.clear()
	layer.queue_free()
	for c in ui.get_children():
		if c.has_meta("was_vis"):
			c.visible = c.get_meta("was_vis")
			c.remove_meta("was_vis")
	board.cam_speed = 3.0
	board.fit_camera(false)
	_later(2.0, func(): board.cam_speed = 8.0)
	_map_music()
	refresh()


func _entrance_side(p: int, layer: Control) -> void:
	var fac = game.P[p]["fac"]
	var fcol = Color(DB.factions[fac]["color"])
	var ec = DB.entry_c[p]
	var ew = board.world_xz(ec)
	var tgt = Vector3(ew.x, 0.6, ew.y)
	var to_c = Vector2(-ew.x, -ew.y).normalized()
	board.cam_speed = 2.2
	board.cam_goal = {"yaw": atan2(to_c.x, to_c.y), "pitch": 0.45, "dist": 10.5, "target": tgt}
	sfx.play(FAC_ENTRY.get(fac, ""), -1.0, 1.0, 0.0)
	# cartão da facção: retrato do comandante, nome e quem é
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(Color(0.02, 0.04, 0.09, 0.9), fcol, 3, 12, 14))
	layer.add_child(card)
	var h = _hbox(card, 14)
	var cid = game.P[p].get("cmd", DB.factions[fac]["cmd"])
	if DB.portraits.has(cid):
		h.add_child(_tex_rect(DB.portraits[cid], Vector2(110, 110)))
	var v = _vbox(h, 2)
	_label(v, "VOCÊ" if p == 0 else "ADVERSÁRIO", 13, C_YOU if p == 0 else C_CPU)
	_label(v, "EXÉRCITO MISTO" if game.P[p].get("mix", false) else DB.factions[fac]["name"].to_upper(), 34, fcol.lightened(0.35))
	_label(v, "Comandante: %s · chega no round 6" % DB.cards[cid]["name"], 15, C_DIM)
	card.position = Vector2(-700, 70) if p == 0 else Vector2(get_viewport().get_visible_rect().size.x + 100, 70)
	var goal_x = 40.0 if p == 0 else get_viewport().get_visible_rect().size.x - 40.0
	await get_tree().process_frame
	if p == 1:
		goal_x -= card.size.x
	var tw = card.create_tween()
	tw.tween_property(card, "position:x", goal_x, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(1.6)
	# as peças chegam uma a uma (portal + queda) e falam ao entrar
	var units = game.field().filter(func(x): return x.owner == p and not x.barrier)
	for u in units:
		if skip_entry:
			break
		board.hidden_uids.erase(u.uid)
		var hp = _hex_pos(u.pos(), 0.0)
		vfx.flip("portal", hp, 2.6, 0.7, fcol.lightened(0.4), true)
		vfx.summon_fx(hp, fcol)
		vfx.dust_burst(hp, true)
		board.shake = max(board.shake, 0.3)
		sfx.play("invocar", -4.0)
		_voice(u.uid, "atk", -1.0, 0.2)
		var line = _line("entrada", u)
		if line != "":
			_say(u.uid, line, 0.5, "fala")
		await _wait(1.7)
	await _wait(1.3)
	var tw2 = card.create_tween()
	tw2.tween_property(card, "modulate:a", 0.0, 0.4)
	tw2.tween_callback(card.queue_free)
