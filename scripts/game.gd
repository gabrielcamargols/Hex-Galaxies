class_name Game
extends RefCounted
## Motor de regras do Hex Galaxies (HEX 0.3 adaptado): 2 ações por turno, relevo, Tarhut e Posto.

signal question(p, q)      # o motor pergunta algo ao jogador humano
signal answered(v)         # a interface responde
signal changed             # o estado mudou: redesenhar
signal fx_event(e)         # efeitos visuais (dano, cura, dunas, vermes...)

const DUNE_EVERY = 5
const WORM_EVERY = 3
const HOLE_ROUNDS = 2
const HOLE_DMG = 4
const FALL_DMG = 1
const NONE = -1
const DRAW = 2


class Unit:
	var uid: int = 0
	var cid: String = ""
	var owner: int = 0
	var st: String = "reserve"   # field, reserve, off, dead
	var q: int = 0
	var r: int = 0
	var hp: int = 1
	var maxhp: int = 1
	var eq: String = ""
	var fx: Array = []
	var mare_used: bool = false
	var first_used: bool = false
	var kills: int = 0
	var hit_round: int = 0
	var phoenix_used: bool = false
	var activated: bool = false
	var rappy_round: int = 0
	var barrier: bool = false
	var is_cmd: bool = false
	var ult_used: bool = false
	var dying: Variant = null

	func pos() -> Vector2i:
		return Vector2i(q, r)


var round_no: int = 0
var first: int = 0
var cur: int = 0
var P: Array = []
var units: Array = []
var mines: Array = []
var pending: Array = []
var act: Variant = null            # Dictionary da ativação atual
var winner: int = NONE
var logs: Array = []
var next_uid: int = 1
var cpu: Array = [false, true]
var map_id: String = "tarhut"
var map_name: String = ""
var dune: int = 0
var dune_next: int = -1
var holes: Array = []
var tremors: Array = []
var res: Dictionary = {}  # Vector2i -> tipo
var final_score: Dictionary = {}
var terr_map: Dictionary = {}
var blocks: Dictionary = {}
var plain: Dictionary = {"k": "plano", "h": 0}
var terr_ver: int = 0
var earth: Dictionary = {}  # Vector2i -> ajuste de altura (Erguer a Terra)
var tree: SceneTree = null
var pace_time: float = 0.28
var fallen: Array = []  # uids dos personagens derrotados, em ordem
var guard_round: Dictionary = {}  # uid -> round em que já protegeu (guardOnce)


# ================= montagem =================
func setup(sides: Array, mid: String) -> void:
	# sides: [{fac, picks:[5 ids], start:[{id, h:Vector2i}]}, x2]
	map_id = mid
	DB.set_map(map_id)
	var def = DB.maps[map_id]
	if def.has("dunes"):
		dune = randi() % def["dunes"].size()
	if def.has("res"):
		for rr in def["res"]:
			res[Vector2i(rr[0], rr[1])] = rr[2]
			res[Vector2i(-rr[0], -rr[1])] = rr[2]
	load_map()
	for p in range(2):
		var s = sides[p]
		var deck = DB.tactic_ids.duplicate()
		deck.shuffle()
		P.append({"fac": s["fac"], "deck": deck, "hand": [], "discard": [], "passed": false, "obj_used": {}, "discount": false})
		_mk(DB.factions[s["fac"]]["cmd"], p, "off")
		for id in s["picks"]:
			var u = _mk(id, p, "reserve")
			for st in s["start"]:
				if st["id"] == id:
					u.st = "field"
					u.q = st["h"].x
					u.r = st["h"].y


func _mk(cid: String, p: int, st: String) -> Unit:
	var c = DB.cards[cid]
	var u = Unit.new()
	u.uid = next_uid
	next_uid += 1
	u.cid = cid
	u.owner = p
	u.st = st
	u.hp = int(c["int"])
	u.maxhp = int(c["int"])
	u.is_cmd = c.get("cmd", false) == true
	units.append(u)
	return u


# ================= mapa =================
func load_map() -> void:
	var def = DB.maps[map_id]
	map_name = def["name"]
	plain = {"k": def["plain"], "h": 0}
	terr_map = {}
	for e in def["half"]:
		terr_map[Vector2i(e[0], e[1])] = {"k": e[2], "h": e[3]}
		terr_map[Vector2i(-e[0], -e[1])] = {"k": e[2], "h": e[3]}
	if def.has("dunes"):
		var dh = dune_heights(dune)
		for h in dh.keys():
			if not terr_map.has(h):
				terr_map[h] = {"k": "duna", "h": dh[h]}
	for b in holes:
		terr_map[b["h"]] = {"k": "buraco", "h": 0}
	for eh in earth.keys():
		var base_t = terr_map.get(eh, plain)
		terr_map[eh] = {"k": base_t["k"], "h": clampi(int(base_t["h"]) + int(earth[eh]), 0, 3)}
	blocks = {}
	for h in terr_map.keys():
		if not tt_of(terr_map[h]["k"]).get("pass", 0):
			blocks[h] = true
	terr_ver += 1


func dune_heights(idx: int) -> Dictionary:
	var def = DB.maps[map_id]
	var out = {}
	if not def.has("dunes"):
		return out
	var base = {}
	for e in def["half"]:
		base[Vector2i(e[0], e[1])] = true
		base[Vector2i(-e[0], -e[1])] = true
	for pk in def["dunes"][idx]["peaks"]:
		var hh = int(pk[2])
		for c in [Vector2i(pk[0], pk[1]), Vector2i(-pk[0], -pk[1])]:
			_put_dune(out, base, c, hh)
			if hh >= 2:
				for n in DB.nbrs(c):
					_put_dune(out, base, n, hh - 1)
	return out


func _put_dune(out: Dictionary, base: Dictionary, h: Vector2i, v: int) -> void:
	if not DB.in_board(h) or base.has(h) or DB.in_entry(0, h) or DB.in_entry(1, h):
		return
	out[h] = max(out.get(h, 0), v)


func tt_of(k: String) -> Dictionary:
	return DB.tt[k]


func terr(h: Vector2i) -> Dictionary:
	return terr_map.get(h, plain)


func h_of(h: Vector2i) -> int:
	return int(terr(h)["h"])


# altura onde a peça fica de pé (no topo do obstáculo, para quem escala)
func stand_h(h: Vector2i) -> int:
	if blocks.has(h) and terr(h)["k"] != "buraco":
		return h_of(h) + int(tt_of(terr(h)["k"]).get("top", 0))
	return h_of(h)


func can_step(a: Vector2i, b: Vector2i, climber: bool = false) -> bool:
	var ta = terr(a)
	var tb = terr(b)
	if climber:
		return tb["k"] != "buraco"
	if not tt_of(tb["k"]).get("pass", 0):
		return false
	var dh = int(tb["h"]) - int(ta["h"])
	if abs(dh) >= 2:
		return false
	if dh == 1 and not (tt_of(tb["k"]).get("climb", 0) or ta["k"] == "rampa"):
		return false
	return true


func step_cost(a: Vector2i, b: Vector2i, climber: bool = false) -> int:
	if climber:
		return max(1, int(tt_of(terr(b)["k"])["c"])) + max(0, stand_h(b) - stand_h(a))
	return int(tt_of(terr(b)["k"])["c"]) + max(0, h_of(b) - h_of(a)) + (2 if tt_of(terr(a)["k"]).get("sink", 0) else 0)


func home_half(p: int, h: Vector2i) -> bool:
	return DB.dist(h, DB.entry_c[p]) < DB.dist(h, DB.entry_c[1 - p])


# ================= consultas =================
func field() -> Array:
	return units.filter(func(u): return u.st == "field")


func unit_at(h: Vector2i) -> Variant:
	for u in units:
		if u.st == "field" and u.q == h.x and u.r == h.y:
			return u
	return null


func by_uid(id: int) -> Variant:
	for u in units:
		if u.uid == id:
			return u
	return null


func barrier_at(h: Vector2i) -> bool:
	for u in units:
		if u.barrier and u.st == "field" and u.q == h.x and u.r == h.y:
			return true
	return false


func top_of(h: Vector2i) -> int:
	return h_of(h) + max(int(tt_of(terr(h)["k"]).get("top", 0)), 2 if barrier_at(h) else 0)


func is_free(h: Vector2i) -> bool:
	return DB.in_board(h) and not blocks.has(h) and unit_at(h) == null


func adj_free(h: Vector2i) -> Array:
	return DB.nbrs(h).filter(func(n): return is_free(n))


func step_free(h: Vector2i) -> Array:
	return DB.nbrs(h).filter(func(n): return is_free(n) and can_step(h, n))


func enemies_of(u) -> Array:
	return field().filter(func(x): return x.owner != u.owner)


func allies_of(u, inc_self: bool = false) -> Array:
	return field().filter(func(x): return x.owner == u.owner and not x.barrier and (inc_self or x != u))


func commander(p: int) -> Variant:
	for u in units:
		if u.owner == p and u.is_cmd:
			return u
	return null


func silenced(u) -> bool:
	for f in u.fx:
		if f["k"] == "silence":
			return true
	return false


func K(u) -> Dictionary:
	if u.barrier or silenced(u):
		return {}
	return DB.cards[u.cid]["k"]


func fx_sum(u, k: String) -> int:
	var s = 0
	for f in u.fx:
		if f["k"] == k:
			s += int(f.get("v", 0))
	return s


func has_fx(u, k: String) -> bool:
	for f in u.fx:
		if f["k"] == k:
			return true
	return false


func imprisoned(u) -> bool:
	for f in u.fx:
		if f["k"] == "prison" and int(f["end"]) >= round_no:
			return true
	return false


func rooted(u) -> bool:
	for f in u.fx:
		if f["k"] == "root" and int(f["end"]) >= round_no:
			return true
	return false


func match_who(u, who) -> bool:
	if who == null or who == "":
		return true
	if u.barrier:
		return false
	var c = DB.cards[u.cid]
	return c["f"] == who or c.get("clan", "") == who


func terra_on(p: int) -> bool:
	var c = commander(p)
	return c != null and c.st != "dead" and c.cid == "rei_mina"


func nm(u) -> String:
	return "Barreira" if u.barrier else DB.cards[u.cid]["name"]


func mov_of(u) -> int:
	return int(DB.cards[u.cid]["mov"]) + (1 if u.eq == "propulsor" else 0)


func alc_of(u) -> int:
	return int(DB.cards[u.cid]["alc"]) + (1 if u.eq == "lente" else 0)


func cmd_point(c) -> Vector2i:
	return c.pos() if c.st == "field" else DB.entry_c[c.owner]


func log_msg(p: int, text: String) -> void:
	logs.append({"p": p, "text": text, "round": round_no})


func emitfx(e: Dictionary) -> void:
	fx_event.emit(e)


# efeito visual de habilidade (flipbook 2.5D): k = tipo, h = casa, uid = quem usou
func abfx(k: String, h: Vector2i, uid: int = -1) -> void:
	emitfx({"t": "abfx", "k": k, "h": h, "uid": uid})


func pace() -> void:
	changed.emit()
	if tree != null:
		await tree.create_timer(pace_time).timeout


