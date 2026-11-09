extends Node
## Dados do jogo (cartas, táticas, mapas, terrenos). Carregado automaticamente (autoload "DB").

var factions: Dictionary = {}
var vfx_pal: Dictionary = {}       # paletas de VFX por facção (data/vfx_paletas.json, Manual de VFX)
var clans: Dictionary = {}
var cards: Dictionary = {}        # id -> carta
var card_list: Array = []
var tactics: Dictionary = {}      # id -> tática
var tactic_ids: Array = []
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


func set_map(id: String) -> void:
	if id == cur_map or not maps.has(id):
		return
	cur_map = id
	var d = maps[id]
	var sh = d.get("shape", {"q": 6, "r": 6, "s": 6})
	SQ = int(sh["q"])
	SR_ = int(sh["r"])
	SS = int(sh["s"])
	entry_c = []
	for ec in d.get("entry_centers", [{"q": 3, "r": -6}, {"q": -3, "r": 6}]):
		entry_c.append(Vector2i(int(ec["q"]), int(ec["r"])))
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
		entry.append(e)


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
