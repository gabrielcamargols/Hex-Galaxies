class_name Game
extends RefCounted
## Motor de regras do Hex Galaxies (HEX 0.3 adaptado): 2 ações por turno, relevo, Tarhut e Posto.

signal question(p, q)      # o motor pergunta algo ao jogador humano
signal answered(v)         # a interface responde
signal changed             # o estado mudou: redesenhar
signal fx_event(e)         # efeitos visuais (dano, cura, dunas, vermes...)

const DUNE_EVERY = 3
const WORM_EVERY = 3
const HOLE_ROUNDS = 2
const HOLE_DMG = 4
const FALL_DMG = 1
const CMD_ROUND = 4          # round em que os comandantes entram
const CORE_ROUNDS = [2, 4, 6, 8]   # rounds em que o núcleo surge (fica 2 rounds)
const NONE = -1
const DRAW = 2
# Recarga das habilidades ativas comuns (em rounds). 1 = a ativa usada no round 3 volta no round 4.
# É um valor provisório de teste dos Valakianos, não uma decisão final: mude aqui para ajustar.
const ABIL_RECHARGE = 1


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
	var charge: bool = false          # Tork: soco carregado neste round
	var luna_used: bool = false       # Luna Nari: já chamou reforços
	var discs: Array = []             # Zaboo: discos já tocados
	var countered: Dictionary = {}    # Skarp: uid do atacante -> round do contra-ataque
	var ult_round: int = -1           # ativas "1 vez por round": round em que já usou
	var hitters: Array = []           # uids de quem já atacou esta peça neste round (Morteiro)
	var hitters_round: int = 0
	var gloria_round: int = 0         # Comandante Krieg: round em que já comprou pela Glória do Clã
	var venoms: int = 0               # Bayak: marcas de veneno já aplicadas na partida
	var dose_used: bool = false       # Médico Krieg: Última Dose já usada
	var crystal: String = ""          # Valak: cristal (verde, azul, roxo) - barreira neutra de 1 de Vida
	var exp: int = 0                  # barreira temporária: some ao fim deste round (0 = permanente)
	var soft: bool = false            # barreira de raízes: bloqueia movimento, mas não tiros e não dá abrigo
	var sp_owner: int = -1            # cristal especial do Rei da Mina: time dele (-1 = cristal natural)
	var block: bool = false           # bloco móvel nascido de um terreno rebaixado pelo Rei

	func pos() -> Vector2i:
		return Vector2i(q, r)


var cine: Callable = Callable()   # main.gd: cinemática antes de os comandantes entrarem
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
var warn_kind: String = ""      # o que as casas marcadas (tremors) vão virar: raiz, fratura, avalanche
var fire: Dictionary = {}        # Abnara: casas de mata em chamas -> round em que começaram
var dyn: Dictionary = {}         # camada dinâmica de terreno dos mapas do dossiê: hex -> {k, until, then}
var res: Dictionary = {}  # Vector2i -> tipo
var final_score: Dictionary = {}
var terr_map: Dictionary = {}
var blocks: Dictionary = {}
var plain: Dictionary = {"k": "plano", "h": 0}
var terr_ver: int = 0
var earth: Dictionary = {}  # Vector2i -> ajuste de altura (Erguer a Terra)
var tree: SceneTree = null
var pace_time: float = 0.28
# ---- online: os dois aparelhos rodam a mesma partida e trocam as jogadas ----
signal remote_ans          # chegou a resposta de uma pergunta feita ao outro jogador
var rng := RandomNumberGenerator.new()   # todo sorteio do jogo passa por aqui (mesma semente nos dois)
var net_send: Callable = Callable()       # envia {"t": "cmd"/"ans", ...} para o outro aparelho
var remote: Array = [false, false]        # lado controlado pelo outro aparelho
var ans_buf: Array = []                   # respostas recebidas e ainda não usadas
var replay: int = 0                       # > 0: repetindo uma jogada que veio do outro aparelho
var net_depth: int = 0
var tut: bool = false                     # partida do tutorial
var pre_hex: Variant = null   # casa onde a carta foi solta (arrastar e soltar)
var tac_fx: Variant = null    # tática esperando o alvo para mostrar o efeito
const TAC_SELF = ["propulsor", "placas", "lente", "reparo", "camuflagem"]
var undo: Variant = null        # último movimento que ainda pode ser desfeito
var core: Variant = null        # núcleo ativo (casa) ou null
var core_until: int = 0
var core_next: Variant = null   # onde o próximo núcleo vai surgir (mostrado antes)
var core_next_round: int = 0
var fallen: Array = []
var bananas: Dictionary = {}   # Karo: casa -> {"t": cura/dano/alcance, "p": dono}
var bomb_queue: Array = []     # Rappy: bombas a esconder (uid do Rappy)  # uids dos personagens derrotados, em ordem
var guard_round: Dictionary = {}  # uid -> round em que já protegeu (guardOnce)
const CLOCK_START = 600.0     # relógio de xadrez: 10 minutos para cada jogador
var clock_on: bool = false
var clock: Array = [CLOCK_START, CLOCK_START]
var flagged: int = NONE       # jogador que estourou o tempo
# ===== Valak (caverna de cristais) =====
var hole: Array = []          # casas do buraco da garra
var vib: int = 0              # medidor de vibração
var carts: Array = []         # [{"h": Vector2i, "track": int}]
var tracks: Array = []        # trilhos (listas ordenadas de casas)
var track_loop: Array = []    # true = trilho fechado (anel): o carrinho dá a volta
const NEUTRAL = 2             # dono dos cristais (inimigo dos dois lados)
var czones: Array = []    # Zonas de Cristal (Lithari): [{h, owner, until}] inimigos que entram ficam Lentos
var fires: Array = []     # Incendiário: [{h, owner, until}] casas em chamas
var portals: Array = []   # Guarda dos Portais: [{a, b, uid, owner}] a = ENTRADA, b = SAÍDA
var portal_pick_a: Variant = null   # entrada já escolhida (a IA usa para pontuar a saída)
var tunnels: Array = []   # Rei da Mina: [{a, b, owner}] entradas de túnel ligadas
var shells: Array = []    # Rádio: [{h, owner, round, src}] artilharia que cai no início do próximo round


# ================= montagem =================
func setup(sides: Array, mid: String) -> void:
	# sides: [{fac, picks:[5 ids], start:[{id, h:Vector2i}]}, x2]
	map_id = mid
	DB.set_map(map_id)
	var def = DB.maps[map_id]
	if def.has("dunes"):
		dune = rng.randi() % def["dunes"].size()
	if def.has("res"):
		for rr in def["res"]:
			res[Vector2i(rr[0], rr[1])] = rr[2]
			res[Vector2i(-rr[0], -rr[1])] = rr[2]
	_setup_valak()
	load_map()
	for p in range(2):
		var s = sides[p]
		var deck = DB.tactic_ids.duplicate()
		_shuffle(deck)
		var cmd_id = s.get("cmd", DB.factions[s["fac"]]["cmd"])
		P.append({"fac": s["fac"], "cmd": cmd_id, "mix": s.get("mix", false), "deck": deck, "hand": [], "discard": [], "passed": false, "obj_used": {}, "discount": false, "scarabs": 0})
		_mk(cmd_id, p, "off")
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
	for e in def.get("half", []):
		terr_map[Vector2i(e[0], e[1])] = {"k": e[2], "h": e[3]}
		terr_map[Vector2i(-e[0], -e[1])] = {"k": e[2], "h": e[3]}
	# mapas do dossiê de level design (Abnara, Gor'Aida): todas as casas listadas, sem espelho automático
	for e in def.get("cells", []):
		terr_map[Vector2i(e[0], e[1])] = {"k": e[2], "h": e[3]}
	for dh2 in dyn.keys():
		terr_map[dh2] = {"k": dyn[dh2]["k"], "h": int(terr_map.get(dh2, plain)["h"])}
	if def.has("dunes"):
		var dh = dune_heights(dune)
		for h in dh.keys():
			if not terr_map.has(h):
				terr_map[h] = {"k": "duna", "h": dh[h]}
	for b in holes:
		terr_map[b["h"]] = {"k": "buraco", "h": 0}
	for hh in hole:
		terr_map[hh] = {"k": "fosso", "h": 0}
	for eh in earth.keys():
		var base_t = terr_map.get(eh, plain)
		terr_map[eh] = {"k": base_t["k"], "h": clampi(int(base_t["h"]) + int(earth[eh]), 0, max(3, int(base_t["h"])))}
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
	for e in def.get("half", []):
		base[Vector2i(e[0], e[1])] = true
		base[Vector2i(-e[0], -e[1])] = true
	for pk in def["dunes"][idx]["peaks"]:
		var hh = int(pk[2])
		for c in [Vector2i(pk[0], pk[1]), Vector2i(-pk[0], -pk[1])]:
			# cone: cada anel afastado do pico desce 1 nível, então dá para subir degrau a degrau
			for dq in range(-hh, hh + 1):
				for dr in range(-hh, hh + 1):
					var cell = c + Vector2i(dq, dr)
					var dd = DB.dist(c, cell)
					if dd < hh:
						_put_dune(out, base, cell, hh - dd)
	return out


func _put_dune(out: Dictionary, base: Dictionary, h: Vector2i, v: int) -> void:
	if not DB.in_board(h) or base.has(h) or DB.in_entry(0, h) or DB.in_entry(1, h):
		return
	out[h] = max(out.get(h, 0), v)


func tt_of(k: String) -> Dictionary:
	return DB.tt[k]


# buraco de verme ou fenda de gelo: ninguém fica de pé ali (nem quem escala)
func is_pit(h: Vector2i) -> bool:
	var k = terr(h)["k"]
	return k == "buraco" or tt_of(k).get("pit", 0) == 1


func terr(h: Vector2i) -> Dictionary:
	return terr_map.get(h, plain)


func h_of(h: Vector2i) -> int:
	return int(terr(h)["h"])


# altura onde a peça fica de pé (no topo do obstáculo, para quem escala)
func stand_h(h: Vector2i) -> int:
	if blocks.has(h) and not is_pit(h):
		return h_of(h) + int(tt_of(terr(h)["k"]).get("top", 0))
	return h_of(h)


func can_step(a: Vector2i, b: Vector2i, climber: bool = false, extra: int = 0) -> bool:
	var ta = terr(a)
	var tb = terr(b)
	if climber:
		return not is_pit(b)
	if not tt_of(tb["k"]).get("pass", 0):
		return false
	var dh = int(tb["h"]) - int(ta["h"])
	if dh <= -2 or dh >= 2 + extra:
		return false
	if extra > 0 and dh >= 1:
		return true   # Rota Traçada: sobe 1 nível a mais
	if dh == 1 and not (tt_of(tb["k"]).get("climb", 0) or ta["k"] == "rampa"):
		return false
	return true


func step_cost(a: Vector2i, b: Vector2i, climber: bool = false) -> int:
	if climber:
		return max(1, int(tt_of(terr(b)["k"])["c"])) + max(0, stand_h(b) - stand_h(a))
	if terr(b)["k"] == "duna":
		# subir a duna: 1 por degrau; os 2 últimos níveis (areia fofa no topo) custam 2
		return 1 + (1 if h_of(b) >= 4 and h_of(b) > h_of(a) else 0) + (2 if tt_of(terr(a)["k"]).get("sink", 0) else 0)
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


# barreira que bloqueia tiros e dá abrigo (a de raízes só bloqueia o movimento)
func solid_barrier_at(h: Vector2i) -> bool:
	for u in units:
		if u.barrier and not u.soft and u.st == "field" and u.q == h.x and u.r == h.y:
			return true
	return false


func top_of(h: Vector2i) -> int:
	return h_of(h) + max(int(tt_of(terr(h)["k"]).get("top", 0)), 2 if solid_barrier_at(h) else 0)


func is_free(h: Vector2i) -> bool:
	return DB.in_board(h) and not blocks.has(h) and unit_at(h) == null and not cart_at(h)


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


# ---- controle Lithari: Lento, Enraizado e Zona de Cristal ----
func slow_aura_hit(u) -> bool:
	if u.barrier:
		return false
	for g in units:
		if g.owner == u.owner or g.st == "dead" or g.barrier:
			continue
		var sn = K(g).get("slowNear", null)
		if sn == null or silenced(g):
			continue
		if g.st != "field" and not sn.get("cmd", false):
			continue
		var pt = g.pos() if g.st == "field" else DB.entry_c[g.owner]
		if DB.dist(pt, u.pos()) <= int(sn["r"]):
			return true
	return false


func slowed(u) -> bool:
	return not u.barrier and (has_fx(u, "slow") or slow_aura_hit(u))


# preso no lugar por Lento/Enraizado (para sinergias de dano)
func held(u) -> bool:
	return rooted(u) or slowed(u)


func apply_slow(t, src = null) -> void:
	if t == null or t.barrier or t.st != "field" or has_fx(t, "slow"):
		return
	t.fx.append({"k": "slow", "until": "end"})
	abfx("glue", t.pos(), src.uid if src != null else -1)
	log_msg(t.owner, "%s ficou Lento (-1 MOV até o fim do round)." % nm(t))


# Enraizado até o fim do próximo round; quem acabou de se soltar fica imune por 1 round
func apply_root(t, src = null) -> bool:
	if t == null or t.barrier or t.st != "field" or has_fx(t, "rootimm") or rooted(t):
		return false
	t.fx.append({"k": "root", "end": round_no + 1})
	t.fx.append({"k": "rootimm", "till": round_no + 3})
	abfx("glue", t.pos(), src.uid if src != null else -1)
	log_msg(t.owner, "%s ficou Enraizado até o fim do próximo round." % nm(t))
	return true


func add_czone(owner: int, h: Vector2i, rounds: int = 2) -> void:
	if not DB.in_board(h):
		return
	czones = czones.filter(func(z): return z["h"] != h)
	czones.append({"h": h, "owner": owner, "until": round_no + rounds - 1})
	var mine = czones.filter(func(z): return z["owner"] == owner)
	while mine.size() > 12:
		czones.erase(mine.pop_front())
	emitfx({"t": "czone", "h": h})


func add_czone_area(owner: int, c: Vector2i, rad: int, rounds: int = 2) -> void:
	for h in DB.hexes:
		if DB.dist(h, c) <= rad and tt_of(terr(h)["k"]).get("pass", 0):
			add_czone(owner, h, rounds)


# a casa está em Zona de Cristal de qual dono? (-1 = nenhum). Inclui a aura do Behemot.
func czone_owner(h: Vector2i) -> int:
	for z in czones:
		if z["h"] == h and int(z["until"]) >= round_no:
			return int(z["owner"])
	for g in units:
		if g.st == "field" and not g.barrier and K(g).has("zoneAura") and not silenced(g) and DB.dist(g.pos(), h) <= int(K(g)["zoneAura"]):
			return g.owner
	return -1


func match_who(u, who) -> bool:
	if who == null or who == "":
		return true
	if u.barrier:
		return false
	var c = DB.cards[u.cid]
	return c["f"] == who or c.get("clan", "") == who


func nm(u) -> String:
	if u.crystal != "":
		return ("Cristal especial " if u.sp_owner >= 0 else "Cristal ") + u.crystal
	if u.block:
		return "Bloco de pedra"
	return "Barreira" if u.barrier else DB.cards[u.cid]["name"]


func mov_of(u) -> int:
	var m = int(DB.cards[u.cid]["mov"]) + (1 if u.eq == "propulsor" else 0) + fx_sum(u, "mov")
	var ls = int(K(u).get("lastStand", 0))
	if ls > 0 and field_count(u.owner) <= 3:
		m = max(m, ls)
	if not u.barrier:
		if has_fx(u, "slow") or slow_aura_hit(u):
			m = max(1, m - 1)
		for g in units:
			if g.st == "field" and g.owner != u.owner and K(g).has("anchor") and not silenced(g) and DB.dist(g.pos(), u.pos()) == 1:
				m = min(m, 1)
				break
	if m > 1 and not u.barrier:
		for g in units:
			if g.st == "field" and g.owner != u.owner and K(g).has("slowAura") and DB.dist(g.pos(), u.pos()) == 1 and allies_of(g).any(func(x): return DB.dist(x.pos(), g.pos()) == 1 and DB.cards[x.cid]["f"] == DB.cards[g.cid]["f"]):
				m -= 1
				break
	return m


func alc_of(u) -> int:
	return int(DB.cards[u.cid]["alc"]) + (1 if u.eq == "lente" else 0) + fx_sum(u, "alc")


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
	if remote[p]:
		# quem responde é o outro aparelho: espera a resposta chegar pela rede
		while ans_buf.is_empty():
			question.emit(p, q)
			await remote_ans
		return ans_buf.pop_front()
	var v: Variant = null
	if cpu[p]:
		v = AI.answer(self, p, q)
	else:
		question.emit(p, q)
		v = await answered
	if net_send.is_valid():
		net_send.call({"t": "ans", "v": v})
	return v


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


func _pick(arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]


# jogadas: quem joga envia, o outro aparelho repete (jogadas internas não são reenviadas)
func _send_cmd(c: Array) -> void:
	if net_send.is_valid() and replay == 0 and net_depth == 0:
		net_send.call({"t": "cmd", "c": c})


func _run(c: Array, f: Callable) -> Variant:
	if c[0] != "move" and net_depth == 0:
		undo = null
	_send_cmd(c)
	net_depth += 1
	var r = await f.call()
	net_depth -= 1
	return r


# repete uma jogada que veio do outro aparelho
func exec_cmd(c: Array) -> void:
	replay += 1
	var u = by_uid(int(c[1])) if c.size() > 1 and (c[1] is int or c[1] is float) and c[0] != "pass" and c[0] != "tactic" and c[0] != "scarab" else null
	match c[0]:
		"start":
			start_activation(u)
		"end":
			await end_activation()
		"pass":
			await pass_turn(int(c[1]))
		"deploy":
			await deploy(u, c[2], bool(c[3]))
		"move":
			await act_move(u, c[2])
		"attack":
			await act_attack(u, by_uid(int(c[2])))
		"moveatk":
			await act_move_attack(u, c[2], by_uid(int(c[3])) if c[3] != null else null)
		"tunnel":
			await act_tunnel(u, c[2])
		"ult":
			await act_ult(u)
		"manip":
			await act_manip(u)
		"mexit":
			await act_mexit(u)
		"interact":
			await act_interact(u)
		"collect":
			await act_collect(u)
		"tactic":
			await play_tactic(int(c[1]), c[2], c[3])
		"undo":
			undo_move()
		"scarab":
			await act_scarab(int(c[1]), str(c[2]))
		"cart":
			await act_cart(u)
		"flag":
			if winner == NONE:
				flagged = int(c[1])
				winner = 1 - flagged
				changed.emit()
	replay -= 1


# resumo do estado (para conferir que os dois aparelhos estão iguais)
func state_hash() -> int:
	var s = "%d|%d|%d|" % [round_no, cur, winner]
	for u in units:
		s += "%d:%s:%d:%d:%d;" % [u.uid, u.st, u.q, u.r, u.hp]
	for pl in P:
		s += ",".join(pl["hand"]) + "|%d|" % int(pl.get("scarabs", 0))
	return s.hash()