func ask(p: int, q: Dictionary) -> Variant:
	if cpu[p]:
		return AI.answer(self, p, q)
	question.emit(p, q)
	var v = await answered
	return v


func pick_hex(p: int, text: String, opts: Array, kind: String, optional: bool = false) -> Variant:
	if opts.is_empty():
		return null
	var hs = []
	for o in opts:
		hs.append(o if o is Vector2i else o.pos())
	var h = await ask(p, {"t": "hex", "text": text, "opts": hs, "optional": optional, "kind": kind})
	if h == null and not optional:
		return hs[0]
	return h


# ================= ataque: valores =================
func atk_of(a, t) -> int:
	if a.barrier:
		return 0
	var c = DB.cards[a.cid]
	var k = K(a)
	var v = int(c["atk"]) + fx_sum(a, "atk")
	if k.has("killGrow"):
		v += min(a.kills, int(k["killGrow"]))
	var cm = commander(a.owner)
	if cm != null and cm != a and cm.st != "dead" and not silenced(cm):
		var ka = DB.cards[cm.cid]["k"].get("auraAtk", null)
		if ka != null and match_who(a, ka.get("who", "")) and DB.dist(a.pos(), cmd_point(cm)) <= int(ka["r"]):
			v += 1
	# estandarte: aliados próximos de uma peça com "allyAtk" ganham ataque
	for s2 in units:
		if s2 == a or s2.owner != a.owner or s2.st != "field" or s2.barrier:
			continue
		var aa2 = K(s2).get("allyAtk", null)
		if aa2 != null and match_who(a, aa2.get("who", "")) and DB.dist(a.pos(), s2.pos()) <= int(aa2["r"]):
			v += int(aa2["n"])
	if t != null:
		if k.has("atkVsLow") and t.hp <= 5:
			v += int(k["atkVsLow"])
		if k.has("atkMelee") and DB.dist(a.pos(), t.pos()) == 1:
			v += int(k["atkMelee"])
		if k.has("atkMoved") and act != null and act["uid"] == a.uid and act["moved"]:
			v += int(k["atkMoved"])
		if k.has("atkTwin") and field().any(func(x): return x.owner == a.owner and x.cid == "caninus_black"):
			v += int(k["atkTwin"])
		if k.has("atkIsolated") and not allies_of(t).any(func(x): return DB.dist(x.pos(), t.pos()) == 1):
			v += int(k["atkIsolated"])
		if k.has("atkBig") and (t.barrier or int(DB.cards[t.cid]["int"]) >= 10):
			v += int(k["atkBig"])
	if k.has("atkAllyAdj"):
		var aa = k["atkAllyAdj"]
		if allies_of(a).any(func(x): return DB.dist(x.pos(), a.pos()) == 1 and match_who(x, aa.get("who", ""))):
			v += int(aa["n"])
	return max(0, v)


func reduction_of(t, peek: bool = false) -> int:
	if t.barrier:
		return 0
	var red = 0
	var k = K(t)
	if t.eq == "placas":
		red += 1
	if k.has("selfRed"):
		red += int(k["selfRed"])
	if k.has("selfRedHome") and home_half(t.owner, t.pos()):
		red += int(k["selfRedHome"])
	if k.has("firstHitRed") and t.hit_round != round_no:
		red += int(k["firstHitRed"])
		if not peek:
			t.hit_round = round_no
	for s in units:
		if s == t or s.owner != t.owner or s.barrier or s.st == "dead":
			continue
		var ar = K(s).get("auraRed", null)
		if ar == null or not match_who(t, ar.get("who", "")):
			continue
		if s.st != "field" and not ar.get("cmd", false):
			continue
		var pt = s.pos() if s.st == "field" else DB.entry_c[s.owner]
		if DB.dist(pt, t.pos()) <= int(ar["r"]):
			red += int(ar["n"])
	return red


# ================= linha de tiro e terreno =================
func _cube_round(x: float, y: float, z: float) -> Vector2i:
	var rx = round(x)
	var ry = round(y)
	var rz = round(z)
	var dx = abs(rx - x)
	var dy = abs(ry - y)
	var dz = abs(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))


func line_hexes(a: Vector2i, b: Vector2i, e: float) -> Array:
	var n = DB.dist(a, b)
	var out = []
	var ax = a.x + e
	var az = a.y + e
	var ay = -ax - az + e * 0.5
	var bx = b.x + e
	var bz = b.y + e
	var by = -bx - bz + e * 0.5
	for i in range(n + 1):
		var t = 0.0 if n == 0 else float(i) / n
		out.append(_cube_round(ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t))
	return out


func los(a: Vector2i, b: Vector2i) -> bool:
	var lim = max(stand_h(a), stand_h(b))
	for e in [1e-6, -1e-6]:
		var hs = line_hexes(a, b, e)
		var ok = true
		for i in range(1, hs.size() - 1):
			if top_of(hs[i]) > lim:
				ok = false
				break
		if ok:
			return true
	return false


func los_blocker(a: Vector2i, b: Vector2i) -> Variant:
	var lim = max(stand_h(a), stand_h(b))
	var hs = line_hexes(a, b, 1e-6)
	for i in range(1, hs.size() - 1):
		if top_of(hs[i]) > lim:
			return hs[i]
	return null


# a pode estar numa posição simulada (from)
func terrain_mods(a, t, fpos = null) -> Dictionary:
	var o = {"atk": 0, "cover": 0, "forest": 0}
	if t.barrier:
		return o
	var ap = a.pos() if fpos == null else fpos
	var ha = stand_h(ap)
	var ht = stand_h(t.pos())
	var d = DB.dist(ap, t.pos())
	if ha > ht:
		o["atk"] = DB.HIGH_DMG
	elif ha < ht:
		o["atk"] = -DB.LOW_DMG
	if d > 1:
		for c in DB.nbrs(t.pos()):
			var is_cov = tt_of(terr(c)["k"]).get("cover", 0) or barrier_at(c)
			if not is_cov:
				continue
			var top = top_of(c)
			if DB.dist(ap, c) < d and top > ht and not (ha > top):
				o["cover"] = DB.COVER_DMG
				break
		if tt_of(terr(t.pos())["k"]).get("forest", 0):
			o["forest"] = DB.FOREST_DMG
	return o


func range_of(a, fpos: Vector2i, t) -> int:
	var base = alc_of(a)
	return base + (1 if base >= 2 and stand_h(fpos) > stand_h(t.pos()) else 0)


func attack_targets(a, fpos = null) -> Array:
	var ap = a.pos() if fpos == null else fpos
	var hp = stand_h(ap)
	var ts = []
	for t in enemies_of(a):
		var d = DB.dist(ap, t.pos())
		if d < 1 or d > range_of(a, ap, t) or has_fx(t, "veil") or imprisoned(t):
			continue
		if d == 1 and abs(hp - stand_h(t.pos())) > 1 and not K(a).has("climbAll"):
			continue
		if not los(ap, t.pos()):
			continue
		ts.append(t)
	# guarda do clã (k_tank)
	ts = ts.filter(func(t): return not _guarded(t))
	var taunters = ts.filter(func(t): return K(t).has("taunt") and DB.dist(ap, t.pos()) == 1)
	if not taunters.is_empty():
		ts = ts.filter(func(t): return not taunters.any(func(tt2): return t != tt2 and not t.barrier and t.owner == tt2.owner and DB.dist(t.pos(), tt2.pos()) == 1))
	return ts


func _guarded(t) -> bool:
	if t.barrier:
		return false
	var clan = DB.cards[t.cid].get("clan", "")
	if clan == "":
		return false
	for g in allies_of(t):
		if g.cid == "k_tank" and not silenced(g) and DB.dist(g.pos(), t.pos()) == 1 and K(g).get("guardClan", "") == clan:
			return true
	return false


# ================= movimento =================
func can_enter(u, h: Vector2i) -> bool:
	if not DB.in_board(h) or unit_at(h) != null:
		return false
	if not blocks.has(h):
		return true
	return K(u).has("climbAll") and terr(h)["k"] != "buraco" and not barrier_at(h)


func move_opts(u, mov: int) -> Array:
	var start = u.pos()
	var cl = K(u).has("climbAll")
	var best = {start: 0}
	var queue = [{"h": start, "c": 0}]
	while not queue.is_empty():
		queue.sort_custom(func(a, b): return a["c"] < b["c"])
		var n = queue.pop_front()
		if n["c"] > 0 and tt_of(terr(n["h"])["k"]).get("sink", 0):
			continue
		for m in DB.nbrs(n["h"]):
			if not can_enter(u, m) or not can_step(n["h"], m, cl):
				continue
			var c = n["c"] + step_cost(n["h"], m, cl)
			if c > mov:
				if n["c"] == 0 and mov > 0:
					c = mov
				else:
					continue
			if best.has(m) and best[m] <= c:
				continue
			best[m] = c
			queue.append({"h": m, "c": c})
	best.erase(start)
	var out = []
	for h in best.keys():
		out.append({"h": h, "c": best[h]})
	return out


func can_reach(u, h: Vector2i) -> bool:
	for m in move_opts(u, mov_of(u)):
		if m["h"] == h:
			return true
	return false


func tunnel_opts(u) -> Array:
	return DB.hexes.filter(func(h): return DB.dist(h, u.pos()) >= 1 and DB.dist(h, u.pos()) <= 3 and is_free(h))


func move_unit(u, h: Vector2i, own: bool = false) -> void:
	var fpos = u.pos()
	u.q = h.x
	u.r = h.y
	emitfx({"t": "move", "uid": u.uid, "from": fpos, "to": h})
	await pace()
	await arrive(u, own)


func arrive(u, own: bool = false) -> void:
	for i in range(mines.size()):
		var m = mines[i]
		if m["owner"] != u.owner and m["h"] == u.pos() and not u.barrier:
			mines.remove_at(i)
			emitfx({"t": "boom", "h": u.pos()})
			log_msg(m["owner"], "%s ativou uma mina." % nm(u))
			damage(u, int(m["n"]), null)
			break
	if u.st == "field" and not u.barrier:
		for rp in enemies_of(u):
			var n = int(K(rp).get("rappy", 0))
			if n == 0 or rp.rappy_round == round_no or DB.dist(rp.pos(), u.pos()) != 1:
				continue
			rp.rappy_round = round_no
			emitfx({"t": "passive", "kind": "trap", "uid": u.uid})
			log_msg(rp.owner, "Campo Preparado de Rappy: %s sofre %d." % [nm(u), n])
			damage(u, n, rp)
			break
	if u.st == "field" and K(u).has("tricer") and act != null and act["uid"] == u.uid and not act["tricer"] and own:
		var ts = enemies_of(u).filter(func(t): return DB.dist(t.pos(), u.pos()) == 1)
		if not ts.is_empty():
			var h = await pick_hex(u.owner, "Carga Frontal: escolha 1 inimigo adjacente para sofrer 2 de dano.", ts, "enemy", true)
			if h != null:
				act["tricer"] = true
				emitfx({"t": "passive", "kind": "power", "uid": u.uid})
				var t = unit_at(h)
				log_msg(u.owner, "Carga Frontal: %s sofre 2." % nm(t))
				damage(t, int(K(u)["tricer"]), u)
	settle()


