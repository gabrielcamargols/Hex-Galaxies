extends Node
## Teste de regressão dos Krieg: godot --headless --path . -- --teste=krieg

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
	g.setup([{"fac": "KRI", "picks": [], "start": []}, {"fac": "ZUK", "picks": [], "start": []}], "posto")
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


func run() -> void:
	print("== Krieg ==")
	var g = novo()
	for u in g.units:
		u.st = "dead"
	var c0 = DB.hexes.filter(func(h): return g.is_free(h) and not livres(g, h, 3).is_empty() and not livres(g, h, 1).is_empty())[0]
	var cm = put(g, "k_cmd", 0, c0.x, c0.y)
	ok(g.alc_of(cm) == 3, "Comandante tem alcance 3")
	# de longe: 2 a menos e sem Sangramento
	var h3 = livres(g, cm.pos(), 3)
	var lo = put(g, "z_vang", 1, h3[0].x, h3[0].y)
	var perto_atk = g.atk_of(cm, null)
	ok(g.atk_of(cm, lo) == perto_atk - 2, "ataque de longe causa 2 a menos (%d contra %d)" % [g.atk_of(cm, lo), perto_atk])
	ok(g.attack_targets(cm).has(lo), "alcança inimigo a 3 casas")
	g.start_activation(cm)
	await g.act_attack(cm, lo)
	ok(not g.has_fx(lo, "bleed"), "tiro de longe não causa Sangramento")
	g.end_activation()
	lo.st = "dead"
	# corpo a corpo: Sangramento por 2 rounds
	var h1 = livres(g, cm.pos(), 1)
	var en = put(g, "z_vang", 1, h1[0].x, h1[0].y)
	en.hp = 9
	ok(g.atk_of(cm, en) == perto_atk, "corpo a corpo sem penalidade")
	cm.activated = false
	g.start_activation(cm)
	await g.act_attack(cm, en)
	g.end_activation()
	ok(g.has_fx(en, "bleed"), "golpe corpo a corpo aplica Sangramento")
	var hp0 = en.hp
	await g._bleed_tick()
	ok(en.hp == hp0 - 1 and g.has_fx(en, "bleed"), "1º round: perde 1 de Vida e continua sangrando")
	await g._bleed_tick()
	ok(en.hp == hp0 - 2 and not g.has_fx(en, "bleed"), "2º round: perde 1 de Vida e o corte fecha")
	await g._bleed_tick()
	ok(en.hp == hp0 - 2, "depois não perde mais")
	print("TESTE FIM falhas=%d" % falhas)