func pick_hex(p: int, text: String, opts: Array, kind: String, optional: bool = false) -> Variant:
	if opts.is_empty():
		return null
	var hs = []
	for o in opts:
		hs.append(o if o is Vector2i else o.pos())
	var h: Variant = null
	if pre_hex != null and hs.has(pre_hex):
		h = pre_hex
		pre_hex = null
	else:
		h = await ask(p, {"t": "hex", "text": text, "opts": hs, "optional": optional, "kind": kind})
	if h == null and not optional:
		h = hs[0]
	if h != null and tac_fx != null:
		emitfx({"t": "tactic_on", "id": tac_fx, "h": h, "p": p})
		tac_fx = null
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
		if k.has("atkVsLow") and t.hp <= int(k.get("lowHp", 5)):
			v += int(k["atkVsLow"])
		if k.has("atkVsHeld") and held(t):
			v += int(k["atkVsHeld"]) if not (k.has("atkVsLow") and t.hp <= int(k.get("lowHp", 5))) else 0
		if k.has("atkVsRoot") and rooted(t):
			v += int(k["atkVsRoot"])
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
		if k.has("atkBarrier") and t.barrier:
			v += int(k["atkBarrier"])
		if not t.barrier and K(t).has("air") and alc_of(a) >= 3:
			v += int(K(t)["air"])
	if k.has("atkAllyAdj"):
		var aa = k["atkAllyAdj"]
		var near = allies_of(a).filter(func(x): return DB.dist(x.pos(), a.pos()) == 1 and match_who(x, aa.get("who", "")))
		if aa.get("per", false):
			v += min(near.size(), int(aa.get("max", 99))) * int(aa["n"])
		elif not near.is_empty():
			v += int(aa["n"])
	if t != null and not t.barrier and match_who(a, "LIT"):
		for rs in units:
			if rs.owner == a.owner and rs.st == "field" and not rs.barrier and K(rs).has("resDmg") and not silenced(rs) and held(t) and DB.dist(rs.pos(), t.pos()) <= 3:
				v += int(K(rs)["resDmg"])
				break
	if t != null and k.has("viva") and act != null and act["uid"] == a.uid and act.has("from") and DB.dist(act["from"], t.pos()) >= 3:
		v += int(k["viva"])
	if k.has("atkStill") and _still(a):
		v += int(k["atkStill"])
	if t != null and k.has("atkFlank"):
		var fl = k["atkFlank"]
		if allies_of(a).any(func(x): return DB.dist(x.pos(), t.pos()) == 1 and match_who(x, fl.get("who", ""))):
			v += int(fl["n"])
	if t != null and k.has("atkFocus") and t.hitters_round == round_no:
		if t.hitters.any(func(id): return id != a.uid and by_uid(id) != null and DB.cards[by_uid(id).cid]["f"] == DB.cards[a.cid]["f"]):
			v += int(k["atkFocus"])
	return max(0, v)


# não se moveu nesta ativação (Mira Travada do Sniper)
func _still(a) -> bool:
	return not (act != null and act["uid"] == a.uid and act["moved"])


func reduction_of(t, peek: bool = false, d: int = 1) -> int:
	if t.barrier:
		return 0
	var red = 0
	var k = K(t)
	if t.eq == "placas":
		red += 1
	red += fx_sum(t, "red")
	if has_fx(t, "coat"):
		red += fx_sum(t, "coat")
		if not peek:
			t.fx = t.fx.filter(func(f): return f["k"] != "coat")
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
		if ar.get("ranged", false) and d <= 1:
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
	var no_cover = K(a).has("lob") or (K(a).has("atkStill") and _still(a)) or (has_fx(t, "dazed") and DB.cards[a.cid]["f"] == "ABY")
	if d > 1:
		for c in DB.nbrs(t.pos()):
			if no_cover:
				break
			var is_cov = tt_of(terr(c)["k"]).get("cover", 0) or solid_barrier_at(c)
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
	var ts0 = _targets_from(a, fpos)
	# Portalis: quem está ao lado da ENTRADA ataca a partir da SAÍDA
	if fpos == null and not a.barrier and a.st == "field":
		for pt in portal_out_of(a):
			if unit_at(pt["b"]) == null:
				for t in _targets_from(a, pt["b"]):
					if not ts0.has(t):
						ts0.append(t)
	return ts0


func _targets_from(a, fpos = null) -> Array:
	var ap = a.pos() if fpos == null else fpos
	var hp = stand_h(ap)
	var ts = []
	for t in enemies_of(a):
		var d = DB.dist(ap, t.pos())
		if d < 1 or d > range_of(a, ap, t) or has_fx(t, "veil") or imprisoned(t):
			continue
		if d == 1 and abs(hp - stand_h(t.pos())) > 1 and not K(a).has("climbAll"):
			continue
		# aéreo: unidades terrestres de corpo a corpo não o alcançam
		if K(t).has("air") and alc_of(a) <= 1 and not K(a).has("air") and not K(a).has("climbAll"):
			continue
		if not _sees(a, ap, t):
			continue
		ts.append(t)
	# guarda do clã (k_tank): só protege de ataques à distância
	ts = ts.filter(func(t): return not _guarded(t, DB.dist(ap, t.pos())))
	var taunters = ts.filter(func(t): return K(t).has("taunt") and DB.dist(ap, t.pos()) == 1)
	if not taunters.is_empty():
		ts = ts.filter(func(t): return not taunters.any(func(tt2): return t != tt2 and not t.barrier and t.owner == tt2.owner and DB.dist(t.pos(), tt2.pos()) == 1))
	return ts


# linha de tiro: a granada passa por cima; o alvo marcado pela Batedora é visto por qualquer artilheiro Krieg
func _sees(a, ap: Vector2i, t) -> bool:
	if K(a).has("lob") or K(a).has("arc"):
		return true
	if DB.dist(ap, t.pos()) > 1 and fx_sum(t, "mark") > 0 and DB.cards[a.cid]["f"] == "KRI" and alc_of(a) >= 2:
		if allies_of(a, true).any(func(x): return x.cid == "k_batedor" and not silenced(x)):
			return true
	return los(ap, t.pos())


func _guarded(t, d: int = 99) -> bool:
	if t.barrier or d <= 1:
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
	if not DB.in_board(h) or unit_at(h) != null or cart_at(h):
		return false
	if not blocks.has(h):
		return true
	return (K(u).has("climbAll") or (K(u).has("air") and String(terr(h)["k"]) == "correnteza")) and not is_pit(h) and not barrier_at(h)


func move_opts(u, mov: int) -> Array:
	var start = u.pos()
	var cl = K(u).has("climbAll")
	var ex = 1 if has_fx(u, "climb1") else 0
	var best = {start: 0}
	var queue = [{"h": start, "c": 0}]
	while not queue.is_empty():
		queue.sort_custom(func(a, b): return a["c"] < b["c"])
		var n = queue.pop_front()
		if n["c"] > 0 and tt_of(terr(n["h"])["k"]).get("sink", 0):
			continue
		for m in DB.nbrs(n["h"]):
			if not can_enter(u, m) or not can_step(n["h"], m, cl, ex):
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
	if not u.barrier and (not bananas.is_empty() or (own and not res.is_empty())):
		for ph in _path(u, fpos, h):
			_eat_banana(u, ph)
			if own:
				_grab_scarab(u, ph)
	u.q = h.x
	u.r = h.y
	emitfx({"t": "move", "uid": u.uid, "from": fpos, "to": h})
	await pace()
	await arrive(u, own)


# caminho mais curto (em casas) por onde a peça passa, para pegar bananas no caminho
func _path(u, a: Vector2i, b: Vector2i) -> Array:
	if a == b:
		return []
	var prev = {a: a}
	var q = [a]
	while not q.is_empty():
		var c = q.pop_front()
		if c == b:
			break
		for n in DB.nbrs(c):
			if prev.has(n):
				continue
			if n != b and (unit_at(n) != null or (blocks.has(n) and not K(u).has("climbAll") and not (K(u).has("air") and String(terr(n)["k"]) == "correnteza"))):
				continue
			prev[n] = c
			q.append(n)
	if not prev.has(b):
		return [b]
	var out = []
	var c2 = b
	while c2 != a:
		out.push_front(c2)
		c2 = prev[c2]
	return out


# escaravelho verde: quem anda por cima (ou para nele) já o guarda, sem gastar ação
func _grab_scarab(u, h: Vector2i) -> void:
	if not res.has(h) or res[h] != "escaravelho" or u.barrier:
		return
	res.erase(h)
	var p = u.owner
	P[p]["scarabs"] = int(P[p]["scarabs"]) + 1
	emitfx({"t": "passive", "kind": "ability", "uid": u.uid})
	log_msg(p, "%s pegou um Escaravelho Verde (%d)." % [nm(u), int(P[p]["scarabs"])])


func _eat_banana(u, h: Vector2i) -> void:
	if not bananas.has(h) or bananas[h]["p"] != u.owner or u.barrier:
		return
	var bt = bananas[h]["t"]
	bananas.erase(h)
	match bt:
		"cura":
			heal(u, 3)
			log_msg(u.owner, "%s comeu uma banana de cura: +3 de Vida." % nm(u))
		"dano":
			u.fx.append({"k": "atk", "v": 2, "until": "end"})
			log_msg(u.owner, "%s comeu uma banana de força: +2 ATQ neste round." % nm(u))
		"alcance":
			u.fx.append({"k": "alc", "v": 1, "until": "end"})
			log_msg(u.owner, "%s comeu uma banana de mira: +1 alcance neste round." % nm(u))
	emitfx({"t": "banana", "h": h, "b": bt, "uid": u.uid})


func arrive(u, own: bool = false) -> void:
	_eat_banana(u, u.pos())
	_grab_scarab(u, u.pos())
	if core != null and u.pos() == core and u.st == "field" and not u.barrier:
		await _capture_core(u)
	for i in range(mines.size()):
		var m = mines[i]
		if m["owner"] != u.owner and m["h"] == u.pos() and not u.barrier:
			mines.remove_at(i)
			emitfx({"t": "boom", "h": u.pos()})
			log_msg(m["owner"], "%s ativou uma mina." % nm(u))
			damage(u, int(m["n"]), null)
			if m.get("root", false) and u.st == "field":
				u.fx.append({"k": "root", "end": round_no + 1})
				log_msg(m["owner"], "%s ficou preso na mina." % nm(u))
			break
	if u.st == "field" and not u.barrier:
		for f in fires:
			if f["h"] == u.pos() and int(f["until"]) >= round_no:
				abfx("burn", u.pos(), u.uid)
				log_msg(f["owner"], "%s pisa em chão em chamas (1)." % nm(u))
				damage(u, 1, null)
				break
	if u.st == "field" and not u.barrier:
		var zo = czone_owner(u.pos())
		if zo >= 0 and zo != u.owner:
			apply_slow(u)
		if own and K(u).has("trail"):
			add_czone(u.owner, u.pos(), 1)
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
		var medic = _dose_medic(t)
		if medic != null:
			medic.dose_used = true
			log_msg(t.owner, "Última Dose: %s salva %s." % [nm(medic), nm(t)])
			emitfx({"t": "passive", "kind": "ability", "uid": medic.uid})
			abfx("heal", t.pos(), medic.uid)
			t.hp = min(3, t.maxhp)
			t.fx = []
			if not t.is_cmd:
				t.st = "reserve"
				t.eq = ""
				emitfx({"t": "die", "uid": t.uid, "h": t.pos()})
			continue
		t.st = "dead"
		t.eq = ""
		_drop_src_fx(t.uid)
		if not t.barrier:
			fallen.append(t.uid)
		if t.crystal != "":
			emitfx({"t": "die", "uid": t.uid, "h": t.pos()})
			if _crystal_burst(t):
				blast = true
			continue
		emitfx({"t": "die", "uid": t.uid, "h": t.pos()})
		log_msg(1 - t.owner, "%s foi derrotado." % nm(t))
		var killer = by_uid(by) if by > 0 else null
		if killer != null and killer.owner != t.owner and K(killer).has("killGrow") and not t.barrier:
			killer.kills += 1
		if killer != null and killer.owner != t.owner and killer.st == "field" and not t.barrier:
			if K(killer).has("killHeal"):
				heal(killer, int(K(killer)["killHeal"]))
				log_msg(killer.owner, "%s: recupera Vida ao derrubar %s." % [DB.cards[killer.cid]["ab"]["name"], nm(t)])
			var kf = commander(killer.owner)
			if kf != null and kf != killer and kf.st != "dead" and kf.gloria_round != round_no and K(kf).has("fome") and DB.cards[killer.cid]["f"] == "ABY" and DB.dist(killer.pos(), cmd_point(kf)) <= int(K(kf)["fome"]):
				kf.gloria_round = round_no
				heal(killer, 2)
				log_msg(killer.owner, "Fome do Abismo: %s restaura 2 de Vida." % nm(killer))
			var kc = commander(killer.owner)
			if kc != null and kc != killer and kc.st != "dead" and kc.gloria_round != round_no and K(kc).has("gloria") and DB.cards[killer.cid]["f"] == "KRI" and DB.dist(killer.pos(), cmd_point(kc)) <= int(K(kc)["gloria"]):
				kc.gloria_round = round_no
				if draw_cards(killer.owner, 1) > 0:
					log_msg(killer.owner, "Glória do Clã: %s compra 1 carta." % nm(kc))
					emitfx({"t": "passive", "kind": "power", "uid": kc.uid})
		if K(t).has("vengeance") and not t.barrier:
			var vg = K(t)["vengeance"]
			for al in units:
				if al != t and al.st == "field" and al.owner == t.owner and not al.barrier and DB.cards[al.cid]["f"] == DB.cards[t.cid]["f"] and DB.dist(al.pos(), t.pos()) <= int(vg["r"]):
					al.fx.append({"k": "atk", "v": int(vg["n"]), "until": "end"})
					abfx("buff", al.pos(), t.uid)
			log_msg(t.owner, "%s: o clã jura vingança (+%d ATQ por perto)." % [DB.cards[t.cid]["ab"]["name"], int(vg["n"])])
		if not t.barrier and DB.cards[t.cid]["f"] == "KRI":
			for sp in units:
				if sp.st == "field" and sp.owner == t.owner and sp != t and K(sp).has("deathMine") and not mines.any(func(m): return m["h"] == t.pos()):
					_add_mine(sp.owner, t.pos(), int(K(sp)["deathMine"]), sp.uid, int(K(sp).get("mineCap", 2)))
					abfx("mine", t.pos(), sp.uid)
					log_msg(sp.owner, "%s arma uma mina onde %s caiu." % [nm(sp), nm(t)])
					break
		if K(t).has("deathGrenade") and not t.barrier:
			blast = true
			var ng = int(K(t)["deathGrenade"])
			abfx("blast", t.pos(), t.uid)
			log_msg(t.owner, "%s lança a última granada: %d de dano nos inimigos ao redor." % [nm(t), ng])
			for o in units.duplicate():
				if o != t and o.st == "field" and o.owner != t.owner and DB.dist(o.pos(), t.pos()) == 1:
					damage(o, ng, t)
		if not t.barrier:
			for rp in units:
				if rp.st == "field" and rp.owner != t.owner and K(rp).has("bombs"):
					bomb_queue.append(rp.uid)
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


# Médico Krieg: salva uma peça Krieg a até 2 casas que seria derrotada (1 vez por partida)
func _dose_medic(t) -> Variant:
	if t.barrier or DB.cards[t.cid]["f"] != "KRI":
		return null
	for m in units:
		if m != t and m.st == "field" and m.owner == t.owner and not m.dose_used and K(m).has("lastDose") and DB.dist(m.pos(), t.pos()) <= int(K(m)["lastDose"]):
			return m
	return null


# mina nova; no máximo `cap` por peça de origem (a mais antiga some)
func _add_mine(owner: int, h: Vector2i, n: int, src: int, cap: int = 1) -> void:
	var mine = mines.filter(func(m): return m["src"] == src)
	while mine.size() >= cap:
		mines.erase(mine.pop_front())
	mines.append({"owner": owner, "h": h, "n": n, "src": src})


func _set_fire(owner: int, h: Vector2i) -> void:
	fires = fires.filter(func(f): return f["h"] != h)
	fires.append({"h": h, "owner": owner, "until": round_no + 1})


func _fire_tick() -> void:
	fires = fires.filter(func(f): return int(f["until"]) >= round_no)
	for f in fires:
		var u = unit_at(f["h"])
		if u != null:
			abfx("burn", f["h"], u.uid)
			log_msg(f["owner"], "%s queima na Terra Queimada (1)." % nm(u))
			damage(u, 1, null)
	settle()


func _shell_tick() -> void:
	var due = shells.filter(func(sh): return int(sh["round"]) < round_no)
	shells = shells.filter(func(sh): return int(sh["round"]) >= round_no)
	for sh in due:
		var h = sh["h"]
		abfx("shell", h, int(sh["src"]))
		emitfx({"t": "boom", "h": h})
		var src = by_uid(int(sh["src"]))
		var c = unit_at(h)
		if c != null:
			damage(c, 3, src)
		for n in DB.nbrs(h):
			var a = unit_at(n)
			if a != null:
				damage(a, 1, src)
		log_msg(sh["owner"], "A carga explode na casa marcada." if sh.get("kind", "") == "charge" else "A artilharia atinge a casa marcada.")
		await pace()
	settle()


# ================= Valak: cristais, buraco da garra, vibração e carrinhos =================
func vrule(k: String, d: Variant) -> Variant:
	return DB.maps[map_id].get("valak_rules", {}).get(k, d)


func _setup_valak() -> void:
	var def = DB.maps[map_id]
	hole = []
	tracks = []
	track_loop = []
	carts = []
	vib = 0
	if def.has("hole"):
		var c = Vector2i(int(def["hole"]["c"][0]), int(def["hole"]["c"][1]))
		for h in DB.hexes:
			if DB.dist(h, c) <= int(def["hole"]["r"]):
				hole.append(h)
	for tr in def.get("tracks", []):
		var a = []
		var b = []
		for e in tr:
			a.append(Vector2i(int(e[0]), int(e[1])))
			b.append(Vector2i(-int(e[0]), -int(e[1])))
		tracks.append(a)
		tracks.append(b)
		track_loop.append(false)
		track_loop.append(false)
	if def.has("track_ring"):
		# trilho circular em volta do mapa todo (anel de casas a uma distância do centro)
		var rr = int(def["track_ring"])
		var ring = []
		var hcur = Vector2i(0, 0) + DB.DIRS[4] * rr
		for side in range(6):
			for k in range(rr):
				ring.append(hcur)
				hcur += DB.DIRS[side]
		tracks.append(ring)
		track_loop.append(true)
		for ci in def.get("carts_ring", []):
			carts.append({"h": ring[int(ci) % ring.size()], "track": tracks.size() - 1})
	for i in range(def.get("carts", []).size()):
		var e = def["carts"][i]
		var h0 = Vector2i(int(e[0]), int(e[1]))
		for ti in range(tracks.size()):
			for hh in [h0, -h0]:
				if tracks[ti].has(hh):
					carts.append({"h": hh, "track": ti})


func hole_dist(h: Vector2i) -> int:
	var d = 99
	for x in hole:
		d = min(d, DB.dist(h, x))
	return d


func in_zone(h: Vector2i) -> bool:
	return not hole.is_empty() and hole_dist(h) <= int(vrule("vib_r", 3))


func cart_at(h: Vector2i) -> bool:
	for c in carts:
		if c["h"] == h:
			return true
	return false


func on_track(h: Vector2i) -> bool:
	for tr in tracks:
		if tr.has(h):
			return true
	return false