# ================= dano =================
func damage(t, n: int, src, is_attack: bool = false) -> int:
	if t == null or t.st != "field" or n <= 0:
		if t != null and n <= 0 and is_attack:
			emitfx({"t": "dmg", "h": t.pos(), "amt": 0, "uid": t.uid})
		return 0
	t.hp -= n
	emitfx({"t": "dmg", "h": t.pos(), "amt": n, "uid": t.uid})
	if t.hp <= 0:
		t.dying = src.uid if src != null else -1
	return n


func settle() -> void:
	var blast = false
	for t in units:
		if t.dying == null or t.st != "field":
			continue
		var by = t.dying
		t.dying = null
		if t.hp > 0:
			continue
		if K(t).has("phoenix") and not t.phoenix_used:
			t.phoenix_used = true
			t.hp = int(K(t)["phoenix"])
			log_msg(t.owner, "%s renasceu com %d de Vida." % [nm(t), t.hp])
			emitfx({"t": "passive", "kind": "phoenix", "uid": t.uid})
			emitfx({"t": "heal", "h": t.pos(), "amt": t.hp, "uid": t.uid})
			continue
		t.st = "dead"
		t.eq = ""
		if not t.barrier:
			fallen.append(t.uid)
		emitfx({"t": "die", "uid": t.uid, "h": t.pos()})
		log_msg(1 - t.owner, "%s foi derrotado." % nm(t))
		var killer = by_uid(by) if by > 0 else null
		if killer != null and killer.owner != t.owner and K(killer).has("killGrow") and not t.barrier:
			killer.kills += 1
		if K(t).has("deathBlast") and not t.barrier:
			blast = true
			var nb = int(K(t)["deathBlast"])
			abfx("blast", t.pos(), t.uid)
			log_msg(t.owner, "%s explode: %d de dano em tudo ao redor." % [nm(t), nb])
			for o in units.duplicate():
				if o != t and o.st == "field" and DB.dist(o.pos(), t.pos()) == 1:
					damage(o, nb, t)
	if blast:
		settle()
		return
	check_win()


func check_win() -> void:
	if winner != NONE:
		return
	var d0 = commander(0).st == "dead"
	var d1 = commander(1).st == "dead"
	if d0 and d1:
		winner = DRAW
	elif d0:
		winner = 1
	elif d1:
		winner = 0


func heal(u, n: int) -> int:
	var h = max(0, min(n, u.maxhp - u.hp))
	u.hp += h
	if h > 0:
		emitfx({"t": "heal", "h": u.pos(), "amt": h, "uid": u.uid})
	return h


# ================= cartas =================
func draw_cards(p: int, n: int = 1) -> int:
	var pl = P[p]
	var got = 0
	for i in range(n):
		if pl["deck"].is_empty():
			if pl["discard"].is_empty():
				break
			pl["deck"] = pl["discard"].duplicate()
			pl["deck"].shuffle()
			pl["discard"] = []
		pl["hand"].append(pl["deck"].pop_front())
		got += 1
	return got


func hand_limit(p: int) -> void:
	var pl = P[p]
	while pl["hand"].size() > 5:
		var c = await ask(p, {"t": "card", "text": "Mão acima de 5: descarte %d carta(s)." % (pl["hand"].size() - 5), "opts": pl["hand"].duplicate(), "optional": false})
		if c == null or not pl["hand"].has(c):
			c = pl["hand"][pl["hand"].size() - 1]
		pl["hand"].erase(c)
		pl["discard"].append(c)


func take_card(p: int, id: String) -> bool:
	var pl = P[p]
	if not pl["hand"].has(id):
		return false
	pl["hand"].erase(id)
	pl["discard"].append(id)
	return true


# ================= rounds =================
func begin_game() -> void:
	for p in range(2):
		draw_cards(p, 3)
		var yes = await ask(p, {"t": "yesno", "text": "Trocar a mão inicial (devolve as 3 cartas e compra 3 novas)? Só dá para fazer uma vez.", "show": P[p]["hand"].duplicate(), "kind": "mulligan"})
		if yes:
			var pl = P[p]
			pl["deck"].append_array(pl["hand"])
			pl["deck"].shuffle()
			pl["hand"] = []
			draw_cards(p, 3)
			log_msg(p, "Trocou a mão inicial.")
	await start_round()


func start_round() -> void:
	round_no += 1
	for u in units:
		u.activated = false
		u.fx = u.fx.filter(func(f): return f.get("until", "") != "start")
	for pl in P:
		pl["obj_used"] = {}
		pl["passed"] = false
	log_msg(-1, "Round %d começou." % round_no)
	await map_events()
	if winner != NONE:
		return
	if round_no == 6:
		for p in range(2):
			await commander_enters(p)
	if winner != NONE:
		return
	for p in range(2):
		draw_cards(p, 1)
		await hand_limit(p)
	first = 0 if round_no % 2 == 1 else 1
	cur = first
	emitfx({"t": "round", "round": round_no})
	await pace()
	await auto_pass()


func map_events() -> void:
	var def = DB.maps[map_id]
	if def.has("dunes"):
		if dune_next >= 0 and (round_no - 1) % DUNE_EVERY == 0:
			var before = {}
			for u in field():
				before[u.uid] = h_of(u.pos())
			dune = dune_next
			dune_next = -1
			load_map()
			log_msg(-1, "As dunas mudaram: %s." % def["dunes"][dune]["name"])
			emitfx({"t": "dunes"})
			for u in field():
				if before.has(u.uid) and before[u.uid] - h_of(u.pos()) >= 2 and not u.barrier:
					log_msg(-1, "%s deslizou da duna." % nm(u))
					damage(u, FALL_DMG, null)
			settle()
			await pace()
			if winner != NONE:
				return
		if round_no % DUNE_EVERY == 0:
			var opts = []
			for i in range(def["dunes"].size()):
				if i != dune:
					opts.append(i)
			dune_next = opts.pick_random()
			emitfx({"t": "wind"})
			log_msg(-1, "O vento muda: no próximo round as dunas viram \"%s\"." % def["dunes"][dune_next]["name"])
	if def.get("worms", false):
		var n0 = holes.size()
		holes = holes.filter(func(b): return b["until"] > round_no)
		if holes.size() != n0:
			load_map()
			log_msg(-1, "Um buraco de verme se fechou.")
		if round_no % WORM_EVERY == 0 and not tremors.is_empty():
			for t in tremors:
				holes.append({"h": t, "until": round_no + HOLE_ROUNDS})
			tremors = []
			load_map()
			log_msg(-1, "Vermes gigantes abriram buracos na areia!")
			emitfx({"t": "worm"})
			# a areia em volta dos buracos desaba: quem está ao lado leva 1 de dano
			for b in holes:
				for u2 in field():
					if not u2.barrier and DB.dist(u2.pos(), b["h"]) == 1 and not holes.any(func(x): return x["h"] == u2.pos()):
						damage(u2, 1, null)
						log_msg(-1, "%s foi atingido pela areia que desabou." % nm(u2))
			for b in holes:
				var u = unit_at(b["h"])
				if u == null:
					continue
				emitfx({"t": "boom", "h": b["h"]})
				log_msg(-1, "%s foi abocanhado pelo verme!" % nm(u))
				damage(u, HOLE_DMG, null)
				var ops = DB.nbrs(u.pos()).filter(func(n): return is_free(n))
				if ops.is_empty():
					var fr = DB.hexes.filter(func(h): return is_free(h))
					fr.sort_custom(func(a, c): return DB.dist(a, u.pos()) < DB.dist(c, u.pos()))
					ops = fr.slice(0, 1)
				if not ops.is_empty() and u.st == "field":
					var h = ops[0]
					if not u.barrier:
						var ch = await ask(u.owner, {"t": "hex", "text": "%s precisa sair do buraco: escolha a casa." % nm(u), "opts": ops, "optional": false, "kind": "move"})
						if ch != null:
							h = ch
					var fpos = u.pos()
					u.q = h.x
					u.r = h.y
					emitfx({"t": "move", "uid": u.uid, "from": fpos, "to": h})
			settle()
			await pace()
			if winner != NONE:
				return
		if (round_no + 1) % WORM_EVERY == 0:
			var cand = DB.hexes.filter(func(h): return _tremor_ok(h))
			if not cand.is_empty():
				var c = cand.pick_random()
				tremors = [c, -c]
				var c2s = cand.filter(func(h): return DB.dist(h, c) >= 3 and DB.dist(h, -c) >= 3)
				if not c2s.is_empty():
					var c2 = c2s.pick_random()
					tremors.append(c2)
					tremors.append(-c2)
				log_msg(-1, "A areia treme: buracos de verme vão abrir no próximo round nas casas marcadas.")
				emitfx({"t": "tremor", "hexes": tremors.duplicate()})


func _tremor_ok(h: Vector2i) -> bool:
	var m = -h
	return terr(h)["k"] == "areia" and terr(m)["k"] == "areia" and h != Vector2i.ZERO and DB.obj_at(h) == null and DB.obj_at(m) == null and not res.has(h) and not res.has(m) and min(DB.dist(h, DB.entry_c[0]), DB.dist(h, DB.entry_c[1])) >= 2


func commander_enters(p: int) -> void:
	var c = commander(p)
	if c.st != "off":
		return
	var opts = DB.entry[p].filter(func(h): return is_free(h))
	if opts.is_empty():
		var occ = []
		for h in DB.entry[p]:
			var u = unit_at(h)
			if u != null and u.owner == p and not u.barrier:
				occ.append(h)
		if not occ.is_empty():
			var h = await pick_hex(p, "Entrada cheia: escolha 1 aliado para voltar à reserva e abrir espaço para o Comandante.", occ, "ally")
			var back = unit_at(h)
			back.st = "reserve"
			log_msg(p, "%s voltou à reserva." % nm(back))
			opts = DB.entry[p].filter(func(hh): return is_free(hh))
	if opts.is_empty():
		return
	var d = await pick_hex(p, "%s entra em campo: escolha uma casa livre da sua entrada." % nm(c), opts, "place")
	c.st = "field"
	c.q = d.x
	c.r = d.y
	emitfx({"t": "summon", "uid": c.uid, "h": d})
	log_msg(p, "%s entrou em campo." % nm(c))
	await arrive(c)


func end_round() -> void:
	if not pending.is_empty():
		for pd in pending:
			var t = by_uid(pd["uid"])
			if t != null and t.st == "field":
				log_msg(pd["p"], "Dano pendente: %s sofre %d." % [nm(t), pd["n"]])
				damage(t, pd["n"], by_uid(pd["src"]))
		pending = []
		settle()
		await pace()
		if winner != NONE:
			return
	for p in range(2):
		for k in field().filter(func(u): return u.owner == p and K(u).has("endHeal")):
			var opts = allies_of(k).filter(func(x): return DB.dist(x.pos(), k.pos()) == 1 and x.hp < x.maxhp)
			if opts.is_empty():
				continue
			var h = await pick_hex(p, "%s: escolha 1 aliado adjacente para restaurar 1 de Vida." % nm(k), opts, "ally")
			var t = unit_at(h)
			if t != null:
				heal(t, int(K(k)["endHeal"]))
				log_msg(p, "%s restaura 1 de Vida de %s." % [nm(k), nm(t)])
	for u in units:
		u.fx = u.fx.filter(func(f): return f.get("until", "") != "end" and not ((f["k"] == "root" or f["k"] == "prison") and int(f["end"]) <= round_no))
	for pl in P:
		pl["discount"] = false
	if round_no >= 10:
		do_final_score()
		return
	await start_round()


