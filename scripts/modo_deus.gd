extends Node
## Modo Deus: caixa de areia para montar e testar qualquer situação no tabuleiro.
## Abre pelo botão MODO DEUS do menu. O painel fica no canto direito da batalha:
##   - coloca qualquer personagem de qualquer facção, para o lado azul ou o laranja
##   - escolhe um alvo e muda vida, recarrega, limpa efeitos, troca de lado, teleporta
##   - remove peças, põe a Hex Energy onde quiser, dá cartas táticas
##   - controla de quem é a vez, a CPU de cada lado, o round e ações infinitas
## Não há fim de jogo: comandantes caídos e o último round não encerram a partida.

const COR = [Color("#2fa8ff"), Color("#ff7a1a")]
const NOMES_LADO = ["Azul", "Laranja"]
const FACS = ["KRI", "ABY", "FAU", "ZUK", "WAC", "LIT", "TER"]

var m = null                 # main.gd
var painel: PanelContainer = null
var corpo: VBoxContainer = null
var aberto: bool = true
var lado: int = 0            # lado em que as peças entram e que recebe as cartas
var fac: String = "KRI"
var cid: String = ""         # personagem escolhido para colocar
var ferr: String = ""        # "" = jogar normal | colocar | alvo | teleporte | remover | hex
var alvo: int = -1           # uid escolhido na ferramenta Alvo
var infinito: bool = true    # ações e habilidades nunca acabam
var w: Dictionary = {}


func setup(main) -> void:
	m = main
	var lista = _chars(fac)
	cid = lista[0] if not lista.is_empty() else ""
	_monta()