# labirinto de cristais: muda a cada partida (pares espelhados), sem prender ninguém
func _gen_crystals() -> void:
	var def = DB.maps[map_id]
	if not def.has("crystals"):
		return
	var cfg = def["crystals"]
	var cand = {}
	for h in DB.hexes:
		if hole.has(h) or on_track(h) or cart_at(h) or blocks.has(h) or h == -h:
			continue
		if DB.dist(h, DB.entry_c[0]) <= int(cfg.get("keep", 2)) or DB.dist(h, DB.entry_c[1]) <= int(cfg.get("keep", 2)):
			continue
		if unit_at(h) != null or unit_at(-h) != null:
			continue
		cand[h] = true
	var colors = ["verde", "azul", "roxo"]
	var best: Array = []
	for attempt in range(60):
		var pick = {}
		var segs = int(cfg.get("segs", 7))
		var keys = cand.keys()
		for sgi in range(segs):
			var st = keys[rng.randi() % keys.size()]
			var dirv = DB.DIRS[rng.randi() % 6]
			var ln = 2 + rng.randi() % 3
			var cur = st
			for k in range(ln):
				if cand.has(cur) and cand.has(-cur):
					pick[cur] = true
					pick[-cur] = true
				cur += dirv
				if rng.randf() < 0.3:
					dirv = DB.DIRS[(DB.DIRS.find(dirv) + (1 if rng.randf() < 0.5 else 5)) % 6]
		if pick.size() < int(cfg.get("min", 20)) or pick.size() > int(cfg.get("max", 34)):
			continue
		if _maze_ok(pick):
			best = pick.keys()
			break
	if best.is_empty():
		return
	best.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	var col_of = {}
	for h in best:
		if col_of.has(h):
			continue
		var c = colors[rng.randi() % 3]
		col_of[h] = c
		col_of[-h] = c
	for h in best:
		var b = Unit.new()
		b.uid = next_uid
		next_uid += 1
		b.cid = "barrier"
		b.owner = NEUTRAL
		b.st = "field"
		b.q = h.x
		b.r = h.y
		b.hp = 1
		b.maxhp = 1
		b.barrier = true
		b.activated = true
		b.crystal = col_of[h]
		units.append(b)
	log_msg(-1, "Valak: %d cristais formam o labirinto desta partida." % best.size())


# todas as casas livres continuam ligadas entre si e às duas entradas
func _maze_ok(pick: Dictionary) -> bool:
	var open = {}
	for h in DB.hexes:
		if hole.has(h) or blocks.has(h) or pick.has(h) or cart_at(h):
			continue
		open[h] = true
	if not open.has(DB.entry_c[0]) or not open.has(DB.entry_c[1]):
		return false
	var seen = {DB.entry_c[0]: true}
	var q = [DB.entry_c[0]]
	while not q.is_empty():
		var h = q.pop_back()
		for n in DB.nbrs(h):
			if open.has(n) and not seen.has(n):
				seen[n] = true
				q.append(n)
	return seen.size() == open.size()


# cristal quebrado: efeito em todos os personagens ao lado (aliados e inimigos)
func _crystal_burst(t) -> bool:
	var hit = false
	var ctr = t.pos() if _burst_at == null else Vector2i(_burst_at)
	var who = units.filter(func(x): return x.st == "field" and not x.barrier and (DB.dist(x.pos(), ctr) == 1 or (_burst_at != null and DB.dist(x.pos(), ctr) == 0)))
	abfx("crystal", ctr, t.uid)
	if t.sp_owner >= 0:
		return _sp_effect(t, who)
	match t.crystal:
		"verde":
			for x in who:
				heal(x, int(vrule("green_heal", 2)))
			log_msg(-1, "Cristal verde quebrado: +%d de Vida para quem estava ao lado." % int(vrule("green_heal", 2)))
		"azul":
			for x in who:
				x.fx = x.fx.filter(func(f): return not f.get("once", false))
				x.fx.append({"k": "mov", "v": 1, "until": "end", "once": true})
				emitfx({"t": "passive", "kind": "power", "uid": x.uid})
			log_msg(-1, "Cristal azul quebrado: +1 de Movimento no próximo movimento (neste round).")
		"roxo":
			for x in who:
				damage(x, int(vrule("purple_dmg", 2)), null)
				hit = true
			log_msg(-1, "Cristal roxo quebrado: %d de dano em quem estava ao lado." % int(vrule("purple_dmg", 2)))
	return hit


# bônus azul: vale só para o próximo movimento
func _use_blue(u) -> void:
	if u.fx.any(func(f): return f.get("once", false)):
		u.fx = u.fx.filter(func(f): return not f.get("once", false))


func vibrate(n: int, why: String) -> void:
	if hole.is_empty() or n <= 0 or winner != NONE:
		return
	vib += n
	log_msg(-1, "Vibração +%d (%s): %d/%d." % [n, why, vib, int(vrule("vib_max", 5))])
	emitfx({"t": "vib", "v": vib})
	if vib >= int(vrule("vib_max", 5)):
		await claw_attack()


# a garra ataca todos a até 3 casas do buraco (distância medida antes do ataque)
func claw_attack() -> void:
	vib = 0
	var r = int(vrule("vib_r", 3))
	var victims = []
	for u in field():
		if u.barrier:
			continue
		var d = hole_dist(u.pos())
		if d <= r:
			victims.append({"u": u, "d": d})
	victims.sort_custom(func(a, b): return a["d"] < b["d"] or (a["d"] == b["d"] and a["u"].uid < b["u"].uid))
	log_msg(-1, "A GARRA ATACA! Ninguém a até %d casas do buraco escapa." % r)
	emitfx({"t": "claw", "hexes": victims.map(func(v): return v["u"].pos())})
	await pace()
	await pace()
	for v in victims:
		var u = v["u"]
		if u.st != "field":
			continue
		if v["d"] <= 1:
			log_msg(-1, "%s foi arrastado para o buraco!" % nm(u))
			emitfx({"t": "claw_grab", "h": u.pos(), "kill": true, "uid": u.uid})
			await pace()
			damage(u, 999, null)
		else:
			damage(u, int(vrule("claw_dmg", 2)), null)
			if u.hp > 0:
				var ops = DB.nbrs(u.pos()).filter(func(n): return is_free(n) and hole_dist(n) == v["d"] - 1)
				ops.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
				if not ops.is_empty():
					log_msg(-1, "%s foi puxado em direção ao buraco." % nm(u))
					emitfx({"t": "claw_grab", "h": u.pos(), "kill": false, "uid": u.uid})
					var fpos = u.pos()
					u.q = ops[0].x
					u.r = ops[0].y
					emitfx({"t": "move", "uid": u.uid, "from": fpos, "to": ops[0]})
	settle()
	await pace()
	changed.emit()


# carrinhos de mina: empurrar gasta 1 ação; anda até 3 casas no trilho
func cart_opts(u) -> Array:
	var out = []
	if not is_live(u) or act["actions"] < 1 or u.barrier:
		return out
	for i in range(carts.size()):
		if DB.dist(carts[i]["h"], u.pos()) == 1:
			for nx in _cart_next(i):
				if nx != u.pos():
					out.append({"cart": i, "to": nx})
	return out


# próxima casa do trilho (dá a volta no trilho circular); -1 = fim da linha
func _track_idx(ti: int, k: int) -> int:
	var n = tracks[ti].size()
	if track_loop[ti]:
		return posmod(k, n)
	return k if (k >= 0 and k < n) else -1


func _track_dir(ti: int, from: Vector2i, to: Vector2i) -> int:
	var tr = tracks[ti]
	var k = tr.find(from)
	return 1 if _track_idx(ti, k + 1) == tr.find(to) else -1


func _cart_next(i: int) -> Array:
	var ti = carts[i]["track"]
	var tr = tracks[ti]
	var k = tr.find(carts[i]["h"])
	var out = []
	for d in [-1, 1]:
		var j = _track_idx(ti, k + d)
		if j >= 0:
			out.append(tr[j])
	return out


# quem o carrinho atingiria se fosse empurrado para "to" (para a CPU e a prévia)
func cart_probe(u, to: Vector2i) -> Variant:
	for o in cart_opts(u):
		if o["to"] != to:
			continue
		var i = o["cart"]
		var ti = carts[i]["track"]
		var tr = tracks[ti]
		var k = tr.find(carts[i]["h"])
		var step = _track_dir(ti, carts[i]["h"], to)
		for n in range(int(vrule("cart_steps", 3))):
			k = _track_idx(ti, k + step)
			if k < 0:
				return null
			var t = unit_at(tr[k])
			if t != null:
				return null if t.barrier else t
			if blocks.has(tr[k]) or cart_at(tr[k]):
				return null
	return null


func can_cart(u) -> bool:
	return not cart_opts(u).is_empty()


func act_cart(u) -> bool:
	return await _run(["cart", u.uid], func(): return await _act_cart(u))


func _act_cart(u) -> bool:
	var ops = cart_opts(u)
	if ops.is_empty():
		return false
	var h = await pick_hex(u.owner, "Carrinho: para onde empurrar? (anda até %d casas no trilho)" % int(vrule("cart_steps", 3)), ops.map(func(o): return o["to"]), "cart", true)
	if h == null:
		return false
	var o = ops.filter(func(x): return x["to"] == h)[0]
	act["actions"] -= 1
	var i = o["cart"]
	var ti = carts[i]["track"]
	var tr = tracks[ti]
	var step = _track_dir(ti, carts[i]["h"], h)
	var shook = in_zone(carts[i]["h"])
	log_msg(u.owner, "%s empurrou um carrinho." % nm(u))
	for n in range(int(vrule("cart_steps", 3))):
		var j = _track_idx(ti, tr.find(carts[i]["h"]) + step)
		if j < 0:
			break
		var nx = tr[j]
		var t = unit_at(nx)
		if t != null and not t.barrier:
			emitfx({"t": "boom", "h": nx})
			log_msg(u.owner, "O carrinho atropelou %s (%d)." % [nm(t), int(vrule("cart_dmg", 3))])
			damage(t, int(vrule("cart_dmg", 3)), u)
			var push = nx + (nx - carts[i]["h"])
			if t.hp > 0 and is_free(push) and can_step(nx, push, true):
				await move_unit(t, push)
			break
		if t != null or blocks.has(nx) or cart_at(nx):
			break
		var fh = carts[i]["h"]
		carts[i]["h"] = nx
		emitfx({"t": "cart", "i": i, "from": fh, "to": nx})
		await pace()
		if in_zone(nx):
			shook = true
	settle()
	if shook and winner == NONE:
		await vibrate(int(vrule("cart", 3)), "um carrinho passou perto do buraco")
	changed.emit()
	return true


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
			_shuffle(pl["deck"])
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
	if not tut:
		_gen_crystals()
	if tut:
		# tutorial: mão combinada para os passos, sem troca de mão
		var pl0 = P[0]
		pl0["hand"] = ["fogo", "sinalizador", "placas"]
		for c in pl0["hand"]:
			pl0["deck"].erase(c)
		draw_cards(1, 3)
		await start_round()
		return
	for p in range(2):
		draw_cards(p, 3)
		var yes = await ask(p, {"t": "yesno", "text": "Trocar a mão inicial (devolve as 3 cartas e compra 3 novas)? Só dá para fazer uma vez.", "show": P[p]["hand"].duplicate(), "kind": "mulligan"})
		if yes:
			var pl = P[p]
			pl["deck"].append_array(pl["hand"])
			_shuffle(pl["deck"])
			pl["hand"] = []
			draw_cards(p, 3)
			log_msg(p, "Trocou a mão inicial.")
	await start_round()


func start_round() -> void:
	round_no += 1
	for u in units:
		u.activated = false
		u.charge = K(u).has("charge")
		u.fx = u.fx.filter(func(f): return f.get("until", "") != "start")
	for pl in P:
		pl["obj_used"] = {}
		pl["passed"] = false
	log_msg(-1, "Round %d começou." % round_no)
	if storm_on():
		log_msg(-1, "Tempestade de areia: todos os ataques causam 2 a menos de dano neste round.")
	if round_no > 1 and (round_no - 1) % zone_grow() == 0:
		log_msg(-1, "A área de entrada cresceu: agora vai até %d casas da base." % zone_radius())
		emitfx({"t": "zone_grow", "r": zone_radius()})
	await map_events()
	if winner != NONE:
		return
	_fire_tick()
	await _shell_tick()
	if winner != NONE:
		return
	if round_no == CMD_ROUND:
		# cinemática dos comandantes observando o campo (só na tela; não muda o estado)
		if cine.is_valid():
			await cine.call()
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
	await _core_events()
	if winner != NONE:
		return
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
					var drop = before[u.uid] - h_of(u.pos())
					var dmg = FALL_DMG + (1 if drop >= 3 else 0) + (1 if drop >= 5 else 0)
					log_msg(-1, "%s despencou da duna (%d níveis): %d de dano." % [nm(u), drop, dmg])
					damage(u, dmg, null)
			settle()
			await pace()
			if winner != NONE:
				return
		if round_no % DUNE_EVERY == 0:
			var opts = []
			for i in range(def["dunes"].size()):
				if i != dune:
					opts.append(i)
			dune_next = _pick(opts)
			emitfx({"t": "wind"})
			log_msg(-1, "O vento muda: no próximo round as dunas viram \"%s\"." % def["dunes"][dune_next]["name"])
	if def.get("worms", false):
		var n0 = holes.size()
		holes = holes.filter(func(b): return b["until"] > round_no)
		if holes.size() != n0:
			load_map()
			log_msg(-1, "Um buraco de verme se fechou.")
		if worm_round(round_no) and not tremors.is_empty():
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
		if worm_round(round_no + 1) and round_no + 1 <= 10:
			# quanto mais perto do fim, mais áreas ameaçadas (sempre com rota de fuga livre ao lado)
			var pairs = 2 if round_no + 1 < 8 else (3 if round_no + 1 < 10 else 4)
			var cand = DB.hexes.filter(func(h): return _tremor_ok(h))
			tremors = []
			for i in range(pairs):
				var ok = cand.filter(func(h): return not tremors.has(h) and tremors.all(func(t): return DB.dist(h, t) >= 3) and DB.dist(h, -h) >= 3 and _escape_ok(h))
				if ok.is_empty():
					break
				var c = _pick(ok)
				tremors.append(c)
				tremors.append(-c)
			if not tremors.is_empty():
				if round_no + 1 >= 8:
					log_msg(-1, "O deserto está cada vez mais perigoso: %d buracos de verme vão abrir no próximo round. Fuja das casas marcadas!" % tremors.size())
					emitfx({"t": "danger", "n": tremors.size()})
				else:
					log_msg(-1, "A areia treme: buracos de verme vão abrir no próximo round nas casas marcadas.")
				emitfx({"t": "tremor", "hexes": tremors.duplicate()})


# vermes: rounds 3 e 6, e todo round a partir do 8
func worm_round(r: int) -> bool:
	return r == 3 or r == 6 or r >= 8


# rota de fuga: pelo menos 2 casas livres e seguras ao lado da casa ameaçada
func _escape_ok(h: Vector2i) -> bool:
	var n = 0
	for c in DB.nbrs(h):
		if not blocks.has(c) and c != -h and terr(c)["k"] != "buraco":
			n += 1
	return n >= 3


# ================= núcleo central =================
func _core_spot() -> Variant:
	var defc = DB.maps[map_id].get("cores", [])
	if not defc.is_empty():
		# mapas do dossiê: o núcleo surge só nas casas candidatas da planta
		var cc = []
		for e in defc:
			var hc = Vector2i(int(e[0]), int(e[1]))
			if hc != core and not blocks.has(hc) and not barrier_at(hc):
				cc.append(hc)
		if not cc.is_empty():
			return _pick(cc)
	var c0 = DB.entry_c[0]
	var c1 = DB.entry_c[1]
	var cand = DB.hexes.filter(func(h): return not blocks.has(h) and not barrier_at(h) and not cart_at(h) and tt_of(terr(h)["k"]).get("pass", 0) and terr(h)["k"] != "movedica" and abs(DB.dist(h, c0) - DB.dist(h, c1)) <= 1 and DB.dist(h, c0) >= 3 and DB.dist(h, c1) >= 3 and h != core and not tremors.has(h))
	if cand.is_empty():
		return null
	return _pick(cand)


func _core_events() -> void:
	if core != null and round_no > core_until:
		log_msg(-1, "O núcleo se apagou sem ser capturado.")
		emitfx({"t": "core", "what": "fade", "h": core})
		core = null
	if round_no == 1:
		core_next = _core_spot()
		core_next_round = CORE_ROUNDS[0]
	if CORE_ROUNDS.has(round_no) and core_next != null:
		core = core_next
		core_until = round_no + 1
		log_msg(-1, "Um NÚCLEO DE ENERGIA surgiu! Leve uma peça até ele para capturar (fica 2 rounds).")
		emitfx({"t": "core", "what": "spawn", "h": core})
		var nx = CORE_ROUNDS.find(round_no) + 1
		core_next = null
		if nx < CORE_ROUNDS.size():
			core_next_round = CORE_ROUNDS[nx]
			core_next = _core_spot()
		var occ = unit_at(core)
		if occ != null and not occ.barrier:
			await _capture_core(occ)


func _capture_core(u) -> void:
	var h = core
	core = null
	emitfx({"t": "core", "what": "take", "h": h, "uid": u.uid})
	log_msg(u.owner, "%s capturou o núcleo!" % nm(u))
	var opts = ["Comprar 2 cartas de tática", "+2 ATQ até o fim do próximo round", "+4 de Vida e -1 dano recebido no próximo round"]
	var pick = await ask(u.owner, {"t": "choice", "text": "Núcleo capturado por %s! Escolha a recompensa:" % nm(u), "opts": opts, "kind": "core", "uid": u.uid})
	match int(pick) if pick != null else 0:
		1:
			u.fx.append({"k": "atk", "v": 2, "till": round_no + 1})
			log_msg(u.owner, "Núcleo: %s ganhou +2 ATQ." % nm(u))
		2:
			heal(u, 4)
			u.fx.append({"k": "red", "v": 1, "till": round_no + 1})
			log_msg(u.owner, "Núcleo: %s recuperou 4 de Vida e está blindado." % nm(u))
		_:
			draw_cards(u.owner, 2)
			log_msg(u.owner, "Núcleo: comprou 2 cartas.")
			await hand_limit(u.owner)
	emitfx({"t": "passive", "kind": "power", "uid": u.uid})


func _tremor_ok(h: Vector2i) -> bool:
	var m = -h
	return terr(h)["k"] == "areia" and terr(m)["k"] == "areia" and h != Vector2i.ZERO and DB.obj_at(h) == null and DB.obj_at(m) == null and not res.has(h) and not res.has(m) and min(DB.dist(h, DB.entry_c[0]), DB.dist(h, DB.entry_c[1])) >= 2


func commander_enters(p: int) -> void:
	var c = commander(p)
	if c.st != "off":
		return
	var opts = deploy_hexes(p)
	if opts.is_empty():
		var occ = []
		for h in entry_zone(p):
			var u = unit_at(h)
			if u != null and u.owner == p and not u.barrier:
				occ.append(h)
		if not occ.is_empty():
			var h = await pick_hex(p, "Entrada cheia: escolha 1 aliado para voltar à reserva e abrir espaço para o Comandante.", occ, "ally")
			var back = unit_at(h)
			back.st = "reserve"
			log_msg(p, "%s voltou à reserva." % nm(back))
			opts = deploy_hexes(p)
	if opts.is_empty():
		return
	var d = await pick_hex(p, "%s entra em campo: escolha uma casa livre da sua entrada." % nm(c), opts, "place")
	c.st = "field"
	c.q = d.x
	c.r = d.y
	emitfx({"t": "summon", "uid": c.uid, "h": d})
	log_msg(p, "%s entrou em campo." % nm(c))
	await arrive(c)
	await entry_effect(c)


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
	await _toxin_tick()
	if winner != NONE:
		return
	_venom_tick()
	if winner != NONE:
		return
	await resolve_queues()
	if winner != NONE:
		return
	await _terrain_round_end()
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
	for bx in units:
		if bx.barrier and bx.st == "field" and bx.exp > 0 and bx.exp <= round_no:
			bx.st = "dead"
			emitfx({"t": "die", "uid": bx.uid, "h": bx.pos()})
			log_msg(-1, "%s se desfaz." % ("A barreira de raízes" if bx.soft else "A barreira"))
	for u in units:
		u.fx = u.fx.filter(func(f): return f.get("until", "") != "end" and int(f.get("till", 999)) > round_no and not ((f["k"] == "root" or f["k"] == "prison") and int(f["end"]) <= round_no))
	czones = czones.filter(func(z): return int(z["until"]) > round_no)
	for pl in P:
		pl["discount"] = false
	if round_no >= 10:
		do_final_score()
		return
	await start_round()


