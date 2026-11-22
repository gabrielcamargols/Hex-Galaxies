extends Node
## Dados do jogo (cartas, táticas, mapas, terrenos). Carregado automaticamente (autoload "DB").

var factions: Dictionary = {}
var vfx_pal: Dictionary = {}       # paletas de VFX por facção (data/vfx_paletas.json, Manual de VFX)
var clans: Dictionary = {}
var cards: Dictionary = {}        # id -> carta
var card_list: Array = []
var tactics: Dictionary = {}      # id -> tática
var tactic_ids: Array = []
var excl_ids: Array = []          # exclusivas de facção (modo Disputa)
var disputa_pares: Array = []     # pares públicos de genéricas do draft
var maps: Dictionary = {}
var tt: Dictionary = {}           # tipos de terreno
var res: Dictionary = {}          # recursos
var objs: Array = []              # objetivos
var R: int = 6                    # maior raio (para laços)
var SQ: int = 6                   # formato do tabuleiro: |q| <= SQ, |r| <= SR_, |q+r| <= SS
var SR_: int = 6
var SS: int = 6
var hexes: Array = []             # Vector2i de todas as casas
var entry_c: Array = []           # centro das entradas [lado 0, lado 1]
var entry: Array = []             # casas de entrada por lado
var art: Dictionary = {}          # id -> Texture2D (corpo inteiro)
var portraits: Dictionary = {}    # id -> Texture2D (retrato)

const DIRS = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const COVER_DMG = 2
const FOREST_DMG = 1
const HIGH_DMG = 1
const LOW_DMG = 1
const TCOL = {"Manobra": Color("#2f7d9a"), "Comando": Color("#8a5a2a"), "Reação": Color("#a03a2a"), "Equipamento": Color("#4a7a3a")}


