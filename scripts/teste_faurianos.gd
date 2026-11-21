extends Node
## Teste de regressão dos Faurianos (Rhombo, Gorun, Mantis Kai, Brazucão, Cameo): --teste=faurianos

var falhas := 0
var fila: Array = []


func ok(c: bool, msg: String) -> void:
	if c:
		print("  ok    ", msg)
	else:
		print("  FALHA ", msg)
		falhas += 1


func novo() -> Game:
	DB.set_map("posto")
	var g = Game.new()
	g.tree = null
	g.pace_time = 0.0
	g.cpu = [false, false]
	g.setup([{"fac": "FAU", "picks": [], "start": []}, {"fac": "ZUK", "picks": [], "start": []}], "posto")
	g.round_no = 7
	g.question.connect(func(_p, _q): g.answered.emit.call_deferred(fila.pop_front() if not fila.is_empty() else null))
	return g


func put(g: Game, cid: String, p: int, q: int, r: int) -> Game.Unit:
	var u = g._mk(cid, p, "field")
	u.q = q
	u.r = r
	return u


func livres(g: Game, c: Vector2i, d: int) -> Array:
	return DB.hexes.filter(func(h): return DB.dist(h, c) == d and g.is_free(h) and g.los(c, h))


func limpa(g: Game) -> void:
	for u in g.units:
		u.st = "reserve" if u.is_cmd else "dead"
	g.winner = g.NONE