# fim do round nos mapas do dossiê: plantas predadoras mordem e a correnteza leva quem está no rio
func _terrain_round_end() -> void:
	var def = DB.maps[map_id]
	if not def.has("cells"):
		return
	var bit = false
	for u in field():
		if u.barrier or K(u).has("air"):
			continue
		for n in DB.nbrs(u.pos()):
			if tt_of(terr(n)["k"]).get("bite", 0):
				emitfx({"t": "boom", "h": n})
				var bd = 2 if (map_id == "abnara" and _pulse(round_no)) else 1
				log_msg(-1, "Planta predadora morde %s (%d)." % [nm(u), bd])
				damage(u, bd, null)
				bit = true
				break
	if bit:
		settle()
		await pace()
		if winner != NONE:
			return
	var flow = {}
	for e in def.get("flow", []):
		flow[Vector2i(int(e[0]), int(e[1]))] = Vector2i(int(e[2]), int(e[3]))
	var moved = false
	for u in field():
		if u.barrier or K(u).has("air") or not flow.has(u.pos()):
			continue
		var to = flow[u.pos()]
		if not is_free(to) or not can_step(u.pos(), to):
			continue
		var fpos = u.pos()
		u.q = to.x
		u.r = to.y
		emitfx({"t": "move", "uid": u.uid, "from": fpos, "to": to})
		log_msg(-1, "A correnteza levou %s 1 casa." % nm(u))
		moved = true
		await arrive(u)
	if moved:
		await pace()
	if winner != NONE:
		return
	await _map_events(def)


# ================= eventos dos mapas do dossiê =================
# Abnara: raízes brotam nos rounds 3, 6, 9 (aviso no round anterior). Gor'Aida: o gelo frágil se rompe nos
# rounds 3, 6, 9 e avalanches descem nos rounds 4, 7, 10. Sempre um round inteiro de aviso, e nunca
# cortam o mapa em pedaços.
func _pulse(r: int) -> bool:
	return r == 3 or r == 6 or r == 9


func _aval(r: int) -> bool:
	return r == 4 or r == 7 or r == 10


func _mirror(h: Vector2i) -> Vector2i:
	return Vector2i(-h.x - h.y, h.y)


func _map_events(def: Dictionary) -> void:
	var ab = map_id == "abnara"
	var gl = map_id == "goraida"
	if not (ab or gl):
		return
	var changed_terrain = false
	if ab:
		await _rain_events()
		if winner != NONE:
			return
	# 1) expira o que já passou (raiz murcha, gelo rompido congela de novo)
	for h in dyn.keys():
		if int(dyn[h]["until"]) <= round_no:
			var then = String(dyn[h].get("then", ""))
			if then == "":
				dyn.erase(h)
			else:
				dyn[h] = {"k": then, "until": 999, "then": ""}
			changed_terrain = true
	# 2) o evento marcado acontece
	if not tremors.is_empty() and ((ab and _pulse(round_no)) or (gl and warn_kind == "fratura" and _pulse(round_no)) or (gl and warn_kind == "avalanche" and _aval(round_no))):
		var hs = tremors.duplicate()
		var kind = warn_kind
		tremors = []
		warn_kind = ""
		if kind == "raiz":
			var n = 0
			for h in hs:
				if unit_at(h) != null or barrier_at(h):
					continue
				dyn[h] = {"k": "raiz", "until": round_no + 3, "then": ""}
				n += 1
			changed_terrain = n > 0
			log_msg(-1, "Raízes brotaram do chão (%d casas) e vão murchar em 3 rounds." % n)
			emitfx({"t": "roots", "hexes": hs})
		elif kind == "fratura":
			for h in hs:
				dyn[h] = {"k": "fenda", "until": round_no + 3, "then": "gelo"}
			changed_terrain = true
			log_msg(-1, "O gelo rachado se rompeu! Quem estava nas casas marcadas caiu para a borda.")
			emitfx({"t": "icebreak", "hexes": hs})
		elif kind == "avalanche":
			log_msg(-1, "Uma avalanche desceu pelo corredor marcado!")
			emitfx({"t": "avalanche", "hexes": hs})
		if changed_terrain:
			load_map()
		for h in hs:
			var u = unit_at(h)
			if u == null or u.barrier:
				continue
			if kind == "fratura" and not K(u).has("air"):
				emitfx({"t": "boom", "h": h})
				log_msg(-1, "%s caiu na fenda do gelo (2)." % nm(u))
				damage(u, 2, null)
				await _eject(u)
			elif kind == "avalanche":
				emitfx({"t": "boom", "h": h})
				log_msg(-1, "%s foi atingido pela avalanche (2)." % nm(u))
				damage(u, 2, null)
				if u.st == "field":
					await _shove_flow(u, def)
		settle()
		await pace()
		if winner != NONE:
			return
	elif changed_terrain:
		load_map()
	# 3) marca o próximo evento (um round inteiro de aviso)
	var nr = round_no + 1
	if nr > 10:
		return
	var kind2 = ""
	if ab and _pulse(nr):
		kind2 = "raiz"
	elif gl and _pulse(nr):
		kind2 = "fratura"
	elif gl and _aval(nr):
		kind2 = "avalanche"
	if kind2 == "":
		return
	var pick = _warn_hexes(kind2, def, nr)
	if pick.is_empty():
		return
	tremors = pick
	warn_kind = kind2
	if kind2 == "raiz":
		log_msg(-1, "A mata se mexe: raízes vão brotar no próximo round nas casas marcadas.")
	elif kind2 == "fratura":
		log_msg(-1, "O gelo estala: as casas marcadas vão se romper no próximo round.")
	else:
		log_msg(-1, "Ruído na montanha: uma avalanche vai descer pelo corredor marcado no próximo round.")
	emitfx({"t": "warn_map", "kind": kind2, "hexes": tremors.duplicate()})
	if changed_terrain:
		load_map()


# escolhe as casas do próximo evento por setor sorteado; nunca corta o mapa e nunca marca as bases
func _warn_hexes(kind: String, def: Dictionary, nr: int) -> Array:
	var secs = def.get("sectors", {})
	var names = []
	for k in secs.keys():
		if (kind == "raiz" and String(k).begins_with("RAIZES")) or (kind == "fratura" and String(k).begins_with("FRATURA")) or (kind == "avalanche" and String(k).begins_with("AVALANCHE")):
			names.append(k)
	if names.is_empty():
		return []
	var sec = names[int(_pick(range(names.size())))]
	var cand = []
	for e in secs[sec]:
		var h = Vector2i(int(e[0]), int(e[1]))
		if DB.in_entry(0, h) or DB.in_entry(1, h) or is_pit(h) or tremors.has(h):
			continue
		cand.append(h)
	if kind == "avalanche":
		return cand
	var pairs = 1 if nr < 9 else 2
	var out = []
	var tries = 0
	while out.size() < pairs * 2 and not cand.is_empty() and tries < 40:
		tries += 1
		var c = _pick(cand)
		var m = _mirror(c)
		if out.has(c) or out.has(m) or c == m or not terr_map.has(m):
			continue
		if kind == "fratura" and terr(m)["k"] != "gelo_fragil":
			continue
		if kind == "raiz" and (unit_at(c) != null or unit_at(m) != null):
			continue
		var test = out.duplicate()
		test.append(c)
		test.append(m)
		if _connected_without(test):
			out = test
	return out


# o mapa continua inteiro (todas as casas andáveis ligadas) se estas casas ficarem bloqueadas?
func _connected_without(blocked: Array) -> bool:
	var open = []
	for h in terr_map.keys():
		if tt_of(terr_map[h]["k"]).get("pass", 0) and not blocked.has(h):
			open.append(h)
	if open.is_empty():
		return false
	var seen = {open[0]: true}
	var q = [open[0]]
	while not q.is_empty():
		var c = q.pop_back()
		for n in DB.nbrs(c):
			if not seen.has(n) and open.has(n):
				seen[n] = true
				q.append(n)
	return seen.size() == open.size()


# quem cai numa fenda sai para a casa livre mais próxima
func _eject(u) -> void:
	if u.st != "field" or not is_pit(u.pos()):
		return
	var fr = DB.hexes.filter(func(h): return is_free(h) and not is_pit(h) and tt_of(terr(h)["k"]).get("pass", 0))
	fr.sort_custom(func(a, c): return DB.dist(a, u.pos()) < DB.dist(c, u.pos()))
	if fr.is_empty():
		return
	var to = fr[0]
	var fpos = u.pos()
	u.q = to.x
	u.r = to.y
	emitfx({"t": "move", "uid": u.uid, "from": fpos, "to": to})
	await arrive(u)


# a avalanche empurra 1 casa no sentido da descida
func _shove_flow(u, def: Dictionary) -> void:
	for e in def.get("flow", []):
		if Vector2i(int(e[0]), int(e[1])) == u.pos():
			var to = Vector2i(int(e[2]), int(e[3]))
			if is_free(to) and not is_pit(to) and tt_of(terr(to)["k"]).get("pass", 0):
				var fpos = u.pos()
				u.q = to.x
				u.r = to.y
				emitfx({"t": "move", "uid": u.uid, "from": fpos, "to": to})
				log_msg(-1, "%s foi empurrado 1 casa." % nm(u))
				await arrive(u)
			return


func do_final_score() -> void:
	# desempate do fim do round 10: vence quem tiver mais vida somada nos personagens restantes
	# (comandantes e aliados, mais os escaravelhos de cada lado); barreiras não contam
	var c = [commander(0).hp + scarabs_of(0), commander(1).hp + scarabs_of(1)]
	var s = [0, 0]
	for u in field():
		if not u.barrier:
			s[u.owner] += u.hp
	var tot = [s[0] + scarabs_of(0), s[1] + scarabs_of(1)]
	final_score = {"c": c, "s": s, "sc": [scarabs_of(0), scarabs_of(1)], "t": tot}
	if tot[0] != tot[1]:
		winner = 0 if tot[0] > tot[1] else 1
	else:
		winner = DRAW
	log_msg(-1, "Fim do round 10. Soma da vida dos personagens: %d × %d." % [tot[0], tot[1]])
	changed.emit()


# ================= ativações =================
# a área de entrada cresce com os rounds: raio 1 (rounds 1-3), 2 (4-6), 3 (7-9), 4 (10)
const ZONE_GROW = 3


# a cada quantos rounds a área de entrada cresce (cada mapa pode ter o seu ritmo)
func zone_grow() -> int:
	return int(DB.maps[map_id].get("zone_grow", ZONE_GROW))


func zone_radius() -> int:
	return 1 + int(max(0, round_no - 1) / zone_grow())


# tempestade de areia (mapas com dunas): no round em que o vento muda e no round em que as dunas mudam
func storm_on() -> bool:
	return DB.maps[map_id].has("dunes") and (round_no % DUNE_EVERY == 0 or (round_no > 1 and (round_no - 1) % DUNE_EVERY == 0))


# Abnara: a partir do round 6 chove (dano -3), o céu escurece e raios caem na mata
const RAIN_ROUND = 6
const RAIN_PEN = 3
const FIRE_ROUNDS = 3


func rain_on() -> bool:
	return map_id == "abnara" and round_no >= RAIN_ROUND


func burning_near(u) -> bool:
	if u == null or u.st != "field":
		return false
	for fh in fire.keys():
		if DB.dist(u.pos(), fh) <= 1:
			return true
	return false


func _ignite(h: Vector2i) -> bool:
	if fire.has(h) or String(terr(h)["k"]) != "mata":
		return false
	fire[h] = round_no
	return true


# chuva, raios e incêndio da mata (rodam no começo de cada round a partir do round 6)
func _rain_events() -> void:
	if not rain_on():
		return
	if round_no == RAIN_ROUND:
		log_msg(-1, "Começa a chover! Todos os ataques causam %d a menos de dano (ninguém enxerga direito)." % RAIN_PEN)
		emitfx({"t": "rain_start"})
		await pace()
	var changed_terrain = false
	# o fogo que já queimou o bastante deixa só clareira
	for h in fire.keys():
		if round_no - int(fire[h]) >= FIRE_ROUNDS:
			fire.erase(h)
			dyn[h] = {"k": "clareira", "until": 999, "then": ""}
			changed_terrain = true
			log_msg(-1, "A mata queimou até virar cinzas.")
	# o fogo se espalha para as árvores vizinhas
	var spread = []
	for h in fire.keys():
		for d in DB.DIRS:
			var nb = h + d
			if not fire.has(nb) and String(terr(nb)["k"]) == "mata" and rng.randf() < 0.5 and not spread.has(nb):
				spread.append(nb)
	for nb in spread:
		_ignite(nb)
	if not spread.is_empty():
		log_msg(-1, "O incêndio se espalhou pela mata (%d casas)." % spread.size())
	# raios aleatórios: metade das vezes cai numa casa de mata
	var matas = []
	for h in DB.hexes:
		if String(terr(h)["k"]) == "mata":
			matas.append(h)
	for i in range(3):
		var tgt: Vector2i = DB.hexes[rng.randi() % DB.hexes.size()]
		if not matas.is_empty() and rng.randf() < 0.5:
			tgt = matas[rng.randi() % matas.size()]
		var lit = _ignite(tgt)
		emitfx({"t": "bolt", "h": tgt, "fire": lit})
		if lit:
			log_msg(-1, "Um raio atingiu a mata: ela pegou fogo!")
		await pace()
	if changed_terrain:
		load_map()
	emitfx({"t": "fire_set", "hexes": fire.keys()})
	# quem está perto do fogo se queima
	for u in units:
		if u.barrier or u.crystal != "" or u.st != "field" or not burning_near(u):
			continue
		log_msg(-1, "%s se queima perto do incêndio (1)." % nm(u))
		emitfx({"t": "boom", "h": u.pos()})
		damage(u, 1, null)
	settle()
	await pace()


func flag_time(p: int) -> void:
	if winner != NONE:
		return
	flagged = p
	winner = 1 - p
	log_msg(-1, "Tempo esgotado: %s." % ("jogador 1" if p == 0 else "jogador 2"))
	_send_cmd(["flag", p])
	changed.emit()


# casas da área de entrada do lado p (sempre na própria metade do mapa)
func entry_zone(p: int) -> Array:
	var r = zone_radius()
	var c0 = DB.entry_c[p]
	var c1 = DB.entry_c[1 - p]
	return DB.hexes.filter(func(h): return DB.dist(h, c0) <= r and (DB.dist(h, c0) <= 1 or DB.dist(h, c0) < DB.dist(h, c1)))


func deploy_hexes(p: int) -> Array:
	return entry_zone(p).filter(func(h): return is_free(h))


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
	await _run(["pass", p], func(): await _pass_turn(p))


func _pass_turn(p: int) -> void:
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
	undo = null
	_send_cmd(["start", u.uid])
	act = _new_act(u, 2, false)
	log_msg(u.owner, "Ativa %s." % nm(u))
	_act_begin(u)


func deploy(u, h: Vector2i, via_obj: bool = false) -> void:
	await _run(["deploy", u.uid, h, via_obj], func(): await _deploy(u, h, via_obj))


func _deploy(u, h: Vector2i, via_obj: bool = false) -> void:
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
		_act_begin(u)
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
	await _run(["end"], func(): await _end_activation())


func _end_activation() -> void:
	if act == null:
		return
	var a = act
	var u = by_uid(a["uid"])
	if u != null:
		u.activated = true
	if u != null and u.st == "field" and K(u).has("discs") and u.discs.size() < int(K(u)["discs"]):
		await _zaboo_disc(u)
	act = null
	await resolve_queues()
	if winner != NONE:
		return
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
	return await _run(["move", u.uid, h], func(): return await _act_move(u, h))


func _act_move(u, h: Vector2i) -> bool:
	if not is_live(u) or act["actions"] < 1 or rooted(u) or act["moved"]:
		return false
	if not can_reach(u, h):
		return false
	var snap = {"uid": u.uid, "from": u.pos(), "act": act.duplicate(true), "logs": logs.size(), "bn": bananas.size(), "core": core, "hp": u.hp,
		"fresh": act["actions"] == 2 and not act["tactic"] and not act["attacked"]}
	act["actions"] -= 1
	act["moved"] = true
	var from_h = u.pos()
	var pth = _path(u, from_h, h)
	await move_unit(u, h, true)
	_use_blue(u)
	await _ice_slide(u, pth[pth.size() - 2] if pth.size() >= 2 else from_h)
	if u.st == "field" and (in_zone(from_h) or in_zone(u.pos())):
		await vibrate(int(vrule("move", 1)), "%s andou perto do buraco" % nm(u))
	# só dá para desfazer se nada aconteceu no caminho (mina, banana, núcleo, dano)
	if logs.size() == snap["logs"] and bananas.size() == snap["bn"] and core == snap["core"] and u.hp == snap["hp"] and u.st == "field" and net_depth <= 1:
		undo = snap
	else:
		undo = null
	return true


# GELO LISO (Gor'Aida): quem termina o movimento no gelo desliza mais 1 casa na direção em que vinha,
# se a casa seguinte estiver livre e der para pisar nela
func _ice_slide(u, prev: Vector2i) -> void:
	if u.st != "field" or u.barrier or not tt_of(terr(u.pos())["k"]).get("slide", 0):
		return
	var d = u.pos() - prev
	if DB.dist(prev, u.pos()) != 1:
		return
	var nx = u.pos() + d
	if not is_free(nx) or not can_step(u.pos(), nx) or K(u).has("air"):
		return
	log_msg(u.owner, "%s escorregou no gelo liso." % nm(u))
	emitfx({"t": "passive", "kind": "slide", "uid": u.uid})
	await move_unit(u, nx, true)
	await arrive(u, true)


func can_undo() -> bool:
	return undo != null and act != null and act["uid"] == undo["uid"] and act["moved"] and not act["attacked"]


# desfaz o último movimento: a peça volta e as ações voltam como estavam
func undo_move() -> void:
	if not can_undo():
		return
	_send_cmd(["undo"])
	var u = by_uid(undo["uid"])
	var fpos = u.pos()
	u.q = undo["from"].x
	u.r = undo["from"].y
	emitfx({"t": "move", "uid": u.uid, "from": fpos, "to": u.pos()})
	act = null if undo["fresh"] else undo["act"]
	log_msg(u.owner, "%s desfez o movimento." % nm(u))
	undo = null
	changed.emit()


func act_attack(u, t) -> bool:
	return await _run(["attack", u.uid, t.uid], func(): return await _act_attack(u, t))


func _act_attack(u, t) -> bool:
	if not can_attack_now(u) or not attack_targets(u).has(t):
		return false
	act["actions"] -= 1
	var zone = in_zone(u.pos())
	var via: Variant = null
	if not _targets_from(u).has(t):
		for pt in portal_out_of(u):
			if unit_at(pt["b"]) == null and _targets_from(u, pt["b"]).has(t):
				via = pt["b"]
				break
	var home = u.pos()
	if via != null:
		log_msg(u.owner, "%s ataca através do portal (entra pela ENTRADA, sai pela SAÍDA)." % nm(u))
		abfx("burrow", home, u.uid)
		abfx("burrow", via, u.uid)
		u.q = via.x
		u.r = via.y
	await resolve_attack(u, t)
	if via != null:
		u.q = home.x
		u.r = home.y
	if zone and winner == NONE:
		await vibrate(int(vrule("act", 2)), "%s atacou perto do buraco" % nm(u))
	return true