func do_final_score() -> void:
	var c = [commander(0).hp, commander(1).hp]
	var s = [0, 0]
	for u in field():
		if not u.is_cmd and not u.barrier:
			s[u.owner] += u.hp
	final_score = {"c": c, "s": s}
	if c[0] != c[1]:
		winner = 0 if c[0] > c[1] else 1
	elif s[0] != s[1]:
		winner = 0 if s[0] > s[1] else 1
	else:
		winner = DRAW
	log_msg(-1, "Fim do round 10. Vida dos comandantes: %d × %d. Aliados: %d × %d." % [c[0], c[1], s[0], s[1]])
	changed.emit()


# ================= ativações =================
func deploy_hexes(p: int) -> Array:
	return DB.entry[p].filter(func(h): return is_free(h))


func reserve_of(p: int) -> Array:
	return units.filter(func(u): return u.owner == p and u.st == "reserve")


func can_activate(p: int) -> bool:
	if winner != NONE:
		return false
	if field().any(func(u): return u.owner == p and not u.barrier and not u.activated):
		return true
	return not reserve_of(p).is_empty() and not deploy_hexes(p).is_empty()


func can_start(u) -> bool:
	return u != null and u.st == "field" and not u.barrier and u.owner == cur and not u.activated and act == null and winner == NONE


func auto_pass() -> void:
	for i in range(2):
		if winner != NONE:
			return
		var p = cur
		if P[p]["passed"] or not can_activate(p):
			if not P[p]["passed"]:
				P[p]["passed"] = true
				log_msg(p, "Sem peças para ativar: passou.")
			if P[1 - p]["passed"]:
				await end_round()
				return
			cur = 1 - p
		else:
			return


func pass_turn(p: int) -> void:
	P[p]["passed"] = true
	log_msg(p, "Passou.")
	if P[1 - p]["passed"]:
		await end_round()
		return
	cur = 1 - p
	await auto_pass()


func _new_act(u, actions: int, cant: bool) -> Dictionary:
	return {"uid": u.uid, "p": u.owner, "actions": actions, "attacked": false, "tactic": false, "reacted": false, "moved": false, "cant_attack": cant, "fogo": 0, "tricer": false}


func start_activation(u) -> void:
	act = _new_act(u, 2, false)
	log_msg(u.owner, "Ativa %s." % nm(u))


func deploy(u, h: Vector2i, via_obj: bool = false) -> void:
	var p = u.owner
	var pl = P[p]
	u.st = "field"
	u.q = h.x
	u.r = h.y
	emitfx({"t": "summon", "uid": u.uid, "h": h})
	await pace()
	if via_obj:
		u.activated = true
		log_msg(p, "Reforços: %s entrou já ativado." % nm(u))
	else:
		var actions = 1
		var cant = false
		if pl["discount"] and DB.cards[u.cid]["f"] == "FAU":
			pl["discount"] = false
			actions = 2
			cant = true
			log_msg(p, "Engenho Improvisado: a peça entra com as 2 ações, mas não pode atacar.")
		act = _new_act(u, actions, cant)
		log_msg(p, "Implanta %s." % nm(u))
		if not cant and pl["hand"].has("reforco"):
			var yes = await ask(p, {"t": "yesno", "text": "Usar Reforço Acelerado? A peça entra com as 2 ações, mas não pode atacar neste turno.", "kind": "reforco"})
			if yes:
				take_card(p, "reforco")
				act["tactic"] = true
				act["actions"] = 2
				act["cant_attack"] = true
				log_msg(p, "Reforço Acelerado.")
	await entry_effect(u)
	await arrive(u)
	await pace()


func end_activation() -> void:
	if act == null:
		return
	var a = act
	var u = by_uid(a["uid"])
	if u != null:
		u.activated = true
	act = null
	await hand_limit(a["p"])
	if winner != NONE:
		return
	var o = 1 - a["p"]
	cur = a["p"] if P[o]["passed"] else o
	await auto_pass()


func is_live(u) -> bool:
	return act != null and act["uid"] == u.uid


func can_attack_now(u) -> bool:
	return is_live(u) and act["actions"] > 0 and not act["attacked"] and not act["cant_attack"] and not imprisoned(u)


func can_attack_any(u) -> bool:
	return is_live(u) and not act["attacked"] and not act["cant_attack"] and not imprisoned(u)


# ================= ações =================
func act_move(u, h: Vector2i) -> bool:
	if not is_live(u) or act["actions"] < 1 or rooted(u) or act["moved"]:
		return false
	if not can_reach(u, h):
		return false
	act["actions"] -= 1
	act["moved"] = true
	await move_unit(u, h, true)
	return true


func act_attack(u, t) -> bool:
	if not can_attack_now(u) or not attack_targets(u).has(t):
		return false
	act["actions"] -= 1
	await resolve_attack(u, t)
	return true


func act_move_attack(u, h, t) -> bool:
	if not is_live(u) or act["actions"] < 1 or K(u).get("action", "") != "moveAttack":
		return false
	act["actions"] -= 1
	if h != null and h != u.pos() and not rooted(u) and not act["moved"]:
		act["moved"] = true
		abfx("dash", u.pos(), u.uid)
		await move_unit(u, h, true)
	if u.st != "field" or winner != NONE:
		return true
	if t == null:
		var ts = attack_targets(u) if can_attack_any(u) else []
		if not ts.is_empty():
			var hh = await pick_hex(u.owner, "Escolha o alvo do ataque.", ts, "enemy", true)
			if hh != null:
				t = unit_at(hh)
	if t != null and can_attack_any(u) and attack_targets(u).has(t):
		await resolve_attack(u, t)
	return true


func act_tunnel(u, h: Vector2i) -> bool:
	if not is_live(u) or act["actions"] < 1 or act["moved"]:
		return false
	if not tunnel_opts(u).has(h):
		return false
	act["actions"] -= 1
	act["moved"] = true
	abfx("burrow", u.pos(), u.uid)
	abfx("burrow", h, u.uid)
	await move_unit(u, h, true)
	return true


# ================= ativas dos comandantes (1 vez por partida) =================
func ult_kind(u) -> String:
	return str(K(u).get("ult", ""))


func can_ult(u) -> bool:
	return is_live(u) and act["actions"] >= 1 and ult_kind(u) != "" and not u.ult_used and not ult_opts(u).is_empty()


func _dirs() -> Array:
	return DB.nbrs(Vector2i(0, 0))


func stampede_path(u, end: Vector2i) -> Array:
	for d in _dirs():
		var path = []
		var cur_h2 = u.pos()
		for k in range(3):
			var c = cur_h2 + d
			if not DB.in_board(c) or blocks.has(c) or barrier_at(c) or not can_step(cur_h2, c):
				break
			var t = unit_at(c)
			if t != null:
				if t.owner == u.owner or t.barrier:
					break
				var nxt = c + d
				var side = DB.nbrs(c).filter(func(n): return n != nxt and n != cur_h2 and is_free(n))
				if side.is_empty():
					break
			path.append(c)
			if c == end:
				return path
			cur_h2 = c
	return []


func ult_opts(u) -> Array:
	var p = u.pos()
	match ult_kind(u):
		"abyss":
			if adj_free(p).is_empty():
				return []
			return enemies_of(u).filter(func(t): return not t.barrier and DB.dist(t.pos(), p) >= 2 and DB.dist(t.pos(), p) <= 8).map(func(t): return t.pos())
		"bombard":
			var out = []
			for h in DB.hexes:
				if DB.dist(h, p) < 1 or DB.dist(h, p) > 6:
					continue
				var t = unit_at(h)
				if (t != null and t.owner != u.owner) or DB.nbrs(h).any(func(n): return unit_at(n) != null and unit_at(n).owner != u.owner):
					out.append(h)
			return out
		"prison":
			return enemies_of(u).filter(func(t): return not t.barrier and not imprisoned(t) and DB.dist(t.pos(), p) <= 4).map(func(t): return t.pos())
		"earth":
			return DB.hexes.filter(func(h): return DB.dist(h, p) <= 4 and not blocks.has(h) and not DB.in_entry(0, h) and not DB.in_entry(1, h))
		"stampede":
			var out2 = []
			for d in _dirs():
				var cur_h2 = p
				for k in range(3):
					var c = cur_h2 + d
					if stampede_path(u, c).is_empty():
						break
					out2.append(c)
					cur_h2 = c
			return out2
		"orbital":
			return DB.hexes.filter(func(h): return DB.dist(h, p) >= 1 and DB.dist(h, p) <= 5 and is_free(h))
	return []


# pontuação para a CPU escolher onde usar a ativa
func ult_score(u, h: Vector2i) -> float:
	var t = unit_at(h)
	match ult_kind(u):
		"abyss", "prison":
			if t == null:
				return 0.0
			return int(DB.cards[t.cid]["atk"]) + (6.0 if t.is_cmd else 0.0) + (3.0 if t.hp <= 6 else 0.0)
		"bombard":
			var s = 0.0
			if t != null:
				s += (3.0 if t.owner != u.owner else -4.0) * (2.0 if t.is_cmd else 1.0)
				if t.owner != u.owner and t.hp <= 3:
					s += 4.0
			for n in DB.nbrs(h):
				var a = unit_at(n)
				if a != null:
					s += 1.0 if a.owner != u.owner else -1.5
			return s
		"stampede":
			var s2 = 0.0
			for c in stampede_path(u, h):
				var e = unit_at(c)
				if e != null:
					s2 += 2.0 + (2.0 if e.hp <= 2 else 0.0)
			# terminar cercado de inimigos é arriscado
			for e5 in enemies_of(u):
				if DB.dist(e5.pos(), h) <= 2:
					s2 -= 1.0 if u.hp > 6 else 2.0
			return s2
		"earth":
			# erguer a casa de um aliado que está perto de inimigos (altura dá +1 de dano e alcance)
			if t == null or t.owner != u.owner or t.barrier:
				return 0.0
			var s4 = 1.5 + (1.5 if alc_of(t) >= 2 else 0.0)
			for e3 in enemies_of(u):
				if DB.dist(e3.pos(), h) <= max(2, alc_of(t)):
					s4 += 1.0
			return s4
		"orbital":
			var s3 = 0.0
			for n in DB.nbrs(h):
				var e2 = unit_at(n)
				if e2 != null and e2.owner != u.owner and not e2.barrier:
					s3 += 2.0 + (3.0 if e2.hp <= 2 else 0.0) + (2.0 if e2.is_cmd else 0.0)
			# pousar no meio de inimigos fortes é arriscado para o comandante
			for e4 in enemies_of(u):
				if DB.dist(e4.pos(), h) <= 2 and e4.hp > 2:
					s3 -= 1.0 if u.hp > 6 else 2.0
			return s3
	return 0.0