# ---------- interface ----------
func _monta() -> void:
	if painel != null and is_instance_valid(painel):
		painel.queue_free()
	painel = PanelContainer.new()
	painel.name = "modo_deus"
	painel.add_theme_stylebox_override("panel", m._flat(Color(0.05, 0.03, 0.12, 0.93), Color("#FFD12E"), 3, 12, 10))
	m.ui.add_child(painel)
	painel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	painel.offset_left = -392
	painel.offset_right = -8
	painel.offset_top = 70
	painel.offset_bottom = -170
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	painel.add_child(v)
	var topo = HBoxContainer.new()
	v.add_child(topo)
	var t = m._label(topo, "⚡ MODO DEUS", 20, Color("#FFD12E"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mini(topo, "–" if aberto else "+", Color("#3340b8"), func():
		aberto = not aberto
		_monta())
	if not aberto:
		painel.offset_bottom = 0
		painel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		painel.offset_left = -200
		painel.offset_right = -8
		painel.offset_top = 70
		return
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 6)
	corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(corpo)
	_secoes()


func _secoes() -> void:
	var g = m.game
	# --- lado ---
	_titulo("Lado")
	var hl = _linha()
	for p in range(2):
		var pp = p
		_mini(hl, NOMES_LADO[p], COR[p], func():
			lado = pp
			_monta(), lado == p)
	# --- ferramentas ---
	_titulo("Ferramenta")
	var gf = _linha()
	for f in [["", "Jogar"], ["colocar", "Colocar"], ["alvo", "Alvo"], ["remover", "Remover"], ["hex", "Hex Energy"], ["teleporte", "Teleportar"]]:
		var ff = f[0]
		_mini(gf, f[1], Color("#A957EC"), func():
			ferr = ff
			_monta(), ferr == ff)
	w["dica"] = m._label(corpo, _dica(), 13, Color("#cbbdff"))
	w["dica"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["dica"].custom_minimum_size = Vector2(330, 0)
	# --- personagem ---
	_titulo("Personagem")
	var hf = _linha()
	var ob = OptionButton.new()
	for f in FACS:
		ob.add_item(DB.factions[f]["name"] if DB.factions.has(f) else f)
	ob.selected = FACS.find(fac)
	ob.item_selected.connect(func(i):
		fac = FACS[i]
		var l = _chars(fac)
		cid = l[0] if not l.is_empty() else ""
		_monta())
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hf.add_child(ob)
	var il = ItemList.new()
	il.custom_minimum_size = Vector2(330, 190)
	il.add_theme_font_size_override("font_size", 14)
	var lista = _chars(fac)
	for c in lista:
		var cd = DB.cards[c]
		il.add_item(("★ " if cd.get("cmd", false) else "") + "%s  ·  %d vida" % [cd["name"], int(cd["int"])])
		if DB.portraits.has(c):
			il.set_item_icon(il.item_count - 1, DB.portraits[c])
	il.fixed_icon_size = Vector2i(28, 28)
	if lista.has(cid):
		il.select(lista.find(cid))
	il.item_selected.connect(func(i):
		cid = lista[i]
		ferr = "colocar"
		_monta())
	corpo.add_child(il)
	# --- alvo ---
	var u = g.by_uid(alvo) if g != null and alvo >= 0 else null
	if u != null and u.st != "field":
		u = null
		alvo = -1
	_titulo("Alvo")
	if u == null:
		var la = m._label(corpo, "Use a ferramenta Alvo e toque numa peça.", 13, Color("#cbbdff"))
		la.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		m._label(corpo, "%s  (%s)  ·  vida %d/%d" % [g.nm(u), NOMES_LADO[u.owner] if u.owner < 2 else "neutro", u.hp, u.maxhp], 15, COR[u.owner] if u.owner < 2 else Color.WHITE)
		var h1 = _linha()
		_mini(h1, "−1 vida", Color("#ff3b4d"), func(): _vida(u, -1))
		_mini(h1, "+1 vida", Color("#4cff6a"), func(): _vida(u, 1))
		_mini(h1, "Cheia", Color("#4cff6a"), func(): _vida(u, 99))
		var h2 = _linha()
		_mini(h2, "+1 máx", Color("#27DDF4"), func():
			u.maxhp += 1
			u.hp += 1
			_ok())
		_mini(h2, "Matar", Color("#ff3b4d"), func():
			m.game.damage(u, u.hp, null)
			m.game.settle()
			_ok())
		_mini(h2, "Recarregar", Color("#FFD12E"), func():
			_recarrega(u)
			_ok())
		var h3 = _linha()
		_mini(h3, "Limpar efeitos", Color("#A957EC"), func():
			u.fx = []
			_ok())
		_mini(h3, "Trocar lado", Color("#3340b8"), func():
			u.owner = 1 - u.owner
			_ok())
		_mini(h3, "Teleportar", Color("#A957EC"), func():
			ferr = "teleporte"
			_monta())
	# --- partida ---
	_titulo("Partida")
	if g != null:
		var hv = _linha()
		m._label(hv, "Vez:", 14, Color.WHITE)
		for p in range(2):
			var pp = p
			_mini(hv, NOMES_LADO[p], COR[p], func(): _vez(pp), g.cur == p)
		var hc = _linha()
		for p in range(2):
			var pp = p
			var cb = CheckBox.new()
			cb.text = "CPU " + NOMES_LADO[p]
			cb.button_pressed = g.cpu[p]
			cb.toggled.connect(func(on):
				m.game.cpu[pp] = on
				m.after())
			hc.add_child(cb)
		var ci = CheckBox.new()
		ci.text = "Ações e habilidades infinitas"
		ci.button_pressed = infinito
		ci.toggled.connect(func(on):
			infinito = on
			_ok())
		corpo.add_child(ci)
		var hr = _linha()
		m._label(hr, "Round %d" % g.round_no, 15, Color("#FFD12E"))
		_mini(hr, "−", Color("#3340b8"), func(): _round(-1))
		_mini(hr, "+", Color("#3340b8"), func(): _round(1))
		_mini(hr, "Próximo round", Color("#FFD12E"), _proximo_round)
		# cartas
		var hk = _linha()
		var ok2 = OptionButton.new()
		for id in DB.tactic_ids:
			ok2.add_item(DB.tactics[id]["name"])
		ok2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hk.add_child(ok2)
		_mini(hk, "Dar carta", Color("#3da0ff"), func():
			m.game.P[lado]["hand"].append(DB.tactic_ids[ok2.selected])
			_ok())
		var hz = _linha()
		_mini(hz, "Limpar tabuleiro", Color("#ff3b4d"), _limpa)
		_mini(hz, "Mapa", Color("#3340b8"), _mapa_menu)
	_titulo("")
	_mini(corpo, "Sair do Modo Deus", Color("#F8FAFF"), func(): m._show_menu())


func _titulo(t: String) -> void:
	var sep = HSeparator.new()
	corpo.add_child(sep)
	if t != "":
		m._label(corpo, t.to_upper(), 13, Color("#FFD12E"))


func _linha() -> HFlowContainer:
	var h = HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 4)
	h.add_theme_constant_override("v_separation", 4)
	corpo.add_child(h)
	return h


func _mini(parent: Control, text: String, col: Color, cb: Callable, ativo: bool = false) -> Button:
	var b = m._cbtn(parent, text, col, cb, ativo)
	b.custom_minimum_size = Vector2(104, 34)
	b.add_theme_font_size_override("font_size", 13)
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _dica() -> String:
	match ferr:
		"colocar":
			return "Toque numa casa livre para colocar %s no lado %s." % [DB.cards[cid]["name"] if DB.cards.has(cid) else "?", NOMES_LADO[lado]]
		"alvo":
			return "Toque numa peça para escolher o alvo."
		"remover":
			return "Toque numa peça para tirá-la do tabuleiro."
		"hex":
			return "Toque numa casa para a Hex Energy surgir ali."
		"teleporte":
			return "Toque na casa de destino do alvo." if alvo >= 0 else "Escolha um alvo primeiro."
	return "Jogando normalmente: o lado da vez move, ataca e usa habilidades."


func _chars(f: String) -> Array:
	var out = []
	for c in DB.card_list:
		if c.get("f", "") == f and c.get("id", "") != "barrier":
			out.append(c["id"])
	out.sort_custom(func(a, b): return (1 if DB.cards[a].get("cmd", false) else 0) > (1 if DB.cards[b].get("cmd", false) else 0))
	return out


# ---------- toques no tabuleiro ----------
## devolve true quando o Modo Deus usou o toque
func tap(h: Vector2i) -> bool:
	var g = m.game
	if g == null or ferr == "":
		return false
	var at = g.unit_at(h)
	match ferr:
		"colocar":
			if at != null or cid == "" or not g.tt_of(g.terr(h)["k"]).get("pass", 0):
				return true
			var u = g._mk(cid, lado, "field")
			u.q = h.x
			u.r = h.y
			g.emitfx({"t": "summon", "uid": u.uid, "h": h})
			alvo = u.uid
		"alvo":
			if at != null:
				alvo = at.uid
		"remover":
			if at != null:
				at.st = "dead" if not at.barrier else "off"
				if alvo == at.uid:
					alvo = -1
		"hex":
			if at == null or not at.barrier:
				g.core = h
				g.core_until = g.round_no + 1
				g.emitfx({"t": "core", "what": "spawn", "h": h})
		"teleporte":
			var u2 = g.by_uid(alvo)
			if u2 != null and at == null:
				u2.q = h.x
				u2.r = h.y
				ferr = "alvo"
	_ok()
	return true


# ---------- ações ----------
func _ok() -> void:
	var g = m.game
	if g == null:
		return
	g.winner = Game.NONE
	g.changed.emit()
	m.refresh()
	_monta()


func _vida(u, n: int) -> void:
	if n >= 99:
		u.hp = u.maxhp
	elif n > 0:
		u.hp = min(u.maxhp, u.hp + n)
	else:
		m.game.damage(u, -n, null)
		m.game.settle()
	_ok()


func _recarrega(u) -> void:
	u.activated = false
	u.ult_used = false
	u.ult_round = -1
	u.mare_used = false
	u.first_used = false
	u.luna_used = false
	u.dose_used = false
	u.phoenix_used = false
	u.gloria_round = 0


func _vez(p: int) -> void:
	var g = m.game
	if g.act != null:
		await g.end_activation()
	g.cur = p
	for pl in g.P:
		pl["passed"] = false
	m.sel = -1
	_ok()
	m.after()


func _round(d: int) -> void:
	var g = m.game
	g.round_no = clamp(g.round_no + d, 1, Game.LAST_ROUND - 1)
	_ok()


func _proximo_round() -> void:
	var g = m.game
	if g.act != null:
		await g.end_activation()
	g.round_no = min(g.round_no, Game.LAST_ROUND - 2)
	m.busy = true
	await g.end_round()
	m.busy = false
	_ok()
	m.after()


func _limpa() -> void:
	for u in m.game.units:
		if u.st == "field" and not u.barrier and u.crystal == "":
			u.st = "dead"
	alvo = -1
	_ok()


func _mapa_menu() -> void:
	var pm = PopupMenu.new()
	var ids = DB.maps.keys()
	for id in ids:
		pm.add_item(String(DB.maps[id].get("name", id)))
	pm.id_pressed.connect(func(i):
		m.setup_cfg["map"] = ids[i]
		m._start_deus())
	m.ui.add_child(pm)
	pm.popup_centered()


## chamado pelo main.gd depois de cada jogada
func depois() -> void:
	var g = m.game
	if g == null:
		return
	g.winner = Game.NONE
	if g.round_no >= Game.LAST_ROUND - 1:
		g.round_no = Game.LAST_ROUND - 2
	if infinito:
		for u in g.units:
			if u.st == "field":
				_recarrega(u)
		if g.act != null:
			g.act["actions"] = max(1, int(g.act["actions"]))
			g.act["attacked"] = false
			g.act["tactic"] = false
	if painel != null and is_instance_valid(painel):
		_monta()
