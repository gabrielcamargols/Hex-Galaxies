class_name AI
extends RefCounted
## CPU: escolhe peça, movimento, ataque e cartas por pontuação simples.


static func value(t) -> float:
	if t.is_cmd:
		return 30.0
	if t.barrier:
		return 1.0
	return 6.0 + int(DB.cards[t.cid]["atk"])


static func dmg_on(g, a, t, fpos = null) -> int:
	return g.preview_damage(a, t, fpos)["dmg"]


static func attack_score(g, a, t, fpos = null) -> float:
	var d = dmg_on(g, a, t, fpos)
	if d <= 0:
		return 0.1
	var kill = d >= t.hp
	return d * (3.0 if t.is_cmd else 1.0) + (value(t) if kill else 0.0) + (-3.0 if t.barrier else 0.0)


static func best_attack_from(g, a, fpos = null) -> Variant:
	var best: Variant = null
	for t in g.attack_targets(a, fpos):
		var s = attack_score(g, a, t, fpos)
		if best == null or s > best["s"]:
			best = {"s": s, "t": t}
	return best


static func threat(g, u, h: Vector2i) -> float:
	var s = 0.0
	for e in g.enemies_of(u):
		if e.barrier:
			continue
		if DB.dist(e.pos(), h) <= g.mov_of(e) + g.alc_of(e):
			s += g.atk_of(e, null)
	return s


static func pos_score(g, u, h: Vector2i) -> float:
	var en = g.enemies_of(u).filter(func(e): return not e.barrier)
	var ecmd = g.commander(1 - u.owner)
	var d = 99
	for e in en:
		d = min(d, DB.dist(h, e.pos()))
	var ranged = g.alc_of(u) >= 2
	var s = 0.0
	if not en.is_empty():
		s -= (abs(d - g.alc_of(u)) * 1.2) if ranged else d * 1.5
	else:
		var goal = ecmd.pos() if ecmd.st == "field" else DB.entry_c[1 - u.owner]
		s -= DB.dist(h, goal) * 0.8
	if ecmd.st == "field":
		s -= DB.dist(h, ecmd.pos()) * 0.6
	var o = DB.obj_at(h)
	if o != null and not g.P[u.owner]["obj_used"].has(o["id"]):
		s += 1.5
	s += g.h_of(h) * (0.9 if ranged else 0.4)
	if g.res.has(h):
		s += 1.2
	if g.tremors.has(h):
		s -= 9.0
	elif g.tremors.any(func(x): return DB.dist(x, h) == 1):
		s -= 2.5
	for c in DB.nbrs(h):
		if g.tt_of(g.terr(c)["k"]).get("cover", 0):
			s += 0.6 if ranged else 0.2
			break
	if g.tt_of(g.terr(h)["k"]).get("forest", 0):
		s += 0.3
	var th = threat(g, u, h)
	s -= th * (0.9 if u.is_cmd else (0.35 if ranged or u.hp <= 5 else 0.12))
	return s


static func unit_plan_score(g, u) -> float:
	var best = 0.5
	var now = best_attack_from(g, u)
	if now != null:
		best = max(best, now["s"] + 1.0)
	if not g.rooted(u):
		for m in g.move_opts(u, g.mov_of(u)):
			var b = best_attack_from(g, u, m["h"])
			if b != null:
				best = max(best, b["s"])
	if u.is_cmd and g.round_no < 6:
		best -= 1.0
	return best