func act_move_attack(u, h, t) -> bool:
	return await _run(["moveatk", u.uid, h, t.uid if t != null else null], func(): return await _act_move_attack(u, h, t))


func _act_move_attack(u, h, t) -> bool:
	if not is_live(u) or act["actions"] < 1 or K(u).get("action", "") != "moveAttack":
		return false
	act["actions"] -= 1
	act["from"] = u.pos()
	if h != null and h != u.pos() and not rooted(u) and not act["moved"]:
		act["moved"] = true
		abfx("dash", u.pos(), u.uid)
		var from_m = u.pos()
		await move_unit(u, h, true)
		_use_blue(u)
		if u.st == "field" and (in_zone(from_m) or in_zone(u.pos())):
			await vibrate(int(vrule("move", 1)), "%s avançou perto do buraco" % nm(u))
	if u.st != "field" or winner != NONE:
		return true
	if t == null:
		var ts = attack_targets(u) if can_attack_any(u) else []
		if not ts.is_empty():
			var hh = await pick_hex(u.owner, "Escolha o alvo do ataque.", ts, "enemy", true)
			if hh != null:
				t = unit_at(hh)
	if t != null and can_attack_any(u) and attack_targets(u).has(t) and winner == NONE:
		var zone2 = in_zone(u.pos())
		await resolve_attack(u, t)
		if zone2 and winner == NONE:
			await vibrate(int(vrule("act", 2)), "%s atacou perto do buraco" % nm(u))
	return true


func act_tunnel(u, h: Vector2i) -> bool:
	return await _run(["tunnel", u.uid, h], func(): return await _act_tunnel(u, h))


func _act_tunnel(u, h: Vector2i) -> bool:
	if not is_live(u) or act["actions"] < 1 or act["moved"]:
		return false
	if not tunnel_opts(u).has(h):
		return false
	act["actions"] -= 1
	act["moved"] = true
	abfx("burrow", u.pos(), u.uid)
	abfx("burrow", h, u.uid)
	var from_t = u.pos()
	await move_unit(u, h, true)
	_use_blue(u)
	if u.st == "field" and (in_zone(from_t) or in_zone(u.pos())):
		await vibrate(int(vrule("move", 1)), "%s cavou perto do buraco" % nm(u))
	return true


# ================= ativas dos comandantes (1 vez por partida) =================
func ult_kind(u) -> String:
	return str(K(u).get("ult", ""))


# ativa já gasta: "1 vez por partida" (comandantes) ou "1 vez por round" (ultRound)
func ult_spent(u) -> bool:
	if K(u).has("ultRound"):
		return u.ult_round >= 0 and round_no < u.ult_round + ABIL_RECHARGE
	return u.ult_used


func can_ult(u) -> bool:
	return is_live(u) and act["actions"] >= 1 and ult_kind(u) != "" and not ult_spent(u) and not ult_opts(u).is_empty()


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


# ================= Valakianos: ajudantes =================
# ativas sem alvo: não pedem escolha, valem para a própria peça
const SELF_ULTS = ["quake", "guardfirm"]


# casa onde alguém pode emergir, ser empurrado ou ser posto: livre, pisável, fora de buracos
func valid_ground(h: Vector2i) -> bool:
	return is_free(h) and not is_pit(h) and not hole.has(h) and int(tt_of(terr(h)["k"]).get("pass", 0)) == 1


# destino do empurrão de 1 casa na direção dir (o empurrão exige casa livre e válida)
func push_dir_dest(t, dir: Vector2i) -> Variant:
	var d = t.pos() + dir
	if not DB.in_board(d) or not valid_ground(d) or not can_step(t.pos(), d):
		return null
	return d


# efeitos "até o início da próxima ativação" da peça uid terminam quando ela sai do jogo
func _drop_src_fx(uid: int) -> void:
	for x in units:
		if x.fx.is_empty():
			continue
		x.fx = x.fx.filter(func(f): return not (f.get("until", "") == "act" and int(f.get("src", -1)) == uid))


# início da ativação de u: acabam os efeitos dela e a carga elétrica do Sniper descarrega
func _act_begin(u) -> void:
	_drop_src_fx(u.uid)
	if not has_fx(u, "elec") or u.barrier:
		return
	var ef = u.fx.filter(func(f): return f["k"] == "elec")[0]
	u.fx = u.fx.filter(func(f): return f["k"] != "elec")
	var sp = int(ef.get("sp", -1))
	var src = by_uid(int(ef.get("src", -1)))
	var hits = field().filter(func(x): return not x.barrier and x.owner != sp and x != u and DB.dist(x.pos(), u.pos()) == 1)
	abfx("bolt", u.pos(), int(ef.get("src", -1)))
	if hits.is_empty():
		return
	log_msg(sp, "Descarga elétrica de %s: 1 de dano em %d inimigo(s) do Sniper ao lado." % [nm(u), hits.size()])
	for x in hits:
		abfx("bolt", x.pos(), int(ef.get("src", -1)))
		damage(x, 1, src)
	settle()


func near_crystal(h: Vector2i) -> bool:
	for x in field():
		if x.crystal != "" and DB.dist(x.pos(), h) == 1:
			return true
	return false


# investida em linha reta (Carrinho de Minério, Golem Feram): casas livres até 2 e a unidade encontrada
func charge_line(u, d: Vector2i, feram: bool) -> Dictionary:
	var steps = []
	var cur = u.pos()
	var hit = null
	for k in range(2):
		var c = cur + d
		if not DB.in_board(c) or blocks.has(c) or cart_at(c) or is_pit(c) or hole.has(c) or not can_step(cur, c):
			break
		var t = unit_at(c)
		if t != null:
			if t.owner != u.owner and (feram or not t.barrier):
				hit = t
			break
		steps.append(c)
		cur = c
	return {"steps": steps, "hit": hit}


func charge_opts(u, feram: bool) -> Array:
	var out = []
	for d in _dirs():
		var L = charge_line(u, d, feram)
		if L["hit"] == null and L["steps"].is_empty():
			continue
		for st in L["steps"]:
			out.append(st)
		if L["hit"] != null:
			out.append(L["hit"].pos())
	return out


# casa baixa que o Engenheiro pode elevar em 1 nível (sem passar da altura dos terrenos ao redor)
func bridge_cell_ok(h: Vector2i) -> bool:
	if not valid_ground(h) or DB.in_entry(0, h) or DB.in_entry(1, h) or (core != null and core == h) or dyn.has(h):
		return false
	var tallest = -99
	for n in DB.nbrs(h):
		if not is_pit(n):
			tallest = max(tallest, h_of(n))
	# em terreno plano (sem nada mais alto por perto) ainda dá para erguer a casa até o nível 1
	return h_of(h) < max(tallest, 1) and h_of(h) < 3


func bridge_opts(u) -> Array:
	return DB.hexes.filter(func(h): return DB.dist(h, u.pos()) >= 1 and DB.dist(h, u.pos()) <= 2 and bridge_cell_ok(h))


# ================= Rei da Mina: Manipulação Mineral =================
const MANIP_R = 6


func tunnel_hex(h: Vector2i) -> bool:
	for t in tunnels:
		if t["a"] == h or t["b"] == h:
			return true
	for pt in live_portals():
		if pt["a"] == h or pt["b"] == h:
			return true
	return false


# portais cujo Guarda ainda está em campo
func live_portals() -> Array:
	return portals.filter(func(pt): return by_uid(int(pt["uid"])) != null and by_uid(int(pt["uid"])).st == "field")


func portal_of(u) -> Variant:
	for pt in live_portals():
		if int(pt["uid"]) == u.uid:
			return pt
	return null


# saídas de portal que u pode usar: precisa estar ao lado da ENTRADA de um portal do seu time
func portal_out_of(u) -> Array:
	var out = []
	if u.barrier or u.st != "field":
		return out
	for pt in live_portals():
		if int(pt["owner"]) == u.owner and DB.dist(u.pos(), pt["a"]) <= 1 and u.pos() != pt["b"]:
			out.append(pt)
	return out


# casa livre onde o Rei pode pôr/mover cristais, blocos e entradas de túnel
func val_hex_ok(h: Vector2i) -> bool:
	if not valid_ground(h) or DB.in_entry(0, h) or DB.in_entry(1, h) or (core != null and core == h) or dyn.has(h) or tunnel_hex(h):
		return false
	return true


func _edge_hex(h: Vector2i) -> bool:
	for d in DB.DIRS:
		if not DB.in_board(h + d):
			return true
	return false


func manip_structs(u) -> Array:
	return field().filter(func(x): return x.barrier and not x.soft and DB.dist(x.pos(), u.pos()) <= MANIP_R)


# destinos do movimento (até 2 casas): casas livres ou um inimigo do Rei, que é atingido pela estrutura
func manip_dests(s, rei = null) -> Array:
	var out = DB.hexes.filter(func(h): return DB.dist(h, s.pos()) >= 1 and DB.dist(h, s.pos()) <= 2 and val_hex_ok(h))
	if rei != null:
		for t in enemies_of(rei):
			var d = DB.dist(s.pos(), t.pos())
			if t.barrier or d < 1 or d > 2 or DB.dist(rei.pos(), t.pos()) > MANIP_R or has_fx(t, "veil") or imprisoned(t):
				continue
			# a 2 casas, precisa de uma casa livre no meio do caminho
			if d == 2 and not DB.nbrs(s.pos()).any(func(m): return DB.dist(m, t.pos()) == 1 and (val_hex_ok(m) or unit_at(m) == null and is_free(m) and not is_pit(m))):
				continue
			out.append(t.pos())
	return out


func manip_move_structs(u) -> Array:
	return manip_structs(u).filter(func(x): return not manip_dests(x, u).is_empty())


# a estrutura atinge o inimigo (4 de dano com altura e abrigo vistos do Rei) e é destruída
func _struct_hit(u, s2, t2) -> void:
	var tm = terrain_mods(u, t2)
	var packet = 4 + int(tm["atk"])
	var red = reduction_of(t2, false, DB.dist(u.pos(), t2.pos()))
	var dealt = max(0, packet - red - int(tm["cover"]) - int(tm["forest"]))
	abfx("bombard", t2.pos(), u.uid)
	emitfx({"t": "boom", "h": t2.pos()})
	log_msg(u.owner, "%s lança %s contra %s (%d de dano)." % [nm(u), nm(s2), nm(t2), dealt])
	damage(t2, dealt, u, true)
	s2.hp = 0
	s2.dying = u.uid
	if s2.crystal != "":
		_burst_at = t2.pos()
	settle()
	_burst_at = null


func manip_crystals(u) -> Array:
	return manip_structs(u).filter(func(x): return x.crystal != "")


func manip_lowerable(h: Vector2i) -> bool:
	return val_hex_ok(h) and h_of(h) >= 2 and not _edge_hex(h) and not hole.has(h)


func manip_lower_opts(u) -> Array:
	return DB.hexes.filter(func(h): return DB.dist(h, u.pos()) >= 1 and DB.dist(h, u.pos()) <= MANIP_R and manip_lowerable(h))


func manip_tunnel_opts(u) -> Array:
	return DB.hexes.filter(func(h): return DB.dist(h, u.pos()) >= 1 and DB.dist(h, u.pos()) <= MANIP_R and val_hex_ok(h))


# inimigos que o arremesso de estrutura pode atingir (até 6 casas do Rei, com linha de tiro)
func throw_targets(u) -> Array:
	return enemies_of(u).filter(func(t): return not t.barrier and DB.dist(u.pos(), t.pos()) <= MANIP_R and not has_fx(t, "veil") and not imprisoned(t) and los(u.pos(), t.pos()))


func manip_modes(u) -> Array:
	var out = []
	if not is_live(u) or not K(u).has("manip") or act == null or act["actions"] < 1:
		return out
	if not manip_move_structs(u).is_empty():
		out.append("move")
	if not manip_crystals(u).is_empty():
		out.append("color")
	if not manip_lower_opts(u).is_empty():
		out.append("lower")
	if manip_tunnel_opts(u).size() >= 2:
		out.append("tunnel")
	if can_attack_now(u) and not manip_structs(u).is_empty() and not throw_targets(u).is_empty():
		out.append("throw")
	return out


func can_manip(u) -> bool:
	return not manip_modes(u).is_empty()


const MANIP_LABEL = {"move": "Mover cristal/estrutura (até 2 casas; inimigo no destino é atingido)", "color": "Mudar a cor de um cristal", "lower": "Rebaixar terreno alto (vira bloco móvel)", "tunnel": "Criar túnel (duas entradas)", "throw": "Arremessar estrutura (ataque, 4 de dano)"}


func _make_crystal(p: int, h: Vector2i, color: String) -> Unit:
	var b = _make_barrier(NEUTRAL, h, 1)
	b.crystal = color
	b.sp_owner = p
	return b


# 5 cristais especiais em linha reta: lista de [início, direção] válidos
func val_lines(u) -> Array:
	var out = []
	for h in DB.hexes:
		if not val_hex_ok(h) or DB.dist(h, u.pos()) > MANIP_R:
			continue
		for d in DB.DIRS:
			var ok = true
			for k in range(5):
				var c = h + d * k
				if not DB.in_board(c) or DB.dist(c, u.pos()) > MANIP_R or not val_hex_ok(c):
					ok = false
					break
			if ok:
				out.append([h, d])
	return out


func val_start_opts(u) -> Array:
	var seen = {}
	for L in val_lines(u):
		seen[L[0]] = true
		seen[L[0] + L[1] * 4] = true
	return seen.keys()


# unidades de campo que sofrem o efeito de um cristal especial (aliados/inimigos do dono)
func _sp_effect(t, who: Array) -> bool:
	var hit = false
	var sp = t.sp_owner
	match t.crystal:
		"verde":
			for x in who:
				if x.owner == sp:
					heal(x, 2)
				else:
					damage(x, 2, null)
					hit = true
			log_msg(-1, "Cristal verde especial: aliados do Rei +2 de Vida, inimigos -2.")
		"azul":
			for x in who:
				x.fx = x.fx.filter(func(f): return not f.get("once", false))
				x.fx.append({"k": "mov", "v": 1 if x.owner == sp else -1, "until": "end", "once": true})
				emitfx({"t": "passive", "kind": "power", "uid": x.uid})
			log_msg(-1, "Cristal azul especial: aliados do Rei +1 de Movimento, inimigos -1 (próximo movimento, neste round).")
		"roxo":
			for x in who:
				x.fx = x.fx.filter(func(f): return f.get("src", -1) != -77)
				x.fx.append({"k": "atk", "v": 2 if x.owner == sp else -2, "till": round_no + 1, "src": -77})
				emitfx({"t": "passive", "kind": "power", "uid": x.uid})
			log_msg(-1, "Cristal roxo especial: aliados do Rei +2 de ATQ, inimigos -2 (até o fim do próximo round).")
	return hit


func act_manip(u) -> bool:
	return await _run(["manip", u.uid], func(): return await _act_manip(u))


func _act_manip(u) -> bool:
	var modes = manip_modes(u)
	if modes.is_empty():
		return false
	var p = u.owner
	var labels = modes.map(func(m): return MANIP_LABEL[m])
	var mi = await ask(p, {"t": "choice", "text": "Manipulação Mineral: o que fazer?", "opts": labels, "kind": "manip", "modes": modes, "uid": u.uid})
	if mi == null or int(mi) < 0 or int(mi) >= modes.size():
		return false
	var mode = String(modes[int(mi)])
	var nm_u = nm(u)
	match mode:
		"move":
			var st = await pick_hex(p, "Manipulação: escolha o cristal/estrutura a mover (até 6 casas).", manip_move_structs(u).map(func(x): return x.pos()), "manip_s", true)
			if st == null:
				return false
			var s = unit_at(st)
			var dh = await pick_hex(p, "Manipulação: escolha o destino (até 2 casas) — um inimigo ali é atingido e a estrutura se destrói.", manip_dests(s, u), "manip_d", true)
			if dh == null:
				return false
			act["actions"] -= 1
			var hit_t = unit_at(dh)
			if hit_t != null and hit_t.owner != p and not hit_t.barrier:
				await _struct_hit(u, s, hit_t)
				await pace()
				return true
			abfx("earth", s.pos(), u.uid)
			s.q = dh.x
			s.r = dh.y
			if s.crystal != "":
				s.sp_owner = p
			abfx("earth", dh, u.uid)
			emitfx({"t": "move", "uid": s.uid, "from": st, "to": dh})
			log_msg(p, "%s move %s." % [nm_u, nm(s)])
		"color":
			var ch = await pick_hex(p, "Manipulação: escolha o cristal cuja cor mudar (até 6 casas).", manip_crystals(u).map(func(x): return x.pos()), "manip_s", true)
			if ch == null:
				return false
			var c = unit_at(ch)
			var others = ["verde", "azul", "roxo"].filter(func(k): return k != c.crystal)
			var ci = await ask(p, {"t": "choice", "text": "Nova cor do cristal:", "opts": others.map(func(k): return k.capitalize()), "kind": "manip_color", "uid": u.uid})
			var ni = int(ci) if ci != null else 0
			c.crystal = others[clampi(ni, 0, others.size() - 1)]
			c.sp_owner = p
			act["actions"] -= 1
			abfx("crystal", c.pos(), u.uid)
			log_msg(p, "%s muda o cristal para %s (agora é especial)." % [nm_u, c.crystal])
		"lower":
			var lh = await pick_hex(p, "Manipulação: escolha o terreno alto a rebaixar (até 6 casas).", manip_lower_opts(u), "manip_s", true)
			if lh == null:
				return false
			act["actions"] -= 1
			earth[lh] = int(earth.get(lh, 0)) - 1
			load_map()
			var bl = _make_barrier(NEUTRAL, lh, 4)
			bl.block = true
			abfx("earth", lh, u.uid)
			emitfx({"t": "rumble", "hexes": [lh]})
			log_msg(p, "%s rebaixa o terreno em 1 nível e deixa um bloco de pedra móvel." % nm_u)
		"tunnel":
			var ta = await pick_hex(p, "Túnel: escolha a 1ª entrada (até 6 casas).", manip_tunnel_opts(u), "manip_d", true)
			if ta == null:
				return false
			var tb = await pick_hex(p, "Túnel: escolha a 2ª entrada.", manip_tunnel_opts(u).filter(func(h): return h != ta), "manip_d", true)
			if tb == null:
				return false
			act["actions"] -= 1
			tunnels = tunnels.filter(func(t): return t["owner"] != p)
			tunnels.append({"a": ta, "b": tb, "owner": p})
			abfx("burrow", ta, u.uid)
			abfx("burrow", tb, u.uid)
			emitfx({"t": "rumble", "hexes": [ta, tb]})
			log_msg(p, "%s abre um túnel entre duas entradas (visíveis para os dois)." % nm_u)
		"throw":
			var sh = await pick_hex(p, "Arremesso: escolha a estrutura a lançar (até 6 casas).", manip_structs(u).map(func(x): return x.pos()), "manip_s", true)
			if sh == null:
				return false
			var tg = await pick_hex(p, "Arremesso: escolha o inimigo a atingir (até 6 casas).", throw_targets(u).map(func(x): return x.pos()), "enemy", true)
			if tg == null:
				return false
			var s2 = unit_at(sh)
			var t2 = unit_at(tg)
			act["actions"] -= 1
			act["attacked"] = true
			_struct_hit(u, s2, t2)
	await pace()
	return true


