extends Node
## Carrinho como cobertura móvel: godot --headless --path . -- --teste=carrinho

var falhas := 0


func ok(c: bool, msg: String) -> void:
	print(("  ok    " if c else "  FALHA ") + msg)
	if not c:
		falhas += 1


func put(g: Game, cid: String, p: int, h: Vector2i) -> Game.Unit:
	var u = g._mk(cid, p, "field")
	u.q = h.x
	u.r = h.y
	return u


func run() -> void:
	print("== Carrinho: cobertura móvel ==")
	DB.troca_padrao = false
	DB.modo_padrao = ""
	DB.set_map("posto")
	var g = Game.new()
	g.tree = null
	g.pace_time = 0.0
	g.cpu = [false, false]
	g.setup([{"fac": "KRI", "picks": [], "start": []}, {"fac": "WAC", "picks": [], "start": []}], "posto")
	# campo limpo: um trilho reto e um carrinho
	g.units = g.units.filter(func(x): return not x.barrier)
	var tr = [Vector2i(-4, 2), Vector2i(-3, 2), Vector2i(-2, 2), Vector2i(-1, 2), Vector2i(0, 2)]
	g.tracks = [tr]
	g.track_loop = [false]
	g.carts = [{"h": Vector2i(-3, 2), "track": 0}]
	var atir = put(g, "k_sniper", 0, Vector2i(-3, 0))
	var alvo = put(g, "w_urso", 1, Vector2i(-3, 3))
	ok(not g.los(atir.pos(), alvo.pos()), "carrinho parado no meio bloqueia o tiro")
	var lado = put(g, "w_alce", 1, Vector2i(-2, 3))
	var atir2 = put(g, "k_front", 0, Vector2i(-2, 0))
	g.carts[0]["h"] = Vector2i(-2, 2)
	var tm = g.terrain_mods(atir2, lado)
	ok(int(tm["cover"]) == DB.COVER_DMG, "carrinho ao lado do alvo, do lado do atirador, dá abrigo (-%d)" % DB.COVER_DMG)
	g.carts[0]["h"] = Vector2i(0, 2)
	tm = g.terrain_mods(atir2, lado)
	ok(int(tm["cover"]) == 0 or g.unit_at(Vector2i(-1, 2)) != null, "carrinho empurrado para longe: o abrigo some")
	ok(g.los(atir.pos(), alvo.pos()), "sem o carrinho no caminho, o tiro passa")
	print("TESTE FIM falhas=%d" % falhas)
	get_tree().quit()
