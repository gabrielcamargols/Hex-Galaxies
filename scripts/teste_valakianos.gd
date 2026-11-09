extends Node
## Teste de regressão dos Valakianos (sem tela):
##   godot --headless --path . -- --teste=valakianos
## Monta partidas pequenas no Valak, põe as peças à mão e confere cada habilidade contra a especificação.

var falhas := 0
var fila: Array = []      # respostas roteirizadas para as perguntas do motor (casas, sim/não)

# atributos aprovados: id -> [vida, atq, alcance, movimento]
const TABELA = {
	"rei_mina": [10, 4, 6, 3], "perfurador": [8, 2, 1, 3], "t_basalto": [12, 2, 1, 2], "t_carrinho": [8, 2, 1, 3],
	"t_britadeira": [9, 3, 1, 2], "t_fundidor": [8, 2, 1, 2], "t_fendas": [9, 3, 1, 2], "sismico": [10, 2, 1, 2],
	"t_dinamite": [7, 2, 2, 2], "t_sentinela": [11, 2, 1, 2], "t_lanterna": [7, 1, 2, 3], "t_raiz": [10, 2, 1, 2],
	"t_cartografo": [7, 1, 2, 3], "t_sniper": [7, 3, 6, 3], "t_enfermeira": [7, 1, 2, 2], "t_feram": [11, 3, 1, 3],
	"t_pontes": [8, 1, 2, 2]}


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
	g.setup([{"fac": "TER", "picks": [], "start": []}, {"fac": "TER", "picks": [], "start": []}], "posto")
	g.round_no = 1
	g.question.connect(func(_p, _q): g.answered.emit.call_deferred(fila.pop_front() if not fila.is_empty() else null))
	return g


func put(g: Game, cid: String, p: int, q: int, r: int) -> Game.Unit:
	var u = g._mk(cid, p, "field")
	u.q = q
	u.r = r
	return u


func H(q: int, r: int) -> Vector2i:
	return Vector2i(q, r)


func ativa(g: Game, u: Game.Unit, respostas: Array) -> bool:
	fila = respostas.duplicate()
	g.start_activation(u)
	var r = await g.act_ult(u)
	return r


func run() -> void:
	print("== Valakianos ==")
	_tabela()
	await _perfurador()
	await _muralha_e_raizes()
	await _carrinho_e_feram()
	_britadeiro()
	await _fundidor_e_sentinela()
	await _demolidor()
	await _sismico()
	await _dinamitador()
	await _curas()
	await _cartografo()
	await _sniper()
	await _engenheiro()
	await _rei_barreira()
	await _rei_cristais()
	await _rei_manip()
	print("TESTE FIM falhas=%d" % falhas)


func _tabela() -> void:
	print("-- atributos")
	var erros = 0
	for id in TABELA.keys():
		var c = DB.cards[id]
		var t = TABELA[id]
		if int(c["int"]) != t[0] or int(c["atk"]) != t[1] or int(c["alc"]) != t[2] or int(c["mov"]) != t[3]:
			ok(false, "%s: vida/atq/alcance/mov = %s" % [id, [c["int"], c["atk"], c["alc"], c["mov"]]])
			erros += 1
		if c["f"] != "TER":
			ok(false, "%s não é Valakiano" % id)
			erros += 1
		if not (ResourceLoader.exists("res://art/%s.webp" % id) and ResourceLoader.exists("res://art/p_%s.webp" % id)):
			ok(false, "%s sem arte ou avatar" % id)
			erros += 1
	var ter = DB.cards.values().filter(func(c): return c["f"] == "TER")
	ok(ter.size() == 17 and TABELA.size() == 17 and erros == 0, "17 Valakianos: atributos, facção e arte conferem")
	ok(DB.factions["TER"]["cmd"] == "rei_mina" and DB.cards["rei_mina"].get("cmd", false), "Rei da Mina é o comandante")
	ok(DB.factions["TER"]["short"] == "Valakianos", "facção se chama Valakianos")


func _perfurador() -> void:
	print("-- Perfurador")
	var g = novo()
	var u = put(g, "perfurador", 0, 4, 0)
	var e = put(g, "t_fundidor", 1, 5, -1)
	var hp0 = e.hp
	var r = await ativa(g, u, [H(5, 0), H(5, -1)])
	ok(r and u.pos() == H(5, 0), "emerge na casa escolhida a 1 casa")
	ok(e.hp == hp0 - 2, "causa 2 de dano no inimigo ao lado da saída")
	ok(g.ult_spent(u), "ativa gasta no round")
	g.round_no = 2
	ok(not g.ult_spent(u), "volta a ficar disponível no round seguinte (recarga 1)")
	# 2 casas, atravessando uma peça no meio do caminho
	var g2 = novo()
	var u2 = put(g2, "perfurador", 0, 4, 0)
	put(g2, "t_basalto", 1, 5, 0)
	ok(g2.ult_opts(u2).has(H(6, 0)), "atravessa peças e sai a 2 casas")
	ok(not g2.ult_opts(u2).has(H(5, 0)), "não emerge em casa ocupada")
	ok(not g2.ult_opts(u2).has(H(7, 0)), "não emerge a 3 casas ou fora do mapa")