var _burst_at: Variant = null


func can_mexit(u) -> bool:
	return is_live(u) and act != null and act["actions"] >= 1 and not act["moved"] and not rooted(u) and not imprisoned(u) and not tunnel_exits(u).is_empty()


func _exit_ok(h: Vector2i) -> bool:
	return DB.in_board(h) and unit_at(h) == null and not cart_at(h) and not hole.has(h) and not is_pit(h) and not blocks.has(h)


func tunnel_exits(u) -> Array:
	var out = []
	if u.barrier or u.st != "field":
		return out
	for pt in portal_out_of(u):
		if _exit_ok(pt["b"]):
			out.append(pt["b"])
		for n in DB.nbrs(pt["b"]):
			if n != u.pos() and _exit_ok(n) and not out.has(n):
				out.append(n)
	for t in tunnels:
		if t["owner"] != u.owner:
			continue
		for pr in [[t["a"], t["b"]], [t["b"], t["a"]]]:
			if DB.dist(u.pos(), pr[0]) <= 1 and u.pos() != pr[1] and unit_at(pr[1]) == null and not cart_at(pr[1]) and not hole.has(pr[1]) and not is_pit(pr[1]):
				out.append(pr[1])
	return out


func act_mexit(u) -> bool:
	return await _run(["mexit", u.uid], func(): return await _act_mexit(u))


func _act_mexit(u) -> bool:
	if not can_mexit(u):
		return false
	var h = await pick_hex(u.owner, "Túnel: escolha a saída.", tunnel_exits(u), "move", true)
	if h == null:
		return false
	act["actions"] -= 1
	act["moved"] = true
	act["from"] = u.pos()
	var from_t = u.pos()
	abfx("burrow", from_t, u.uid)
	abfx("burrow", h, u.uid)
	await move_unit(u, h, true)
	_use_blue(u)
	log_msg(u.owner, "%s atravessa o túnel." % nm(u))
	if u.st == "field" and (in_zone(from_t) or in_zone(u.pos())):
		await vibrate(int(vrule("move", 1)), "%s cruzou o túnel perto do buraco" % nm(u))
	return true


func ult_opts(u) -> Array:
	var p = u.pos()
	match ult_kind(u):
		# ---- Valakianos ----
		"burrow":
			return DB.hexes.filter(func(h): return DB.dist(h, p) >= 1 and DB.dist(h, p) <= 2 and valid_ground(h))
		"bwall", "rootweb":
			return DB.nbrs(p).filter(func(h): return valid_ground(h))
		"cartcharge":
			return charge_opts(u, false)
		"ferram":
			return charge_opts(u, true)
		"coat":
			return allies_of(u).filter(func(x): return DB.dist(x.pos(), p) == 1).map(func(x): return x.pos())
		"rupture":
			return field().filter(func(x): return x.barrier and DB.dist(x.pos(), p) == 1).map(func(x): return x.pos())
		"quake":
			if enemies_of(u).any(func(x): return DB.dist(x.pos(), p) == 1):
				return [p]
			return []
		"guardfirm":
			return [p]
		"timedcharge":
			return DB.hexes.filter(func(h): return DB.dist(h, p) >= 1 and DB.dist(h, p) <= 2 and is_free(h) and not shells.any(func(sh): return sh["h"] == h))
		"lumen", "nursing":
			return allies_of(u).filter(func(x): return DB.dist(x.pos(), p) <= 2 and x.hp < x.maxhp).map(func(x): return x.pos())
		"route":
			return allies_of(u).filter(func(x): return DB.dist(x.pos(), p) <= 2).map(func(x): return x.pos())
		"bridge":
			return bridge_opts(u)
		"valbarrier":
			return val_start_opts(u)
		"portalis":
			var po = DB.hexes.filter(func(h): return DB.dist(h, p) >= 1 and DB.dist(h, p) <= 6 and val_hex_ok(h))
			return po if po.size() >= 2 else []
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
		"mend":
			return allies_of(u, true).filter(func(x): return DB.cards[x.cid]["f"] == "ABY" and DB.dist(x.pos(), p) <= 3 and x.hp < x.maxhp).map(func(x): return x.pos())
		"plate":
			return allies_of(u).filter(func(x): return DB.dist(x.pos(), p) == 1 and not has_fx(x, "plated")).map(func(x): return x.pos())
		"detonate":
			return mines.filter(func(m): return m["owner"] == u.owner and not m.get("hidden", false)).map(func(m): return m["h"])
		"barricade":
			return adj_free(p)
		"grenade":
			return enemies_of(u).filter(func(t): return DB.dist(t.pos(), p) <= 3 and not has_fx(t, "veil") and not imprisoned(t)).map(func(t): return t.pos())
		"artillery":
			return DB.hexes.filter(func(h): return DB.dist(h, p) >= 1 and DB.dist(h, p) <= 5 and not blocks.has(h))
	return []


# pontuação para a CPU escolher onde usar a ativa
func ult_score(u, h: Vector2i) -> float:
	var t = unit_at(h)
	match ult_kind(u):
		"portalis":
			if portal_pick_a == null:
				# entrada: perto dos aliados que vão usar
				var pe = 0.0
				for al in allies_of(u, true):
					if DB.dist(al.pos(), h) <= 1:
						pe += 1.5
				return pe
			# saída: perto dos inimigos, longe do alcance da entrada
			var ps = 0.0
			for e in enemies_of(u):
				if not e.barrier and DB.dist(e.pos(), h) <= 6 and DB.dist(e.pos(), portal_pick_a) > 4:
					ps += 2.0 + (3.0 if e.is_cmd else 0.0)
			return ps
		"valbarrier":
			# linha que separa o Rei dos inimigos: conta os inimigos mais perto da linha que do Rei
			var vs = 0.0
			for e in enemies_of(u):
				if not e.barrier and DB.dist(e.pos(), h) <= 3:
					vs += 0.8
			return vs + (1.0 if u.hp * 2 <= u.maxhp else 0.0)
		"burrow":
			var sb1 = 0.0
			for e1 in enemies_of(u):
				if not e1.barrier and DB.dist(e1.pos(), h) == 1:
					sb1 = max(sb1, 2.0 + (3.0 if e1.hp <= 2 else 0.0) + (3.0 if e1.is_cmd else 0.0))
			return sb1
		"bwall", "rootweb":
			var sw = 0.0
			for e2 in enemies_of(u):
				if DB.dist(e2.pos(), h) <= 3:
					sw += 0.7
			for a2 in allies_of(u):
				if DB.dist(a2.pos(), h) == 1:
					sw += 0.5
			return sw
		"cartcharge", "ferram":
			if t == null:
				return 0.0
			return 3.0 + (3.0 if t.hp <= 2 else 0.0) + (2.0 if t.is_cmd else 0.0) - (1.5 if t.barrier else 0.0)
		"coat":
			if t == null:
				return 0.0
			var sc2 = 0.0
			for e3 in enemies_of(u):
				if DB.dist(e3.pos(), t.pos()) <= 3:
					sc2 += 0.7
			return sc2 + (1.0 if t.hp <= 6 else 0.0)
		"rupture":
			if t == null or t.owner == u.owner:
				return -5.0
			var behind = unit_at(h + (h - u.pos()))
			return 2.0 + (3.0 if behind != null and behind.owner != u.owner and not behind.barrier else 0.0)
		"quake":
			var sq = 0.0
			for e4 in enemies_of(u):
				if DB.dist(e4.pos(), u.pos()) == 1:
					sq += 1.0 if e4.barrier else 2.0 + (3.0 if e4.hp <= 1 else 0.0) + (3.0 if e4.is_cmd else 0.0)
			return sq
		"timedcharge":
			var st2 = 0.0
			if t != null:
				st2 += 3.0 if t.owner != u.owner else -4.0
			for n3 in DB.nbrs(h):
				var o3 = unit_at(n3)
				if o3 != null:
					st2 += 1.0 if o3.owner != u.owner else -2.0
			# o inimigo ainda pode se mexer: vale mais cercar quem está perto
			for e5 in enemies_of(u):
				if DB.dist(e5.pos(), h) <= 2:
					st2 += 0.4
			return st2
		"guardfirm":
			var sg2 = 0.0
			var near_e = enemies_of(u).filter(func(x): return DB.dist(x.pos(), u.pos()) <= 3).size()
			if near_e > 0:
				sg2 = 0.6 * float(1 + allies_of(u).filter(func(x): return DB.dist(x.pos(), u.pos()) == 1).size())
			return sg2
		"lumen", "nursing":
			if t == null:
				return 0.0
			var amt = (3 if near_crystal(h) else 2) if ult_kind(u) == "lumen" else (4 if (near_crystal(h) or near_crystal(u.pos())) else 3)
			return float(min(t.maxhp - t.hp, amt)) + (2.0 if t.is_cmd else 0.0)
		"route":
			if t == null:
				return 0.0
			return 1.0 if enemies_of(u).any(func(x): return DB.dist(x.pos(), t.pos()) <= 6) else 0.0
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
		"mend":
			return float(t.maxhp - t.hp) + (3.0 if t.is_cmd else 0.0) if t != null else 0.0
		"plate":
			var sp = 0.0
			if t != null:
				for e9 in enemies_of(u):
					if DB.dist(e9.pos(), t.pos()) <= 3:
						sp += 0.7
				sp += 0.3 * float(10 - t.hp) / 3.0
			return sp
		"detonate":
			var sd = 0.0
			for e6 in enemies_of(u):
				if DB.dist(e6.pos(), h) <= 1:
					sd += 3.0 + (3.0 if e6.hp <= 3 else 0.0) + (3.0 if e6.is_cmd else 0.0)
			return sd
		"grenade":
			var sg = 0.0
			if t != null:
				sg += 3.0 + (4.0 if t.hp <= 2 else 0.0) + (3.0 if t.is_cmd else 0.0)
			for e7 in enemies_of(u):
				if e7 != t and DB.dist(e7.pos(), h) <= 1:
					sg += 1.0 + (2.0 if e7.hp <= 1 else 0.0)
			return sg
		"artillery":
			# o inimigo pode se mexer: vale mais cercar quem está perto e evitar os próprios aliados
			var sa = 0.0
			if t != null:
				sa += (2.0 if t.owner != u.owner else -4.0)
			for n2 in DB.nbrs(h):
				var o2 = unit_at(n2)
				if o2 != null:
					sa += 1.0 if o2.owner != u.owner else -2.0
			return sa
		"barricade":
			var sb = 0.0
			for e8 in enemies_of(u):
				if DB.dist(e8.pos(), h) <= 3:
					sb += 0.7
			for a8 in allies_of(u):
				if DB.dist(a8.pos(), h) == 1:
					sb += 0.5
			return sb
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
	return await _run(["ult", u.uid], func(): return await _act_ult(u))


func _act_ult(u) -> bool:
	if not can_ult(u):
		return false
	var p = u.owner
	var kind = ult_kind(u)
	var ab2 = DB.active_of(u.cid)
	var uname = ab2.get("name", "Ativa")
	var texts = {"mend": "escolha o Abyssal a restaurar (até 3 casas)", "plate": "escolha o aliado adjacente a reforçar", "detonate": "escolha a mina a detonar", "barricade": "escolha a casa adjacente da Barricada", "grenade": "escolha o alvo da granada (até 3, passa por cima de obstáculos)", "artillery": "escolha a casa que a artilharia vai atingir no início do próximo round (até 5)", "abyss": "escolha o inimigo a puxar (até 8 casas)", "bombard": "escolha a casa do bombardeio (até 6)", "prison": "escolha o inimigo a prender (até 4)", "earth": "escolha a 1ª casa a mudar de altura (até 4)", "stampede": "escolha até onde avançar em linha reta", "orbital": "escolha onde pousar (até 5)",
		"burrow": "escolha onde emergir (até 2 casas)", "bwall": "escolha a casa adjacente da muralha", "rootweb": "escolha a casa adjacente das raízes",
		"cartcharge": "escolha até onde avançar em linha reta (até 2) ou o alvo do impacto", "ferram": "escolha até onde avançar em linha reta (até 2) ou o alvo da investida",
		"coat": "escolha o aliado adjacente a revestir", "rupture": "escolha a barreira adjacente a romper", "timedcharge": "escolha a casa da carga (até 2)",
		"lumen": "escolha o aliado a curar (até 2 casas)", "nursing": "escolha o aliado a tratar (até 2 casas)", "route": "escolha o aliado que ganha a rota (até 2 casas)",
		"bridge": "escolha a 1ª casa baixa a elevar (até 2 casas dele; até 3 casas ligadas)",
		"valbarrier": "escolha uma ponta da linha de 5 cristais (até 6 casas)",
		"portalis": "escolha a ENTRADA do portal (até 6 casas): por onde aliados e ataques entram"}
	var h: Variant = null
	if SELF_ULTS.has(kind):
		h = u.pos()
	else:
		h = await pick_hex(p, "%s: %s." % [uname, texts.get(kind, "escolha")], ult_opts(u), "ult", true)
	if h == null:
		return false
	act["actions"] -= 1
	var ult_zone = in_zone(u.pos())
	if K(u).has("ultRound"):
		u.ult_round = round_no
	else:
		u.ult_used = true
	log_msg(p, "%s usou %s." % [nm(u), uname])
	emitfx({"t": "ult", "uid": u.uid, "name": uname, "p": p})
	emitfx({"t": "passive", "kind": "ability", "uid": u.uid})
	await pace()
	match kind:
		# ---- Valakianos ----
		"burrow":
			abfx("burrow", u.pos(), u.uid)
			await move_unit(u, h, true)
			abfx("burrow", h, u.uid)
			if u.st == "field":
				var vb_t = enemies_of(u).filter(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) == 1)
				if not vb_t.is_empty():
					var vb_h = await pick_hex(p, "%s: 2 de dano em um inimigo ao lado da saída (ou Pular)." % uname, vb_t, "enemy", true)
					if vb_h != null:
						var vb_e = unit_at(vb_h)
						emitfx({"t": "strike", "from": u.uid, "to": vb_e.uid, "ranged": false})
						damage(vb_e, 2, u)
						log_msg(p, "%s emerge e causa 2 de dano em %s." % [nm(u), nm(vb_e)])
						settle()
		"bwall", "rootweb":
			var bw_soft = kind == "rootweb"
			var bw_n = 3 if bw_soft else 4
			abfx("barrier", h, u.uid)
			_make_barrier(p, h, bw_n, round_no + 1, bw_soft)
			log_msg(p, "%s cria %s com %d de Vida (some ao fim do próximo round)." % [nm(u), "uma trama de raízes" if bw_soft else "uma muralha de basalto", bw_n])
		"cartcharge", "ferram":
			var ch_f = kind == "ferram"
			var ch_from = u.pos()
			var ch_dir = Vector2i.ZERO
			var ch_L = {"steps": [], "hit": null}
			for d in _dirs():
				var Lx = charge_line(u, d, ch_f)
				if Lx["steps"].has(h) or (Lx["hit"] != null and Lx["hit"].pos() == h):
					ch_dir = d
					ch_L = Lx
					break
			var ch_moved = false
			for c in ch_L["steps"]:
				abfx("stomp", c, u.uid)
				await move_unit(u, c, true)
				ch_moved = true
				if u.st != "field" or winner != NONE or c == h:
					break
			if u.st == "field" and ch_L["hit"] != null and ch_L["hit"].pos() == h:
				var ch_t = ch_L["hit"]
				var ch_dmg = 4 if (ch_f and ch_t.barrier) else 2
				emitfx({"t": "strike", "from": u.uid, "to": ch_t.uid, "ranged": false})
				damage(ch_t, ch_dmg, u, true)
				log_msg(p, "%s: %s sofre %d." % [uname, nm(ch_t), ch_dmg])
				settle()
				if ch_t.st == "field" and not ch_t.barrier and winner == NONE:
					var ch_to = push_dir_dest(ch_t, ch_dir)
					if ch_to != null:
						abfx("push", ch_t.pos(), u.uid)
						await move_unit(ch_t, ch_to)
			# o deslocamento do Carrinho perto do buraco vale +3 de vibração (no lugar do +1 de andar)
			if not ch_f and ch_moved and winner == NONE and (in_zone(ch_from) or (u.st == "field" and in_zone(u.pos()))):
				await vibrate(3, "%s avançou perto do buraco" % nm(u))
		"coat":
			var ct_t = unit_at(h)
			ct_t.fx = ct_t.fx.filter(func(f): return not (f["k"] == "coat" and int(f.get("src", -1)) == u.uid))
			ct_t.fx.append({"k": "coat", "v": 2, "src": u.uid, "until": "act"})
			abfx("barrier", h, u.uid)
			emitfx({"t": "passive", "kind": "shield", "uid": ct_t.uid})
			log_msg(p, "%s reveste %s: -2 no próximo dano sofrido." % [nm(u), nm(ct_t)])
		"rupture":
			var rp_b = unit_at(h)
			var rp_dir = h - u.pos()
			abfx("blast", h, u.uid)
			emitfx({"t": "strike", "from": u.uid, "to": rp_b.uid, "ranged": false})
			damage(rp_b, 4, u, true)
			settle()
			if rp_b.st == "dead":
				var rp_e = unit_at(h + rp_dir)
				if rp_e != null and rp_e.owner != p and not rp_e.barrier:
					var rp_to = push_dir_dest(rp_e, rp_dir)
					if rp_to != null:
						abfx("push", rp_e.pos(), u.uid)
						log_msg(p, "A barreira rompe e empurra %s." % nm(rp_e))
						await move_unit(rp_e, rp_to)
		"quake":
			abfx("quake", u.pos(), u.uid)
			var qk_en = enemies_of(u).filter(func(x): return DB.dist(x.pos(), u.pos()) == 1)
			for qx in qk_en:
				damage(qx, 2 if qx.barrier else 1, u)
			settle()
			for qx2 in qk_en:
				if qx2.st == "field" and not qx2.barrier and winner == NONE:
					var qk_to = push_dir_dest(qx2, qx2.pos() - u.pos())
					if qk_to != null:
						abfx("push", qx2.pos(), u.uid)
						await move_unit(qx2, qk_to)
		"timedcharge":
			shells.append({"h": h, "owner": p, "round": round_no, "src": u.uid, "kind": "charge"})
			abfx("mark", h, u.uid)
			log_msg(p, "%s planta uma carga: explode no início do próximo round." % nm(u))
		"guardfirm":
			var gf_group = [u]
			for gx in allies_of(u):
				if DB.dist(gx.pos(), u.pos()) == 1:
					gf_group.append(gx)
			for gx2 in gf_group:
				gx2.fx = gx2.fx.filter(func(f): return not (f["k"] == "red" and f.get("until", "") == "act" and int(f.get("src", -1)) == u.uid))
				gx2.fx.append({"k": "red", "v": 1, "until": "act", "src": u.uid})
				emitfx({"t": "passive", "kind": "shield", "uid": gx2.uid})
			abfx("barrier", u.pos(), u.uid)
			log_msg(p, "%s firma a guarda: -1 de dano para %d peça(s) até a próxima ativação." % [nm(u), gf_group.size()])
		"lumen", "nursing":
			var lm_t = unit_at(h)
			var lm_n = 0
			if kind == "lumen":
				lm_n = 3 if near_crystal(h) else 2
			else:
				lm_n = 4 if (near_crystal(h) or near_crystal(u.pos())) else 3
			abfx("heal", h, u.uid)
			var lm_got = heal(lm_t, lm_n)
			log_msg(p, "%s cura %d de Vida de %s." % [nm(u), lm_got, nm(lm_t)])
		"route":
			var rt_t = unit_at(h)
			rt_t.fx = rt_t.fx.filter(func(f): return not (int(f.get("src", -1)) == u.uid and (f["k"] == "mov" or f["k"] == "climb1")))
			rt_t.fx.append({"k": "mov", "v": 1, "once": true, "till": round_no + 1, "src": u.uid})
			rt_t.fx.append({"k": "climb1", "till": round_no + 1, "src": u.uid})
			abfx("buff", h, u.uid)
			emitfx({"t": "passive", "kind": "power", "uid": rt_t.uid})
			log_msg(p, "%s traça uma rota: %s ganha +1 de Movimento e sobe 1 nível a mais." % [nm(u), nm(rt_t)])
		"valbarrier":
			var vb_ends = []
			for vl in val_lines(u):
				if vl[0] == h:
					vb_ends.append(vl[0] + vl[1] * 4)
				elif vl[0] + vl[1] * 4 == h:
					vb_ends.append(vl[0])
			var vb_o = h
			if vb_ends.size() > 1:
				vb_o = await pick_hex(p, "%s: escolha a outra ponta da linha." % uname, vb_ends, "ult", false)
			else:
				vb_o = vb_ends[0]
			var vb_step = Vector2i(0, 0)
			for d2 in DB.DIRS:
				if h + d2 * 4 == vb_o:
					vb_step = d2
			var vb_cols = ["verde", "azul", "roxo"]
			for k in range(5):
				var vb_c = h + vb_step * k
				var vb_ci = await ask(p, {"t": "choice", "text": "Cor do cristal %d de 5:" % (k + 1), "opts": ["Verde", "Azul", "Roxo"], "kind": "val_color", "uid": u.uid, "h": vb_c})
				_make_crystal(p, vb_c, vb_cols[clampi(int(vb_ci) if vb_ci != null else 0, 0, 2)])
				abfx("crystal", vb_c, u.uid)
			emitfx({"t": "rumble", "hexes": [h, h + vb_step * 4]})
			log_msg(p, "%s ergue a Barreira de Valak: 5 cristais especiais em linha." % nm(u))
		"portalis":
			portal_pick_a = h
			var po_b = ult_opts(u).filter(func(x): return x != h)
			var hb = await pick_hex(p, "%s: escolha a SAÍDA do portal (até 6 casas): por onde aliados e ataques saem." % uname, po_b, "ult", false)
			portal_pick_a = null
			portals = portals.filter(func(pt): return int(pt["uid"]) != u.uid)
			portals.append({"a": h, "b": hb, "uid": u.uid, "owner": p})
			abfx("burrow", h, u.uid)
			abfx("burrow", hb, u.uid)
			emitfx({"t": "rumble", "hexes": [h, hb]})
			log_msg(p, "%s abre o portal: ENTRADA em %s e SAÍDA em %s. Aliados ao lado da entrada atravessam e atacam pela saída." % [nm(u), t_name(h), t_name(hb)])
		"bridge":
			var br_cells = [h]
			for br_i in range(2):
				var br_more = bridge_opts(u).filter(func(x): return not br_cells.has(x) and br_cells.any(func(c): return DB.dist(x, c) == 1))
				if br_more.is_empty():
					break
				var br_h2 = await pick_hex(p, "%s: elevar também uma casa vizinha (%d de 3) ou Pular." % [uname, br_cells.size() + 1], br_more, "ult", true)
				if br_h2 == null:
					break
				br_cells.append(br_h2)
			for bc in br_cells:
				earth[bc] = int(earth.get(bc, 0)) + 1
				abfx("earth", bc, u.uid)
			load_map()
			emitfx({"t": "rumble", "hexes": br_cells})
			log_msg(p, "%s eleva %d casa(s) e liga os terrenos (permanente)." % [nm(u), br_cells.size()])
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
				for ex in enemies_of(u).filter(func(x): return x != t3 and DB.dist(x.pos(), h) == 1):
					apply_slow(ex, u)
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
				emitfx({"t": "rumble", "hexes": [cur_h]})
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
		"mend":
			var tm9 = unit_at(h)
			abfx("heal", h, u.uid)
			heal(tm9, 6)
			log_msg(p, "Luz da Fenda: %s se recompõe." % nm(tm9))
		"plate":
			var tp9 = unit_at(h)
			tp9.fx.append({"k": "red", "v": 1, "until": "end"})
			tp9.fx.append({"k": "plated", "v": 1, "until": "end"})
			abfx("barrier", h, u.uid)
			log_msg(p, "Casco de Reparo: %s sofre 1 a menos de dano neste round." % nm(tp9))
		"detonate":
			mines = mines.filter(func(m): return not (m["h"] == h and m["owner"] == p))
			abfx("bombard", h, u.uid)
			emitfx({"t": "boom", "h": h})
			for e in enemies_of(u).filter(func(x): return DB.dist(x.pos(), h) <= 1):
				damage(e, 3, u)
			settle()
		"barricade":
			var nb = 3
			abfx("barrier", h, u.uid)
			_make_barrier(p, h, nb)
			log_msg(p, "%s ergue uma Barricada com %d de Vida." % [nm(u), nb])
		"grenade":
			var tg = unit_at(h)
			abfx("blast", h, u.uid)
			emitfx({"t": "boom", "h": h})
			if tg != null:
				damage(tg, 2, u)
			for e2 in enemies_of(u).filter(func(x): return x != tg and DB.dist(x.pos(), h) <= 1):
				damage(e2, 1, u)
			settle()
		"artillery":
			shells.append({"h": h, "owner": p, "round": round_no, "src": u.uid})
			abfx("mark", h, u.uid)
			log_msg(p, "Artilharia marcada: cai no início do próximo round.")
		"orbital":
			abfx("orbital", h, u.uid)
			await move_unit(u, h, true)
			emitfx({"t": "boom", "h": h})
			for n in DB.nbrs(h):
				var e3 = unit_at(n)
				if e3 != null and e3.owner != p and not e3.barrier:
					damage(e3, 2, u)
			settle()
	if ult_zone and winner == NONE:
		await vibrate(int(vrule("act", 2)), "%s usou uma habilidade perto do buraco" % nm(u))
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
	return await _run(["interact", u.uid], func(): return await _act_interact(u))