func act_ult(u) -> bool:
	if not can_ult(u):
		return false
	var p = u.owner
	var kind = ult_kind(u)
	var ab2 = DB.cards[u.cid].get("ab2", {})
	var uname = ab2.get("name", "Ativa")
	var texts = {"abyss": "escolha o inimigo a puxar (até 8 casas)", "bombard": "escolha a casa do bombardeio (até 6)", "prison": "escolha o inimigo a prender (até 4)", "earth": "escolha a 1ª casa a mudar de altura (até 4)", "stampede": "escolha até onde avançar em linha reta", "orbital": "escolha onde pousar (até 5)"}
	var h = await pick_hex(p, "%s: %s." % [uname, texts.get(kind, "escolha")], ult_opts(u), "ult", true)
	if h == null:
		return false
	act["actions"] -= 1
	u.ult_used = true
	log_msg(p, "%s usou %s." % [nm(u), uname])
	emitfx({"t": "ult", "uid": u.uid, "name": uname, "p": p})
	emitfx({"t": "passive", "kind": "ability", "uid": u.uid})
	await pace()
	match kind:
		"abyss":
			var t = unit_at(h)
			var spots = adj_free(u.pos())
			spots.sort_custom(func(a, b): return DB.dist(a, h) < DB.dist(b, h))
			if t != null and not spots.is_empty():
				abfx("abyss", h, u.uid)
				abfx("abyss", spots[0], u.uid)
				emitfx({"t": "passive", "kind": "curse", "uid": t.uid})
				log_msg(p, "%s foi puxado para o abismo." % nm(t))
				await move_unit(t, spots[0])
		"bombard":
			abfx("bombard", h, u.uid)
			emitfx({"t": "boom", "h": h})
			var t2 = unit_at(h)
			if t2 != null:
				damage(t2, 3, u)
			for n in DB.nbrs(h):
				var a = unit_at(n)
				if a != null:
					damage(a, 1, u)
			settle()
		"prison":
			var t3 = unit_at(h)
			if t3 != null:
				abfx("prison", h, u.uid)
				t3.fx.append({"k": "prison", "end": round_no + 1})
				t3.fx.append({"k": "root", "end": round_no + 1})
				emitfx({"t": "passive", "kind": "shield", "uid": t3.uid})
				log_msg(p, "%s está preso no cristal." % nm(t3))
		"earth":
			var done = []
			var cur_h = h
			for i in range(3):
				var up = await ask(p, {"t": "yesno", "text": "%s: subir (Sim) ou descer (Não) esta casa?" % uname, "kind": "earth", "h": cur_h})
				var delta = 1 if up else -1
				earth[cur_h] = int(earth.get(cur_h, 0)) + delta
				abfx("earth", cur_h, u.uid)
				done.append(cur_h)
				load_map()
				emitfx({"t": "tremor", "hexes": [cur_h]})
				await pace()
				if i == 2:
					break
				var more = ult_opts(u).filter(func(x): return not done.has(x))
				var nh = await pick_hex(p, "%s: escolha outra casa (ou Pular)." % uname, more, "ult", true)
				if nh == null:
					break
				cur_h = nh
		"stampede":
			var path = stampede_path(u, h)
			for c in path:
				var e = unit_at(c)
				if e != null:
					var nxt = c + (c - u.pos())
					var side = DB.nbrs(c).filter(func(n): return n != nxt and n != u.pos() and is_free(n))
					emitfx({"t": "strike", "from": u.uid, "to": e.uid, "ranged": false})
					damage(e, 2, u)
					if not side.is_empty() and e.hp > 0:
						await move_unit(e, side[0])
					settle()
					if unit_at(c) != null:
						break
				abfx("stomp", c, u.uid)
				await move_unit(u, c, true)
				if u.st != "field":
					break
		"orbital":
			abfx("orbital", h, u.uid)
			await move_unit(u, h, true)
			emitfx({"t": "boom", "h": h})
			for n in DB.nbrs(h):
				var e3 = unit_at(n)
				if e3 != null and e3.owner != p and not e3.barrier:
					damage(e3, 2, u)
			settle()
	changed.emit()
	return true


func can_interact(u) -> bool:
	var o = DB.obj_at(u.pos())
	if o == null or not is_live(u) or act["actions"] <= 0 or P[u.owner]["obj_used"].has(o["id"]):
		return false
	if o["id"] == "reforcos":
		return not reserve_of(u.owner).is_empty() and not adj_free(Vector2i(o["q"], o["r"])).is_empty()
	return true


func act_interact(u) -> bool:
	if not can_interact(u):
		return false
	var o = DB.obj_at(u.pos())
	var p = u.owner
	act["actions"] -= 1
	P[p]["obj_used"][o["id"]] = true
	match o["id"]:
		"energia":
			draw_cards(p, 1)
			log_msg(p, "Energia: comprou 1 tática.")
		"radar":
			log_msg(p, "Radar: olhou a mão do rival.")
			await ask(p, {"t": "show", "text": "Mão do rival", "cards": P[1 - p]["hand"].duplicate()})
		"reforcos":
			var rs = reserve_of(p)
			var ids = []
			for x in rs:
				ids.append(x.uid)
			var pick = await ask(p, {"t": "unitlist", "text": "Reforços: escolha a reserva a implantar.", "opts": ids, "optional": false})
			var r = by_uid(pick) if pick != null else null
			if r == null:
				r = rs[0]
			var spots = adj_free(Vector2i(o["q"], o["r"]))
			var h = await pick_hex(p, "Escolha uma casa livre ao lado do objetivo para %s." % nm(r), spots, "place")
			await deploy(r, h, true)
	return true


func can_collect(u) -> bool:
	return res.has(u.pos()) and is_live(u) and act["actions"] > 0


func act_collect(u) -> bool:
	if not can_collect(u):
		return false
	var k = u.pos()
	var t = res[k]
	var p = u.owner
	res.erase(k)
	act["actions"] -= 1
	log_msg(p, "%s coletou %s." % [nm(u), DB.res[t]["name"]])
	if t == "agua":
		heal(u, 3)
	elif t == "equip":
		var c = await ask(p, {"t": "card", "text": "Equipamento abandonado: escolha o que equipar.", "opts": ["placas", "propulsor", "lente"], "optional": false, "kind": "equip"})
		u.eq = c if c != null else "placas"
		log_msg(p, "%s equipou %s." % [nm(u), DB.tactics[u.eq]["name"]])
	elif t == "sucata":
		var ops = adj_free(u.pos())
		if not ops.is_empty():
			var h = await pick_hex(p, "Sucata: escolha onde montar a Barreira de 3 de Vida (ou pule).", ops, "place", true)
			if h != null:
				_make_barrier(p, h, 3)
	await pace()
	return true


func _make_barrier(p: int, h: Vector2i, n: int) -> void:
	var b = Unit.new()
	b.uid = next_uid
	next_uid += 1
	b.cid = "barrier"
	b.owner = p
	b.st = "field"
	b.q = h.x
	b.r = h.y
	b.hp = n
	b.maxhp = n
	b.barrier = true
	b.activated = true
	units.append(b)
	emitfx({"t": "summon", "uid": b.uid, "h": h})


# ================= ataque =================
# Maré de Rhazur: +1 no 1º ataque de cada Abyssal a até MARE_R casas dele (fora do campo: da entrada)
const MARE_R = 3


func _mare_on(cm, a) -> bool:
	if cm == null or cm.st == "dead" or silenced(cm) or a.mare_used:
		return false
	var mk = DB.cards[cm.cid]["k"].get("mare", null)
	if mk == null:
		return false
	return DB.dist(a.pos(), cmd_point(cm)) <= MARE_R