func _muralha_e_raizes() -> void:
	print("-- Golem de Basalto e Guarda-Raiz")
	var g = novo()
	var b = put(g, "t_basalto", 0, 4, 0)
	var r = await ativa(g, b, [H(5, 0)])
	var w = g.unit_at(H(5, 0))
	ok(r and w != null and w.barrier and w.hp == 4 and not w.soft, "Muralha: barreira de 4 de Vida")
	ok(w != null and w.exp == 2, "Muralha dura até o fim do round seguinte")
	ok(g.top_of(H(5, 0)) >= 2, "Muralha bloqueia tiros")
	var g2 = novo()
	var gr = put(g2, "t_raiz", 0, 4, 0)
	var r2 = await ativa(g2, gr, [H(5, 0)])
	var t = g2.unit_at(H(5, 0))
	ok(r2 and t != null and t.barrier and t.hp == 3 and t.soft, "Trama: barreira de raízes de 3 de Vida")
	ok(g2.top_of(H(5, 0)) == 0, "raízes não bloqueiam tiros")
	var e = put(g2, "t_fundidor", 1, 6, 0)
	ok(g2.terrain_mods(gr, e)["cover"] == 0, "raízes não dão abrigo")
	ok(not g2.can_enter(e, H(5, 0)), "raízes bloqueiam o movimento")
	# validade: criada no round 1, some ao fim do round 2
	g2.cpu = [true, true]
	g2.round_no = 1
	await g2.end_round()
	ok(t.st == "field", "ainda existe ao fim do round em que foi criada")
	await g2.end_round()
	ok(t.st == "dead", "some ao fim do segundo round")


func _carrinho_e_feram() -> void:
	print("-- Carrinho de Minério e Golem Feram")
	var g = novo()
	# fora da zona da Garra (a zona vai até 3 casas do buraco): não há vibração aqui
	var c = put(g, "t_carrinho", 0, 5, 1)
	var e = put(g, "t_fundidor", 1, 5, -1)
	var hp0 = e.hp
	var r = await ativa(g, c, [H(5, -1)])
	ok(r and c.pos() == H(5, 0), "Carrinho avança e para ao encontrar a unidade")
	ok(e.hp == hp0 - 2, "Carrinho causa 2 de dano")
	ok(e.pos() == H(5, -2), "Carrinho empurra 1 casa")
	ok(g.vib == 0, "fora da zona não gera vibração")
	ok(g.act["actions"] == 1 and g.can_attack_now(c), "usa 1 ação e ainda pode atacar normalmente")
	# vibração: +3 no deslocamento perto do buraco (no lugar do +1)
	var gv = novo()
	var cv = put(gv, "t_carrinho", 0, 5, 0)
	await ativa(gv, cv, [H(4, 0)])
	ok(gv.vib == 3, "deslocamento que chega perto do buraco soma +3 de vibração (vib=%d)" % gv.vib)
	# começar a ativa já perto do buraco soma +2 da habilidade, além do +3 do deslocamento (5 = a Garra ataca)
	var gw = novo()
	var cw = put(gw, "t_carrinho", 0, 4, 0)
	await ativa(gw, cw, [H(3, 0)])
	ok(gw.logs.any(func(l): return l["text"].begins_with("Vibração +3")) and gw.logs.any(func(l): return l["text"].begins_with("Vibração +2")), "habilidade perto do buraco soma +2 e o deslocamento +3 (sem +1 de andar)")
	# Feram: 2 em unidade (com empurrão) e 4 em construção
	var g2 = novo()
	var f = put(g2, "t_feram", 0, 2, 2)
	var bar = g2._make_barrier(1, H(1, 3), 8)
	var r2 = await ativa(g2, f, [H(1, 3)])
	ok(r2 and bar.hp == 4 and f.pos() == H(2, 2), "Feram causa 4 de dano em construção (sem sair do lugar)")
	var g3 = novo()
	var f3 = put(g3, "t_feram", 0, 2, 2)
	var e3 = put(g3, "t_basalto", 1, 0, 4)
	await ativa(g3, f3, [H(0, 4)])
	ok(e3.hp == 10 and e3.pos() == H(-1, 5), "Feram causa 2 de dano e empurra 1 casa")
	# empurrão bloqueado: a peça fica onde está
	var g4 = novo()
	var f4 = put(g4, "t_feram", 0, 2, 2)
	var e4 = put(g4, "t_basalto", 1, 0, 4)
	put(g4, "t_fundidor", 1, -1, 5)
	await ativa(g4, f4, [H(0, 4)])
	ok(e4.pos() == H(0, 4) and e4.hp == 10, "empurrão com casa ocupada: fica onde está, sem dano extra")


