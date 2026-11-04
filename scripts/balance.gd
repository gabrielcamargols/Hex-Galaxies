extends Node
## Teste de balanceamento: CPU contra CPU em todos os confrontos de facção, nos dois mapas.
## godot --headless --path . -- --balance=N out=/caminho/resultado.json [maps=tarhut,posto]
## N = partidas por confronto (cada par joga N vezes em cada mapa, alternando o lado).
## only=MIX testa exércitos do modo Mix contra cada facção.

var results: Array = []


func run(n: int, out_path: String, maps: Array, only: String = "") -> void:
	var facs = DB.factions.keys()
	if only == "MIX":
		facs.append("MIX")
	var total = 0
	var t0 = Time.get_ticks_msec()
	for mp in maps:
		for a in facs:
			for b in facs:
				if a == b or (only != "" and a != only and b != only):
					continue
				for k in range(n):
					var r = await play(a, b, mp)
					results.append(r)
					total += 1
		print("mapa %s: %d partidas (%.0f s)" % [mp, total, (Time.get_ticks_msec() - t0) / 1000.0])
	var f = FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(results))
	f.close()
	print("BALANCE FIM ", total)


func _side(p: int, fac: String) -> Dictionary:
	var s = AI.setup_mix() if fac == "MIX" else AI.setup(fac)
	var tough = s["picks"].duplicate()
	tough.sort_custom(func(x, y): return int(DB.cards[x]["int"]) > int(DB.cards[y]["int"]))
	var spots = DB.entry[p]
	s["start"] = [{"id": tough[0], "h": spots[0]}, {"id": tough[1], "h": spots[spots.size() - 1]}]
	return s


func play(fa: String, fb: String, mp: String) -> Dictionary:
	DB.set_map(mp)
	var g = Game.new()
	g.tree = null
	g.pace_time = 0.0
	g.cpu = [true, true]
	g.setup([_side(0, fa), _side(1, fb)], mp)
	var dmg = [0, 0]
	var kills = [0, 0]
	g.fx_event.connect(func(e):
		if e["t"] == "dmg":
			var u = g.by_uid(e["uid"])
			if u != null:
				dmg[1 - u.owner] += int(e["amt"])
		elif e["t"] == "die":
			var u2 = g.by_uid(e["uid"])
			if u2 != null and not u2.barrier:
				kills[1 - u2.owner] += 1)
	await g.begin_game()
	var guard = 0
	while g.winner == Game.NONE and guard < 2000:
		await AI.activation(g, g.cur)
		guard += 1
	var ults = [false, false]
	var cmd_hp = [0, 0]
	for p in range(2):
		var c = g.commander(p)
		if c != null:
			ults[p] = c.ult_used
			cmd_hp[p] = max(0, c.hp)
	var units = []
	for u in g.units:
		if not u.barrier and not u.is_cmd:
			units.append({"id": u.cid, "p": u.owner, "alive": u.st != "dead", "hp": max(0, u.hp), "max": u.maxhp, "kills": u.kills, "st": u.st})
	var tacs = [{}, {}]
	for l in g.logs:
		if l["text"].begins_with("Tática: ") and l["p"] >= 0:
			var nm = l["text"].substr(8).trim_suffix(".")
			tacs[l["p"]][nm] = tacs[l["p"]].get(nm, 0) + 1
	return {"a": fa, "b": fb, "map": mp, "first": g.first, "winner": g.winner, "round": g.round_no,
		"by_score": not g.final_score.is_empty(), "ults": ults, "cmd_hp": cmd_hp, "dmg": dmg, "kills": kills,
		"units": units, "tactics": tacs}