func _ready() -> void:
	var c = _ints(JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json")))
	factions = c["factions"]
	var pf = FileAccess.open("res://data/vfx_paletas.json", FileAccess.READ)
	if pf != null:
		var pj = JSON.parse_string(pf.get_as_text())
		if pj is Dictionary:
			vfx_pal = pj
	clans = c["clans"]
	card_list = c["cards"]
	for card in card_list:
		cards[card["id"]] = card
		if not card.has("k") or card["k"] == null:
			card["k"] = {}
	for t in c["tactics"]:
		tactics[t["id"]] = t
		tactic_ids.append(t["id"])
	# táticas exclusivas de facção (Disputa pela Hex Energy): entram no catálogo, mas não no baralho comum
	for t in c.get("tactics_ex", []):
		tactics[t["id"]] = t
		excl_ids.append(t["id"])
	disputa_pares = c.get("disputa_pares", [])
	var m = _ints(JSON.parse_string(FileAccess.get_file_as_string("res://data/maps.json")))
	R = int(m["radius"])
	maps = m["maps"]
	tt = m["terrain"]
	res = m["resources"]
	objs = m["objectives"]
	set_map("tarhut" if maps.has("tarhut") else maps.keys()[0])
	for id in cards.keys():
		var path = "res://art/%s.webp" % id
		if ResourceLoader.exists(path):
			art[id] = load(path)
		var pp = "res://art/p_%s.webp" % id
		if ResourceLoader.exists(pp):
			portraits[id] = load(pp)


# JSON do Godot devolve números como float: converte inteiros de volta para int.
func _ints(v) -> Variant:
	if v is float and v == floor(v):
		return int(v)
	if v is Array:
		var out = []
		for x in v:
			out.append(_ints(x))
		return out
	if v is Dictionary:
		var d = {}
		for k in v.keys():
			d[k] = _ints(v[k])
		return d
	return v


# cada mapa tem o seu tamanho/formato e suas entradas
var cur_map: String = ""


var cur_troca: bool = false
var modo_padrao: String = ""     # "disputa": usa a base dos Guardiões e o início dos Invasores do bloco "disputa" do mapa
var cur_modo: String = ""
var troca_padrao: bool = false   # Disputa com os Invasores no lado 1: as entradas trocam de lado


# troca = true: as entradas trocam de lado (Disputa: a zona de início acompanha o papel)
func set_map(id: String, troca_v: Variant = null) -> void:
	var troca: bool = troca_padrao if troca_v == null else bool(troca_v)
	var md: String = modo_padrao if maps.has(id) and maps[id].has("disputa") else ""
	if (id == cur_map and troca == cur_troca and md == cur_modo) or not maps.has(id):
		return
	cur_map = id
	cur_troca = troca
	cur_modo = md
	var d = maps[id]
	var sh = d.get("shape", {"q": 6, "r": 6, "s": 6})
	SQ = int(sh["q"])
	SR_ = int(sh["r"])
	SS = int(sh["s"])
	entry_c = []
	var ecs = d.get("entry_centers", [{"q": 3, "r": -6}, {"q": -3, "r": 6}])
	if md == "disputa":
		ecs = d["disputa"]["entry_centers"]   # [início dos Invasores, base dos Guardiões]
	for ec in ecs:
		entry_c.append(Vector2i(int(ec["q"]), int(ec["r"])))
	if troca:
		entry_c.reverse()
	hexes = []
	for q in range(-R, R + 1):
		for r in range(-R, R + 1):
			if in_board(Vector2i(q, r)):
				hexes.append(Vector2i(q, r))
	entry = []
	for p in [0, 1]:
		var e = []
		for h in hexes:
			if dist(h, entry_c[p]) <= 1:
				e.append(h)
		e = _lado_a_lado(e, entry_c[p])
		entry.append(e)


# casa do núcleo (base que os Guardiões protegem) na Disputa
func disputa_core(id: String) -> Vector2i:
	var c = maps[id].get("disputa", {}).get("core", [0, 0])
	return Vector2i(int(c[0]), int(c[1]))


func in_board(h: Vector2i) -> bool:
	return abs(h.x) <= SQ and abs(h.y) <= SR_ and abs(h.x + h.y) <= SS


# quantas casas fora do tabuleiro (0 ou menos = dentro)
func out_dist(h: Vector2i) -> int:
	return max(abs(h.x) - SQ, max(abs(h.y) - SR_, abs(h.x + h.y) - SS))


func dist(a: Vector2i, b: Vector2i) -> int:
	var dq = a.x - b.x
	var dr = a.y - b.y
	return (abs(dq) + abs(dr) + abs(dq + dr)) / 2


func nbrs(h: Vector2i) -> Array:
	var out = []
	for d in DIRS:
		var n = h + d
		if in_board(n):
			out.append(n)
	return out


func obj_at(h: Vector2i) -> Variant:
	for o in objs:
		if int(o["q"]) == h.x and int(o["r"]) == h.y:
			return o
	return null


# as duas peças iniciais (primeiro e último da entrada) ficam lado a lado, na linha de visão do jogador:
# escolhe o par mais perpendicular à direção do centro do mapa
func _wxz(h: Vector2i) -> Vector2:
	return Vector2(1.5 * h.y, -sqrt(3.0) * (h.x + h.y / 2.0))


func _lado_a_lado(e: Array, c: Vector2i) -> Array:
	var wc = _wxz(c)
	var inward = (-wc).normalized() if wc.length() > 0.001 else Vector2(0, 1)
	var lat = Vector2(-inward.y, inward.x)
	var best = null
	var best_s = -INF
	for i in range(e.size()):
		for j in range(e.size()):
			if i == j:
				continue
			var d = _wxz(e[j]) - _wxz(e[i])
			var sc = abs(d.dot(lat)) - 0.5 * abs(d.dot(inward))
			if sc > best_s:
				best_s = sc
				best = [i, j]
	if best == null:
		return e
	var out = [e[best[0]]]
	for k in range(e.size()):
		if k != best[0] and k != best[1]:
			out.append(e[k])
	out.append(e[best[1]])
	return out


# exclusivas de uma facção
func excl_of(fac: String) -> Array:
	return excl_ids.filter(func(i): return tactics[i].get("fac", "") == fac)


func in_entry(p: int, h: Vector2i) -> bool:
	return entry[p].has(h)


# a habilidade ativa da carta: fica em "ab" (kind ativa) quando a peça só tem ela, senão em "ab2"
func active_of(cid: String) -> Dictionary:
	var c = cards[cid]
	if c.get("ab", {}).get("kind", "") == "ativa":
		return c["ab"]
	var a2 = c.get("ab2", {})
	if a2.get("kind", "ativa") == "passiva":
		return {}
	return a2


func card_name(cid: String) -> String:
	if cid == "barrier":
		return "Barreira"
	return cards[cid]["name"]


# cor de VFX da facção ("primary", "secondary", "shadow", "outline", "highlight", "extra")
func pal(fac: String, key: String = "primary", fallback: Color = Color.WHITE) -> Color:
	if vfx_pal.has(fac) and vfx_pal[fac].has(key):
		return Color(vfx_pal[fac][key])
	if factions.has(fac) and key == "primary":
		return Color(factions[fac]["color"])
	return fallback