func _britadeiro() -> void:
	print("-- Britadeiro")
	var g = novo()
	var b = put(g, "t_britadeira", 0, 4, 0)
	var bar = g._make_barrier(1, H(5, 0), 4)
	var e = put(g, "t_fundidor", 1, 4, -1)
	ok(g.atk_of(b, bar) == 5, "+2 de dano contra barreiras (3+2)")
	ok(g.atk_of(b, e) == 3, "ataque normal contra unidades continua 3")
	var cr = g._make_barrier(Game.NEUTRAL, H(5, -1), 1)
	cr.crystal = "verde"
	ok(g.atk_of(b, cr) >= 1, "cristal quebra com um ataque")


func _fundidor_e_sentinela() -> void:
	print("-- Fundidor e Sentinela de Pedra")
	var g = novo()
	var f = put(g, "t_fundidor", 0, 4, 0)
	var al = put(g, "perfurador", 0, 5, 0)
	var en = put(g, "t_britadeira", 1, 6, 0)
	await ativa(g, f, [H(5, 0)])
	ok(g.has_fx(al, "coat"), "Revestimento Fundido aplicado")
	g.end_activation()
	g.start_activation(en)
	var hp0 = al.hp
	await g.act_attack(en, al)
	ok(hp0 - al.hp == 1, "1º dano sofrido é reduzido em 2 (3-2=1, perdeu %d)" % (hp0 - al.hp))
	ok(not g.has_fx(al, "coat"), "proteção some depois do dano")
	# expira no início da próxima ativação do Fundidor
	var g2 = novo()
	var f2 = put(g2, "t_fundidor", 0, 4, 0)
	var al2 = put(g2, "perfurador", 0, 5, 0)
	await ativa(g2, f2, [H(5, 0)])
	g2.act = null
	g2.round_no = 2
	g2.start_activation(f2)
	ok(not g2.has_fx(al2, "coat"), "expira no início da próxima ativação do Fundidor")
	# se o Fundidor sai do jogo antes, a proteção acaba
	var g3 = novo()
	var f3 = put(g3, "t_fundidor", 0, 4, 0)
	var al3 = put(g3, "perfurador", 0, 5, 0)
	await ativa(g3, f3, [H(5, 0)])
	f3.hp = 0
	f3.dying = -1
	g3.settle()
	ok(not g3.has_fx(al3, "coat"), "se o Fundidor sai do jogo, a proteção expira")
	# Sentinela
	var g4 = novo()
	var s = put(g4, "t_sentinela", 0, 4, 0)
	var a1 = put(g4, "perfurador", 0, 5, 0)
	var a2 = put(g4, "t_fundidor", 0, 3, 0)
	var longe = put(g4, "t_lanterna", 0, 4, -3)
	var ene = put(g4, "t_britadeira", 1, 6, 0)
	await ativa(g4, s, [])
	ok(g4.reduction_of(s, true) == 1 and g4.reduction_of(a1, true) == 1 and g4.reduction_of(a2, true) == 1, "Guarda Firme: -1 nela e nos aliados adjacentes")
	ok(g4.reduction_of(longe, true) == 0, "aliado longe não recebe")
	g4.act = null
	g4.round_no = 2
	g4.start_activation(s)
	ok(g4.reduction_of(a1, true) == 0, "acaba no início da próxima ativação da Sentinela")
	ene.hp = ene.hp


func _demolidor() -> void:
	print("-- Demolidor de Fendas")
	var g = novo()
	var d = put(g, "t_fendas", 0, 2, 2)
	var bar = g._make_barrier(1, H(3, 1), 4)
	var e = put(g, "t_fundidor", 1, 4, 0)
	var hp0 = e.hp
	var r = await ativa(g, d, [H(3, 1)])
	ok(r and bar.st == "dead", "Ruptura destrói barreira de 4 de Vida")
	ok(e.pos() == H(5, -1) and e.hp == hp0, "empurra 1 casa o inimigo logo atrás da barreira")
	var g2 = novo()
	var d2 = put(g2, "t_fendas", 0, 2, 2)
	var bar2 = g2._make_barrier(1, H(3, 1), 8)
	var e2 = put(g2, "t_fundidor", 1, 4, 0)
	await ativa(g2, d2, [H(3, 1)])
	ok(bar2.st == "field" and bar2.hp == 4 and e2.pos() == H(4, 0), "barreira que sobrevive não empurra ninguém")


