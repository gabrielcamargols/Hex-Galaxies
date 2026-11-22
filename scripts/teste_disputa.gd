extends Node
## Teste de regressão da Disputa pela Hex Energy: godot --headless --path . -- --teste=disputa

var falhas := 0
var fila: Array = []
var perguntas: Array = []


func ok(c: bool, msg: String) -> void:
	if c:
		print("  ok    ", msg)
	else:
		print("  FALHA ", msg)
		falhas += 1


func H(q: int, r: int) -> Vector2i:
	return Vector2i(q, r)


func novo(fac0: String = "KRI", fac1: String = "WAC", inv: int = 0) -> Game:
	DB.troca_padrao = inv == 1
	DB.set_map("galeria")
	var g = Game.new()
	g.tree = null
	g.pace_time = 0.0
	g.cpu = [false, false]
	g.modo = "disputa"
	g.inv = inv
	g.setup([{"fac": fac0, "picks": [], "start": []}, {"fac": fac1, "picks": [], "start": []}], "galeria")
	g.question.connect(func(p, q):
		perguntas.append({"p": p, "q": q})
		g.answered.emit.call_deferred(fila.pop_front() if not fila.is_empty() else null))
	return g


func put(g: Game, cid: String, p: int, q: int, r: int) -> Game.Unit:
	var u = g._mk(cid, p, "field")
	u.q = q
	u.r = r
	return u


# deixa o núcleo pronto sem passar pela preparação
func arma(g: Game) -> void:
	g.core = H(3, 0)
	g.core_until = 999
	g.round_no = 2
	g._gen_crystals()