func _act_interact(u) -> bool:
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
	return res.has(u.pos()) and res[u.pos()] != "escaravelho" and is_live(u) and act["actions"] > 0


func act_collect(u) -> bool:
	return await _run(["collect", u.uid], func(): return await _act_collect(u))


func _act_collect(u) -> bool:
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
	elif t == "escaravelho":
		P[p]["scarabs"] = int(P[p]["scarabs"]) + 1
		emitfx({"t": "passive", "kind": "ability", "uid": u.uid})
		log_msg(p, "Escaravelho Verde guardado (%d)." % int(P[p]["scarabs"]))
	elif t == "sucata":
		var ops = adj_free(u.pos())
		if not ops.is_empty():
			var h = await pick_hex(p, "Sucata: escolha onde montar a Barreira de 3 de Vida (ou pule).", ops, "place", true)
			if h != null:
				_make_barrier(p, h, 3)
	await pace()
	return true


# ================= escaravelhos verdes (Tarhut) =================
# 1 escaravelho: restaura 6 de Vida de uma peça. 2 escaravelhos: uma peça usa a ativa mais uma vez.
# No fim da partida, cada escaravelho guardado soma +1 à Vida do comandante na contagem.
const SCARAB_HEAL = 6


func scarabs_of(p: int) -> int:
	return int(P[p].get("scarabs", 0))


func scarab_opts(p: int, mode: String) -> Array:
	if mode == "heal":
		return field().filter(func(x): return x.owner == p and not x.barrier and x.hp < x.maxhp).map(func(x): return x.pos())
	if mode == "ult":
		return field().filter(func(x): return x.owner == p and not x.barrier and ult_kind(x) != "" and ult_spent(x)).map(func(x): return x.pos())
	return []


func can_scarab(p: int, mode: String) -> bool:
	if winner != NONE or cur != p or scarabs_of(p) < (1 if mode == "heal" else 2):
		return false
	return not scarab_opts(p, mode).is_empty()


func act_scarab(p: int, mode: String) -> bool:
	return await _run(["scarab", p, mode], func(): return await _act_scarab(p, mode))


func _act_scarab(p: int, mode: String) -> bool:
	if not can_scarab(p, mode):
		return false
	var txt = "Escaravelho: escolha a peça que restaura %d de Vida." % SCARAB_HEAL if mode == "heal" else "2 Escaravelhos: escolha a peça que poderá usar a ativa mais uma vez."
	var h = await pick_hex(p, txt, scarab_opts(p, mode), "ally", true)
	if h == null:
		return false
	var t = unit_at(h)
	if t == null:
		return false
	if mode == "heal":
		P[p]["scarabs"] = scarabs_of(p) - 1
		abfx("heal", h, t.uid)
		heal(t, SCARAB_HEAL)
		log_msg(p, "Escaravelho: %s restaura Vida." % nm(t))
	else:
		P[p]["scarabs"] = scarabs_of(p) - 2
		t.ult_used = false
		t.ult_round = -1
		abfx("buff", h, t.uid)
		emitfx({"t": "passive", "kind": "power", "uid": t.uid})
		log_msg(p, "2 Escaravelhos: %s pode usar a ativa mais uma vez." % nm(t))
	await pace()
	changed.emit()
	return true


func _make_barrier(p: int, h: Vector2i, n: int, exp: int = 0, soft: bool = false) -> Unit:
	var b = Unit.new()
	b.exp = exp
	b.soft = soft
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
	return b


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
	if t.hitters_round != round_no:
		t.hitters = []
		t.hitters_round = round_no
	t.hitters.append(a.uid)
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
	var bomb_punch = false
	if K(a).has("charge") and a.charge and a.hp > int(K(a).get("chargeCost", 2)):
		var yes_c = await ask(p, {"t": "yesno", "text": "Soco Bomba: liberar a carga? +%d de dano, mas %s perde %d de Vida." % [int(K(a)["charge"]), nm(a), int(K(a).get("chargeCost", 2))], "kind": "charge", "uid": a.uid})
		if yes_c:
			a.charge = false
			bomb_punch = true
			packet += int(K(a)["charge"])
			emitfx({"t": "passive", "kind": "power", "uid": a.uid})
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
	var counter_by: Variant = null
	if not t.barrier:
		for b in allies_of(t).filter(func(x): return K(x).has("guard") and DB.dist(x.pos(), t.pos()) == 1 and not (K(x).has("guardOnce") and guard_round.get(x.uid, -1) == round_no)):
			var yes = await ask(d, {"t": "yesno", "text": "Guarda Silencioso: %s recebe o ataque de %d no lugar de %s?" % [nm(b), packet, nm(t)], "kind": "balu", "packet": packet, "target": t.uid, "guard": b.uid})
			if yes:
				target = b
				if K(b).has("counter"):
					counter_by = b
				if K(b).has("lament"):
					a.fx.append({"k": "atk", "v": -1, "until": "end"})
					log_msg(d, "Lamento do Abismo: %s perde 1 ATQ neste round." % nm(a))
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
	var red = reduction_of(target, false, DB.dist(a.pos(), target.pos()))
	var storm_pen = 2 if storm_on() else 0
	if rain_on():
		storm_pen += RAIN_PEN
	var dealt = max(0, packet - red - react_red - int(tm2["cover"]) - int(tm2["forest"]) - storm_pen)
	if target.crystal != "":
		dealt = max(dealt, 1)   # um ataque normal sempre quebra o cristal
	if rain_on():
		log_msg(p, "Chuva: -%d de dano (o golpe erra o alvo)." % RAIN_PEN)
	if storm_on():
		log_msg(p, "Tempestade de areia: -2 de dano.")
	if (red > 0 or react_red > 0) and not target.barrier:
		emitfx({"t": "passive", "kind": "shield", "uid": target.uid})
	damage(target, dealt, a, true)
	if counter_by != null and counter_by.hp > 0 and a.st == "field" and DB.dist(counter_by.pos(), a.pos()) <= int(K(counter_by)["counter"]):
		var cd2 = max(0, atk_of(counter_by, a) - reduction_of(a))
		emitfx({"t": "strike", "from": counter_by.uid, "to": a.uid, "ranged": DB.dist(counter_by.pos(), a.pos()) > 1})
		log_msg(counter_by.owner, "Contragolpe: %s revida %s (%d)." % [nm(counter_by), nm(a), cd2])
		damage(a, cd2, counter_by, true)
	if bomb_punch:
		abfx("blast", target.pos(), a.uid)
		log_msg(p, "Soco Bomba! %s perde %d de Vida." % [nm(a), int(K(a).get("chargeCost", 2))])
		damage(a, int(K(a).get("chargeCost", 2)), null)
	# Skarp: devolve dano sempre que é atacado e pode contra-atacar 1 vez por inimigo a cada round
	if K(target).has("spiky") and not target.barrier and a.st == "field":
		var ns = int(K(target)["spiky"])
		abfx("zap", a.pos(), target.uid)
		log_msg(target.owner, "%s: %s sofre %d de retorno." % [DB.cards[target.cid]["ab"]["name"], nm(a), ns])
		damage(a, ns, target)
		if target.hp > 0 and a.hp > 0 and target.countered.get(a.uid, -1) != round_no:
			var dd = DB.dist(target.pos(), a.pos())
			if dd <= alc_of(target) and los(target.pos(), a.pos()) and not (dd == 1 and abs(stand_h(target.pos()) - stand_h(a.pos())) > 1):
				target.countered[a.uid] = round_no
				var cdmg = max(0, atk_of(target, a) - reduction_of(a))
				emitfx({"t": "strike", "from": target.uid, "to": a.uid, "ranged": dd > 1})
				log_msg(target.owner, "%s contra-ataca %s (%d)." % [nm(target), nm(a), cdmg])
				damage(a, cdmg, target, true)
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
		if after == "toxin" and not target.barrier and not target.fx.any(func(f): return f["k"] == "tox"):
			target.fx.append({"k": "tox", "src": a.uid})
			abfx("poison", target.pos(), a.uid)
			log_msg(p, "%s foi envenenado: perde 1 de Vida a cada round." % nm(target))
		if after == "slowHit":
			apply_slow(target, a)
		if after == "elec" and not target.barrier:
			target.fx = target.fx.filter(func(f): return not (f["k"] == "elec" and int(f.get("src", -1)) == a.uid))
			target.fx.append({"k": "elec", "src": a.uid, "sp": a.owner, "till": round_no + 1})
			abfx("zap", target.pos(), a.uid)
			log_msg(p, "%s está carregado de eletricidade." % nm(target))
		if after == "rootCharge" and act != null and act["uid"] == a.uid and act["moved"] and act.has("from") and DB.dist(act["from"], a.pos()) >= 2:
			apply_root(target, a)
		if after == "breakRoot" and rooted(target):
			target.fx = target.fx.filter(func(f): return f["k"] != "root")
			target.fx.append({"k": "rootimm", "till": round_no + 3})
			abfx("nova", target.pos(), a.uid)
			log_msg(p, "Quebra-gelo: o enraizamento de %s se desfaz." % nm(target))
		if after == "pending":
			pending.append({"uid": target.uid, "n": 1, "p": p, "src": a.uid})
			abfx("poison", target.pos(), a.uid)
		if after == "venom" and not target.barrier and a.venoms < 3 and not has_fx(target, "venom"):
			a.venoms += 1
			target.fx.append({"k": "venom", "src": a.uid})
			abfx("poison", target.pos(), a.uid)
			log_msg(p, "Veneno Lento: %s está envenenado até o fim da partida (%d/3)." % [nm(target), a.venoms])
		if after == "blind" and not target.barrier:
			target.fx.append({"k": "atk", "v": -2, "until": "end"})
			target.fx.append({"k": "dazed", "v": 1, "until": "end"})
			abfx("silence", target.pos(), a.uid)
			log_msg(p, "Nuvem de Tinta: %s está cego (-2 ATQ)." % nm(target))
		if after == "rootHit":
			abfx("glue", target.pos(), a.uid)
			target.fx.append({"k": "root", "end": round_no + 1})
			log_msg(p, "Presa de Aço: %s não pode se mover até o fim do próximo round." % nm(target))
	if after == "burn":
		_set_fire(p, target.pos())
		abfx("burn", target.pos(), a.uid)
		log_msg(p, "Terra Queimada: a casa de %s pega fogo até o fim do próximo round." % nm(target))
	if after == "dynamite":
		# Dinamitador: o alvo recebe o ataque; todas as unidades nas 6 casas ao redor (aliadas ou inimigas) sofrem 1,
		# com altura e abrigo aplicados a cada uma
		abfx("blast", target.pos(), a.uid)
		var near_d = 0
		for x in field():
			if x != target and DB.dist(x.pos(), target.pos()) == 1:
				var tmx = terrain_mods(a, x)
				var dd = max(0, 1 + int(tmx["atk"]) - int(tmx["cover"]) - int(tmx["forest"]))
				damage(x, dd, a, true)
				near_d += 1
		if near_d > 0:
			log_msg(p, "%s: a explosão atinge %d unidade(s) ao redor do alvo." % [DB.cards[a.cid]["ab"]["name"], near_d])
	if after == "splash" or after == "burn":
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
	if after == "burstSafe":
		var ss5 = field().filter(func(x): return x != a and x != target and DB.dist(x.pos(), a.pos()) == 1 and (x.owner != a.owner or (not x.is_cmd and not x.barrier and x.hp > 5)))
		abfx("nova", a.pos(), a.uid)
		for x in ss5:
			damage(x, 1, a)
	if after == "burstEnemies":
		var ss3 = enemies_of(a).filter(func(x): return x != target and DB.dist(x.pos(), a.pos()) == 1)
		abfx("zap", a.pos(), a.uid)
		for x in ss3:
			damage(x, 1, a)
	settle()
	if winner != NONE:
		return
	if after == "arc" and target.st != "dead":
		var ss6 = enemies_of(a).filter(func(x): return x != target and DB.dist(x.pos(), target.pos()) == 1)
		ss6.sort_custom(func(x, y): return x.hp < y.hp)
		for x in ss6.slice(0, 2):
			abfx("bolt", x.pos(), a.uid)
			damage(x, 2 if has_fx(x, "venom") else 1, a)
		if not ss6.is_empty():
			log_msg(p, "Descarga Condutiva atinge %d inimigo(s)." % min(2, ss6.size()))
		settle()
		if winner != NONE:
			return
	if after == "echo" and dealt > 0 and target.st == "field" and not target.barrier and target.hitters.any(func(id): return id != a.uid and by_uid(id) != null and DB.cards[by_uid(id).cid]["f"] == "ABY"):
		var ed = push_dest(target, a.pos())
		if ed != null:
			abfx("sonic", target.pos(), a.uid)
			log_msg(p, "Eco Profundo: %s é empurrado." % nm(target))
			await move_unit(target, ed)
			if winner != NONE:
				return
	if K(a).has("viva") and dealt > 0 and target.st == "field" and not target.barrier and act != null and act.has("from") and DB.dist(act["from"], target.pos()) >= 3:
		var vo = step_free(target.pos()).filter(func(h2): return DB.dist(h2, a.pos()) < DB.dist(target.pos(), a.pos()))
		if not vo.is_empty():
			abfx("hook", target.pos(), a.uid)
			log_msg(p, "Maré Viva: %s é puxado." % nm(target))
			await move_unit(target, vo[0])
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
	if after == "pull2" and dealt > 0 and target.st == "field" and not target.barrier:
		for i in range(2):
			var op2 = step_free(target.pos()).filter(func(h2): return DB.dist(h2, a.pos()) < DB.dist(target.pos(), a.pos()))
			if op2.is_empty() or target.st != "field":
				break
			var hp2 = await pick_hex(p, "Arpão de Arrasto: puxe o alvo %d casa(s) em sua direção (%dª casa)." % [1, i + 1], op2, "move", true)
			if hp2 == null:
				break
			abfx("hook", target.pos(), a.uid)
			await move_unit(target, hp2)
			if winner != NONE:
				return
		if target.st == "field" and a.gloria_round != round_no:
			var fr = allies_of(a).filter(func(x): return DB.cards[x.cid]["f"] == "ABY" and DB.dist(x.pos(), target.pos()) == 1 and not rooted_cant(x))
			if not fr.is_empty():
				var hf = await pick_hex(p, "Arrasto: um Abyssal adjacente ao alvo ataca de graça (ou pule).", fr, "ally", true)
				if hf != null:
					var fa = unit_at(hf)
					a.gloria_round = round_no
					var fd = max(0, atk_of(fa, target) + fx_sum(target, "mark") - reduction_of(target))
					emitfx({"t": "strike", "from": fa.uid, "to": target.uid, "ranged": false})
					log_msg(p, "%s ataca de graça %s (%d)." % [nm(fa), nm(target), fd])
					damage(target, fd, fa, true)
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
	# impulso: derrubar uma tropa dá 1 casa grátis (1 vez por ativação)
	if target.st == "dead" and not target.barrier and is_live(a) and not A.get("momentum", false) and not rooted(a) and not step_free(a.pos()).is_empty():
		A["momentum"] = true
		var hm = await ask(p, {"t": "hex", "text": "Impulso! %s derrubou %s: avançar 1 casa grátis?" % [nm(a), nm(target)], "opts": step_free(a.pos()), "optional": true, "kind": "move"})
		if hm != null:
			abfx("dash", a.pos(), a.uid)
			log_msg(p, "Impulso: %s avança." % nm(a))
			await move_unit(a, hm, true)
		if winner != NONE or a.st != "field":
			return
	if K(a).has("hunt") and not A.get("hunted", false):
		A["hunted"] = true
		await _hunt(a, target)
		if winner != NONE or a.st != "field":
			return
	if not A["tactic"] and P[p]["hand"].has("retirada") and not rooted(a) and not step_free(a.pos()).is_empty():
		var h = await ask(p, {"t": "hex", "text": "Retirada Calculada: mover o ativo 1 casa livre?", "opts": step_free(a.pos()), "optional": true, "kind": "move", "card": "retirada"})
		if h != null:
			take_card(p, "retirada")
			A["tactic"] = true
			log_msg(p, "Retirada Calculada.")
			await move_unit(a, h)