func resolve_attack(a, t) -> void:
	var A = act
	var p = a.owner
	var d = 1 - p
	A["attacked"] = true
	var ranged = DB.dist(a.pos(), t.pos()) > 1
	var tm = terrain_mods(a, t)
	var packet = atk_of(a, t) + int(A["fogo"]) + fx_sum(t, "mark") + int(tm["atk"])
	A["fogo"] = 0
	if K(a).has("firstAtk") and not a.first_used:
		packet += int(K(a)["firstAtk"])
	var had_first = K(a).has("firstAtk") and not a.first_used
	a.first_used = true
	var cm = commander(p)
	if _mare_on(cm, a):
		packet += 1
	var passive_boost = atk_of(a, t) > int(DB.cards[a.cid]["atk"]) + fx_sum(a, "atk")
	if had_first or _mare_on(cm, a):
		passive_boost = true
	a.mare_used = true
	emitfx({"t": "strike", "from": a.uid, "to": t.uid, "ranged": ranged})
	if passive_boost:
		emitfx({"t": "passive", "kind": "power", "uid": a.uid})
	var extra = ""
	if tm["atk"] > 0:
		extra += ", do alto"
	elif tm["atk"] < 0:
		extra += ", de baixo"
	if tm["cover"] > 0:
		extra += ", alvo abrigado -%d" % tm["cover"]
	if tm["forest"] > 0:
		extra += ", floresta -%d" % tm["forest"]
	log_msg(p, "%s ataca %s (%d%s)." % [nm(a), nm(t), packet, extra])
	var target = t
	var react_red = 0
	if not t.barrier:
		for b in allies_of(t).filter(func(x): return K(x).has("guard") and DB.dist(x.pos(), t.pos()) == 1 and not (K(x).has("guardOnce") and guard_round.get(x.uid, -1) == round_no)):
			var yes = await ask(d, {"t": "yesno", "text": "Guarda Silencioso: %s recebe o ataque de %d no lugar de %s?" % [nm(b), packet, nm(t)], "kind": "balu", "packet": packet, "target": t.uid, "guard": b.uid})
			if yes:
				target = b
				guard_round[b.uid] = round_no
				log_msg(d, "%s protege %s." % [nm(b), nm(t)])
				break
		var pl = P[d]
		var opts = []
		if not A["reacted"] and ranged and pl["hand"].has("cobertura"):
			opts.append("cobertura")
		if not A["reacted"] and not ranged and pl["hand"].has("escudo"):
			opts.append("escudo")
		if not opts.is_empty():
			var c = await ask(d, {"t": "card", "text": "Reação: %s vai sofrer um ataque de %d. Usar reação?" % [nm(target), packet], "opts": opts, "optional": true, "kind": "reaction", "packet": packet, "target": target.uid})
			if c != null and c != "":
				take_card(d, c)
				A["reacted"] = true
				react_red = 3 if c == "cobertura" else 2
				log_msg(d, "%s: -%d de dano." % [DB.tactics[c]["name"], react_red])
	var tm2 = tm if target == t else terrain_mods(a, target)
	var red = reduction_of(target)
	var dealt = max(0, packet - red - react_red - int(tm2["cover"]) - int(tm2["forest"]))
	if (red > 0 or react_red > 0) and not target.barrier:
		emitfx({"t": "passive", "kind": "shield", "uid": target.uid})
	damage(target, dealt, a, true)
	# espinhos: quem ataca corpo a corpo sofre dano de volta (Medusa)
	if K(target).has("thorns") and DB.dist(a.pos(), target.pos()) == 1 and a.st == "field":
		var nt = int(K(target)["thorns"])
		abfx("zap", a.pos(), target.uid)
		log_msg(target.owner, "%s: %s sofre %d ao tocá-la." % [DB.cards[target.cid]["ab"]["name"], nm(a), nt])
		damage(a, nt, target)
	await pace()
	var k = K(a)
	var after = k.get("after", "")
	if dealt > 0 and target.hp > 0:
		if after == "pending":
			pending.append({"uid": target.uid, "n": 1, "p": p, "src": a.uid})
			abfx("poison", target.pos(), a.uid)
		if after == "rootHit":
			abfx("glue", target.pos(), a.uid)
			target.fx.append({"k": "root", "end": round_no + 1})
			log_msg(p, "Presa de Aço: %s não pode se mover até o fim do próximo round." % nm(target))
	if after == "splash":
		var ss = enemies_of(a).filter(func(x): return x != target and DB.dist(x.pos(), target.pos()) == 1)
		abfx("splash", target.pos(), a.uid)
		for x in ss:
			damage(x, 1, a)
		if not ss.is_empty():
			log_msg(p, "%s: 1 de dano em %d inimigo(s) ao redor do alvo." % [DB.cards[a.cid]["ab"]["name"], ss.size()])
	if after == "burstAll":
		var ss2 = field().filter(func(x): return x != a and x != target and DB.dist(x.pos(), a.pos()) == 1)
		abfx("nova", a.pos(), a.uid)
		for x in ss2:
			damage(x, 1, a)
	if after == "burstEnemies":
		var ss3 = enemies_of(a).filter(func(x): return x != target and DB.dist(x.pos(), a.pos()) == 1)
		abfx("zap", a.pos(), a.uid)
		for x in ss3:
			damage(x, 1, a)
	settle()
	if winner != NONE:
		return
	if after == "chain":
		var ss4 = enemies_of(a).filter(func(x): return x != target and DB.dist(x.pos(), a.pos()) == 1)
		if not ss4.is_empty():
			var h = await pick_hex(p, "Descarga em Cadeia: 1 de dano em outro inimigo adjacente.", ss4, "enemy")
			var x = unit_at(h)
			abfx("bolt", x.pos(), a.uid)
			damage(x, 1, a)
			log_msg(p, "Descarga em Cadeia: %s sofre 1." % nm(x))
			settle()
			if winner != NONE:
				return
	if after == "pull" and dealt > 0 and target.st == "field" and not target.barrier:
		var ops = step_free(target.pos()).filter(func(h2): return DB.dist(h2, a.pos()) < DB.dist(target.pos(), a.pos()))
		if not ops.is_empty():
			var h = await pick_hex(p, "Arpão de Arrasto: puxe o alvo 1 casa em sua direção.", ops, "move", true)
			if h != null:
				abfx("hook", target.pos(), a.uid)
				log_msg(p, "%s foi arrastado." % nm(target))
				await move_unit(target, h)
				if winner != NONE:
					return
	if after == "knock" and dealt > 0 and target.st == "field" and not target.barrier:
		var kd = push_dest(target, a.pos())
		if kd != null:
			abfx("sonic", target.pos(), a.uid)
			log_msg(p, "%s: %s foi arremessado 1 casa." % [DB.cards[a.cid]["ab"]["name"], nm(target)])
			await move_unit(target, kd)
			if winner != NONE:
				return
	if target.st == "field" and target.hp > 0 and not target.barrier and not A["reacted"] and a.st == "field" and DB.dist(a.pos(), target.pos()) == 1 and P[d]["hand"].has("revide"):
		var yr = await ask(d, {"t": "yesno", "text": "Revide: %s causa 2 de dano em %s?" % [nm(target), nm(a)], "kind": "revide", "card": "revide"})
		if yr:
			take_card(d, "revide")
			A["reacted"] = true
			abfx("blast", a.pos(), target.uid)
			log_msg(d, "Revide: %s devolve 2 de dano em %s." % [nm(target), nm(a)])
			damage(a, 2, target)
			settle()
			if winner != NONE or a.st != "field":
				return
	if target.st == "field" and not target.barrier and not A["reacted"] and P[d]["hand"].has("dispersao") and not step_free(target.pos()).is_empty():
		var h = await ask(d, {"t": "hex", "text": "Dispersão: mover %s 1 casa livre?" % nm(target), "opts": step_free(target.pos()), "optional": true, "kind": "move", "card": "dispersao"})
		if h != null:
			take_card(d, "dispersao")
			A["reacted"] = true
			log_msg(d, "Dispersão: %s recua." % nm(target))
			await move_unit(target, h)
			if winner != NONE:
				return
	if a.st != "field":
		return
	if after == "freeMove" and not rooted(a) and not step_free(a.pos()).is_empty():
		var h = await ask(p, {"t": "hex", "text": "%s: mover 1 casa livre sem gastar ação?" % DB.cards[a.cid]["ab"]["name"], "opts": step_free(a.pos()), "optional": true, "kind": "move"})
		if h != null:
			abfx("dash", a.pos(), a.uid)
			await move_unit(a, h)
		if winner != NONE or a.st != "field":
			return
	if not A["tactic"] and P[p]["hand"].has("retirada") and not rooted(a) and not step_free(a.pos()).is_empty():
		var h = await ask(p, {"t": "hex", "text": "Retirada Calculada: mover o ativo 1 casa livre?", "opts": step_free(a.pos()), "optional": true, "kind": "move", "card": "retirada"})
		if h != null:
			take_card(p, "retirada")
			A["tactic"] = true
			log_msg(p, "Retirada Calculada.")
			await move_unit(a, h)


# ================= efeitos de entrada =================
func push_dest(t, fpos: Vector2i) -> Variant:
	var best: Variant = null
	var bs = -1e9
	var tp = t.pos()
	for n in DB.nbrs(tp):
		if DB.dist(n, fpos) <= DB.dist(tp, fpos):
			continue
		var s = -abs((n.x - tp.x) - (tp.x - fpos.x)) - abs((n.y - tp.y) - (tp.y - fpos.y))
		if s > bs:
			bs = s
			best = n
	if best != null and is_free(best) and can_step(tp, best):
		return best
	return null


func entry_effect(u) -> void:
	var e = K(u).get("entry", null)
	if e == null:
		return
	var p = u.owner
	var name = DB.cards[u.cid]["ab"]["name"]
	var r = int(e.get("r", 1))
	var n = int(e.get("n", 0))
	var en = enemies_of(u).filter(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) <= r)
	emitfx({"t": "passive", "kind": "ability", "uid": u.uid})
	match e["t"]:
		"peek", "top3", "discount":
			abfx("insight", u.pos(), u.uid)
		"pushAllAdj", "dmgAdj":
			abfx("quake" if e["t"] == "pushAllAdj" else "explode", u.pos(), u.uid)
	match e["t"]:
		"peek":
			var pl = P[p]
			if pl["deck"].is_empty() and not pl["discard"].is_empty():
				pl["deck"] = pl["discard"].duplicate()
				pl["deck"].shuffle()
				pl["discard"] = []
			if not pl["deck"].is_empty():
				var ans = await ask(p, {"t": "peek", "text": "%s: carta do topo do baralho." % name, "card": pl["deck"][0]})
				if ans == "bottom":
					pl["deck"].append(pl["deck"].pop_front())
					log_msg(p, "%s: colocou a carta do topo no fundo." % name)
		"top3":
			log_msg(p, "%s: olhou o topo do baralho." % name)
		"pushAdj":
			var ts = enemies_of(u).filter(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) == 1 and push_dest(x, u.pos()) != null)
			var h = await pick_hex(p, "%s: empurre 1 inimigo adjacente." % name, ts, "enemy")
			if h != null:
				var t = unit_at(h)
				abfx("push", h, u.uid)
				log_msg(p, "%s: %s foi empurrado." % [name, nm(t)])
				await move_unit(t, push_dest(t, u.pos()))
		"pushAllAdj":
			for t in enemies_of(u).filter(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) == 1):
				var dd = push_dest(t, u.pos())
				if dd != null:
					await move_unit(t, dd)
					log_msg(p, "%s: %s foi empurrado." % [name, nm(t)])
		"pushFar":
			var ts2 = en.filter(func(x): return push_dest(x, u.pos()) != null)
			var h2 = await pick_hex(p, "%s: empurre 1 inimigo a até %d casas." % [name, r], ts2, "enemy")
			if h2 != null:
				var t2 = unit_at(h2)
				abfx("sonic", h2, u.uid)
				await move_unit(t2, push_dest(t2, u.pos()))
				log_msg(p, "%s: %s foi empurrado." % [name, nm(t2)])
		"dmgAdj":
			var ts3 = enemies_of(u).filter(func(x): return DB.dist(x.pos(), u.pos()) == 1)
			for t in ts3:
				damage(t, n, u)
			if not ts3.is_empty():
				log_msg(p, "%s: %d de dano em %d inimigo(s)." % [name, n, ts3.size()])
			settle()
		"dmg":
			var h3 = await pick_hex(p, "%s: cause %d de dano a 1 inimigo a até %d casas." % [name, n, r], enemies_of(u).filter(func(x): return DB.dist(x.pos(), u.pos()) <= r), "enemy")
			if h3 != null:
				var t3 = unit_at(h3)
				abfx("blast", h3, u.uid)
				log_msg(p, "%s: %s sofre %d." % [name, nm(t3), n])
				damage(t3, n, u)
				settle()
		"debuff", "silence", "root", "mark":
			var txt = "marque 1 inimigo (+%d de dano contra ele)" % n
			if e["t"] == "debuff":
				txt = "-%d de ataque em 1 inimigo" % n
			elif e["t"] == "silence":
				txt = "1 inimigo perde a habilidade neste round"
			elif e["t"] == "root":
				txt = "1 inimigo não pode se mover até o fim do próximo round"
			var h4 = await pick_hex(p, "%s: %s (até %d casas)." % [name, txt, r], en, "enemy")
			if h4 != null:
				var t4 = unit_at(h4)
				emitfx({"t": "passive", "kind": "curse", "uid": t4.uid})
				abfx(e["t"], h4, u.uid)
				match e["t"]:
					"debuff":
						t4.fx.append({"k": "atk", "v": -n, "until": "end"})
					"silence":
						t4.fx.append({"k": "silence", "v": 1, "until": "end"})
					"root":
						t4.fx.append({"k": "root", "end": round_no + 1})
					"mark":
						t4.fx.append({"k": "mark", "v": n, "until": "end"})
				log_msg(p, "%s: %s afetado." % [name, nm(t4)])
		"heal":
			var who = e.get("who", "")
			var ts5 = allies_of(u, e.get("self", false)).filter(func(x): return DB.dist(x.pos(), u.pos()) <= r and match_who(x, who) and x.hp < x.maxhp)
			var h5 = await pick_hex(p, "%s: restaure %d de Vida de 1 aliado a até %d casas." % [name, n, r], ts5, "ally")
			if h5 != null:
				var t5 = unit_at(h5)
				abfx("heal", h5, u.uid)
				heal(t5, n)
				log_msg(p, "%s: %s restaura Vida." % [name, nm(t5)])
		"buff":
			var ts6 = allies_of(u).filter(func(x): return DB.dist(x.pos(), u.pos()) <= r)
			var h6 = await pick_hex(p, "%s: 1 aliado a até %d casas recebe +%d de ataque neste round." % [name, r, n], ts6, "ally")
			if h6 != null:
				abfx("buff", h6, u.uid)
				unit_at(h6).fx.append({"k": "atk", "v": n, "until": "end"})
				emitfx({"t": "passive", "kind": "power", "uid": unit_at(h6).uid})
		"discount":
			P[p]["discount"] = true
			log_msg(p, "%s: a próxima implantação de um Fauriano neste round entra com as 2 ações." % name)
		"veil":
			u.fx.append({"k": "veil", "v": 1, "until": "start"})
			abfx("veil", u.pos(), u.uid)
			emitfx({"t": "passive", "kind": "shield", "uid": u.uid})
			log_msg(p, "%s: não pode ser alvo de ataques até o próximo round." % name)
		"mine":
			var ops = adj_free(u.pos()).filter(func(h7): return not mines.any(func(m): return m["h"] == h7))
			var h7b = await pick_hex(p, "%s: marque 1 casa livre adjacente para a mina." % name, ops, "place")
			if h7b != null:
				abfx("mine", h7b, u.uid)
				mines = mines.filter(func(m): return m["src"] != u.uid)
				mines.append({"owner": p, "h": h7b, "n": n + (1 if terra_on(p) else 0), "src": u.uid})
				log_msg(p, "%s: mina posicionada." % name)
		"barrier":
			var h8 = await pick_hex(p, "%s: escolha uma casa livre adjacente para a Barreira." % name, adj_free(u.pos()), "place")
			if h8 != null:
				var nn = n + (2 if terra_on(p) else 0)
				abfx("barrier", h8, u.uid)
				_make_barrier(p, h8, nn)
				log_msg(p, "%s: Barreira com %d de Vida." % [name, nn])
		"nudgeAlly":
			var ts9 = allies_of(u).filter(func(x): return DB.dist(x.pos(), u.pos()) <= r and not step_free(x.pos()).is_empty() and not rooted(x))
			var h9 = await pick_hex(p, "%s: escolha 1 aliado a até %d casas para mover 1 casa." % [name, r], ts9, "ally", true)
			if h9 != null:
				var t9 = unit_at(h9)
				var d9 = await pick_hex(p, "Para onde %s vai?" % nm(t9), step_free(t9.pos()), "move")
				if d9 != null:
					abfx("dash", t9.pos(), u.uid)
					await move_unit(t9, d9)
		"pullAlly":
			var spots = adj_free(u.pos())
			if not spots.is_empty():
				var who2 = e.get("who", "")
				var ts10 = allies_of(u).filter(func(x): return DB.dist(x.pos(), u.pos()) <= r and DB.dist(x.pos(), u.pos()) > 1 and match_who(x, who2))
				var h10 = await pick_hex(p, "%s: escolha 1 aliado a até %d casas para trazer ao lado." % [name, r], ts10, "ally", true)
				if h10 != null:
					var t10 = unit_at(h10)
					var d10 = await pick_hex(p, "Escolha a casa ao lado para %s." % nm(t10), spots, "move")
					if d10 != null:
						abfx("portal", t10.pos(), u.uid)
						abfx("portal", d10, u.uid)
						await move_unit(t10, d10)


