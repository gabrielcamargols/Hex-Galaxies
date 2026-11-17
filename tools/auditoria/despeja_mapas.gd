extends Node
## auditoria de mapas: despeja terreno, passos, linhas de tiro e casas especiais em JSON
func _ready():
	for mid in ["posto", "tarhut", "abnara", "goraida"]:
		DB.set_map(mid)
		var g = Game.new()
		g.tree = null
		g.pace_time = 0.0
		g.cpu = [false, false]
		g.setup([{"fac": "ZUK", "picks": [], "start": []}, {"fac": "ZUK", "picks": [], "start": []}], mid)
		g._gen_crystals()
		var occ = {}
		for u in g.units:
			if u.st == "field" and u.barrier:
				occ[u.pos()] = u.crystal if u.crystal != "" else "barreira"
		var hx = []
		var edges = []
		for h in DB.hexes:
			var t = g.terr(h)
			var tt = g.tt_of(t["k"])
			var passa = not g.blocks.has(h) and not occ.has(h) and int(tt.get("pass", 0)) == 1
			hx.append({"q": h.x, "r": h.y, "k": t["k"], "h": int(t["h"]), "top": g.top_of(h), "pass": passa,
				"cover": int(tt.get("cover", 0)) == 1 or occ.has(h), "forest": int(tt.get("forest", 0)) == 1, "brush": int(tt.get("brush", 0)) == 1,
				"cost": int(tt.get("c", 1)), "occ": occ.get(h, ""), "sink": int(tt.get("sink", 0)) == 1, "safe": int(tt.get("safe", 0)) == 1})
			if passa:
				for m in DB.nbrs(h):
					if DB.in_board(m) and not g.blocks.has(m) and not occ.has(m) and g.can_step(h, m, false, 0):
						edges.append([h.x, h.y, m.x, m.y, g.step_cost(h, m, false)])
		# linhas de tiro longas (5 a 8 casas) entre casas onde se pode ficar
		var pas = DB.hexes.filter(func(h): return not g.blocks.has(h) and not occ.has(h))
		var los = []
		for i in range(pas.size()):
			for j in range(i + 1, pas.size()):
				var d = DB.dist(pas[i], pas[j])
				if d >= 5 and d <= 8 and g.los(pas[i], pas[j]):
					los.append([pas[i].x, pas[i].y, pas[j].x, pas[j].y, d])
		var out = {"map": mid, "entry": [[DB.entry_c[0].x, DB.entry_c[0].y], [DB.entry_c[1].x, DB.entry_c[1].y]],
			"cores": DB.maps[mid].get("cores", []), "hex_scale": DB.maps[mid].get("hex_scale", 1.0), "hexes": hx, "edges": edges, "los": los,
			"deploy0": g.deploy_hexes(0).map(func(h): return [h.x, h.y]), "deploy1": g.deploy_hexes(1).map(func(h): return [h.x, h.y])}
		var f = FileAccess.open("user://auditoria_mapa_%s.json" % mid, FileAccess.WRITE)
		f.store_string(JSON.stringify(out))
		f.close()
		print("mapa ", mid, " casas ", hx.size(), " arestas ", edges.size(), " tiros ", los.size())
	get_tree().quit()