func _sismico() -> void:
	print("-- Sísmico")
	var g = novo()
	var s = put(g, "sismico", 0, 3, 1)
	var e1 = put(g, "t_fundidor", 1, 4, 1)
	var e2 = put(g, "t_lanterna", 1, 3, 2)
	var bar = g._make_barrier(1, H(2, 1), 4)
	var h1 = e1.hp
	var h2 = e2.hp
	var r = await ativa(g, s, [])
	ok(r, "Onda Sísmica usada sem escolher alvo")
	ok(e1.hp == h1 - 1 and e2.hp == h2 - 1, "1 de dano em cada inimigo adjacente")
	ok(e1.pos() == H(5, 1) and e2.pos() == H(3, 3), "empurra cada um 1 casa para longe")
	ok(bar.hp == 2, "2 de dano em construção adjacente")
	var g2 = novo()
	var s2 = put(g2, "sismico", 0, 3, 1)
	ok(g2.ult_opts(s2).is_empty(), "sem nada adjacente a ativa não pode ser usada")


func _dinamitador() -> void:
	print("-- Dinamitador")
	var g = novo()
	var d = put(g, "t_dinamite", 0, 5, 1)
	var alvo = put(g, "t_basalto", 1, 3, 1)
	var aliado = put(g, "t_fundidor", 0, 3, 2)
	var inimigo = put(g, "t_lanterna", 1, 2, 1)
	var hp_a = alvo.hp
	var hp_al = aliado.hp
	var hp_i = inimigo.hp
	g.start_activation(d)
	await g.act_attack(d, alvo)
	ok(hp_a - alvo.hp == 2, "alvo principal sofre 2 (sem dano secundário)")
	ok(hp_al - aliado.hp == 1 and hp_i - inimigo.hp == 1, "aliado e inimigo ao redor do alvo sofrem 1")
	# Carga Temporizada
	var g2 = novo()
	var d2 = put(g2, "t_dinamite", 0, 5, 1)
	var e = put(g2, "t_basalto", 1, 4, 1)
	var ad = put(g2, "t_fundidor", 0, 4, 2)
	var r = await ativa(g2, d2, [H(4, 1)])
	ok(r, "Carga Temporizada usada")
	ok(g2.shells.any(func(sh): return sh["h"] == H(4, 1) and sh.get("kind", "") == "charge"), "carga fica marcada (visível) até detonar")
	g2.act = null
	var hpc = e.hp
	var hpa = ad.hp
	g2.round_no = 2
	await g2._shell_tick()
	ok(hpc - e.hp == 3, "3 de dano na casa da carga (perdeu %d)" % (hpc - e.hp))
	ok(hpa - ad.hp == 1, "1 de dano ao redor, aliados incluídos")
	# o Dinamitador cai e a carga permanece
	var g3 = novo()
	var d3 = put(g3, "t_dinamite", 0, 5, 1)
	var e3 = put(g3, "t_basalto", 1, 4, 1)
	await ativa(g3, d3, [H(4, 1)])
	d3.hp = 0
	d3.dying = -1
	g3.settle()
	ok(g3.shells.size() == 1, "carga permanece mesmo com o Dinamitador eliminado")
	g3.act = null
	g3.round_no = 2
	await g3._shell_tick()
	ok(e3.hp == 9, "e detona no início do próximo round (hp %d)" % e3.hp)


func _curas() -> void:
	print("-- Lanterneira e Enfermeira dos Cristais")
	var g = novo()
	var l = put(g, "t_lanterna", 0, 4, 0)
	var a = put(g, "perfurador", 0, 5, 0)
	a.hp = 3
	await ativa(g, l, [H(5, 0)])
	ok(a.hp == 5, "Lanterneira cura 2 (hp %d)" % a.hp)
	var g2 = novo()
	var l2 = put(g2, "t_lanterna", 0, 4, 0)
	var a2 = put(g2, "perfurador", 0, 5, 0)
	var cr = g2._make_barrier(Game.NEUTRAL, H(5, 1), 1)
	cr.crystal = "azul"
	a2.hp = 3
	await ativa(g2, l2, [H(5, 0)])
	ok(a2.hp == 6, "cura 3 com o aliado ao lado de um cristal (hp %d)" % a2.hp)
	var g3 = novo()
	var n = put(g3, "t_enfermeira", 0, 4, 0)
	var a3 = put(g3, "perfurador", 0, 5, 0)
	a3.hp = 2
	await ativa(g3, n, [H(5, 0)])
	ok(a3.hp == 5, "Enfermeira cura 3 (hp %d)" % a3.hp)
	var g4 = novo()
	var n4 = put(g4, "t_enfermeira", 0, 4, 0)
	var a4 = put(g4, "perfurador", 0, 5, 0)
	var cr4 = g4._make_barrier(Game.NEUTRAL, H(4, 1), 1)
	cr4.crystal = "roxo"
	a4.hp = 2
	await ativa(g4, n4, [H(5, 0)])
	ok(a4.hp == 6, "cura 4 com cristal ao lado da Enfermeira (hp %d)" % a4.hp)
	ok(cr4.st == "field", "o cristal não é consumido")
	var g5 = novo()
	var n5 = put(g5, "t_enfermeira", 0, 4, 0)
	var a5 = put(g5, "perfurador", 0, 4, -2)
	a5.hp = 8
	await ativa(g5, n5, [H(4, -2)])
	ok(a5.hp == a5.maxhp, "a vida não passa da Vida máxima")