static func activation(g, p: int) -> void:
	var mine = g.field().filter(func(u): return u.owner == p and not u.barrier and not u.activated)
	var rs = g.reserve_of(p)
	var spots = g.deploy_hexes(p)
	var best: Variant = null
	for u in mine:
		var s = unit_plan_score(g, u)
		if best == null or s > best["s"]:
			best = {"s": s, "u": u}
	var on_field = g.field().filter(func(u): return u.owner == p and not u.barrier and not u.is_cmd).size()
	if not rs.is_empty() and not spots.is_empty() and (best == null or on_field < 3 or best["s"] < 2.0):
		rs.sort_custom(func(a, b): return (int(DB.cards[a.cid]["atk"]) + int(DB.cards[a.cid]["int"]) / 2.0) > (int(DB.cards[b.cid]["atk"]) + int(DB.cards[b.cid]["int"]) / 2.0))
		var r = rs[0]
		var en = g.enemies_of(r)
		var tgt = en[0].pos() if not en.is_empty() else DB.entry_c[1 - p]
		spots.sort_custom(func(a, b): return DB.dist(a, tgt) < DB.dist(b, tgt))
		await g.deploy(r, spots[0])
		if g.winner == Game.NONE:
			await run(g, r)
		return
	if best != null:
		g.start_activation(best["u"])
		await run(g, best["u"])
		return
	await g.pass_turn(p)


static func run(g, u) -> void:
	var p = u.owner
	for guard in range(8):
		if g.act == null or g.winner != Game.NONE or u.st != "field":
			break
		var A = g.act
		if not A["tactic"]:
			var hand = g.P[p]["hand"]
			if hand.has("reparo") and u.maxhp - u.hp >= 4 and g.tactic_playable(p, "reparo") and best_attack_from(g, u) == null:
				await g.play_tactic(p, "reparo")
				continue
			var nt = new_tactic(g, u, hand, A)
			if nt != "":
				await g.play_tactic(p, nt)
				continue
			var ba = best_attack_from(g, u) if g.can_attack_now(u) else null
			if ba != null and hand.has("fogo") and g.tactic_playable(p, "fogo") and A["actions"] >= 2:
				var d = dmg_on(g, u, ba["t"])
				if (d < ba["t"].hp and d + 2 >= ba["t"].hp) or ba["t"].is_cmd:
					await g.play_tactic(p, "fogo")
					continue
		if A["actions"] <= 0:
			break
		if g.can_ult(u):
			var need = {"abyss": 7.0, "bombard": 4.0, "prison": 7.0, "stampede": 3.0, "orbital": 5.0, "earth": 3.0}
			var kind_u = g.ult_kind(u)
			if need.has(kind_u):
				var bs = -1e9
				for h in g.ult_opts(u):
					bs = max(bs, g.ult_score(u, h))
				if bs >= need[kind_u]:
					await g.act_ult(u)
					continue
		if g.can_attack_now(u):
			var b = best_attack_from(g, u)
			if b != null and b["s"] > 0.5:
				await g.act_attack(u, b["t"])
				continue
		if g.can_collect(u) and not (g.can_attack_now(u) and best_attack_from(g, u) != null):
			await g.act_collect(u)
			continue
		if g.can_interact(u):
			await g.act_interact(u)
			continue
		if not g.rooted(u) and not A["moved"]:
			var kind = g.K(u).get("action", "")
			var opts = []
			if kind == "tunnel":
				for h in g.tunnel_opts(u):
					opts.append({"h": h, "c": 1})
			else:
				opts = g.move_opts(u, g.mov_of(u))
			var here = pos_score(g, u, u.pos()) + (4.0 if g.can_attack_any(u) and best_attack_from(g, u) != null else 0.0)
			var bm: Variant = null
			for m in opts:
				var s = pos_score(g, u, m["h"])
				if g.can_attack_any(u) and (A["actions"] >= 2 or kind == "moveAttack"):
					var b2 = best_attack_from(g, u, m["h"])
					if b2 != null:
						s += 4.0 + b2["s"]
				if bm == null or s > bm["s"]:
					bm = {"s": s, "h": m["h"]}
			if bm != null and bm["s"] > here + 0.4:
				if kind == "moveAttack" and g.can_attack_any(u):
					var b3 = best_attack_from(g, u, bm["h"])
					await g.act_move_attack(u, bm["h"], b3["t"] if b3 != null else null)
					continue
				if kind == "tunnel":
					await g.act_tunnel(u, bm["h"])
					continue
				await g.act_move(u, bm["h"])
				continue
		if not A["tactic"] and A["actions"] >= 1 and u.eq == "":
			for eqc in ["placas", "propulsor", "lente"]:
				if g.P[p]["hand"].has(eqc) and g.tactic_playable(p, eqc):
					await g.play_tactic(p, eqc)
					break
			if A["tactic"]:
				continue
		break
	if g.act != null and g.winner == Game.NONE:
		await g.end_activation()


