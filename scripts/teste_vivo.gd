extends Node
## Tabuleiro vivo: mouse em cima (olha + gesto da facção), seleção (sobe da mesa), arrasto (inclina e
## projeta sombra), soltar (cai, toc e poeira) e derrota (a miniatura tomba e sai do tabuleiro).
##   SAIDA=prefixo godot --path . --fixed-fps 30 --write-movie vivo.avi -- --teste=vivo
func _espera(seg: float) -> void:
	for i in int(seg * 30):
		await get_tree().process_frame


var fotos: Array = []
var alvo_w: Vector3


# recorte em volta da peça (a posição dela na tela muda a cada partida)
func _foto(rot: String) -> void:
	var b = get_parent().board
	var img: Image = get_viewport().get_texture().get_image()
	var sp: Vector2 = b.cam.unproject_position(alvo_w + Vector3(0, 0.7, 0))
	sp *= Vector2(img.get_size()) / get_viewport().get_visible_rect().size
	var r = Rect2i(int(sp.x) - 170, int(sp.y) - 190, 340, 340)
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var c = img.get_region(r)
	c.save_png(OS.get_environment("SAIDA") + "_%02d_%s.png" % [fotos.size(), rot])
	fotos.append(rot)


func _fotos(rot: String, n: int, intervalo: float) -> void:
	for i in n:
		_foto("%s%d" % [rot, i])
		await _espera(intervalo)


func run() -> void:
	var m = get_parent()
	m.setup_cfg["map"] = OS.get_environment("MAPA") if OS.get_environment("MAPA") != "" else "posto"
	m.setup_cfg["modo"] = ""
	m.setup_cfg["fac"] = OS.get_environment("FAC") if OS.get_environment("FAC") != "" else "KRI"
	m._set_papel(0)
	m._start_match(null)
	await _espera(1.0)
	m.skip_entry = true
	await _espera(6.0)
	if m.asking != null:
		m._answer(false)
	var g = m.game
	var b = m.board
	# põe em campo, perto do centro, uma peça minha que tenha modelo 3D (e um inimigo à frente)
	var zona = g.entry_zone(m.me).filter(func(h): return g.is_free(h))
	zona.sort_custom(func(x, y): return DB.dist(x, Vector2i.ZERO) < DB.dist(y, Vector2i.ZERO))
	for x in g.units:
		if x.owner == m.me and x.st != "field" and b.FIG3D.has(x.cid) and not zona.is_empty():
			var hz: Vector2i = zona.pop_front()
			x.st = "field"
			x.q = hz.x
			x.r = hz.y
			break
	m.refresh()
	b.sync_units()
	await _espera(1.5)
	var minhas = g.field().filter(func(x): return x.owner == m.me and not x.barrier and b.tem_fig3d(x.uid))
	printerr("VIVO minhas=", minhas.map(func(x): return x.cid))
	if minhas.is_empty():
		get_tree().quit()
		return
	var u = minhas[0]
	var p: Vector3 = m._hex_pos(u.pos(), 0.0)
	b.cam_goal = null
	b.cam_target = p + Vector3(0, 0.5, 0)
	b.cam_dist = 5.5
	b.cam_pitch = 0.62
	m.skip_entry = true
	await _espera(1.0)
	alvo_w = p
	await _fotos("parado", 1, 0.1)
	# 1) mouse em cima
	b.hover_seen = u.pos()
	await _espera(0.3)
	await _fotos("mouse", 4, 0.3)
	b.hover_seen = null
	await _espera(0.6)
	# 2) seleciona: sobe da mesa
	m.sel = u.uid
	m.refresh()
	await _espera(0.8)
	await _fotos("erguida", 1, 0.5)
	# 3) arrasta em arco por cima do tabuleiro e solta na casa de origem
	var mao = {"uid": u.uid, "start": Vector2.ZERO, "on": true}
	b.drag = mao
	var y0 = b.top_y(u.pos()) + 0.2
	for i in 50:
		var a = float(i) / 49.0
		mao["world"] = p + Vector3(sin(a * TAU) * 1.4, 0, -sin(a * PI) * 1.2)
		mao["world"].y = y0
		await get_tree().process_frame
		if i % 10 == 5:
			_foto("arrasto%d" % i)
	b.drag = null
	await _fotos("pouso", 4, 0.07)
	await _espera(1.0)
	m.sel = -1
	m.refresh()
	await _espera(0.8)
	# 4) derrota: a peça tomba
	u.hp = 0
	u.st = "dead"
	b.sync_units()
	await _fotos("tomba", 8, 0.12)
	await _espera(1.5)
	await _fotos("sumiu", 1, 0.1)
	get_tree().quit()