func _cartografo() -> void:
	print("-- Cartógrafo Subterrâneo")
	var g = novo()
	var c = put(g, "t_cartografo", 0, 4, 0)
	var a = put(g, "perfurador", 0, 5, -1)
	var base = g.mov_of(a)
	await ativa(g, c, [H(5, -1)])
	ok(g.mov_of(a) == base + 1, "aliado ganha +1 de Movimento")
	ok(g.has_fx(a, "climb1"), "e pode subir 1 nível adicional")
	g.terr_map[H(6, -1)] = {"k": "plano", "h": 2}
	ok(not g.can_step(H(5, -1), H(6, -1)), "sem a rota, 2 níveis de subida não passam")
	ok(g.can_step(H(5, -1), H(6, -1), false, 1), "com a rota passam")
	g.act = null
	g.start_activation(a)
	await g.act_move(a, H(5, -3))
	ok(g.mov_of(a) == base, "o +1 vale só para o próximo movimento")


func _sniper() -> void:
	print("-- Sniper")
	var g = novo()
	var s = put(g, "t_sniper", 0, 4, 0)
	var alvo = put(g, "t_fundidor", 1, 6, -2)
	var viz = put(g, "t_lanterna", 1, 5, -2)
	var aliado = put(g, "perfurador", 0, 6, -3)
	var hp_a = alvo.hp
	var hp_v = viz.hp
	var hp_al = aliado.hp
	g.start_activation(s)
	await g.act_attack(s, alvo)
	ok(alvo.hp < hp_a, "ataque acerta o alvo")
	ok(g.has_fx(alvo, "elec"), "alvo recebe a carga elétrica")
	ok(viz.hp == hp_v, "nenhuma descarga imediata")
	g.act = null
	g.round_no = 2
	g.start_activation(alvo)
	ok(hp_v - viz.hp == 1, "início da ativação do alvo: 1 de dano no inimigo do Sniper ao lado")
	ok(aliado.hp == hp_al, "aliado do Sniper não sofre")
	ok(not g.has_fx(alvo, "elec"), "descarga única")
	# nova carga renova, sem acumular
	var g2 = novo()
	var s2 = put(g2, "t_sniper", 0, 4, 0)
	var alvo2 = put(g2, "t_basalto", 1, 6, -2)
	g2.start_activation(s2)
	await g2.act_attack(s2, alvo2)
	var n1 = alvo2.fx.filter(func(f): return f["k"] == "elec").size()
	g2.act = null
	g2.start_activation(s2)
	await g2.act_attack(s2, alvo2)
	var n2 = alvo2.fx.filter(func(f): return f["k"] == "elec").size()
	ok(n1 == 1 and n2 == 1, "uma carga por alvo (renova sem acumular)")
	ok(g2.K(s2).get("ult", "") == "", "Sniper não tem ativa própria")


func _engenheiro() -> void:
	print("-- Engenheiro de Pontes")
	var g = novo()
	var e = put(g, "t_pontes", 0, 4, 0)
	g.terr_map[H(5, 0)] = {"k": "plano", "h": 0}
	g.terr_map[H(6, 0)] = {"k": "colina", "h": 1}
	g.terr_map[H(5, 1)] = {"k": "colina", "h": 1}
	ok(g.bridge_cell_ok(H(5, 0)), "casa baixa ao lado de terreno mais alto é elegível")
	g.terr_map[H(2, 3)] = {"k": "colina", "h": 1}
	ok(not g.bridge_cell_ok(H(2, 3)), "casa de nível 1 sem terreno mais alto por perto não é elegível")
	var opts = g.bridge_opts(e)
	ok(opts.has(H(5, 0)), "Engenheiro enxerga a casa a elevar")
	var r = await ativa(g, e, [H(5, 0), null])
	ok(r and int(g.earth.get(H(5, 0), 0)) == 1, "casa elevada em 1 nível (permanente na partida)")
	ok(g.h_of(H(5, 0)) == 1, "altura da casa agora é 1")
	ok(g.unit_at(H(5, 0)) == null, "não cria objeto de ponte")


