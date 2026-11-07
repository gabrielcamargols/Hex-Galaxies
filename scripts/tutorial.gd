extends Node
## Tutorial guiado: uma partida montada em Valak. Um painel explica cada passo e o próximo
## só aparece quando o jogador faz a ação pedida. A CPU fica passando a vez até o fim do
## tutorial; depois o jogador pode continuar a partida contra ela normalmente.

var m                        # main.gd
var step := -1
var panel: PanelContainer
var title_l: Label
var text_l: Label
var count_l: Label
var btn_row: HBoxContainer
var frame: Panel             # moldura pulsante sobre o botão/carta indicado
var mark_t := 0.0
var brawler = null
var foe = null
var approach: Variant = null
var field0 := 0
var pos0 := Vector2i.ZERO

const STEPS = [
	{"t": "Bem-vindo ao Hex Galaxies!", "x": "Você comanda um exército numa batalha por turnos em hexágonos.\n\nPara vencer: derrote o COMANDANTE inimigo (ele entra no round 4) ou chegue ao fim do round 10 com mais Vida no seu comandante.", "next": true},
	{"t": "Escolha quem vai agir", "x": "Cada vez que chega a sua vez, você ativa UMA peça.\n\nToque no Krieg Brawler (a peça marcada com AQUI)."},
	{"t": "Táticas são grátis", "x": "As cartas embaixo são táticas. Jogar uma carta NÃO gasta ação (1 carta por ativação).\n\nArraste \"Fogo Concentrado\" e solte em cima do Brawler: o próximo ataque dele causa +2 de dano."},
	{"t": "Mova-se", "x": "Cada peça ativada tem 2 AÇÕES: mover 1 vez e atacar 1 vez.\n\nAs casas verdes mostram até onde ele anda. Toque na casa marcada com AQUI e depois em Confirmar."},
	{"t": "Ataque!", "x": "O inimigo ao lado está em vermelho: dá para atacar.\n\nToque nele, veja a prévia do dano e toque em Confirmar."},
	{"t": "A vez passa", "x": "As 2 ações acabaram, então a ativação terminou sozinha. Agora a vez é do adversário, depois volta para você.\n\nOs dois lados se alternam, uma peça por vez, até todos passarem.", "next": true},
	{"t": "Reforços", "x": "Suas reservas estão na lista à esquerda. Colocar uma em campo gasta 1 ação.\n\nToque num retrato \"▶ pode entrar\" e depois numa casa ciano \"+ ENTRAR\" (ou arraste o retrato até lá)."},
	{"t": "Termine a ativação", "x": "Quem acabou de entrar ainda tem 1 ação: pode andar ou atacar.\n\nQuando não quiser fazer mais nada, toque em \"Encerrar ativação\"."},
	{"t": "O terreno importa", "x": "• Atacar de cima: +1 de dano (de baixo: -1).\n• Rochas, galpões e caixas bloqueiam a linha de tiro e dão abrigo (-2 de dano).\n• Floresta e lama custam mais movimento.\n• A área de entrada cresce a cada 3 rounds.\n\nToque numa casa ou peça para ver o que ela faz.", "next": true},
	{"t": "Passe o round", "x": "Quando não quiser ativar mais peças, toque em \"Passar o round\". O round acaba quando os dois passam, e as peças ficam prontas de novo.", "pass": true},
	{"t": "Pronto para a guerra!", "x": "No round 4 os comandantes entram em campo e cada um tem uma habilidade especial que pode virar a partida. A partir do round 2, dispute o NÚCLEO DE ENERGIA: o próximo local aparece marcado antes.\n\nDica: abra \"Regras\" a qualquer momento. Na tela do exército há o modo Mix e o Jogar Online.", "end": true},
]


func start(main) -> void:
	m = main
	_build_ui()
	var b = m.game.units.filter(func(u): return u.owner == 0 and u.cid == "k_brawler")
	brawler = b[0] if not b.is_empty() else null
	_arrange()
	_go(0)


# coloca um inimigo fraco perto do Brawler, a uma casa de alcance depois de andar
func _arrange() -> void:
	var g = m.game
	var foes = g.units.filter(func(u): return u.owner == 1 and u.st == "field" and not u.is_cmd)
	if brawler == null or foes.is_empty():
		return
	foe = foes[0]
	var reach = g.move_opts(brawler, g.mov_of(brawler)).map(func(o): return o["h"])
	var best: Variant = null
	for h in DB.hexes:
		if not g.is_free(h) or DB.dist(h, brawler.pos()) < 3 or g.terr(h)["k"] != g.plain["k"]:
			continue
		for r in reach:
			if DB.dist(r, h) == 1 and g.h_of(r) == g.h_of(h):
				if best == null or DB.dist(h, brawler.pos()) < DB.dist(best, brawler.pos()):
					best = h
					approach = r
				break
	if best != null:
		foe.q = best.x
		foe.r = best.y