# ================= táticas =================
func active_unit() -> Variant:
	return by_uid(act["uid"]) if act != null else null


func tactic_playable(p: int, id: String) -> bool:
	var A = act
	if A == null or A["p"] != p or A["tactic"] or not P[p]["hand"].has(id):
		return false
	var u = active_unit()
	if u == null or u.st != "field":
		return false
	if int(DB.tactics[id]["cost"]) > A["actions"]:
		return false
	match id:
		"flanquear":
			return not rooted(u) and not step_free(u.pos()).is_empty()
		"troca":
			return allies_of(u).any(func(x): return DB.dist(x.pos(), u.pos()) == 1)
		"avanco":
			return allies_of(u, true).any(func(x): return not step_free(x.pos()).is_empty() and not rooted(x))
		"propulsor", "placas", "lente":
			return true
		"reparo":
			return u.hp < u.maxhp
		"dados":
			return P[p]["deck"].size() + P[p]["discard"].size() > 0
		"fogo":
			return not A["attacked"] and not A["cant_attack"]
		"pulso":
			return enemies_of(u).any(func(x): return x.eq != "" and DB.dist(x.pos(), u.pos()) <= 2 and los(u.pos(), x.pos()))
		"granada":
			return not granada_opts(u).is_empty()
		"sinalizador":
			return enemies_of(u).any(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) <= 4 and los(u.pos(), x.pos()))
		"adrenalina":
			return u.hp > 1
		"barreira":
			return not adj_free(u.pos()).is_empty()
		"gancho":
			return not gancho_targets(u).is_empty()
		"camuflagem":
			return not has_fx(u, "veil")
		"onda":
			return enemies_of(u).any(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) == 1 and push_dest(x, u.pos()) != null)
		"orbital":
			return enemies_of(u).any(func(x): return DB.dist(x.pos(), u.pos()) <= 5)
		"kit":
			return allies_of(u, true).any(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) <= 2 and x.hp < x.maxhp)
		"ultimo":
			return u.hp * 2 <= u.maxhp and not A["attacked"] and not A["cant_attack"]
		"resgate":
			return allies_of(u).any(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) <= 4)
		"quantica":
			return not quantica_allies(u).is_empty() and not quantica_enemies(u).is_empty()
		"interceptar":
			return not P[1 - p]["hand"].is_empty()
		"grito":
			return true
		"evacuacao":
			return evac_unit(p) != null
		"execucao":
			return not execucao_targets(u).is_empty()
		"contra":
			return field_count(p) < field_count(1 - p)
		"rede":
			return not rede_targets(u).is_empty()
	return false


func field_count(p: int) -> int:
	return units.filter(func(x): return x.owner == p and x.st == "field" and not x.barrier).size()


func quantica_allies(u) -> Array:
	return allies_of(u, true).filter(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) <= 3)


func quantica_enemies(u) -> Array:
	return enemies_of(u).filter(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) <= 3 and not imprisoned(x))


func evac_unit(p: int) -> Variant:
	for i in range(fallen.size() - 1, -1, -1):
		var x = by_uid(fallen[i])
		if x != null and x.owner == p and x.st == "dead" and not x.is_cmd and not x.barrier:
			return x
	return null


func execucao_targets(u) -> Array:
	return enemies_of(u).filter(func(x): return not x.barrier and not x.is_cmd and x.hp <= 3 and DB.dist(x.pos(), u.pos()) == 1)


func rede_targets(u) -> Array:
	return enemies_of(u).filter(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) <= 3 and los(u.pos(), x.pos()))


func _swap(a, b) -> void:
	var pa = a.pos()
	var pb = b.pos()
	a.q = pb.x
	a.r = pb.y
	b.q = pa.x
	b.r = pa.y
	emitfx({"t": "move", "uid": a.uid, "from": pa, "to": pb})
	emitfx({"t": "move", "uid": b.uid, "from": pb, "to": pa})
	await arrive(a)
	await arrive(b)


# casas que a Granada pode mirar (com pelo menos 1 inimigo no raio de 1)
func granada_opts(u) -> Array:
	var out = []
	for h in DB.hexes:
		if DB.dist(h, u.pos()) > 3 or DB.dist(h, u.pos()) < 1 or not los(u.pos(), h):
			continue
		if enemies_of(u).any(func(x): return DB.dist(x.pos(), h) <= 1):
			out.append(h)
	return out


func gancho_dest(u, t) -> Variant:
	var best: Variant = null
	for h in step_free(t.pos()):
		if DB.dist(h, u.pos()) < DB.dist(t.pos(), u.pos()) and can_step(t.pos(), h):
			if best == null or DB.dist(h, u.pos()) < DB.dist(best, u.pos()):
				best = h
	return best


func gancho_targets(u) -> Array:
	return enemies_of(u).filter(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) >= 2 and DB.dist(x.pos(), u.pos()) <= 3 and los(u.pos(), x.pos()) and gancho_dest(u, x) != null)