# quando vale a pena usar as táticas novas
static func new_tactic(g, u, hand: Array, A: Dictionary) -> String:
	var p = u.owner
	var en = g.enemies_of(u).filter(func(x): return not x.barrier)
	for id in hand:
		if not g.tactic_playable(p, id):
			continue
		match id:
			"orbital":
				if A["actions"] >= 2:
					for e in en:
						if DB.dist(e.pos(), u.pos()) <= 5 and (e.hp <= 3 or e.is_cmd):
							return id
			"granada":
				for h in g.granada_opts(u):
					var n = en.filter(func(x): return DB.dist(x.pos(), h) <= 1).size()
					if n >= 2 or en.any(func(x): return DB.dist(x.pos(), h) <= 1 and x.hp == 1):
						return id
			"kit":
				var miss = 0
				for x in g.allies_of(u, true):
					if not x.barrier and DB.dist(x.pos(), u.pos()) <= 2:
						miss += min(2, x.maxhp - x.hp)
				if miss >= 4:
					return id
			"camuflagem":
				if u.hp <= u.maxhp / 2 and en.any(func(x): return DB.dist(x.pos(), u.pos()) <= 3):
					return id
			"onda":
				if en.filter(func(x): return DB.dist(x.pos(), u.pos()) == 1).size() >= 2 and g.alc_of(u) >= 2:
					return id
			"sinalizador":
				if g.can_attack_now(u) and best_attack_from(g, u) != null:
					return id
			"adrenalina":
				if u.hp >= 5 and A["actions"] == 1 and g.can_attack_any(u):
					return id
			"barreira":
				if u.hp <= u.maxhp / 2 and en.any(func(x): return DB.dist(x.pos(), u.pos()) <= 2):
					return id
			"gancho":
				if g.alc_of(u) == 1 and A["actions"] >= 2 and not g.gancho_targets(u).is_empty():
					return id
			"ultimo":
				if g.can_attack_now(u) and best_attack_from(g, u) != null:
					return id
			"execucao":
				return id
			"evacuacao":
				var ev = g.evac_unit(p)
				if ev != null and int(DB.cards[ev.cid]["int"]) >= 7:
					return id
			"contra":
				return id
			"interceptar":
				if A["actions"] >= 2 or not g.can_attack_any(u):
					return id
			"grito":
				if g.field_count(p) >= 3 and g.can_attack_any(u):
					return id
			"rede":
				for e in g.rede_targets(u):
					if e.is_cmd or (g.alc_of(e) == 1 and DB.dist(e.pos(), u.pos()) <= 3):
						return id
			"resgate":
				if u.hp <= u.maxhp / 3 and en.any(func(x): return DB.dist(x.pos(), u.pos()) <= 2):
					for x in g.allies_of(u):
						if not x.barrier and DB.dist(x.pos(), u.pos()) <= 4 and x.hp >= 6:
							return id
	return ""