func run() -> void:
	print("== Faurianos ==")
	var g = novo()
	limpa(g)
	var c0 = DB.hexes.filter(func(h): return g.is_free(h) and livres(g, h, 1).size() >= 2 and not livres(g, h, 4).is_empty())[0]
	# ---- Mantis Kai: cada golpe cura 1
	var mt = put(g, "mantis", 0, c0.x, c0.y)
	mt.hp = 2
	var e1 = put(g, "z_vang", 1, livres(g, c0, 1)[0].x, livres(g, c0, 1)[0].y)
	e1.hp = 20
	g.start_activation(mt)
	await g.act_attack(mt, e1)
	g.end_activation()
	ok(mt.hp == 3, "Mantis Kai cura 1 ao golpear (%d)" % mt.hp)
	limpa(g)
	# ---- Rhombo: ao derrubar, avança empurrando
	var rb = put(g, "rhombo", 0, c0.x, c0.y)
	var vz = livres(g, c0, 1)
	var fraco = put(g, "z_vang", 1, vz[0].x, vz[0].y)
	fraco.hp = 1
	g.start_activation(rb)
	var ends = []
	fila = []
	g.question.disconnect(g.question.get_connections()[0]["callable"])
	g.question.connect(func(_p, q):
		if q.get("kind", "") == "move" and q.has("opts") and not q["opts"].is_empty() and ends.is_empty():
			ends.append_array(q["opts"])
			g.answered.emit.call_deferred(q["opts"].back())
		else:
			g.answered.emit.call_deferred(null))
	var antes = rb.pos()
	await g.act_attack(rb, fraco)
	g.end_activation()
	ok(fraco.st != "field", "Rhombo derruba o alvo")
	ok(not ends.is_empty() and rb.pos() == ends.back(), "Impacto de Rhombo: avança até a casa escolhida")
	g.question.disconnect(g.question.get_connections()[0]["callable"])
	g.question.connect(func(_p, _q): g.answered.emit.call_deferred(fila.pop_front() if not fila.is_empty() else null))
	limpa(g)
	# ---- Gorun: Alcance Dominante e Projétil Animal
	var gr = put(g, "gorun", 0, c0.x, c0.y)
	ok(g.alc_of(gr) == 4, "Gorun ALC 4 sem atirador inimigo")
	var h4 = livres(g, c0, 4)
	var sn = put(g, "klang", 1, h4[0].x, h4[0].y)
	ok(g.alc_of(gr) == 6, "na mira de um atirador inimigo: ALC 6 (%d)" % g.alc_of(gr))
	sn.st = "dead"
	# linha: alvo a 1 casa e dois inimigos atrás dele
	var d0 = DB.DIRS.filter(func(d): return g.is_free(c0 + d) and g.is_free(c0 + d * 2) and g.is_free(c0 + d * 3) and DB.hexes.has(c0 + d * 3))
	ok(not d0.is_empty(), "há linha livre para o Projétil Animal")
	if not d0.is_empty():
		var dd = d0[0]
		var a1 = put(g, "z_vang", 1, (c0 + dd).x, (c0 + dd).y)
		var a2 = put(g, "z_vang", 1, (c0 + dd * 2).x, (c0 + dd * 2).y)
		var a3 = put(g, "z_vang", 1, (c0 + dd * 3).x, (c0 + dd * 3).y)
		for x in [a1, a2, a3]:
			x.hp = 20
		var base = g.atk_of(gr, a1)
		g.start_activation(gr)
		fila = [a1.pos()]
		await g.act_ult(gr)
		g.end_activation()
		ok(a1.hp == 20 - base and a2.hp == 20 - (base - 1) and a3.hp == 20 - (base - 2), "Projétil Animal: %d, %d, %d" % [20 - a1.hp, 20 - a2.hp, 20 - a3.hp])
	limpa(g)
	# ---- Brazucão: itens +2 e Matilha
	var bz = put(g, "brazucao", 0, c0.x, c0.y)
	var al = put(g, "vexa", 0, livres(g, c0, 1)[0].x, livres(g, c0, 1)[0].y)
	al.eq = "propulsor"
	ok(g.mov_of(al) == 3 + 3, "Propulsor perto do Brazucão: +3 MOV (%d)" % g.mov_of(al))
	var c2 = put(g, "nokka", 0, livres(g, c0, 1)[1].x, livres(g, c0, 1)[1].y)
	var hpv = al.maxhp
	var hpb = bz.maxhp
	g._pack_check()
	ok(al.maxhp == hpv + 2 and bz.maxhp == hpb + 2 and c2.packed, "Matilha: caninos e Brazucão +2 de Vida")
	g._pack_check()
	ok(al.maxhp == hpv + 2, "Matilha só uma vez")
	limpa(g)
	# ---- Cameo: rouba a ativa
	var cm = put(g, "cameo", 0, c0.x, c0.y)
	ok(cm.maxhp == 3, "Cameo com 3 de Vida")
	var far = DB.hexes.filter(func(h): return g.is_free(h) and DB.dist(h, c0) >= 6 and DB.dist(h, c0) <= 12)[0]
	var vit = put(g, "moby", 1, far.x, far.y)
	g.start_activation(cm)
	fila = [vit.pos()]
	await g.act_ult(cm)
	g.end_activation()
	ok(g.ult_kind(cm) == "berserk" and not g.ult_spent(cm), "Cameo fica com a ativa roubada")
	ok(g.ult_spent(vit), "o inimigo perde a ativa")
	# ---- Karo (Escalada Primepata): sobe em estruturas, mas não anda na água funda
	limpa(g)
	var kh = DB.hexes.filter(func(h): return g.is_free(h) and not g.blocks.has(h) and livres(g, h, 1).size() >= 3)[0]
	var kr = put(g, "karo", 0, kh.x, kh.y)
	var viz = livres(g, kh, 1)
	g.terr_map[viz[0]] = {"k": "correnteza", "h": 0}
	g.blocks[viz[0]] = true
	g.terr_map[viz[1]] = {"k": "rocha", "h": 2}
	g.blocks[viz[1]] = true
	ok(not g.can_enter(kr, viz[0]), "Karo não entra na água funda")
	ok(g.can_enter(kr, viz[1]), "Karo escala a rocha")
	ok(not g.move_opts(kr, 6).any(func(m): return m["h"] == viz[0]), "água funda fora das casas de movimento do Karo")
	print("TESTE FIM falhas=%d" % falhas)