func play_tactic(p: int, id: String) -> bool:
	if not tactic_playable(p, id):
		return false
	var A = act
	var u = active_unit()
	var c = DB.tactics[id]
	take_card(p, id)
	A["tactic"] = true
	A["actions"] -= int(c["cost"])
	log_msg(p, "Tática: %s." % c["name"])
	emitfx({"t": "card", "id": id, "p": p})
	match id:
		"flanquear":
			var h = await pick_hex(p, "Flanquear: mova o ativo 1 casa livre.", step_free(u.pos()), "move")
			if h != null:
				await move_unit(u, h)
		"troca":
			var ts = allies_of(u).filter(func(x): return DB.dist(x.pos(), u.pos()) == 1)
			var h2 = await pick_hex(p, "Troca de Posições: escolha o aliado adjacente.", ts, "ally")
			if h2 != null:
				var t = unit_at(h2)
				var a = u.pos()
				u.q = t.q
				u.r = t.r
				t.q = a.x
				t.r = a.y
				emitfx({"t": "move", "uid": u.uid, "from": a, "to": u.pos()})
				emitfx({"t": "move", "uid": t.uid, "from": u.pos(), "to": a})
				await arrive(u)
				await arrive(t)
		"avanco":
			var done = []
			for i in range(2):
				var ts2 = allies_of(u, true).filter(func(x): return not done.has(x.uid) and not step_free(x.pos()).is_empty() and not rooted(x))
				var h3 = await pick_hex(p, "Avanço Coordenado: escolha o %dº aliado (ou pule)." % (i + 1), ts2, "ally", true)
				if h3 == null:
					break
				var t2 = unit_at(h3)
				done.append(t2.uid)
				var d = await pick_hex(p, "Para onde %s vai?" % nm(t2), step_free(t2.pos()), "move")
				if d != null:
					await move_unit(t2, d)
				if winner != NONE:
					break
		"propulsor", "placas", "lente":
			u.eq = id
			log_msg(p, "%s equipou %s." % [nm(u), c["name"]])
		"reparo":
			heal(u, 4)
		"dados":
			draw_cards(p, 2)
			var dc = await ask(p, {"t": "card", "text": "Dados de Combate: descarte 1 carta da mão.", "opts": P[p]["hand"].duplicate(), "optional": false})
			if dc == null or not P[p]["hand"].has(dc):
				dc = P[p]["hand"][0]
			take_card(p, dc)
		"fogo":
			A["fogo"] = 2
		"pulso":
			var ts3 = enemies_of(u).filter(func(x): return x.eq != "" and DB.dist(x.pos(), u.pos()) <= 2 and los(u.pos(), x.pos()))
			var h4 = await pick_hex(p, "Pulso de Interferência: escolha o inimigo.", ts3, "enemy")
			if h4 != null:
				var t3 = unit_at(h4)
				log_msg(p, "%s perdeu %s." % [nm(t3), DB.tactics[t3.eq]["name"]])
				t3.eq = ""
		"granada":
			var hg = await pick_hex(p, "Granada: escolha a casa do centro da explosão.", granada_opts(u), "blast")
			if hg != null:
				abfx("blast", hg, u.uid)
				await pace()
				for e in enemies_of(u).filter(func(x): return DB.dist(x.pos(), hg) <= 1):
					damage(e, 1, u)
				await settle()
		"sinalizador":
			var ts5 = enemies_of(u).filter(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) <= 4 and los(u.pos(), x.pos()))
			var hs5 = await pick_hex(p, "Sinalizador: marque o inimigo.", ts5.map(func(x): return x.pos()), "enemy")
			if hs5 != null:
				var t5 = unit_at(hs5)
				t5.fx.append({"k": "mark", "v": 1, "until": "end"})
				abfx("mark", hs5, u.uid)
				log_msg(p, "%s foi marcado: +1 de dano contra ele neste round." % nm(t5))
		"adrenalina":
			abfx("buff", u.pos(), u.uid)
			damage(u, 1, null)
			A["actions"] += 1
			log_msg(p, "%s ganhou +1 ação." % nm(u))
			await settle()
		"barreira":
			var hb = await pick_hex(p, "Barreira Portátil: escolha a casa.", adj_free(u.pos()), "place")
			if hb != null:
				abfx("barrier", hb, u.uid)
				_make_barrier(p, hb, 3)
		"gancho":
			var ts6 = gancho_targets(u)
			var hh = await pick_hex(p, "Gancho Magnético: escolha o inimigo para puxar.", ts6.map(func(x): return x.pos()), "enemy")
			if hh != null:
				var t6 = unit_at(hh)
				abfx("hook", hh, u.uid)
				log_msg(p, "%s foi puxado." % nm(t6))
				await move_unit(t6, gancho_dest(u, t6))
		"camuflagem":
			u.fx.append({"k": "veil", "v": 1, "until": "start"})
			abfx("veil", u.pos(), u.uid)
			log_msg(p, "%s sumiu de vista até o próximo round." % nm(u))
		"onda":
			abfx("quake", u.pos(), u.uid)
			for t7 in enemies_of(u).filter(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) == 1):
				var d7 = push_dest(t7, u.pos())
				if d7 != null:
					await move_unit(t7, d7)
					log_msg(p, "Onda de Choque: %s foi empurrado." % nm(t7))
					if winner != NONE:
						break
		"orbital":
			var ts8 = enemies_of(u).filter(func(x): return DB.dist(x.pos(), u.pos()) <= 5)
			var ho = await pick_hex(p, "Bombardeio Orbital: escolha o alvo.", ts8.map(func(x): return x.pos()), "enemy")
			if ho != null:
				abfx("orbital", ho, u.uid)
				await pace()
				damage(unit_at(ho), 3, u)
				await settle()
		"kit":
			abfx("heal", u.pos(), u.uid)
			for x in allies_of(u, true).filter(func(y): return not y.barrier and DB.dist(y.pos(), u.pos()) <= 2):
				heal(x, 2)
		"ultimo":
			A["fogo"] += 3
			abfx("buff", u.pos(), u.uid)
			log_msg(p, "%s junta as últimas forças: +3 de dano no próximo ataque." % nm(u))
		"resgate":
			var tr = allies_of(u).filter(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) <= 4)
			var hr = await pick_hex(p, "Teletransporte de Resgate: escolha o aliado para trocar de lugar.", tr.map(func(x): return x.pos()), "ally")
			if hr != null:
				var tx = unit_at(hr)
				abfx("dash", u.pos(), u.uid)
				abfx("dash", hr, u.uid)
				log_msg(p, "%s e %s trocaram de lugar." % [nm(u), nm(tx)])
				await _swap(u, tx)
		"quantica":
			var ha = await pick_hex(p, "Troca Quântica: escolha o aliado.", quantica_allies(u).map(func(x): return x.pos()), "ally")
			if ha != null:
				var xa = unit_at(ha)
				var he = await pick_hex(p, "Troca Quântica: escolha o inimigo que vai para o lugar de %s." % nm(xa), quantica_enemies(u).map(func(x): return x.pos()), "enemy")
				if he != null:
					var xe = unit_at(he)
					abfx("sonic", ha, u.uid)
					abfx("sonic", he, u.uid)
					log_msg(p, "Troca Quântica: %s e %s trocaram de lugar." % [nm(xa), nm(xe)])
					await _swap(xa, xe)
		"interceptar":
			var oh = P[1 - p]["hand"]
			if not oh.is_empty():
				var cid = oh[randi() % oh.size()]
				oh.erase(cid)
				P[p]["hand"].append(cid)
				log_msg(p, "Interceptar: roubou %s do oponente." % DB.tactics[cid]["name"])

		"grito":
			for x in allies_of(u, true).filter(func(y): return not y.barrier):
				x.fx.append({"k": "atk", "v": 1, "until": "end"})
				abfx("buff", x.pos(), u.uid)
			log_msg(p, "Grito de Guerra: +1 ATQ para todos até o fim do round.")
		"evacuacao":
			var ev = evac_unit(p)
			if ev != null:
				ev.st = "reserve"
				ev.hp = int(ceil(ev.maxhp / 2.0))
				ev.fx = []
				ev.eq = ""
				ev.dying = null
				fallen.erase(ev.uid)
				emitfx({"t": "revive", "uid": ev.uid})
				log_msg(p, "Evacuação Médica: %s voltou para a reserva com %d de Vida." % [nm(ev), ev.hp])
		"execucao":
			var hx = await pick_hex(p, "Golpe de Misericórdia: escolha o inimigo.", execucao_targets(u).map(func(x): return x.pos()), "enemy")
			if hx != null:
				var tx2 = unit_at(hx)
				abfx("blast", hx, u.uid)
				log_msg(p, "Golpe de Misericórdia em %s." % nm(tx2))
				damage(tx2, tx2.hp, u)
				settle()
		"contra":
			A["actions"] += 1
			draw_cards(p, 1)
			abfx("buff", u.pos(), u.uid)
			log_msg(p, "Contraofensiva: +1 ação e 1 carta.")
		"rede":
			var hn = await pick_hex(p, "Rede de Contenção: escolha o inimigo.", rede_targets(u).map(func(x): return x.pos()), "enemy")
			if hn != null:
				var tn = unit_at(hn)
				tn.fx.append({"k": "root", "end": round_no + 1})
				abfx("glue", hn, u.uid)
				log_msg(p, "%s está preso na rede até o fim do próximo round." % nm(tn))
	changed.emit()
	return true


# ================= explicações (por que não dá) =================
func t_name(h: Vector2i) -> String:
	var t = terr(h)
	return tt_of(t["k"])["name"] + (" (altura %d)" % t["h"] if int(t["h"]) > 0 else "")


func why_no_attack(a, t, fpos = null) -> Variant:
	var ap = a.pos() if fpos == null else fpos
	var live = is_live(a)
	if live and act["attacked"]:
		return {"s": "já atacou", "l": "%s já atacou neste turno. Cada peça ataca no máximo 1 vez por turno." % nm(a)}
	if live and act["cant_attack"]:
		return {"s": "não pode atacar", "l": "%s não pode atacar neste turno." % nm(a)}
	if live and act["actions"] < 1:
		return {"s": "sem ações", "l": "Sem ações restantes neste turno."}
	if imprisoned(t):
		return {"s": "preso no cristal", "l": "%s está preso na Prisão de Cristal e não pode ser atacado até o fim do próximo round." % nm(t)}
	if imprisoned(a):
		return {"s": "preso", "l": "%s está preso na Prisão de Cristal e não pode atacar." % nm(a)}
	if has_fx(t, "veil"):
		return {"s": "protegido", "l": "%s está protegido e não pode ser alvo até o próximo round." % nm(t)}
	var d = DB.dist(ap, t.pos())
	var rng = range_of(a, ap, t)
	if d > rng:
		return {"s": "longe · %d casas" % d, "l": "Longe demais: %s está a %d casas e o alcance de %s é %d." % [nm(t), d, nm(a), rng]}
	if d == 1 and abs(h_of(ap) - h_of(t.pos())) > 1:
		return {"s": "desnível", "l": "Desnível de %d níveis: ataque corpo a corpo só funciona com até 1 nível de diferença." % abs(h_of(ap) - h_of(t.pos()))}
	if not los(ap, t.pos()):
		var b = los_blocker(ap, t.pos())
		return {"s": "sem linha", "l": "Sem linha de tiro: %s está no caminho e é mais alto que %s e o alvo." % [t_name(b) if b != null else "um obstáculo", nm(a)], "block": b, "from": ap, "to": t.pos()}
	if not attack_targets(a, ap).has(t):
		if _guarded(t):
			return {"s": "guardado", "l": "%s está guardado por um aliado ao lado dele." % nm(t)}
		return {"s": "provocação", "l": "Provocação: precisa atacar primeiro o inimigo que está colado em você."}
	return null


func why_no_move(u, h: Vector2i) -> String:
	if is_live(u) and act["moved"]:
		return "%s já se moveu neste turno. Cada ação (mover, atacar, carta) só pode ser usada 1 vez por turno." % nm(u)
	var left = act["actions"] if is_live(u) else 2
	if left < 1:
		return "Sem ações restantes neste turno."
	if rooted(u):
		return "%s está preso e não pode se mover neste round." % nm(u)
	var o = unit_at(h)
	if o != null:
		return "Casa ocupada por %s." % nm(o)
	var t = terr(h)
	if not tt_of(t["k"]).get("pass", 0):
		return "%s: ninguém entra nessa casa." % tt_of(t["k"])["name"]
	for m in move_opts(u, 99):
		if m["h"] == h:
			return "Longe demais: chegar em %s custa %d de movimento e %s tem %d. Terreno difícil e subidas custam mais." % [t_name(h), m["c"], nm(u), mov_of(u)]
	return "Não há caminho até %s: só dá para subir 1 nível por vez e descer no máximo 1." % t_name(h)


# ================= previsão de dano =================
func preview_damage(a, t, fpos = null) -> Dictionary:
	var ap = a.pos() if fpos == null else fpos
	var save = a.pos()
	a.q = ap.x
	a.r = ap.y
	var tm = terrain_mods(a, t)
	var total = atk_of(a, t)
	var parts = ["ATQ %d" % total]
	if is_live(a) and act["fogo"] > 0:
		total += act["fogo"]
		parts.append("+%d Fogo" % act["fogo"])
	var mk = fx_sum(t, "mark")
	if mk > 0:
		total += mk
		parts.append("+%d alvo marcado" % mk)
	if K(a).has("firstAtk") and not a.first_used:
		total += int(K(a)["firstAtk"])
		parts.append("+%d emboscada" % int(K(a)["firstAtk"]))
	if tm["atk"] != 0:
		total += tm["atk"]
		parts.append(("+%d altura" % tm["atk"]) if tm["atk"] > 0 else ("-%d altura" % abs(tm["atk"])))
	if tm["cover"] > 0:
		total -= tm["cover"]
		parts.append("-%d abrigo" % tm["cover"])
	if tm["forest"] > 0:
		total -= tm["forest"]
		parts.append("-%d floresta" % tm["forest"])
	var red = reduction_of(t, true)
	if red > 0:
		total -= red
		parts.append("-%d defesas do alvo" % red)
	a.q = save.x
	a.r = save.y
	var dmg = max(0, total)
	return {"dmg": dmg, "parts": parts, "kills": dmg >= t.hp, "high": tm["atk"] > 0, "cover": tm["cover"] > 0}