func _rei() -> Array:
	var g = novo()
	var r = put(g, "rei_mina", 0, 5, 0)
	return [g, r]


func _quebra(g: Game, c: Game.Unit) -> void:
	c.hp = 0
	c.dying = -1
	g.settle()


func _rei_barreira() -> void:
	print("-- Rei da Mina: Barreira de Valak")
	var gr = _rei()
	var g: Game = gr[0]
	var rei: Game.Unit = gr[1]
	ok(g.ult_kind(rei) == "valbarrier", "Rei tem a ativa Barreira de Valak")
	var lines = g.val_lines(rei)
	ok(not lines.is_empty(), "há linha de 5 casas livres a até 6 do Rei")
	var L = lines[0]
	var st: Vector2i = L[0]
	var ends = []
	for l2 in lines:
		if l2[0] == st:
			ends.append(l2[0] + l2[1] * 4)
	var ans = [st]
	if ends.size() > 1:
		ans.append(L[0] + L[1] * 4)
	ans.append_array([0, 1, 2, 1, 0])
	var r = await ativa(g, rei, ans)
	ok(r, "Barreira de Valak usada")
	var crs = g.units.filter(func(x): return x.crystal != "" and x.sp_owner == 0 and x.st == "field")
	ok(crs.size() == 5, "criou 5 cristais especiais (%d)" % crs.size())
	var cols = []
	for k in range(5):
		var c = g.unit_at(st + L[1] * k)
		cols.append(c.crystal if c != null else "?")
	ok(cols == ["verde", "azul", "roxo", "azul", "verde"], "cores escolhidas uma a uma: %s" % str(cols))
	ok(g.units.filter(func(x): return x.crystal != "" and x.sp_owner == 0 and x.exp == 0).size() == 5, "cristais não expiram sozinhos")
	ok(rei.ult_used and not g.can_ult(rei), "uma vez por partida")
	# sem 5 casas válidas: não pode usar e não gasta nada
	var gr2 = _rei()
	var g2: Game = gr2[0]
	var rei2: Game.Unit = gr2[1]
	for h in DB.hexes:
		if h != rei2.pos() and DB.dist(h, rei2.pos()) <= 6 and not (h.x % 2 == 0 and h.y % 2 == 0):
			g2.blocks[h] = true
	g2.start_activation(rei2)
	ok(g2.val_lines(rei2).is_empty() and not g2.can_ult(rei2) and not rei2.ult_used, "sem 5 casas válidas: não usa e não consome")


func _rei_cristais() -> void:
	print("-- Rei da Mina: cristais especiais")
	var gr = _rei()
	var g: Game = gr[0]
	var rei: Game.Unit = gr[1]
	var a = put(g, "t_basalto", 0, 3, 0)
	var e = put(g, "t_basalto", 1, 3, 2)
	a.hp = 5
	e.hp = 9
	var c = g._make_crystal(0, H(3, 1), "verde")
	_quebra(g, c)
	ok(a.hp == 7 and e.hp == 7, "verde especial: aliado +2 e inimigo -2 (%d/%d)" % [a.hp, e.hp])
	var c2 = g._make_crystal(0, H(3, 1), "azul")
	var m_a = g.mov_of(a)
	var m_e = g.mov_of(e)
	_quebra(g, c2)
	ok(g.mov_of(a) == m_a + 1 and g.mov_of(e) == m_e - 1, "azul especial: aliado +1 Mov, inimigo -1")
	var c3 = g._make_crystal(0, H(3, 1), "roxo")
	var atk_a = g.atk_of(a, null)
	var atk_e = g.atk_of(e, null)
	_quebra(g, c3)
	ok(g.atk_of(a, null) == atk_a + 2 and g.atk_of(e, null) == atk_e - 2, "roxo especial: aliado +2 ATQ, inimigo -2")
	var c4 = g._make_crystal(0, H(3, 1), "roxo")
	_quebra(g, c4)
	ok(g.atk_of(a, null) == atk_a + 2 and g.atk_of(e, null) == atk_e - 2, "roxo reaplicado renova, não acumula")
	var fxa = a.fx.filter(func(f): return f["k"] == "atk")
	ok(fxa.size() == 1 and int(fxa[0]["till"]) == g.round_no + 1, "roxo vale até o fim do próximo round")
	# cristal natural continua com o efeito do mapa
	var gr3 = _rei()
	var g3: Game = gr3[0]
	var a3 = put(g3, "t_basalto", 0, 3, 0)
	var e3 = put(g3, "t_basalto", 1, 3, 2)
	a3.hp = 5
	e3.hp = 5
	var cn = g3._make_barrier(g3.NEUTRAL, H(3, 1), 1)
	cn.crystal = "verde"
	_quebra(g3, cn)
	ok(a3.hp == 7 and e3.hp == 7, "cristal natural verde cura os dois lados")
	# cristal que o Rei mexe vira especial
	var cn2 = g3._make_barrier(g3.NEUTRAL, H(4, 1), 1)
	cn2.crystal = "roxo"
	ok(cn2.sp_owner == -1, "cristal natural começa sem dono")