func _build_ui() -> void:
	panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.12, 0.95)
	sb.border_color = Color("#ffab40")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	m.ui.add_child(panel)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.47
	panel.anchor_bottom = 0.47
	panel.offset_left = -(340 if m.compact else 390)
	panel.offset_right = -14
	panel.z_index = 40
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	count_l = m._label(v, "", 11, Color("#ffcf8a"))
	title_l = m._label(v, "", 22, Color("#ffcf5a"))
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_l = m._label(v, "", 15, Color(0.92, 0.95, 1.0))
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	v.add_child(btn_row)
	frame = Panel.new()
	var fs = StyleBoxFlat.new()
	fs.bg_color = Color(0, 0, 0, 0)
	fs.border_color = Color("#ffab40")
	fs.set_border_width_all(4)
	fs.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", fs)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = 45
	frame.visible = false
	m.ui.add_child(frame)


func _go(i: int) -> void:
	step = i
	var s = STEPS[i]
	count_l.text = "TUTORIAL · %d de %d" % [i + 1, STEPS.size()]
	title_l.text = s["t"]
	text_l.text = s["x"]
	for c in btn_row.get_children():
		c.queue_free()
	if s.get("next", false):
		var b = m._cbtn(btn_row, "Próximo ▶", Color("#ffab40"), func(): _go(step + 1), true)
		m._primary(b)
		b.custom_minimum_size = Vector2(140, 40)
	if s.get("end", false):
		var b1 = m._cbtn(btn_row, "Continuar a partida", Color("#ffab40"), _finish_play, true)
		m._primary(b1)
		b1.custom_minimum_size = Vector2(0, 40)
		m._cbtn(btn_row, "Menu", Color("#5ec8f0"), _finish_menu).custom_minimum_size = Vector2(90, 40)
	else:
		var sk = m._cbtn(btn_row, "Sair do tutorial", Color("#5ec8f0"), _finish_menu)
		sk.custom_minimum_size = Vector2(0, 40)
	if i == 6:
		field0 = m.game.units.filter(func(u): return u.owner == 0 and u.st == "field").size()
	if i == 1 and brawler != null:
		pos0 = brawler.pos()
	m.sfx.play("clique", -6.0)
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.3)


func _done() -> bool:
	var g = m.game
	var A = g.act
	match step:
		1:
			return brawler != null and (m.sel == brawler.uid or (A != null and A["uid"] == brawler.uid))
		2:
			return A != null and A["tactic"]
		3:
			return A != null and A["moved"]
		4:
			return (A != null and A["attacked"]) or (foe != null and foe.st != "field") or (A == null and g.units.any(func(u): return u.uid == brawler.uid and u.activated))
		6:
			return g.units.filter(func(u): return u.owner == 0 and u.st == "field").size() > field0
		7:
			return A == null and m.my_turn()
		9:
			return g.P[0]["passed"] or g.round_no >= 2
	return false


# alvo do destaque: casa do tabuleiro (Vector2i) ou controle da interface
func _target() -> Variant:
	var g = m.game
	match step:
		1:
			return brawler.pos() if brawler != null and brawler.st == "field" else null
		2:
			for c in m.w["hand"].get_children():
				if c is PanelContainer:
					return c
		3:
			return approach
		4:
			return foe.pos() if foe != null and foe.st == "field" else null
		6:
			var hs = g.deploy_hexes(0)
			return hs[0] if not hs.is_empty() else null
		7, 9:
			return m.w["end"]
	return null


func _process(dt: float) -> void:
	if m == null or m.game == null or step < 0:
		return
	# passos de ação: avança quando o jogador faz o que foi pedido
	if not STEPS[step].get("next", false) and not STEPS[step].get("end", false) and _done():
		_go(step + 1)
		return
	if step == 5 and not m.my_turn():
		btn_row.modulate.a = 0.4
	else:
		btn_row.modulate.a = 1.0
	var tg = _target()
	frame.visible = tg is Control and is_instance_valid(tg) and tg.is_visible_in_tree()
	if frame.visible:
		var r: Rect2 = tg.get_global_rect()
		frame.position = r.position - Vector2(6, 6)
		frame.size = r.size + Vector2(12, 12)
		frame.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 160.0)
	mark_t -= dt
	if tg is Vector2i and mark_t <= 0.0:
		mark_t = 1.3
		var p = m._hex_pos(tg, 0.05)
		m.vfx.flip("ring", p, 2.6, 0.9, Color("#ffab40"), true)
		m.board.float_text(tg, "AQUI", Color("#ffcf5a"))


func _finish_play() -> void:
	m.tut = false
	m.game.tut = false
	queue_free_ui()
	m.refresh()
	m.after()


func _finish_menu() -> void:
	m.tut = false
	queue_free_ui()
	m._show_menu()


func queue_free_ui() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
	if is_instance_valid(frame):
		frame.queue_free()
	step = -1
	queue_free()