func run() -> void:
	print("== Disputa pela Hex Energy ==")
	# ---------- dados ----------
	for f in ["KRI", "WAC", "ZUK", "FAU", "ABY", "LIT", "TER"]:
		ok(DB.excl_of(f).size() == 4, "%s tem 4 táticas exclusivas" % f)
	ok(DB.excl_ids.size() == 28, "28 exclusivas no catálogo")
	ok(not DB.tactic_ids.any(func(i): return DB.excl_ids.has(i)), "exclusivas fora do baralho comum")
	ok(DB.disputa_pares.size() == 3 and DB.disputa_pares.all(func(pr): return DB.tactic_ids.has(pr[0]) and DB.tactic_ids.has(pr[1])), "3 pares públicos de genéricas existentes")
	var gal = DB.maps["galeria"]
	ok(gal.get("disputa", false) and gal.has("core_fixed"), "galeria de Valak marcada como mapa da Disputa")

	# ---------- preparação: 3 exclusivas + draft ----------
	var g = novo("KRI", "ZUK", 0)
	ok(g.cmd_round == 4 and g.last_round == 5, "prazo de 5 rounds e comandantes no round 4")
	fila = [["x_fogo_cruzado", "x_marcacao", "x_cobrir"], ["x_desvio", "x_rele", "x_holo"], null, null]
	perguntas = []
	await g._disputa_preparo()
	var qx = perguntas.filter(func(x): return x["q"]["t"] == "excl")
	var qd = perguntas.filter(func(x): return x["q"]["t"] == "draft")
	ok(qx.size() == 2 and qx[0]["q"]["opts"].size() == 4 and int(qx[0]["q"]["n"]) == 3, "cada lado escolhe 3 de 4 exclusivas")
	ok(qd.size() == 2 and qd[0]["p"] == 1 and qd[1]["p"] == 0, "draft: Guardiões escolhem no 1º par, Invasores no 2º (prioridade invertida)")
	ok(not qd.any(func(x): return x["q"].has("excl") or str(x["q"]).contains("x_desvio") and x["p"] == 0), "a pergunta do draft não mostra as exclusivas do rival")
	ok(g.P[0]["hand"].size() == 5 and g.P[1]["hand"].size() == 5, "mão inicial de 5 cartas para cada lado")
	ok(g.P[0]["hand"].slice(0, 3) == ["x_fogo_cruzado", "x_marcacao", "x_cobrir"], "Invasores: as 3 exclusivas escolhidas")
	var gen = []
	for p in range(2):
		for c in g.P[p]["hand"]:
			if DB.tactic_ids.has(c):
				gen.append(c)
	var unicas = {}
	for c in gen:
		unicas[c] = true
	ok(gen.size() == 4 and unicas.size() == 4, "draft distribui 4 genéricas diferentes, 2 para cada lado")
	ok(g.draft_log.size() == 4 and g.draft_log.all(func(d): return g.P[int(d["p"])]["hand"].has(d["id"])), "registro público do draft bate com as mãos")
	ok(range(2).all(func(p): return not g.P[p]["deck"].any(func(c): return g.P[p]["hand"].has(c))), "as genéricas recebidas saem do baralho de quem recebeu")

	# ---------- extração ----------
	g = novo("KRI", "WAC", 0)
	arma(g)
	var a = put(g, "k_tank", 0, 3, 0)
	var b = put(g, "k_front", 0, 1, 0)
	var w1 = put(g, "w_urso", 1, 6, -2)
	var w2 = put(g, "w_alce", 1, 5, -2)
	g.cur = 0
	g.start_activation(b)
	ok(not g.can_extract(b), "fora do núcleo não dá para extrair")
	await g.end_activation()
	g.cur = 0
	g.start_activation(a)
	ok(g.can_extract(a), "tropa invasora no núcleo pode extrair")
	await g.act_extract(a)
	ok(g.extr != null and int(g.extr["uid"]) == a.uid and not g.extr["resp"] and g.act["actions"] == 1, "extração começa e gasta 1 ação")
	await g.end_activation()
	# a vez volta para a mesma tropa antes de os Guardiões agirem: não conclui
	a.activated = false
	g.cur = 0
	g.start_activation(a)
	ok(g.winner == Game.NONE and g.extr != null, "sem resposta dos Guardiões, não conclui (espera a próxima)")
	await g.end_activation()
	g.cur = 1
	g.start_activation(w1)
	ok(g.extr["resp"], "Guardião agiu: conta como oportunidade de resposta")
	damage_sem_sair(g, a)
	ok(g.extr != null, "sofrer dano sem sair da casa mantém a extração")
	await g.end_activation()
	a.activated = false
	g.cur = 0
	g.start_activation(a)
	ok(g.winner == 0 and g.win_cause == "extracao", "na próxima ativação elegível, a extração termina: vitória imediata dos Invasores")

	# passar a vez conta como resposta
	g = novo("KRI", "WAC", 0)
	arma(g)
	a = put(g, "k_tank", 0, 3, 0)
	w1 = put(g, "w_urso", 1, 6, -2)
	g.cur = 0
	g.start_activation(a)
	await g.act_extract(a)
	await g.end_activation()
	g.P[1]["passed"] = false
	g.cur = 1
	await g.pass_turn(1)
	ok(g.extr != null and g.extr["resp"], "Guardião passar a vez também conta como resposta")

	# sair do núcleo cancela
	g = novo("KRI", "WAC", 0)
	arma(g)
	a = put(g, "k_tank", 0, 3, 0)
	g.cur = 0
	g.start_activation(a)
	await g.act_extract(a)
	await g.move_unit(a, H(2, 0))
	ok(g.extr == null, "sair do núcleo cancela a extração")
	# empurrado para fora cancela; outra tropa começa nova tentativa com 1 ação
	g = novo("KRI", "WAC", 0)
	arma(g)
	a = put(g, "k_tank", 0, 3, 0)
	b = put(g, "k_front", 0, 2, 0)
	w1 = put(g, "w_gorila", 1, 4, 0)
	g.cur = 0
	g.start_activation(a)
	await g.act_extract(a)
	await g.end_activation()
	await g.move_unit(a, H(3, 1))   # empurrão
	ok(g.extr == null, "ser deslocado para fora do núcleo cancela")
	g.cur = 0
	await g.move_unit(b, H(3, 0))
	g.start_activation(b)
	ok(g.can_extract(b) and g.extr == null, "tropa que chega depois começa uma nova tentativa (precisa da ação)")
	await g.act_extract(b)
	ok(g.extr != null and int(g.extr["uid"]) == b.uid, "nova tentativa registrada para a nova tropa")
	# derrotado cancela
	b.hp = 1
	g.damage(b, 5, w1)
	g.settle()
	ok(g.extr == null and b.st == "dead", "ser derrotado cancela a extração")

	# ---------- prazo, comandante e eliminação ----------
	g = novo("KRI", "WAC", 0)
	arma(g)
	a = put(g, "k_tank", 0, 1, 0)
	put(g, "w_urso", 1, 6, -2)
	g.round_no = 5
	await g.end_round()
	ok(g.winner == 1 and g.win_cause == "prazo", "fim do round 5 sem extração: Guardiões vencem")
	g = novo("KRI", "WAC", 0)
	arma(g)
	a = put(g, "k_tank", 0, 1, 0)
	var cmd1 = g.commander(1)
	cmd1.st = "dead"
	g.check_win()
	ok(g.winner == Game.NONE, "comandante caído não decide a Disputa")
	for x in g.units.filter(func(y): return y.owner == 0):
		x.st = "dead"
	g.check_win()
	ok(g.winner == 1 and g.win_cause == "eliminacao", "sem nenhum Invasor de pé, os Guardiões vencem")
	# partida normal continua igual
	DB.troca_padrao = false
	DB.set_map("posto")
	var gn = Game.new()
	gn.tree = null
	gn.setup([{"fac": "KRI", "picks": [], "start": []}, {"fac": "WAC", "picks": [], "start": []}], "posto")
	ok(gn.modo == "" and gn.cmd_round == Game.CMD_ROUND and gn.last_round == Game.LAST_ROUND, "partida normal mantém rounds e comandantes")
	gn.commander(1).st = "dead"
	gn.check_win()
	ok(gn.winner == 0, "partida normal: comandante caído ainda decide")

	# ---------- papéis: zonas acompanham ----------
	DB.troca_padrao = false
	DB.set_map("galeria")
	var z0 = DB.entry_c[0]
	DB.troca_padrao = true
	DB.set_map("galeria")
	ok(DB.entry_c[1] == z0, "revanche: a zona dos Invasores vai para o outro lado junto com o papel")
	DB.troca_padrao = false
	DB.set_map("galeria")

	# ---------- táticas exclusivas ----------
	await testa_exclusivas()
	print("TESTE FIM falhas=%d" % falhas)