# ================= habilidades especiais =================
# Vexa: avança até o inimigo mais próximo e ataca também
func _hunt(a, first) -> void:
	var reach = int(K(a)["hunt"])
	var foes = enemies_of(a).filter(func(x): return x != first and not x.barrier and x.st == "field" and not has_fx(x, "veil") and not imprisoned(x))
	foes.sort_custom(func(x, y): return DB.dist(x.pos(), a.pos()) < DB.dist(y.pos(), a.pos()))
	for t2 in foes:
		if attack_targets(a).has(t2):
			log_msg(a.owner, "Caçada em Sequência: %s ataca %s." % [nm(a), nm(t2)])
			await resolve_attack(a, t2)
			return
		if rooted(a):
			continue
		var best: Variant = null
		for o in move_opts(a, reach):
			if attack_targets(a, o["h"]).has(t2) and (best == null or o["c"] < best["c"]):
				best = o
		if best != null:
			abfx("dash", a.pos(), a.uid)
			log_msg(a.owner, "Caçada em Sequência: %s avança até %s." % [nm(a), nm(t2)])
			await move_unit(a, best["h"], true)
			if winner != NONE or a.st != "field" or t2.st != "field":
				return
			await resolve_attack(a, t2)
			return


# Drako: veneno tira 1 de Vida por round e cura 1 aliado a até 5 casas de Drako (ou ele mesmo)
# Bayak: veneno que dura até o fim da partida (1 de dano no fim de cada round)
func _venom_tick() -> void:
	var hit = false
	for t in units.duplicate():
		if t.st != "field":
			continue
		for f in t.fx.filter(func(x): return x["k"] == "venom"):
			var by = by_uid(int(f["src"]))
			abfx("poison", t.pos(), int(f["src"]))
			log_msg(by.owner if by != null else -1, "Veneno Lento: %s perde 1 de Vida." % nm(t))
			damage(t, 1, by)
			hit = true
	if hit:
		settle()


func rooted_cant(x) -> bool:
	return x.barrier or imprisoned(x)


func _toxin_tick() -> void:
	var hit = false
	for t in units.duplicate():
		if t.st != "field":
			continue
		for f in t.fx.filter(func(x): return x["k"] == "tox"):
			var dk = by_uid(int(f["src"]))
			log_msg(dk.owner if dk != null else -1, "Veneno Transfusor: %s perde 1 de Vida." % nm(t))
			abfx("poison", t.pos(), dk.uid if dk != null else -1)
			damage(t, 1, dk)
			hit = true
			if dk != null and dk.st == "field":
				var opts = allies_of(dk).filter(func(x): return not x.barrier and DB.dist(x.pos(), dk.pos()) <= 5 and x.hp < x.maxhp)
				var who = dk
				if not opts.is_empty():
					var hh = await pick_hex(dk.owner, "Veneno Transfusor: escolha o aliado (até 5 casas de %s) que recupera 1 de Vida." % nm(dk), opts, "ally")
					if hh != null and unit_at(hh) != null:
						who = unit_at(hh)
				heal(who, 1)
	if hit:
		settle()
		await pace()


# bombas do Rappy e reforços da Luna: resolvidos ao fim de cada ativação e do round
func resolve_queues() -> void:
	while not bomb_queue.is_empty():
		var rp = by_uid(bomb_queue.pop_front())
		if rp == null or rp.st != "field":
			continue
		var opts = DB.hexes.filter(func(h): return is_free(h) and DB.dist(h, rp.pos()) <= int(K(rp)["bombs"]) and not mines.any(func(m): return m["h"] == h) and tt_of(terr(h)["k"]).get("pass", 0))
		var hb = await pick_hex(rp.owner, "Campo Minado Clandestino: esconda uma bomba (o adversário não vê). Até %d casas de %s." % [int(K(rp)["bombs"]), nm(rp)], opts, "place", true)
		if hb != null:
			mines.append({"owner": rp.owner, "h": hb, "n": 3, "src": -rp.uid, "hidden": true})
			log_msg(rp.owner, "Rappy escondeu uma bomba em algum lugar do mapa.")
	for lu in field().filter(func(x): return K(x).has("rally") and not x.luna_used and x.hp * 2 <= x.maxhp):
		lu.luna_used = true
		var yes = await ask(lu.owner, {"t": "yesno", "text": "Chamando Reforços: %s está ferida. Trazer até 2 aliados para perto dela?" % nm(lu), "kind": "rally"})
		if not yes:
			continue
		emitfx({"t": "passive", "kind": "power", "uid": lu.uid})
		for i in range(int(K(lu)["rally"])):
			var al = allies_of(lu).filter(func(x): return not x.barrier and DB.dist(x.pos(), lu.pos()) > 1)
			var spots = adj_free(lu.pos())
			if al.is_empty() or spots.is_empty():
				break
			var ha = await pick_hex(lu.owner, "Chamando Reforços: escolha o %dº aliado (ou pule)." % (i + 1), al, "ally", true)
			if ha == null:
				break
			var mover = unit_at(ha)
			var hd = await pick_hex(lu.owner, "Para qual casa ao lado de %s?" % nm(lu), spots, "move")
			abfx("dash", mover.pos(), lu.uid)
			log_msg(lu.owner, "Chamando Reforços: %s veio para perto de %s." % [nm(mover), nm(lu)])
			await move_unit(mover, hd)
			if winner != NONE:
				return


const DISCS = [
	{"id": "guerra", "name": "Tambores de Guerra", "text": "+2 ATQ até o fim do round"},
	{"id": "cura", "name": "Balada Verde", "text": "+3 de Vida"},
	{"id": "ritmo", "name": "Ritmo Veloz", "text": "+1 Movimento até o fim do round"},
	{"id": "ferro", "name": "Hino de Ferro", "text": "-1 dano recebido até o fim do round"},
]


# alcance da música: só Zaboo nos rounds 1-3, aliados a 1 casa nos rounds 4-6, a 2 casas depois
func disc_radius() -> int:
	return 0 if round_no <= 3 else (1 if round_no <= 6 else 2)


func _zaboo_disc(u) -> void:
	var left = DISCS.filter(func(d): return not u.discs.has(d["id"]))
	var r = disc_radius()
	var who = "só Zaboo" if r == 0 else ("Zaboo e aliados a até %d casa%s" % [r, "s" if r > 1 else ""])
	var labels = left.map(func(d): return "%s: %s" % [d["name"], d["text"]])
	labels.append("Guardar para depois")
	var pick = await ask(u.owner, {"t": "choice", "text": "Set dos Quatro Discos (%d de %d tocados). Tocar um disco agora? Afeta %s." % [u.discs.size(), int(K(u)["discs"]), who], "opts": labels, "kind": "disc", "uid": u.uid})
	var i = int(pick) if pick != null else -1
	if i < 0 or i >= left.size():
		return
	var dsc = left[i]
	u.discs.append(dsc["id"])
	emitfx({"t": "music", "uid": u.uid, "disc": dsc["id"]})
	log_msg(u.owner, "Zaboo tocou \"%s\" (%s)." % [dsc["name"], who])
	for x in allies_of(u, true).filter(func(y): return not y.barrier and DB.dist(y.pos(), u.pos()) <= r):
		match dsc["id"]:
			"guerra":
				x.fx.append({"k": "atk", "v": 2, "until": "end"})
			"cura":
				heal(x, 3)
			"ritmo":
				x.fx.append({"k": "mov", "v": 1, "until": "end"})
			"ferro":
				x.fx.append({"k": "red", "v": 1, "until": "end"})
		abfx("buff", x.pos(), u.uid)


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
		"bananas":
			# Karo: espalha bananas de cura, força e mira perto dele (só os aliados pegam)
			var spots = DB.hexes.filter(func(h): return is_free(h) and h != u.pos() and DB.dist(h, u.pos()) <= int(e.get("r", 6)) and tt_of(terr(h)["k"]).get("pass", 0) and not bananas.has(h))
			_shuffle(spots)
			var kinds = []
			for kk in ["cura", "dano", "alcance"]:
				for j in range(n):
					kinds.append(kk)
			for j in range(min(kinds.size(), spots.size())):
				bananas[spots[j]] = {"t": kinds[j], "p": p}
			abfx("insight", u.pos(), u.uid)
			emitfx({"t": "bananas"})
			log_msg(p, "Banquete dos Clãs: %d bananas espalhadas pelo mapa." % min(kinds.size(), spots.size()))
		"peek", "top3", "discount":
			abfx("insight", u.pos(), u.uid)
		"pushAllAdj", "dmgAdj":
			abfx("quake" if e["t"] == "pushAllAdj" else "explode", u.pos(), u.uid)
	match e["t"]:
		"peek":
			var pl = P[p]
			if pl["deck"].is_empty() and not pl["discard"].is_empty():
				pl["deck"] = pl["discard"].duplicate()
				_shuffle(pl["deck"])
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
						if K(u).has("dazeCover"):
							t4.fx.append({"k": "dazed", "v": 1, "until": "end"})
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
		"czone":
			var zs = DB.hexes.filter(func(h2): return DB.dist(h2, u.pos()) <= r and h2 != u.pos() and tt_of(terr(h2)["k"]).get("pass", 0))
			var zh = await pick_hex(p, "%s: escolha o centro da Zona de Cristal (até %d casas)." % [name, r], zs, "place")
			if zh != null:
				abfx("barrier", zh, u.uid)
				add_czone_area(p, zh, 1, 2)
				log_msg(p, "%s: Zona de Cristal por 2 rounds (inimigos que entram ficam Lentos)." % name)
		"barrierZone":
			var hz = await pick_hex(p, "%s: escolha uma casa livre adjacente para a Barreira." % name, adj_free(u.pos()), "place")
			if hz != null:
				var nz = n
				abfx("barrier", hz, u.uid)
				_make_barrier(p, hz, nz)
				add_czone_area(p, hz, 1, 2)
				log_msg(p, "%s: Barreira com %d de Vida e Zona de Cristal ao redor." % [name, nz])
		"healZ":
			var tsz = allies_of(u, true).filter(func(x): return DB.dist(x.pos(), u.pos()) <= r and x.hp < x.maxhp and not x.barrier)
			var hzz = await pick_hex(p, "%s: restaure %d de Vida de 1 aliado a até %d casas (+1 se ele estiver em Zona de Cristal)." % [name, n, r], tsz, "ally")
			if hzz != null:
				var tz = unit_at(hzz)
				var amt = n + (1 if czone_owner(tz.pos()) == p else 0)
				abfx("heal", hzz, u.uid)
				heal(tz, amt)
				log_msg(p, "%s: %s restaura %d de Vida." % [name, nm(tz), amt])
		"prism":
			var tsw = field().filter(func(x): return x != u and not x.barrier and DB.dist(x.pos(), u.pos()) <= r and not (x.owner != u.owner and (has_fx(x, "veil") or imprisoned(x))))
			var hsw = await pick_hex(p, "%s: escolha uma peça a até %d casas para trocar de lugar (inimigo fica Enraizado)." % [name, r], tsw.map(func(x): return x.pos()), "prism", true)
			if hsw != null:
				var tx2 = unit_at(hsw)
				abfx("portal", u.pos(), u.uid)
				abfx("portal", hsw, u.uid)
				log_msg(p, "%s: troca de lugar com %s." % [name, nm(tx2)])
				await _swap(u, tx2)
				if tx2.owner != u.owner:
					apply_root(tx2, u)
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
				_add_mine(p, h7b, n, u.uid, int(K(u).get("mineCap", 1)))
				if K(u).has("mineRoot"):
					mines.back()["root"] = true
				log_msg(p, "%s: mina posicionada." % name)
		"barrier":
			var h8 = await pick_hex(p, "%s: escolha uma casa livre adjacente para a Barreira." % name, adj_free(u.pos()), "place")
			if h8 != null:
				var nn = n
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
			return self_targets(p, id).size() > 0
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
			return self_targets(p, id).size() > 0
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


# personagens seus que podem receber uma tática pessoal (equipamento, reparo, camuflagem)
func self_targets(p: int, id: String) -> Array:
	return units.filter(func(x): return x.owner == p and x.st == "field" and not x.barrier and (id != "reparo" or x.hp < x.maxhp) and (id != "camuflagem" or not has_fx(x, "veil")))


# casas onde dá para soltar a carta (vazio = em qualquer lugar do tabuleiro)
func drop_opts(p: int, id: String) -> Array:
	var u = active_unit()
	if u == null:
		return []
	var mine = func(arr): return arr.map(func(x): return x.pos())
	match id:
		"propulsor", "placas", "lente", "reparo", "camuflagem":
			return mine.call(self_targets(p, id))
		"fogo", "ultimo", "adrenalina", "contra", "kit", "onda":
			return [u.pos()]
		"grito":
			return mine.call(allies_of(u, true).filter(func(x): return not x.barrier))
		"avanco":
			return mine.call(allies_of(u, true).filter(func(x): return not step_free(x.pos()).is_empty() and not rooted(x)))
		"flanquear":
			return step_free(u.pos())
		"troca":
			return mine.call(allies_of(u).filter(func(x): return DB.dist(x.pos(), u.pos()) == 1))
		"resgate":
			return mine.call(allies_of(u).filter(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) <= 4))
		"quantica":
			return mine.call(quantica_allies(u) + quantica_enemies(u))
		"pulso":
			return mine.call(enemies_of(u).filter(func(x): return x.eq != "" and DB.dist(x.pos(), u.pos()) <= 2 and los(u.pos(), x.pos())))
		"granada":
			return granada_opts(u)
		"sinalizador":
			return mine.call(enemies_of(u).filter(func(x): return not x.barrier and DB.dist(x.pos(), u.pos()) <= 4 and los(u.pos(), x.pos())))
		"barreira":
			return adj_free(u.pos())
		"gancho":
			return mine.call(gancho_targets(u))
		"orbital":
			return mine.call(enemies_of(u).filter(func(x): return DB.dist(x.pos(), u.pos()) <= 5))
		"execucao":
			return mine.call(execucao_targets(u))
		"rede":
			return mine.call(rede_targets(u))
	return []


func drop_ok(p: int, id: String, h: Vector2i) -> bool:
	var opts = drop_opts(p, id)
	return opts.is_empty() or opts.has(h)


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


func play_tactic(p: int, id: String, drop: Variant = null) -> bool:
	return await _run(["tactic", p, id, drop], func(): return await _play_tactic(p, id, drop))


func _play_tactic(p: int, id: String, drop: Variant = null) -> bool:
	if not tactic_playable(p, id):
		return false
	var A = act
	var u = active_unit()
	var c = DB.tactics[id]
	# quem recebe uma tática pessoal: a peça onde a carta foi solta (ou o ativo)
	var tu = u
	if TAC_SELF.has(id):
		var ts0 = self_targets(p, id)
		if drop != null and unit_at(drop) != null and ts0.has(unit_at(drop)):
			tu = unit_at(drop)
		elif not ts0.has(u) and not ts0.is_empty():
			tu = ts0[0]
	take_card(p, id)
	A["tactic"] = true
	A["actions"] -= int(c["cost"])
	log_msg(p, "Tática: %s." % c["name"])
	emitfx({"t": "card", "id": id, "p": p})
	pre_hex = drop
	tac_fx = null
	if TAC_SELF.has(id) or ["fogo", "ultimo", "adrenalina", "contra", "kit", "onda", "dados", "interceptar", "evacuacao"].has(id):
		emitfx({"t": "tactic_on", "id": id, "h": tu.pos(), "p": p})
	elif id == "grito":
		for x in allies_of(u, true).filter(func(y): return not y.barrier):
			emitfx({"t": "tactic_on", "id": id, "h": x.pos(), "p": p})
	else:
		tac_fx = id
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
			tu.eq = id
			log_msg(p, "%s equipou %s." % [nm(tu), c["name"]])
		"reparo":
			heal(tu, 4)
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
			tu.fx.append({"k": "veil", "v": 1, "until": "start"})
			abfx("veil", tu.pos(), tu.uid)
			log_msg(p, "%s sumiu de vista até o próximo round." % nm(tu))
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
				var cid = oh[rng.randi() % oh.size()]
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
	pre_hex = null
	tac_fx = null
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
	if not _sees(a, ap, t):
		var b = los_blocker(ap, t.pos())
		return {"s": "sem linha", "l": "Sem linha de tiro: %s está no caminho e é mais alto que %s e o alvo." % [t_name(b) if b != null else "um obstáculo", nm(a)], "block": b, "from": ap, "to": t.pos()}
	if not attack_targets(a, ap).has(t):
		if _guarded(t, d):
			return {"s": "guardado", "l": "%s está guardado por um aliado ao lado dele (protege só de ataques à distância)." % nm(t)}
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
	var red = reduction_of(t, true, DB.dist(a.pos() if fpos == null else fpos, t.pos()))
	if red > 0:
		total -= red
		parts.append("-%d defesas do alvo" % red)
	if storm_on():
		total -= 2
		parts.append("-2 tempestade de areia")
	if rain_on():
		total -= RAIN_PEN
		parts.append("-%d chuva" % RAIN_PEN)
	a.q = save.x
	a.r = save.y
	var dmg = max(0, total)
	return {"dmg": dmg, "parts": parts, "kills": dmg >= t.hp, "high": tm["atk"] > 0, "cover": tm["cover"] > 0}
