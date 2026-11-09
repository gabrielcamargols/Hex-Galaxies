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
	var sn = put(g, "z_piloto", 0, 4, 1)
	var en = put(g, "z_vang", 1, 2, -5)
	g.start_activation(gd)
	ok(g.ult_kind(gd) == "portalis" and g.can_ult(gd), "Portalis disponível")
	ok(g.ult_opts(gd).all(func(h): return DB.dist(h, gd.pos()) <= 6 and DB.dist(h, gd.pos()) >= 1), "portais a até 6 casas")
	var cand = g.ult_opts(gd).filter(func(h): return DB.dist(h, en.pos()) <= 3 and g.los(h, en.pos()))
	cand.sort_custom(func(a, b): return DB.dist(a, gd.pos()) > DB.dist(b, gd.pos()))
	var PB: Vector2i = cand[0]
	var PA: Vector2i = H(4, -1) if H(4, -1) in g.ult_opts(gd) else g.ult_opts(gd).filter(func(h): return DB.dist(h, al.pos()) == 1)[0]
	fila = [PA, PB]
	var r = await g.act_ult(gd)
	var pt = g.portal_of(gd)
	ok(r and pt != null and pt["a"] == PA and pt["b"] == PB, "dois portais: entrada e saída escolhidas")
	ok(g.tunnel_hex(PA) and g.tunnel_hex(PB), "as duas casas ficam reservadas e visíveis")
	g.end_activation()
	# aliado ao lado da ENTRADA ataca a partir da SAÍDA
	var adj = DB.nbrs(PA)
	sn.q = adj[0].x
	sn.r = adj[0].y
	if sn.pos() == PB or g.unit_at(adj[0]) != sn:
		sn.q = adj[1].x
		sn.r = adj[1].y
	ok(not g._targets_from(sn).has(en), "sem portal o atirador não alcançaria o inimigo")
	ok(g.attack_targets(sn).has(en), "ataque entra pela entrada e sai pela saída")
	g.start_activation(sn)
	var hp = en.hp
	var home = sn.pos()
	var okat = await g.act_attack(sn, en)
	ok(okat and en.hp < hp and sn.pos() == home, "ataque feito pelo portal e o atirador não saiu do lugar")
	g.end_activation()
	# travessia de aliados: só entrando pela entrada
	var al2 = put(g, "z_tank", 0, adj[2].x, adj[2].y)
	g.start_activation(al2)
	ok(g.tunnel_exits(al2).has(PB), "aliado ao lado da entrada sai pela saída")
	fila = [PB]
	var rx = await g.act_mexit(al2)
	ok(rx and al2.pos() == PB and g.act["moved"], "aliado atravessou (ação de movimento)")
	g.end_activation()
	g.start_activation(al2)
	ok(g.tunnel_exits(al2).is_empty(), "da saída não se volta pela entrada (sentido único)")
	g.end_activation()
	ok(g.tunnel_exits(en).is_empty(), "inimigo não usa o portal")
	# um portal por vez e some com o Guarda
	g.round_no = 5
	g.start_activation(gd)
	var o2 = g.ult_opts(gd).filter(func(h): return h != PA and h != PB)
	fila = [o2[0], o2[1]]
	await g.act_ult(gd)
	ok(g.live_portals().size() == 1 and g.portal_of(gd)["a"] == o2[0], "um portal por vez")
	gd.st = "dead"
	ok(g.live_portals().is_empty() and not g.tunnel_hex(o2[0]), "portais desaparecem com o Guarda")
	print("TESTE FIM falhas=%d" % falhas)
