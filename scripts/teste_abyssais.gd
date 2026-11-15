extends Node
## Teste de regressão dos Abyssais (Moby, Rayak, Sapturne): --teste=abyssais

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
	g.setup([{"fac": "ABY", "picks": [], "start": []}, {"fac": "ZUK", "picks": [], "start": []}], "posto")
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
	print("== Abyssais ==")
	var g = novo()
	for u in g.units:
		u.st = "dead"
	var c0 = DB.hexes.filter(func(h): return g.is_free(h) and not livres(g, h, 1).is_empty() and not livres(g, h, 3).is_empty())[0]
	# Rayak
	var ry = put(g, "rayak", 0, c0.x, c0.y)
	ok(g.alc_of(ry) == 5 and g.mov_of(ry) == 3 and ry.maxhp == 6 and g.atk_of(ry, null) == 4, "Rayak: MOV 3, ATQ 4, ALC 5, Vida 6")
	ry.st = "dead"
	# Moby: Fúria Ferida
	var mb = put(g, "moby", 0, c0.x, c0.y)
	ok(g.mov_of(mb) == 4 and mb.maxhp == 8 and g.alc_of(mb) == 1, "Moby: MOV 4, ALC 1, Vida 8")
	ok(g.atk_of(mb, null) == 3, "Moby com Vida cheia: ATQ 3")
	mb.hp = 3
	ok(g.atk_of(mb, null) == 8, "Moby com 3 de Vida: ATQ 3 + 5 = 8")
	# Berserker Total
	g.start_activation(mb)
	ok(g.can_ult(mb), "Berserker disponível com 2 ações")
	var r = await g.act_ult(mb)
	ok(r and g.act["actions"] == 0, "Berserker gasta as 2 ações")
	ok(g.atk_of(mb, null) == 16, "Berserker dobra o dano (8 -> 16)")
	g.end_activation()
	var r0 = g.round_no
	g.winner = g.NONE
	await g.end_round()
	ok(mb.st == "field", "Moby continua de pé no fim do round em que entrou em fúria")
	g.winner = g.NONE
	g.round_no = r0 + 1
	await g.end_round()
	ok(mb.st != "field", "Moby cai no fim do round seguinte")
	# Sapturne: Campo Minado só com Rhazur em campo
	var sp = put(g, "sapturne", 0, c0.x, c0.y)
	g.start_activation(sp)
	ok(not g.can_ult(sp), "Campo Minado bloqueado sem Rhazur")
	var far = DB.hexes.filter(func(h): return g.is_free(h) and DB.dist(h, c0) >= 5)[0]
	var rz = put(g, "rhazur", 0, far.x, far.y)
	ok(g.can_ult(sp), "Campo Minado liberado com Rhazur em campo")
	var alvo8 = g.ult_opts(sp).filter(func(h): return DB.dist(h, c0) >= 6)
	ok(not alvo8.is_empty() and g.ult_opts(sp).all(func(h): return DB.dist(h, c0) <= 8), "minas a até 8 casas")
	# duas minas lado a lado e uma terceira: limite de 2
	var h1 = livres(g, c0, 3)[0]
	var h2 = DB.nbrs(h1).filter(func(h): return g.is_free(h) and DB.dist(h, c0) <= 8)[0]
	fila = [h1]
	await g.act_ult(sp)
	g.act["actions"] = 2
	fila = [h2]
	await g.act_ult(sp)
	ok(g.mines.filter(func(m): return m["src"] == sp.uid).size() == 2, "duas minas de Sapturne em campo")
	g.end_activation()
	# cadeia: inimigo pisa em h1; a mina de h2 explode junto
	var viz = DB.nbrs(h2).filter(func(h): return g.is_free(h) and h != h1)
	var en2 = put(g, "z_vang", 1, viz[0].x, viz[0].y)
	var en1 = put(g, "z_vang", 1, h1.x, h1.y)
	en1.hp = 9
	en2.hp = 9
	g.mines = g.mines.filter(func(m): return m["h"] != h1)
	g.mines.append({"owner": 0, "h": h1, "n": 3, "src": sp.uid, "root": true})
	var m1 = g.mines.back()
	g.mines.erase(m1)
	g._mine_chain(m1)
	g.settle()
	ok(g.mines.is_empty(), "a mina vizinha explodiu em cadeia")
	ok(en2.hp == 8, "inimigo ao lado da mina em cadeia sofre 1 (%d)" % en2.hp)
	ok(en1.hp == 8, "inimigo vizinho da 2ª mina também sofre 1 (%d)" % en1.hp)
	print("TESTE FIM falhas=%d" % falhas)
