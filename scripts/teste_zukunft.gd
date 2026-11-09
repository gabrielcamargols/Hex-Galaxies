extends Node
## Teste de regressão dos Zukunft novos: godot --headless --path . -- --teste=zukunft

var falhas := 0
var fila: Array = []


func ok(c: bool, msg: String) -> void:
	if c:
		print("  ok    ", msg)
	else:
		print("  FALHA ", msg)
		falhas += 1


func H(q: int, r: int) -> Vector2i:
	return Vector2i(q, r)


func novo() -> Game:
	DB.set_map("posto")
	var g = Game.new()
	g.tree = null
	g.pace_time = 0.0
	g.cpu = [false, false]
	g.setup([{"fac": "ZUK", "picks": [], "start": []}, {"fac": "ZUK", "picks": [], "start": []}], "posto")
	g.round_no = 4
	g.question.connect(func(_p, _q): g.answered.emit.call_deferred(fila.pop_front() if not fila.is_empty() else null))
	return g


func put(g: Game, cid: String, p: int, q: int, r: int) -> Game.Unit:
	var u = g._mk(cid, p, "field")
	u.q = q
	u.r = r
	return u


func run() -> void:
	print("== Zukunft ==")
	var c = DB.cards["z_portais"]
	ok(int(c["int"]) == 8 and int(c["atk"]) == 4 and int(c["mov"]) == 2 and int(c["alc"]) == 6, "Guarda dos Portais: 8 de Vida, 4 de ATQ, Mov 2, alcance 6")
	ok(not DB.cards.has("z_infect"), "Infectado foi substituído")
	var g = novo()
	var gd = put(g, "z_portais", 0, 5, 0)
	var al = put(g, "z_vang", 0, 4, 0)
	var en = put(g, "z_vang", 1, 1, -6)
	g.start_activation(gd)
	ok(g.ult_kind(gd) == "portalis" and g.can_ult(gd), "Portalis disponível")
	ok(g.ult_opts(gd).all(func(h): return DB.dist(h, gd.pos()) <= 6 and DB.dist(h, gd.pos()) >= 1), "portal a até 6 casas")
	ok(not g.attack_targets(gd).has(en), "sem portal o inimigo distante não é alvo")
	var cand = g.ult_opts(gd).filter(func(h): return DB.dist(h, en.pos()) <= 5 and g.los(h, en.pos()))
	cand.sort_custom(func(a, b): return DB.dist(a, gd.pos()) > DB.dist(b, gd.pos()))
	var PH: Vector2i = cand[0]
	fila = [PH]
	var r = await g.act_ult(gd)
	ok(r and g.portal_of(gd) == PH, "portal aberto")
	ok(g.tunnel_hex(PH), "casa do portal fica reservada e visível")
	ok(g.attack_targets(gd).has(en), "ataque pelo portal alcança o inimigo")
	var hp = en.hp
	var okat = await g.act_attack(gd, en)
	ok(okat and en.hp < hp and gd.pos() == H(5, 0), "ataque feito pelo portal e o Guarda continua onde estava")
	g.end_activation()
	# travessia de aliados
	g.start_activation(al)
	ok(g.tunnel_exits(al).has(PH), "aliado ao lado do Guarda sai pelo portal")
	fila = [PH]
	var rx = await g.act_mexit(al)
	ok(rx and al.pos() == PH, "aliado atravessou")
	g.end_activation()
	g.start_activation(al)
	ok(g.tunnel_exits(al).any(func(h): return DB.dist(h, gd.pos()) == 1), "aliado ao lado do portal volta para perto do Guarda")
	ok(g.tunnel_exits(en).is_empty(), "inimigo não usa o portal")
	g.end_activation()
	# um portal por vez e some com o Guarda
	g.round_no = 5
	g.start_activation(gd)
	var PH2: Vector2i = g.ult_opts(gd).filter(func(h): return h != PH)[0]
	fila = [PH2]
	await g.act_ult(gd)
	ok(g.live_portals().size() == 1 and g.portal_of(gd) == PH2, "um portal por vez")
	gd.st = "dead"
	ok(g.live_portals().is_empty() and not g.tunnel_hex(PH2), "portal desaparece com o Guarda")
	print("TESTE FIM falhas=%d" % falhas)