func damage_sem_sair(g: Game, u) -> void:
	g.damage(u, 1, null)
	g.settle()


func joga(g: Game, p: int, id: String, u, respostas: Array) -> bool:
	g.P[p]["hand"].append(id)
	fila = respostas
	if g.act == null or g.act["uid"] != u.uid:
		g.cur = p
		u.activated = false
		g.start_activation(u)
	return await g.play_tactic(p, id)


func testa_exclusivas() -> void:
	# Krieg
	var g = novo("KRI", "WAC", 0)
	arma(g)
	var k1 = put(g, "k_sniper", 0, 0, 0)
	var k2 = put(g, "k_front", 0, 1, 1)
	var e = put(g, "w_urso", 1, 2, 1)
	e.hitters = [k1.uid]
	e.hitters_round = g.round_no
	ok(await joga(g, 0, "x_fogo_cruzado", k2, [e.pos()]), "Fogo Cruzado: alvo já atingido por um Krieg")
	ok(g._x_bonus_atk(k1, e, true) == 0, "Fogo Cruzado: o mesmo Krieg que acertou não ganha o bônus")
	ok(g._x_bonus_atk(k2, e, false) == 2, "Fogo Cruzado: outro Krieg ganha +2 no próximo ataque")
	ok(g._x_bonus_atk(k2, e, false) == 0, "Fogo Cruzado: o bônus é só uma vez")
	g = novo("KRI", "WAC", 0)
	arma(g)
	k1 = put(g, "k_sniper", 0, 0, 0)
	k2 = put(g, "k_front", 0, 1, 0)
	var p1 = k1.pos()
	var p2 = k2.pos()
	ok(await joga(g, 0, "x_retirada_ordem", k1, [p1, p2]), "Retirada em Ordem")
	ok(k1.pos() == p2 and k2.pos() == p1, "Retirada em Ordem: os dois Krieg trocam de lugar")
	# Wächter
	g = novo("WAC", "KRI", 0)
	arma(g)
	var w = put(g, "w_urso", 0, 2, 0)
	ok(await joga(g, 0, "x_retomar", w, [w.pos()]) and w.pos() == g.core, "Retomar o Perímetro: avança para o núcleo")
	g = novo("WAC", "KRI", 0)
	arma(g)
	var wa = put(g, "w_urso", 0, 0, 0)
	var wb = put(g, "w_alce", 0, 1, 0)
	var en = put(g, "k_front", 1, 0, 1)
	ok(await joga(g, 0, "x_linha_escudos", wa, [wa.pos(), wb.pos()]), "Linha de Escudos")
	ok(g.reduction_of(wa, true) >= 2 and g.reduction_of(wb, true) >= 1, "Linha de Escudos: -1 no próximo golpe de cada um")
	# Interposição
	g = novo("WAC", "KRI", 0)
	arma(g)
	wa = put(g, "w_lince", 0, 0, 0)
	wb = put(g, "w_alce", 0, 1, 0)
	en = put(g, "k_front", 1, 0, 1)
	g.P[0]["hand"].append("x_interposicao")
	g.cur = 1
	g.start_activation(en)
	fila = [wb.pos()]
	var hp_a = wa.hp
	var hp_b = wb.hp
	var d0 = await g._x_interposicao(en, wa, 3, false)
	ok(d0 == 1 and not g.P[0]["hand"].has("x_interposicao"), "Interposição: absorve 2 do golpe corpo a corpo")
	ok(wb.hp == hp_b - 2 and wa.hp == hp_a, "Interposição: o Watcher ao lado recebe o dano absorvido")
	# Zukunft
	g = novo("ZUK", "KRI", 0)
	arma(g)
	var z = put(g, "z_vang", 0, -2, 0)
	var dests = g._x_desvio_dest(z)
	ok(not dests.is_empty() and dests.all(func(h): return DB.dist(h, z.pos()) <= 2), "Desvio Portalis: casas a até 2")
	var zd = dests[0]
	ok(await joga(g, 0, "x_desvio", z, [z.pos(), zd]) and z.pos() == zd, "Desvio Portalis: salta")
	g = novo("ZUK", "KRI", 0)
	arma(g)
	z = put(g, "z_vang", 0, 0, 0)
	var atir = put(g, "k_sniper", 1, 0, 4) if g.is_free(H(0, 4)) else put(g, "k_sniper", 1, -3, 3)
	var mira = g.line_hexes(atir.pos(), z.pos(), 1e-6)
	var meio = mira[1] if mira.size() > 2 else null
	if meio != null and g.is_free(meio):
		g.holos.append({"h": meio, "owner": 0, "till": g.round_no})
		ok(g._holo_bloqueia(atir, z) == 0, "Projeção Holográfica: bloqueia o tiro que cruza a casa")
	# Faurianos
	g = novo("FAU", "KRI", 0)
	arma(g)
	var f = put(g, "karu", 0, 0, 0)
	f.hp = f.maxhp - 3
	var bh = H(1, 0)
	ok(await joga(g, 0, "x_suprimento", f, [bh]) and g.bananas.has(bh), "Suprimento de Campo: banana na casa")
	await g.move_unit(f, bh)
	ok(f.hp == f.maxhp - 1 and not g.bananas.has(bh), "Suprimento de Campo: Fauriano cura 2 e consome")
	# Abyssais: tinta bloqueia tiro
	g = novo("ABY", "KRI", 0)
	arma(g)
	var ab1 = H(-2, 0)
	var ab2 = H(2, 0)
	var antes = g.los(ab1, ab2)
	g.smokes.append({"h": H(0, 0), "till": g.round_no})
	ok(antes and not g.los(ab1, ab2), "Maré de Recuo: a tinta bloqueia tiros que passam por ela")
	# Lithari
	g = novo("LIT", "KRI", 0)
	arma(g)
	var l = put(g, "l_tank", 0, 0, 0)
	ok(await joga(g, 0, "x_semente", l, [H(1, 0)]) and g.czone_owner(H(1, 0)) == 0, "Semente Mineral: vira Zona de Cristal")
	await g.end_round()
	# Valakianos: Escora e Passagem
	g = novo("TER", "KRI", 0)
	arma(g)
	var ter = put(g, "t_basalto", 0, 0, -3)
	var alto = H(1, -4)
	var pode_antes = g.can_step(ter.pos(), alto)
	g.escoras[alto] = g.round_no + 1
	ok(g.terr(alto)["h"] == 1 and (pode_antes == false or g.tt_of(g.terr(alto)["k"]).get("climb", 0)) , "Escora: casa alta escolhida")
	var esc = H(1, -3)
	var custo = g.step_cost(H(0, -3), esc)
	g.passagens[esc] = g.round_no + 1
	ok(g.step_cost(H(0, -3), esc) == max(1, custo - 1), "Passagem Escorada: entrar custa 1 a menos")
	var vf = put(g, "t_britadeira", 0, -2, -1)
	g.cur = 0
	g.start_activation(vf)
	g.act["ferramenta"] = true
	var cr = g.unit_at(H(-2, -2))
	ok(cr != null and cr.crystal != "" and g._x_bonus_atk(vf, cr, false) == 2, "Ferramenta de Reserva: +2 contra cristal")