static func answer(g, p: int, q: Dictionary) -> Variant:
	match q["t"]:
		"yesno":
			if q.get("kind", "") == "mulligan":
				for c in q["show"]:
					if ["fogo", "placas", "reparo", "cobertura", "escudo"].has(c):
						return false
				return true
			if q.get("kind", "") == "balu":
				var t = g.by_uid(q["target"])
				var b = g.by_uid(q["guard"])
				return (q["packet"] >= t.hp and b.hp > q["packet"] + 1) or (t.is_cmd and b.hp > q["packet"])
			if q.get("kind", "") == "reforco":
				return true
			if q.get("kind", "") == "revide":
				return true
			if q.get("kind", "") == "charge" or q.get("kind", "") == "rally":
				return true
			if q.get("kind", "") == "earth":
				var eu = g.unit_at(q["h"])
				return eu != null and eu.owner == p
			return false
		"card":
			if q.get("kind", "") == "equip":
				return "placas"
			if q.get("kind", "") == "reaction":
				var t2 = g.by_uid(q["target"])
				if q["packet"] >= 3 or (t2 != null and t2.hp <= q["packet"]):
					return q["opts"][0]
				return null
			var pri = ["quantica", "resgate", "dados", "interceptar", "contra", "avanco", "troca", "pulso", "flanquear", "gancho", "onda", "adrenalina", "sinalizador", "lente", "propulsor", "barreira", "retirada", "dispersao", "reforco", "camuflagem", "escudo", "cobertura", "revide", "rede", "grito", "kit", "granada", "ultimo", "execucao", "evacuacao", "reparo", "placas", "fogo", "orbital"]
			var best = q["opts"][0]
			for c in q["opts"]:
				if pri.find(c) < pri.find(best):
					best = c
			return best
		"peek":
			return "keep" if ["fogo", "placas", "reparo", "cobertura", "escudo"].has(q["card"]) else "bottom"
		"show":
			return true
		"choice":
			# Zaboo: toca o primeiro disco (ATQ) quando dá, senão a cura
			return 0
		"unitlist":
			return q["opts"][0]
		"hex":
			var opts = q["opts"]
			var kind = q.get("kind", "")
			if q.get("optional", false) and q.has("card"):
				return null
			var best_h = opts[0]
			var bs = -1e9
			for h in opts:
				var s = 0.0
				var t3 = g.unit_at(h)
				match kind:
					"ult":
						var cu = g.active_unit()
						s = g.ult_score(cu if cu != null else g.commander(p), h)
					"enemy":
						s = ((50.0 if t3.is_cmd else 0.0) + 20.0 - t3.hp) if t3 != null else 0.0
					"blast":
						for e in g.field():
							if DB.dist(e.pos(), h) <= 1 and not e.barrier:
								s += (3.0 + (2.0 if e.hp == 1 else 0.0)) if e.owner != p else -4.0
					"ally":
						s = ((t3.maxhp - t3.hp) + (3.0 if t3.is_cmd else 0.0)) if t3 != null else 0.0
					"place":
						var dmin = 9
						for e in g.enemies_of(g.commander(p)):
							dmin = min(dmin, DB.dist(e.pos(), h))
						s = -dmin
					"move":
						var au = g.active_unit()
						if q.get("optional", false) and au != null and g.alc_of(au) == 1 and au.hp > 4:
							return null
						s = -threat(g, au if au != null else g.commander(p), h)
				if s > bs:
					bs = s
					best_h = h
			return best_h
	return null


# modo Mix: comandante e tropas de qualquer facção
static func setup_mix() -> Dictionary:
	var cmds = []
	for f in DB.factions.keys():
		cmds.append(DB.factions[f]["cmd"])
	var cmd = cmds[randi() % cmds.size()]
	var pool = DB.card_list.filter(func(c): return not c.get("cmd", false))
	pool.shuffle()
	var picks = []
	var needs = [func(c): return int(c["alc"]) >= 2, func(c): return int(c["int"]) >= 10, func(_c): return true, func(_c): return true, func(_c): return true]
	for f in needs:
		for c in pool:
			if f.call(c) and not picks.has(c["id"]):
				picks.append(c["id"])
				break
	return {"fac": DB.cards[cmd]["f"], "cmd": cmd, "mix": true, "picks": picks}


static func setup(fac: String) -> Dictionary:
	var pool = DB.card_list.filter(func(c): return c["f"] == fac and not c.get("cmd", false))
	pool.shuffle()
	var picks = []
	var needs = [func(c): return int(c["alc"]) >= 2, func(c): return int(c["int"]) >= 10, func(_c): return true, func(_c): return true, func(_c): return true]
	for f in needs:
		for c in pool:
			if f.call(c) and not picks.has(c["id"]):
				picks.append(c["id"])
				break
	return {"fac": fac, "picks": picks}