func _rei_manip() -> void:
	print("-- Rei da Mina: Manipulação Mineral")
	var gr = _rei()
	var g: Game = gr[0]
	var rei: Game.Unit = gr[1]
	var c = g._make_crystal(0, H(4, 1), "verde")
	g.start_activation(rei)
	var modes = g.manip_modes(rei)
	ok(modes.has("move") and modes.has("color") and modes.has("tunnel"), "modos disponíveis: %s" % str(modes))
	# mover até 2 casas
	var dst = g.manip_dests(c)
	ok(not dst.is_empty() and dst.all(func(h): return DB.dist(h, c.pos()) <= 2), "destinos a até 2 casas")
	fila = [modes.find("move"), H(4, 1), dst[0]]
	var acts0 = g.act["actions"]
	var r = await g.act_manip(rei)
	ok(r and c.pos() == dst[0] and c.sp_owner == 0 and g.act["actions"] == acts0 - 1, "cristal movido, vira especial e custa 1 ação")
	# mudar a cor (não faz as duas coisas: o movimento já gastou a ação, a cor é outra ação)
	modes = g.manip_modes(rei)
	fila = [modes.find("color"), c.pos(), 1]
	r = await g.act_manip(rei)
	ok(r and c.crystal == "roxo" and c.sp_owner == 0, "cor trocada (verde -> roxo, 2ª opção)")
	ok(g.act["actions"] == acts0 - 2, "cada manipulação gasta 1 ação")
	# rebaixar terreno alto
	var g2: Game = _rei()[0]
	var rei2 = g2.units.filter(func(x): return x.cid == "rei_mina")[0]
	g2.earth[H(3, 1)] = 2 - g2.h_of(H(3, 1))
	g2.load_map()
	ok(g2.h_of(H(3, 1)) == 2, "terreno de teste com 2 níveis")
	g2.start_activation(rei2)
	var m2 = g2.manip_modes(rei2)
	ok(m2.has("lower"), "terreno alto pode ser rebaixado")
	fila = [m2.find("lower"), H(3, 1)]
	r = await g2.act_manip(rei2)
	var bl = g2.unit_at(H(3, 1))
	ok(r and g2.h_of(H(3, 1)) == 1 and bl != null and bl.block and bl.barrier, "rebaixou 1 nível e deixou um bloco móvel")
	ok(not g2.manip_lowerable(H(3, 1)), "casa de 1 nível não pode ser rebaixada")
	# túnel
	var g3: Game = _rei()[0]
	var rei3 = g3.units.filter(func(x): return x.cid == "rei_mina")[0]
	var al = put(g3, "t_basalto", 0, 4, 1)
	var en = put(g3, "t_basalto", 1, 4, 2)
	g3.start_activation(rei3)
	var m3 = g3.manip_modes(rei3)
	fila = [m3.find("tunnel"), H(3, 1), H(7, -2)]
	r = await g3.act_manip(rei3)
	ok(r and g3.tunnels.size() == 1 and g3.tunnel_hex(H(3, 1)) and g3.tunnel_hex(H(7, -2)), "túnel com duas entradas visíveis")
	g3.end_activation()
	g3.start_activation(al)
	al.q = 4
	al.r = 0
	ok(g3.tunnel_exits(al) == [H(7, -2)] or g3.tunnel_exits(al).has(H(7, -2)), "aliado ao lado de uma entrada pode sair pela outra")
	ok(g3.tunnel_exits(en).is_empty(), "inimigo não usa o túnel")
	fila = [H(7, -2)]
	r = await g3.act_mexit(al)
	ok(r and al.pos() == H(7, -2) and g3.act["moved"], "saída pelo túnel usa a ação de movimento")
	# saída ocupada
	var g4: Game = _rei()[0]
	var rei4 = g4.units.filter(func(x): return x.cid == "rei_mina")[0]
	var a4 = put(g4, "t_basalto", 0, 4, 0)
	put(g4, "t_basalto", 1, 7, -2)
	g4.tunnels.append({"a": H(3, 1), "b": H(7, -2), "owner": 0})
	ok(g4.tunnel_exits(a4).is_empty() or not g4.tunnel_exits(a4).has(H(7, -2)), "saída ocupada não vale")
	# arremesso de estrutura
	var g5: Game = _rei()[0]
	var rei5 = g5.units.filter(func(x): return x.cid == "rei_mina")[0]
	var e5 = put(g5, "t_basalto", 1, 4, -2)
	var a5 = put(g5, "t_basalto", 1, 3, -2)
	var st5 = g5._make_crystal(0, H(6, -1), "verde")
	g5.start_activation(rei5)
	var m5 = g5.manip_modes(rei5)
	ok(m5.has("throw"), "arremesso disponível")
	var hp_e = e5.hp
	var hp_a = a5.hp
	fila = [m5.find("throw"), H(6, -1), H(4, -2)]
	r = await g5.act_manip(rei5)
	var tm = g5.terrain_mods(rei5, e5)
	ok(r and g5.act["attacked"], "conta como o ataque do Rei")
	ok(st5.st == "dead", "estrutura destruída")
	ok(e5.hp <= hp_e - 2, "inimigo atingido (%d -> %d)" % [hp_e, e5.hp])
	ok(a5.hp == hp_a - 2, "efeito do cristal também no entorno do impacto (verde: -2 em inimigo ao lado)")

	# mapa plano (Valak): a habilidade precisa funcionar, e liga até 3 casas
	var gp = novo()
	var ep = put(gp, "t_pontes", 0, 5, 0)
	ok(gp.bridge_opts(ep).size() > 0, "no mapa plano há casas para elevar")
	var rp = await ativa(gp, ep, [H(4, 0), H(4, 1), H(3, 1)])
	ok(rp and gp.h_of(H(4, 0)) == 1 and gp.h_of(H(4, 1)) == 1 and gp.h_of(H(3, 1)) == 1, "eleva 3 casas ligadas em 1 nível")
	ok(not gp.bridge_cell_ok(H(4, 0)), "no plano, a casa não passa do nível 1")

	# mover a estrutura contra um inimigo: ele é atingido e a estrutura se destrói
	var g6: Game = _rei()[0]
	var rei6 = g6.units.filter(func(x): return x.cid == "rei_mina")[0]
	var e6 = put(g6, "t_basalto", 1, 3, 1)
	var a6 = put(g6, "t_basalto", 1, 2, 1)
	var c6 = g6._make_crystal(0, H(5, -1), "verde")
	var bl6 = g6._make_barrier(g6.NEUTRAL, H(3, -1), 4)
	bl6.block = true
	g6.start_activation(rei6)
	ok(g6.manip_dests(bl6, rei6).has(e6.pos()), "enemigo a 2 casas da estrutura é destino válido")
	var hp6 = e6.hp
	var m6 = g6.manip_modes(rei6)
	fila = [m6.find("move"), H(3, -1), H(3, 1)]
	var r6 = await g6.act_manip(rei6)
	ok(r6 and e6.hp == hp6 - 4 and bl6.st == "dead", "bloco movido contra o inimigo causa 4 e é destruído (%d -> %d)" % [hp6, e6.hp])
	ok(not g6.act["attacked"], "manipulação não gasta o ataque do Rei")
	var hp7 = e6.hp
	var ha7 = a6.hp
	var cr7 = g6._make_crystal(0, H(4, 0), "verde")
	m6 = g6.manip_modes(rei6)
	fila = [m6.find("move"), H(4, 0), H(3, 1)]
	r6 = await g6.act_manip(rei6)
	ok(r6 and cr7.st == "dead" and e6.hp <= hp7 - 4, "cristal movido contra o inimigo também o atinge")
	ok(a6.hp == ha7 - 2, "efeito do cristal especial no impacto (verde: -2 em inimigo ao lado)")

	# Dinamitador: o ataque básico passa por cima de estruturas (arremesso)
	var gd: Game = novo()
	var dn = put(gd, "t_dinamite", 0, 5, 0)
	var ed = put(gd, "t_basalto", 1, 3, 0)
	ok(gd.attack_targets(dn).has(ed), "Dinamitador acerta alvo a 2 casas em campo aberto")
	gd._make_barrier(0, H(4, 0), 4)
	ok(gd.attack_targets(dn).has(ed), "estrutura entre os dois não bloqueia o ataque do Dinamitador")
	var gk: Game = novo()
	var kk = put(gk, "t_sniper", 0, 5, 0)
	var ek = put(gk, "t_basalto", 1, 2, 0)
	gk._make_barrier(0, H(4, 0), 4)
	ok(not gk.attack_targets(kk).has(ek), "outros atacantes continuam bloqueados por estruturas")
