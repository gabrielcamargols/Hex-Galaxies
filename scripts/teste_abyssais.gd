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
		u.st = "reserve" if u.is_cmd else "dead"   # comandante fora do campo, mas vivo (senão a partida acaba)
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
	await parte2()
	print("TESTE FIM falhas=%d" % falhas)


func limpa(g: Game) -> void:
	for u in g.units:
		u.st = "reserve" if u.is_cmd else "dead"   # comandante fora do campo, mas vivo (senão a partida acaba)
	g.mines = []
	g.stars = []
	g.winner = g.NONE


func parte2() -> void:
	var g = novo()
	limpa(g)
	var c0 = DB.hexes.filter(func(h): return g.is_free(h) and not livres(g, h, 1).is_empty() and not livres(g, h, 4).is_empty() and not livres(g, h, 3).is_empty())[0]
	# ---- Oncus: Roda Punk
	var on = put(g, "oncus", 0, c0.x, c0.y)
	var e1 = put(g, "z_vang", 1, livres(g, c0, 1)[0].x, livres(g, c0, 1)[0].y)
	var e4 = put(g, "z_vang", 1, livres(g, c0, 4)[0].x, livres(g, c0, 4)[0].y)
	var lejos = DB.hexes.filter(func(h): return g.is_free(h) and DB.dist(h, c0) >= 6)
	var e9 = put(g, "z_vang", 1, lejos[0].x, lejos[0].y)
	e1.hp = 9; e4.hp = 9; e9.hp = 9
	g.start_activation(on)
	var dest = DB.hexes.filter(func(h): return g.is_free(h) and DB.dist(h, c0) == 2)[0]
	fila = [dest]
	ok(g.can_ult(on), "Roda Punk disponível com inimigo a até 4")
	await g.act_ult(on)
	ok(e1.hp == 4 and e4.hp == 4, "Roda Punk: 1+2+2 = 5 em cada inimigo a até 4 (%d, %d)" % [e1.hp, e4.hp])
	ok(e9.hp == 9, "fora da área não é atingido")
	ok(on.pos() == dest, "Oncus escolhe onde parar dentro da área")
	g.end_activation()
	limpa(g)
	# ---- Esterina: Estrela Hexa
	var es = put(g, "sterina", 0, c0.x, c0.y)
	var al = put(g, "moby", 0, livres(g, c0, 1)[0].x, livres(g, c0, 1)[0].y)
	al.hp = 3
	g.start_activation(es)
	fila = [c0]
	await g.act_ult(es)
	g.end_activation()
	ok(g.in_star(al) and g.in_star(es), "aliados dentro da estrela")
	var viz = DB.nbrs(al.pos()).filter(func(h): return g.is_free(h))
	var inim = put(g, "z_vang", 1, viz[0].x, viz[0].y)
	ok(not g.attack_targets(inim).has(al), "protegido de ataque corpo a corpo dentro da estrela")
	g._star_tick()
	ok(al.hp == 5, "Estrela cura 2 por round (%d)" % al.hp)
	limpa(g)
	# ---- Klang: Tiro Sônico, empurra / atordoa e Marca Abyssal
	var kl = put(g, "klang", 0, c0.x, c0.y)
	ok(g.alc_of(kl) == 4, "Klang alcance 4")
	var h4 = livres(g, c0, 4)
	var alvo = put(g, "z_vang", 1, h4[0].x, h4[0].y)
	alvo.hp = 9
	var antes = alvo.pos()
	g.start_activation(kl)
	await g.act_attack(kl, alvo)
	g.end_activation()
	var empurrou = alvo.pos() != antes and DB.dist(alvo.pos(), kl.pos()) == 5
	var atordoou = alvo.fx.any(func(f): return f["k"] == "stun")
	ok(empurrou or atordoou, "alcance máximo: empurra 1 casa ou atordoa se bloqueado")
	ok(g.marked_by(alvo, 0), "alvo fica com a Marca Abyssal")
	# atordoado: força o bloqueio
	alvo.fx.append({"k": "stun", "end": g.round_no + 1})
	ok(g.rooted(alvo) and g.stunned(alvo), "atordoado não move nem ataca")
	g.cur = 1
	g.P[1]["scarabs"] = 1
	fila = [alvo.pos()]
	await g.act_scarab(1, "stun")
	ok(not g.stunned(alvo) and g.scarabs_of(1) == 0, "1 Escaravelho liberta do atordoamento")
	# marca: +1 a cada 2 de Vida perdida; com menos de 2 cai na hora
	alvo.hp = alvo.maxhp - 4   # perdeu 4 -> +2
	ok(g.atk_of(kl, alvo) == g.atk_of(kl, null) + 2, "marca: +2 com 4 de Vida perdida")
	alvo.hp = 1
	g._mark_ko(alvo, kl)
	g.settle()
	ok(alvo.st != "field", "marcado com menos de 2 de Vida é nocauteado")
	limpa(g)
	# ---- Kling: Oficina Móvel
	var kg = put(g, "kling", 0, c0.x, c0.y)
	var rec = put(g, "a_garra", 0, livres(g, c0, 3)[0].x, livres(g, c0, 3)[0].y)
	g.start_activation(kg)
	fila = [rec.pos()]
	await g.act_ult(kg)
	g.end_activation()
	ok(["casco", "adaga", "garras"].any(func(k): return g.has_fx(rec, k)), "item entregue a aliado a até 6")
	rec.fx = [{"k": "casco"}]
	ok(g.reduction_of(rec, true, 3) >= 4 and g.reduction_of(rec, true, 1) < 4, "Casco Duro: -4 só à distância")
	rec.fx = [{"k": "adaga"}]
	var en_m = put(g, "z_vang", 1, DB.nbrs(rec.pos()).filter(func(h): return g.is_free(h))[0].x, DB.nbrs(rec.pos()).filter(func(h): return g.is_free(h))[0].y)
	ok(g.atk_of(rec, en_m) == g.atk_of(rec, null) + 5, "Adaga Abyssal: +5 corpo a corpo")
	limpa(g)
	# ---- Medusa: Queimadura Insuportável
	var md = put(g, "a_medusa", 0, c0.x, c0.y)
	var vt = put(g, "z_vang", 1, livres(g, c0, 3)[0].x, livres(g, c0, 3)[0].y)
	vt.hp = 9
	g.start_activation(md)
	fila = [vt.pos()]
	await g.act_ult(md)
	g.end_activation()
	ok(vt.hp == 8 and g.has_fx(vt, "shock"), "1 de dano sem marca e eletrocutado")
	ok(not g.can_attack_any(vt), "eletrocutado não ataca")
	g.winner = g.NONE
	await g.end_round()
	ok(vt.hp == 7 and not g.has_fx(vt, "shock"), "no fim do round sofre mais 1 e o choque passa")
	limpa(g)
	# ---- Inkshadow: Cortina de Tinta e Silentus Mortis
	var ik = put(g, "inkshadow", 0, c0.x, c0.y)
	ok(g.mov_of(ik) == 6, "Inkshadow MOV 6")
	var p1 = livres(g, c0, 3)[0]
	var p2 = DB.hexes.filter(func(h): return g.is_free(h) and DB.dist(h, c0) <= 8 and DB.dist(h, p1) >= 2 and h != c0)[0]
	g.start_activation(ik)
	fila = [p1, p2]
	await g.act_ult(ik)
	g.end_activation()
	ok(ik.pos() == p2 and not g.inks.is_empty(), "duas corridas e rastro de tinta")
	ok(g.in_ink(ik) and g.alc_of(ik) == 3 and g.atk_of(ik, null) == 8, "no rastro: +2 ALC e +4 ATQ (%d, %d)" % [g.alc_of(ik), g.atk_of(ik, null)])
	var tir = DB.hexes.filter(func(h): return g.is_free(h) and DB.dist(h, ik.pos()) == 2 and g.los(h, ik.pos()))
	var atir = put(g, "klang", 1, tir[0].x, tir[0].y)
	ok(not g.attack_targets(atir).has(ik), "inimigo à distância não vê quem está na tinta")
	atir.st = "dead"
	var mk = put(g, "z_vang", 1, DB.nbrs(ik.pos()).filter(func(h): return g.is_free(h))[0].x, DB.nbrs(ik.pos()).filter(func(h): return g.is_free(h))[0].y)
	mk.fx.append({"k": "amark", "by": 0, "until": "end"})
	ok(g.atk_of(ik, mk) >= 8 + 6, "marcado atacado de dentro da tinta: +6")
	mk.hp = 3
	g._mark_ko(mk, ik)
	g.settle()
	ok(mk.st != "field", "Silentus Mortis: marcado com 3 de Vida cai")
