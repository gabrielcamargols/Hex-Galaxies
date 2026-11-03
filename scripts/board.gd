extends Node3D
## Tabuleiro 3D (2.5D): casas em prisma com altura, cenário, câmera e peças com as artes.

signal hex_tapped(h)                 # clique/toque numa casa (Vector2i)
signal unit_dropped(uid, h)          # soltou uma peça arrastada (h pode ser null)
signal unit_drag_started(uid)

const S3 = 1.7320508
const HS = 0.55          # altura de cada nível
const BASE_Y = -0.6
const TILE = 0.9
const INNER = 0.76
# [centro, borda, lateral] — cada tipo de terreno tem uma cor própria para não se confundir
const PAL = {
	"grass": ["#86bd4a", "#64a034", "#3a5e20"], "grass2": ["#a0c856", "#7aa83c", "#4a6a26"],
	"sand": ["#d4a868", "#c08e50", "#7a5430"], "dune": ["#e0925a", "#c87440", "#8a4a28"],
	"wood": ["#b07840", "#8c5a2c", "#4e3018"], "ramp": ["#d09a58", "#b07a3a", "#5e3e20"],
	"mud": ["#6a5238", "#4e3c28", "#2e2214"], "rubble": ["#8c8c9a", "#70707e", "#44444e"],
	"quick": ["#8e8040", "#6e6230", "#3e3618"], "stone": ["#8e827c", "#726862", "#4a4240"],
	"bone": ["#d8ccb0", "#bcae90", "#7e7058"], "cracked": ["#b8a688", "#9a8a6c", "#665a44"],
	"hole": ["#3a2418", "#24140c", "#120a04"],
}
const ELEV = {"tarhut": "#c0583a", "posto": "#e0c060"}  # tom que as casas altas puxam
# planeta: o tabuleiro fica num platô e o chão se curva em volta (deserto contínuo)
var PLAT = 18.5       # raio plano em volta do tabuleiro (ajustado ao tamanho do mapa)
var RIM = 12.0         # raio da borda arredondada (onde o deserto se curva)
var UNDER = 34.0       # altura da base rochosa por baixo do planetoide
const ZOOM_MIN = 4.0
const ZOOM_MAX = 140.0
const BIG = ["moby", "balu", "banker", "l_behemot", "l_leviathan", "z_dragao", "golk", "w_mamute", "k_tank", "z_tank", "l_tank", "l_colosso", "sismico", "rhombo", "tork", "w_tric", "z_meca", "t_fendas", "t_raiz"]

var g: Game = null
var cam: Camera3D
var cam_yaw: float = 0.0
var cam_pitch: float = 0.95
var cam_dist: float = 26.0
var cam_target: Vector3 = Vector3(0, 0, 1.0)
var cam_goal: Variant = null
var cam_speed: float = 8.0      # mais baixo = câmera mais lenta (chegada no planeta)
var shake: float = 0.0

var tiles: Dictionary = {}       # Vector2i -> {node, disp_h, props, hl, dim, label, flash}
var tile_mat: StandardMaterial3D
var unit_nodes: Dictionary = {}  # uid -> {node, sprite, hp, label, path, ...}
var state: Dictionary = {}       # destaques vindos do controlador
var built_ver: int = -1
var heart_tex: ImageTexture
var scenery_root: Node3D
var ground: MeshInstance3D
var env: Environment

var drag: Variant = null                  # {uid, start, on}
var pan: Variant = null
# toque: dedos ativos e gesto de dois dedos (pinça/giro/inclinação)
var touches: Dictionary = {}
var multi: bool = false
var gest: Variant = null
var hover: Variant = null
var picking_enabled: bool = true
var outline_mat: StandardMaterial3D
var model_cache: Dictionary = {}   # nome -> PackedScene (ou null se não existir)


func _ready() -> void:
	outline_mat = StandardMaterial3D.new()
	outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_mat.albedo_color = Color("#16110c")
	outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	outline_mat.grow = true
	outline_mat.grow_amount = 0.025
	tile_mat = StandardMaterial3D.new()
	tile_mat.vertex_color_use_as_albedo = true
	tile_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	tile_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	tile_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tile_mat.roughness = 1.0
	heart_tex = _make_heart()
	var we = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.95)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	ground = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(160, 160)
	ground.mesh = pm
	ground.position = Vector3(0, BASE_Y - 0.1, 0)
	add_child(ground)
	scenery_root = Node3D.new()
	add_child(scenery_root)


# ================= construção =================
func build(game: Game) -> void:
	g = game
	for n in tiles.values():
		n["node"].queue_free()
	tiles.clear()
	for n in unit_nodes.values():
		n["node"].queue_free()
	unit_nodes.clear()
	for c in scenery_root.get_children():
		c.queue_free()
	var desert = g.map_id == "tarhut"
	# planetoide do tamanho do tabuleiro
	var far = 0.0
	for h in DB.hexes:
		far = max(far, world_xz(h).length())
	PLAT = far + 2.0
	RIM = PLAT * 0.68
	UNDER = PLAT * 1.85
	_setup_sky()
	ground.mesh = _planet_mesh(desert)
	ground.position = Vector3.ZERO
	var gm = StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	gm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	gm.roughness = 1.0
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.material_override = gm
	for h in DB.hexes:
		var node = Node3D.new()
		var wp = world_xz(h)
		node.position = Vector3(wp.x, 0, wp.y)
		add_child(node)
		var hl = MeshInstance3D.new()
		hl.mesh = _disc(INNER, 6)
		hl.material_override = _overlay_mat(Color(0, 0, 0, 0))
		hl.visible = false
		node.add_child(hl)
		var dim = MeshInstance3D.new()
		dim.mesh = _disc(TILE, 6)
		dim.material_override = _overlay_mat(Color(0.04, 0.02, 0.01, 0.5))
		dim.visible = false
		node.add_child(dim)
		var lab = Label3D.new()
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true
		lab.font_size = 64
		lab.outline_size = 18
		lab.pixel_size = 0.006
		lab.visible = false
		node.add_child(lab)
		tiles[h] = {"node": node, "disp_h": float(g.h_of(h)), "body": null, "props": null, "hl": hl, "dim": dim, "label": lab, "flash": 0.0, "sig": ""}
	_build_scenery(desert)
	_build_far(desert)
	built_ver = -1
	refresh_terrain()
	fit_camera(true)


# ================= céu de galáxias e planeta =================
func _setup_sky() -> void:
	var path = "res://sky/galaxias.jpg"
	if not ResourceLoader.exists(path):
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("#1a1030")
		return
	var sm = PanoramaSkyMaterial.new()
	sm.panorama = load(path)
	var sky = Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.sky_rotation = Vector3(0, 0.6, 0)


# altura do chão do planetoide: plano no meio, borda arredondada (raio RIM) com dunas
func planet_y(x: float, z: float) -> float:
	var r = sqrt(x * x + z * z)
	var base = BASE_Y - 0.1
	if r <= PLAT:
		return base
	var d = min(r - PLAT, RIM - 0.001)
	var y = base - (RIM - sqrt(RIM * RIM - d * d))
	if g != null and g.map_id == "tarhut":
		var amp = min(1.0, d / 7.0) * 1.3 * (1.0 - d / RIM * 0.6)
		var a = atan2(z, x)
		var dune = 0.55 * pow(abs(sin(x * 0.21 + z * 0.08 + sin(z * 0.05) * 2.0)), 1.6) + 0.45 * pow(abs(sin(z * 0.17 - x * 0.06 + a)), 2.0)
		y += amp * dune
	else:
		y += 0.08 * sin(x * 0.7) * sin(z * 0.6)
	return y


func planet_normal(x: float, z: float) -> Vector3:
	var e = 0.3
	var dx = planet_y(x + e, z) - planet_y(x - e, z)
	var dz = planet_y(x, z + e) - planet_y(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


func _planet_col(desert: bool, x: float, z: float, y: float, under: float) -> Color:
	if under > 0.0:
		# base rochosa em camadas, mais escura embaixo
		var band = int(floor(-y * 0.9)) % 3
		var rock_d = [Color("#8a5a3c"), Color("#6e4430"), Color("#a0704a")]
		var rock_g = [Color("#4a6a5a"), Color("#3a5446"), Color("#5a7a62")]
		var rc = rock_d[band] if desert else rock_g[band]
		return rc.darkened(clamp(under * 0.7, 0.0, 0.6))
	var r = sqrt(x * x + z * z)
	var d = max(0.0, r - PLAT)
	if desert:
		var ground = BASE_Y - 0.1 - (RIM - sqrt(max(0.0, RIM * RIM - min(d, RIM) * min(d, RIM))))
		var crest = clamp((y - ground) / 1.3, 0.0, 1.0)
		var c = Color("#c9965e").lerp(Color("#f2cf92"), crest)
		return c.lerp(Color("#9a6440"), clamp(d / RIM, 0.0, 0.45))
	return Color("#2aa6c8").lerp(Color("#11507e"), clamp(d / RIM, 0.0, 1.0))


func _planet_mesh(desert: bool) -> ArrayMesh:
	var seg = 160
	var base = BASE_Y - 0.1
	# perfil: (raio, y fixo ou NAN para usar a altura do chão, quanto é "de baixo")
	var prof = []
	var r = 0.0
	while r < PLAT:
		prof.append([r, NAN, 0.0])
		r += 0.7
	for i in range(24):
		var th = PI / 2.0 * i / 23.0
		prof.append([PLAT + RIM * sin(th), NAN if i < 23 else base - RIM, 0.0])
	for i in range(1, 22):
		var t = float(i) / 21.0
		prof.append([(PLAT + RIM) * (1.0 - pow(t, 1.7)) + 0.3, base - RIM - t * UNDER, t])
	var pts = []
	var cols = []
	for p in prof:
		var row = []
		var crow = []
		for k in range(seg):
			var a = TAU * k / seg
			var rr = p[0]
			if p[2] > 0.0:
				rr *= 1.0 + 0.09 * sin(a * 5.0 + p[1] * 0.4) * sin(a * 3.0 - p[1] * 0.7)
			var x = cos(a) * rr
			var z = sin(a) * rr
			var y = p[1] if not is_nan(p[1]) else planet_y(x, z)
			row.append(Vector3(x, y, z))
			crow.append(_planet_col(desert, x, z, y, p[2]))
		pts.append(row)
		cols.append(crow)
	var center = Vector3(0, base - RIM - UNDER * 0.35, 0)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nr = pts.size()
	var nrm = []
	for i in range(nr):
		var row_n = []
		for k in range(seg):
			var pu = pts[min(i + 1, nr - 1)][k] - pts[max(i - 1, 0)][k]
			var pv = pts[i][(k + 1) % seg] - pts[i][(k - 1 + seg) % seg]
			var n = pu.cross(pv)
			if n.length() < 0.0001:
				n = Vector3.UP
			n = n.normalized()
			if i == 0:
				n = Vector3.UP
			elif n.dot(pts[i][k] - center) < 0.0:
				n = -n
			row_n.append(n)
		nrm.append(row_n)
	for i in range(nr - 1):
		for k in range(seg):
			var k2 = (k + 1) % seg
			for v in [[i, k], [i + 1, k], [i + 1, k2], [i, k], [i + 1, k2], [i, k2]]:
				st.set_color(cols[v[0]][v[1]])
				st.set_normal(nrm[v[0]][v[1]])
				st.add_vertex(pts[v[0]][v[1]])
	return st.commit()


# objetos grandes espalhados pelo planeta (rochas, ossadas gigantes, ilhas)
func _place_on_planet(node: Node3D, x: float, z: float) -> void:
	var y = planet_y(x, z)
	var n = planet_normal(x, z)
	node.position = Vector3(x, y, z)
	var axis = Vector3.UP.cross(n)
	if axis.length() > 0.001:
		node.rotate(axis.normalized(), Vector3.UP.angle_to(n))


func _build_far(desert: bool) -> void:
	for i in range(40):
		var h = Vector2i(i * 7 + 3, i * 13 + 5)
		var a = _rnd(h, 1) * TAU
		var rr = PLAT + 1.0 + _rnd(h, 2) * 9.0
		var holder = Node3D.new()
		scenery_root.add_child(holder)
		_place_on_planet(holder, cos(a) * rr, sin(a) * rr)
		holder.rotate_object_local(Vector3.UP, _rnd(h, 3) * TAU)
		var s = 1.6 + _rnd(h, 4) * 2.8
		if desert:
			var kind = int(_rnd(h, 5) * 5)
			if kind <= 1:
				if not _model(holder, "rocha", Vector3.ZERO, 2.2 * s, 0.0):
					_mesh(holder, _cyl(0.5 * s, 0.9 * s, 1.6 * s, 7), Color("#8a6a52"), Vector3(0, 0.8 * s, 0))
			elif kind == 2:
				if not _model(holder, "ossada", Vector3.ZERO, 3.0 * s, 0.0):
					_ribs(holder, Vector3.ZERO, s * 1.4, 5)
			elif kind == 3:
				# pilar de arenito em camadas
				for j in range(3):
					_mesh(holder, _cyl((0.7 - j * 0.15) * s, (0.8 - j * 0.12) * s, 0.9 * s, 7), Color("#b4703e").lerp(Color("#e0a060"), j * 0.4), Vector3(0, (0.45 + j * 0.85) * s, 0), Vector3(0, j * 0.4, 0))
			else:
				var cm = _mesh(holder, _cyl(0.0, 0.25 * s, 1.4 * s, 5), Color("#a35cf0"), Vector3(0, 0.7 * s, 0))
				var em = StandardMaterial3D.new()
				em.albedo_color = Color("#b06af5")
				em.emission_enabled = true
				em.emission = Color("#8a4ad8")
				em.emission_energy_multiplier = 0.8
				cm.material_override = em
		else:
			if _rnd(h, 5) < 0.6:
				var isl = _mesh(holder, _cyl(1.2 * s, 1.6 * s, 0.6, 9), Color("#e8d29a"), Vector3(0, 0.15, 0))
				isl.material_overlay = outline_mat
				_mesh(holder, _cyl(0.9 * s, 1.2 * s, 0.4, 9), Color("#7fb54a"), Vector3(0, 0.45, 0))
				for j in range(2 + int(_rnd(h, 6) * 3)):
					_pine(holder, Vector3((_rnd(h, j + 10) - 0.5) * 1.4 * s, 0.6, (_rnd(h, j + 20) - 0.5) * 1.4 * s), 0.9 + _rnd(h, j) * 0.5)


func world_xz(h: Vector2i) -> Vector2:
	return Vector2(1.5 * h.y, -S3 * (h.x + h.y / 2.0))


func hex_from_world(x: float, z: float) -> Vector2i:
	var r = x / 1.5
	var q = -z / S3 - r / 2.0
	var s = -q - r
	var rq = round(q)
	var rr = round(r)
	var rs = round(s)
	var dq = abs(rq - q)
	var dr = abs(rr - r)
	var ds = abs(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


func top_y(h: Vector2i) -> float:
	if tiles.has(h):
		var extra = 0.0
		if g != null and g.blocks.has(h) and g.terr(h)["k"] != "buraco" and g.unit_at(h) != null:
			extra = float(g.tt_of(g.terr(h)["k"]).get("top", 0)) * 0.55
		return (tiles[h]["disp_h"] + extra) * HS
	return 0.0


func pal_of(t: Dictionary, h: Vector2i) -> String:
	var desert = g.map_id == "tarhut"
	match t["k"]:
		"duna":
			return "dune"
		"rocha", "ruina", "galpao":
			return "stone"
		"ossada", "ossada_c":
			return "bone" if desert else "grass"
		"areia":
			return "sand" if desert else "grass"
		"movedica":
			return "quick"
		"instavel":
			return "cracked"
		"buraco":
			return "hole"
		"plataforma":
			return "wood"
		"rampa":
			return "ramp"
		"lama":
			return "mud"
		"escombros":
			return "rubble"
		"colina":
			return "grass2"
	return "sand" if desert else "grass"


# reconstrói o visual das casas quando o terreno muda (dunas, buracos)
func refresh_terrain() -> void:
	if g == null or built_ver == g.terr_ver:
		return
	var first = built_ver < 0
	built_ver = g.terr_ver
	for h in DB.hexes:
		var t = g.terr(h)
		var tile = tiles[h]
		var sig = "%s:%d" % [t["k"], t["h"]]
		if sig == tile["sig"]:
			continue
		if not first:
			tile["flash"] = 1.0
		tile["sig"] = sig
		if first:
			tile["disp_h"] = float(t["h"])
		if tile["body"] != null:
			tile["body"].queue_free()
		if tile["props"] != null:
			tile["props"].queue_free()
		var pal = PAL[pal_of(t, h)]
		var ec = Color(ELEV.get(g.map_id, "#c0583a"))
		var lv = clamp(float(t["h"]) * 0.16, 0.0, 0.5)
		var body = MeshInstance3D.new()
		body.mesh = _tile_mesh(Color(pal[0]).lerp(ec, lv).lightened(lv * 0.25), Color(pal[1]).lerp(ec, lv), Color(pal[2]).lerp(ec.darkened(0.3), lv))
		body.material_override = tile_mat
		body.material_overlay = outline_mat
		tile["node"].add_child(body)
		tile["body"] = body
		var props = Node3D.new()
		tile["node"].add_child(props)
		tile["props"] = props
		_add_props(props, h, t)
		_place_tile(h)


func _place_tile(h: Vector2i) -> void:
	var tile = tiles[h]
	var y = tile["disp_h"] * HS
	# o corpo vai da base até o topo: escala vertical
	var height = y - BASE_Y
	tile["body"].scale = Vector3(1, height, 1)
	tile["body"].position = Vector3(0, BASE_Y, 0)
	tile["props"].position = Vector3(0, y, 0)
	tile["hl"].position = Vector3(0, y + 0.03, 0)
	tile["dim"].position = Vector3(0, y + 0.035, 0)
	tile["label"].position = Vector3(0, y + 0.35, 0)


# prisma unitário (altura 1 a partir de 0); topo com aro claro e centro colorido
func _tile_mesh(c0: Color, c1: Color, cs: Color) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim = c0.lightened(0.28)
	var pts_o = []
	var pts_i = []
	for k in range(6):
		var a = PI / 3.0 * k
		pts_o.append(Vector2(cos(a), sin(a)) * TILE)
		pts_i.append(Vector2(cos(a), sin(a)) * INNER)
	# laterais
	for k in range(6):
		var a = pts_o[k]
		var b = pts_o[(k + 1) % 6]
		var mid = (a + b) * 0.5
		var n = Vector3(mid.x, 0, mid.y).normalized()
		st.set_normal(n)
		var top_c = cs
		var bot_c = cs.darkened(0.35)
		_tri(st, Vector3(a.x, 1, a.y), top_c, Vector3(b.x, 1, b.y), top_c, Vector3(b.x, 0, b.y), bot_c)
		_tri(st, Vector3(a.x, 1, a.y), top_c, Vector3(b.x, 0, b.y), bot_c, Vector3(a.x, 0, a.y), bot_c)
	st.set_normal(Vector3.UP)
	# aro
	for k in range(6):
		var o1 = pts_o[k]
		var o2 = pts_o[(k + 1) % 6]
		var i1 = pts_i[k]
		var i2 = pts_i[(k + 1) % 6]
		_tri(st, Vector3(o1.x, 1, o1.y), rim, Vector3(o2.x, 1, o2.y), rim, Vector3(i2.x, 1, i2.y), rim)
		_tri(st, Vector3(o1.x, 1, o1.y), rim, Vector3(i2.x, 1, i2.y), rim, Vector3(i1.x, 1, i1.y), rim)
	# centro (leque com cor do centro para a borda)
	for k in range(6):
		var i1b = pts_i[k]
		var i2b = pts_i[(k + 1) % 6]
		_tri(st, Vector3(0, 1.001, 0), c0, Vector3(i1b.x, 1.001, i1b.y), c1, Vector3(i2b.x, 1.001, i2b.y), c1)
	return st.commit()


func _tri(st: SurfaceTool, a: Vector3, ca: Color, b: Vector3, cb: Color, c: Vector3, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


func _disc(radius: float, seg: int) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in range(seg):
		var a1 = TAU / seg * k
		var a2 = TAU / seg * (k + 1)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a1), 0, sin(a1)) * radius)
		st.add_vertex(Vector3(cos(a2), 0, sin(a2)) * radius)
	return st.commit()


func _overlay_mat(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	m.render_priority = 1
	return m


func _mat(c: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _mesh(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cyl(top: float, bottom: float, height: float, seg: int = 12) -> CylinderMesh:
	var c = CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = seg
	c.rings = 1
	return c


func _box(s: Vector3) -> BoxMesh:
	var b = BoxMesh.new()
	b.size = s
	return b


func _rnd(h: Vector2i, i: int) -> float:
	var v = (h.x * 73856093) ^ (h.y * 19349663) ^ (i * 83492791)
	return float(abs(v) % 1000) / 1000.0


func _pine(parent: Node3D, pos: Vector3, s: float) -> void:
	_mesh(parent, _cyl(0.05 * s, 0.06 * s, 0.3 * s, 6), Color("#5a3d22"), pos + Vector3(0, 0.15 * s, 0))
	var cols = [Color("#2f6a3a"), Color("#3c8048"), Color("#4b9656")]
	for i in range(3):
		var w = 0.36 * s * (1.0 - i * 0.22)
		_mesh(parent, _cyl(0.0, w, 0.5 * s, 8), cols[i], pos + Vector3(0, 0.3 * s + i * 0.26 * s + 0.25 * s, 0))


func _ribs(parent: Node3D, pos: Vector3, s: float, n: int) -> void:
	for i in range(n):
		var x = -0.45 * s + i * (0.9 * s / max(1, n - 1))
		var cap = CapsuleMesh.new()
		cap.radius = 0.055 * s
		cap.height = 1.0 * s
		_mesh(parent, cap, Color("#efe4c8"), pos + Vector3(x, 0.4 * s, 0), Vector3(0, 0, -0.45))


func _add_props(root: Node3D, h: Vector2i, t: Dictionary) -> void:
	match t["k"]:
		"rocha":
			if _model(root, "rocha", Vector3.ZERO, 1.55, _rnd(h, 2) * TAU):
				pass
			else:
				_rock_fallback(root)
		"_rocha_old":
			_mesh(root, _cyl(0.5, 0.66, 0.6, 6), Color("#7d6a58"), Vector3(0, 0.3, 0), Vector3(0, 0.3, 0))
			_mesh(root, _cyl(0.32, 0.5, 0.35, 6), Color("#a8937a"), Vector3(0.05, 0.75, -0.04), Vector3(0, 0.7, 0))
		"ruina":
			_mesh(root, _box(Vector3(0.9, 0.9, 0.35)), Color("#cfc3b0"), Vector3(0, 0.45, 0))
			_mesh(root, _box(Vector3(0.35, 0.5, 0.8)), Color("#9c8f84"), Vector3(0.3, 0.25, 0.1))
		"galpao":
			_mesh(root, _box(Vector3(1.2, 1.1, 1.2)), Color("#7a8088"), Vector3(0, 0.55, 0))
			var roof = PrismMesh.new()
			roof.size = Vector3(1.3, 0.5, 1.3)
			_mesh(root, roof, Color("#c25a3a"), Vector3(0, 1.35, 0))
		"floresta":
			for sp in [Vector3(-0.32, 0, -0.2), Vector3(0.32, 0, -0.25), Vector3(0.02, 0, 0.28)]:
				_pine(root, sp, 1.0 + _rnd(h, int(sp.x * 10)) * 0.2)
		"ossada":
			if not _model(root, "ossada", Vector3.ZERO, 1.6, _rnd(h, 3) * TAU):
				_ribs(root, Vector3.ZERO, 0.9, 4)
		"ossada_c":
			_ribs(root, Vector3(0, 0, -0.1), 1.5, 3)
		"movedica":
			_mesh(root, _cyl(0.55, 0.55, 0.02, 20), Color("#6b4520"), Vector3(0, 0.02, 0))
			var tor = TorusMesh.new()
			tor.inner_radius = 0.25
			tor.outer_radius = 0.33
			_mesh(root, tor, Color("#8a5a2a"), Vector3(0, 0.03, 0))
		"instavel":
			for i in range(3):
				_mesh(root, _box(Vector3(0.7, 0.02, 0.04)), Color("#8a5a28"), Vector3(-0.1 + i * 0.1, 0.02, -0.3 + i * 0.28), Vector3(0, _rnd(h, i) * 2.0, 0))
		"buraco":
			_mesh(root, _cyl(0.62, 0.62, 0.03, 20), Color("#120804"), Vector3(0, 0.02, 0))
			for i in range(10):
				var a = TAU / 10.0 * i
				_mesh(root, _cyl(0.0, 0.07, 0.25, 6), Color("#efe4c8"), Vector3(cos(a) * 0.55, 0.12, sin(a) * 0.55), Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5))
		"lama":
			for sp2 in [Vector3(-0.3, 0.02, -0.1), Vector3(0.28, 0.02, 0.12), Vector3(-0.05, 0.02, 0.32)]:
				_mesh(root, _cyl(0.24, 0.24, 0.02, 14), Color("#3e3322"), sp2)
		"escombros":
			for i in range(5):
				_mesh(root, _box(Vector3(0.18, 0.12, 0.14)), Color("#6a6a72"), Vector3((_rnd(h, i) - 0.5) * 1.0, 0.06, (_rnd(h, i + 7) - 0.5) * 0.9), Vector3(0, _rnd(h, i + 3) * 3.0, 0))
		"plataforma":
			for i in range(5):
				_mesh(root, _box(Vector3(1.4, 0.03, 0.12)), Color("#8a5d3d"), Vector3(0, 0.015, -0.34 + i * 0.17))
		"rampa":
			var up: Variant = null
			for n in DB.nbrs(h):
				if g.h_of(n) > g.h_of(h):
					up = n
					break
			if up != null:
				var a2 = world_xz(up) - world_xz(h)
				var ang = atan2(a2.y, a2.x)
				var arrow = Node3D.new()
				arrow.rotation = Vector3(0, -ang, 0)
				root.add_child(arrow)
				_mesh(arrow, _box(Vector3(0.6, 0.03, 0.1)), Color("#fff4d0"), Vector3(-0.05, 0.03, 0))
				_mesh(arrow, _cyl(0.0, 0.18, 0.04, 3), Color("#fff4d0"), Vector3(0.35, 0.03, 0), Vector3(0, PI / 2, 0))
		"plano", "colina":
			for i in range(3):
				_mesh(root, _cyl(0.0, 0.05, 0.14, 4), Color("#4f8a22"), Vector3((_rnd(h, i) - 0.5) * 1.0, 0.07, (_rnd(h, i + 9) - 0.5) * 0.9))
	var o = DB.obj_at(h)
	if o != null:
		_mesh(root, _cyl(0.04, 0.04, 0.9, 6), Color("#3a2508"), Vector3(0, 0.45, 0))
		var ball = _mesh(root, SphereMesh.new(), Color("#f6dc72"), Vector3(0, 1.0, 0))
		ball.scale = Vector3(0.36, 0.36, 0.36)
		var lab = Label3D.new()
		lab.text = o["name"].to_upper()
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.font_size = 48
		lab.outline_size = 14
		lab.pixel_size = 0.006
		lab.modulate = Color("#ffe39a")
		lab.position = Vector3(0, 1.45, 0)
		root.add_child(lab)
	if g.res.has(h):
		var rt = g.res[h]
		var rc = Color("#b07a3a")
		if rt == "agua":
			rc = Color("#5ec8f0")
		elif rt == "sucata":
			rc = Color("#c9c2b4")
		var rm = _mesh(root, (SphereMesh.new() as Mesh) if rt == "agua" else (_box(Vector3(0.3, 0.22, 0.3)) as Mesh), rc, Vector3(0.42, 0.18, 0.22))
		if rt == "agua":
			rm.scale = Vector3(0.3, 0.36, 0.3)
		var rl = Label3D.new()
		rl.text = DB.res[rt]["name"].split(" ")[0].to_upper()
		rl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rl.font_size = 36
		rl.outline_size = 12
		rl.pixel_size = 0.006
		rl.position = Vector3(0.42, 0.55, 0.22)
		root.add_child(rl)


# ---------- modelos 3D da Meshy (res://models/<nome>.glb) ----------
func _scene_of(mname: String) -> Variant:
	if not model_cache.has(mname):
		var path = "res://models/%s.glb" % mname
		model_cache[mname] = load(path) if ResourceLoader.exists(path) else null
	return model_cache[mname]


# coloca o modelo com a base no chão, cabendo num círculo de "footprint" de diâmetro
func _model(parent: Node3D, mname: String, pos: Vector3, footprint: float, yaw: float) -> bool:
	var sc = _scene_of(mname)
	if sc == null:
		return false
	var inst: Node3D = sc.instantiate()
	var meshes = inst.find_children("*", "MeshInstance3D", true, false)
	var box = AABB()
	var first = true
	for mi in meshes:
		var ab = mi.transform * mi.get_aabb()
		if first:
			box = ab
			first = false
		else:
			box = box.merge(ab)
		mi.material_overlay = outline_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var wide = max(box.size.x, box.size.z)
	var k = footprint / wide if wide > 0.0001 else 1.0
	var holder = Node3D.new()
	holder.position = pos
	holder.rotation = Vector3(0, yaw, 0)
	parent.add_child(holder)
	holder.add_child(inst)
	inst.scale = Vector3.ONE * k
	inst.position = Vector3(-(box.position.x + box.size.x / 2.0) * k, -box.position.y * k, -(box.position.z + box.size.z / 2.0) * k)
	return true


func _rock_fallback(root: Node3D) -> void:
	_mesh(root, _cyl(0.5, 0.66, 0.6, 6), Color("#7d6a58"), Vector3(0, 0.3, 0), Vector3(0, 0.3, 0))
	_mesh(root, _cyl(0.32, 0.5, 0.35, 6), Color("#a8937a"), Vector3(0.05, 0.75, -0.04), Vector3(0, 0.7, 0))


func _build_scenery(desert: bool) -> void:
	for q in range(-DB.R - 4, DB.R + 5):
		for r in range(-DB.R - 4, DB.R + 5):
			var h = Vector2i(q, r)
			var d = DB.out_dist(h)
			if d <= 0 or d > 4:
				continue
			if _rnd(h, 9) < (0.55 if d == 1 else 0.7):
				continue
			var wp = world_xz(h)
			var px = wp.x + (_rnd(h, 5) - 0.5) * 0.9
			var pz = wp.y + (_rnd(h, 6) - 0.5) * 0.9
			var p = Vector3(px, planet_y(px, pz), pz)
			var s = 0.8 + _rnd(h, 8) * 0.6
			var k = int(_rnd(h, 7) * 6)
			if desert:
				match k:
					0, 1:
						if not _model(scenery_root, "rocha", p, 1.1 * s, _rnd(h, 2) * TAU):
							_mesh(scenery_root, _cyl(0.3 * s, 0.45 * s, 0.6 * s, 6), Color("#8a7562"), p + Vector3(0, 0.3 * s, 0), Vector3(0, _rnd(h, 2) * 3.0, 0))
					2:
						if not _model(scenery_root, "ossada", p, 1.3 * s, _rnd(h, 3) * TAU):
							_ribs(scenery_root, p, s * 0.8, 4)
					3:
						for i in range(3):
							var cm = _mesh(scenery_root, _cyl(0.0, 0.1 * s, (0.5 + i * 0.25) * s, 5), Color("#a35cf0").lerp(Color("#c98aff"), i * 0.4), p + Vector3(-0.2 + i * 0.2, (0.25 + i * 0.12) * s, 0))
							var em = StandardMaterial3D.new()
							em.albedo_color = Color("#b06af5")
							em.emission_enabled = true
							em.emission = Color("#8a4ad8")
							em.emission_energy_multiplier = 0.6
							cm.material_override = em
					4:
						_mesh(scenery_root, _cyl(0.09 * s, 0.09 * s, 0.9 * s, 8), Color("#5f9a4a"), p + Vector3(0, 0.45 * s, 0))
						_mesh(scenery_root, _cyl(0.06 * s, 0.06 * s, 0.35 * s, 8), Color("#5f9a4a"), p + Vector3(0.15 * s, 0.6 * s, 0), Vector3(0, 0, 1.2))
					_:
						var dm = _mesh(scenery_root, SphereMesh.new(), Color("#f0cf8e"), p)
						dm.scale = Vector3(1.6 * s, 0.4 * s, 1.1 * s)
			else:
				match k:
					0, 1, 2:
						_mesh(scenery_root, _cyl(0.6 * s, 0.7 * s, 0.3, 7), Color("#8fc24e"), p + Vector3(0, 0.12, 0), Vector3(0, _rnd(h, 3) * 3.0, 0))
						if _rnd(h, 4) > 0.4:
							_pine(scenery_root, p + Vector3(0, 0.27, 0), 0.9 * s)
					3:
						_mesh(scenery_root, _cyl(0.3 * s, 0.45 * s, 0.5 * s, 6), Color("#8a7562"), p + Vector3(0, 0.2 * s, 0))
					4:
						_mesh(scenery_root, _box(Vector3(0.45, 0.45, 0.45)), Color("#a6763f"), p + Vector3(0, 0.15, 0), Vector3(0, _rnd(h, 1) * 3.0, 0))
					_:
						_mesh(scenery_root, _cyl(0.0, 0.15, 0.5, 6), Color("#e0563f"), p + Vector3(0, 0.2, 0))


func _make_heart() -> ImageTexture:
	var w = 64
	var img = Image.create(w, w, false, Image.FORMAT_RGBA8)
	for y in range(w):
		for x in range(w):
			var fx = (x - w / 2.0) / (w * 0.42)
			var fy = -(y - w * 0.45) / (w * 0.42)
			var v = pow(fx * fx + fy * fy - 1.0, 3.0) - fx * fx * fy * fy * fy
			var v2 = pow(fx * fx * 0.78 + fy * fy * 0.78 - 1.0, 3.0) - fx * fx * 0.78 * pow(fy * 0.88, 3.0)
			if v2 <= 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			elif v <= 0.0:
				img.set_pixel(x, y, Color(0.1, 0.02, 0.02, 1))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


# ================= peças =================
func sync_units() -> void:
	if g == null:
		return
	var seen = {}
	for u in g.units:
		if u.st != "field":
			continue
		seen[u.uid] = true
		if not unit_nodes.has(u.uid):
			_make_unit(u)
	for uid in unit_nodes.keys():
		if not seen.has(uid):
			var n = unit_nodes[uid]
			n["node"].queue_free()
			unit_nodes.erase(uid)


func _make_unit(u) -> void:
	var node = Node3D.new()
	add_child(node)
	var sc = 0.75 if u.barrier else (1.15 if BIG.has(u.cid) else (1.08 if u.is_cmd else 1.0))
	var shadow = MeshInstance3D.new()
	shadow.mesh = _disc(0.5, 16)
	shadow.material_override = _overlay_mat(Color(0, 0, 0, 0.35))
	shadow.position = Vector3(0, 0.02, 0)
	node.add_child(shadow)
	var ring = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 0.42
	tor.outer_radius = 0.5
	ring.mesh = tor
	ring.material_override = _mat(Color("#3d8bff") if u.owner == 0 else Color("#ff7a2f"), true)
	ring.position = Vector3(0, 0.04, 0)
	ring.scale = Vector3(1, 0.4, 1)
	node.add_child(ring)
	var sprite: Variant = null
	var body_h = 1.75 * sc
	if u.barrier:
		_mesh(node, _cyl(0.4, 0.5, 0.7, 6), Color("#6d6250"), Vector3(0, 0.35, 0))
		body_h = 0.8
	elif DB.art.has(u.cid):
		sprite = Sprite3D.new()
		var tex = DB.art[u.cid]
		sprite.texture = tex
		sprite.pixel_size = body_h / float(tex.get_height())
		sprite.centered = true
		sprite.offset = Vector2(0, tex.get_height() / 2.0)
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.shaded = false
		sprite.double_sided = true
		node.add_child(sprite)
	else:
		var col = Color(DB.factions[DB.cards[u.cid]["f"]]["color"])
		var cap = CapsuleMesh.new()
		cap.radius = 0.32
		cap.height = 1.3
		_mesh(node, cap, col, Vector3(0, 0.65, 0))
		var il = Label3D.new()
		var words = DB.cards[u.cid]["name"].split(" ")
		var ini = ""
		for wd in words:
			if wd.length() > 0 and ini.length() < 2:
				ini += wd.substr(0, 1).to_upper()
		il.text = ini
		il.font_size = 96
		il.outline_size = 20
		il.pixel_size = 0.006
		il.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		il.position = Vector3(0, 0.75, 0.0)
		node.add_child(il)
		body_h = 1.4
	var heart = Sprite3D.new()
	heart.texture = heart_tex
	heart.pixel_size = 0.0075
	heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heart.no_depth_test = true
	heart.render_priority = 5
	heart.modulate = Color("#3d8bff") if u.owner == 0 else Color("#ff7a2f")
	heart.position = Vector3(0, body_h + 0.25, 0)
	node.add_child(heart)
	var hp = Label3D.new()
	hp.font_size = 56
	hp.outline_size = 14
	hp.pixel_size = 0.0065
	hp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp.no_depth_test = true
	hp.render_priority = 6
	hp.position = Vector3(0, body_h + 0.27, 0)
	node.add_child(hp)
	var tag = Label3D.new()
	tag.font_size = 40
	tag.outline_size = 14
	tag.pixel_size = 0.006
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.render_priority = 6
	tag.position = Vector3(0, -0.05, 0.45)
	tag.visible = false
	node.add_child(tag)
	var flags = Label3D.new()
	flags.font_size = 32
	flags.outline_size = 10
	flags.pixel_size = 0.006
	flags.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flags.no_depth_test = true
	flags.position = Vector3(0, body_h + 0.62, 0)
	node.add_child(flags)
	var wp = world_xz(u.pos())
	var start = Vector3(wp.x, top_y(u.pos()), wp.y)
	node.position = start
	node.scale = Vector3(0.01, 0.01, 0.01)
	unit_nodes[u.uid] = {"node": node, "sprite": sprite, "hp": hp, "heart": heart, "tag": tag, "flags": flags, "ring": ring,
		"hex": u.pos(), "path": [], "seg_t": 0.0, "from": start, "pop": 0.0, "flip": u.owner == 1, "bob": randf() * TAU, "hurt": 0.0, "lunge": 0.0}


# caminho casa a casa só pelo terreno (para a animação)
func walk_path(a: Vector2i, b: Vector2i) -> Array:
	if a == b:
		return [a]
	var best = {a: 0}
	var prev = {}
	var queue = [{"h": a, "c": 0}]
	while not queue.is_empty():
		queue.sort_custom(func(x, y): return x["c"] < y["c"])
		var n = queue.pop_front()
		if n["h"] == b:
			break
		for m in DB.nbrs(n["h"]):
			if m != b and (not g.tt_of(g.terr(m)["k"]).get("pass", 0) or not g.can_step(n["h"], m)):
				continue
			var c = n["c"] + max(1, g.step_cost(n["h"], m))
			if best.has(m) and best[m] <= c:
				continue
			best[m] = c
			prev[m] = n["h"]
			queue.append({"h": m, "c": c})
	if not prev.has(b):
		return [a, b]
	var out = [b]
	var k = b
	while prev.has(k) and prev[k] != a:
		k = prev[k]
		out.push_front(k)
	out.push_front(a)
	return out if out.size() <= 9 else [a, b]


func _unit_goal(u) -> Vector2i:
	var gh = state.get("ghost", null)
	if gh != null and state.get("sel_uid", -1) == u.uid:
		return gh
	return u.pos()


func _process(delta: float) -> void:
	if g == null:
		return
	_update_camera(delta)
	# casas de entrada piscando quando dá para colocar reserva
	for dh in state.get("hl", {}).keys():
		if state["hl"][dh] == "deploy" and tiles.has(dh):
			_apply_overlay(dh)
	# relevo animado (dunas sobem e descem)
	for h in tiles.keys():
		var tile = tiles[h]
		if tile["body"] == null:
			continue
		var tgt = float(g.h_of(h))
		if abs(tile["disp_h"] - tgt) > 0.003:
			tile["disp_h"] += (tgt - tile["disp_h"]) * min(1.0, delta * 4.0)
			_place_tile(h)
		elif tile["disp_h"] != tgt:
			tile["disp_h"] = tgt
			_place_tile(h)
		if tile["flash"] > 0.0:
			tile["flash"] = max(0.0, tile["flash"] - delta * 0.9)
			_apply_overlay(h)
	_update_units(delta)


func _update_units(delta: float) -> void:
	var t_now = Time.get_ticks_msec() / 1000.0
	for u in g.units:
		if u.st != "field" or not unit_nodes.has(u.uid):
			continue
		var d = unit_nodes[u.uid]
		var node: Node3D = d["node"]
		var goal = _unit_goal(u)
		if goal != d["hex"]:
			var path = walk_path(d["hex"], goal)
			path.pop_front()
			d["path"] = path
			d["from"] = Vector3(node.position.x, node.position.y, node.position.z)
			d["seg_t"] = 0.0
			d["long"] = path.size() == 1 and DB.dist(d["hex"], goal) > 1
			d["hex"] = goal
		if d["pop"] < 1.0:
			d["pop"] = min(1.0, d["pop"] + delta * 3.5)
			var e = 1.0 + 0.25 * sin(d["pop"] * PI) if d["pop"] < 1.0 else 1.0
			node.scale = Vector3.ONE * d["pop"] * e
		var walking = not d["path"].is_empty()
		if walking:
			var w2 = world_xz(d["path"][0])
			var w = Vector3(w2.x, top_y(d["path"][0]), w2.y)
			d["seg_t"] += delta * (1.6 if d.get("long", false) else 5.0)
			var t = min(1.0, d["seg_t"])
			var e2 = 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
			var p = d["from"].lerp(w, e2)
			p.y += sin(PI * t) * (1.2 if d.get("long", false) else 0.3)
			node.position = p
			var sa = cam.unproject_position(d["from"])
			var sb = cam.unproject_position(w)
			if abs(sb.x - sa.x) > 2.0:
				d["flip"] = sb.x < sa.x
			if t >= 1.0:
				d["from"] = w
				d["path"].pop_front()
				d["seg_t"] = 0.0
		else:
			var hw = world_xz(d["hex"])
			node.position = Vector3(hw.x, top_y(d["hex"]), hw.y)
		if drag != null and drag["on"] and drag["uid"] == u.uid and drag.has("world"):
			node.position = drag["world"] + Vector3(0, 0.6, 0)
		# vida e marcas
		d["hp"].text = str(u.hp)
		d["heart"].modulate = (Color("#ff2a2a") if u.hp <= u.maxhp / 3 else (Color("#3d8bff") if u.owner == 0 else Color("#ff7a2f")))
		var fl = []
		if u.is_cmd:
			fl.append("CMD")
		if u.eq != "":
			fl.append(u.eq.to_upper())
		if g.rooted(u):
			fl.append("PRESO")
		if g.silenced(u):
			fl.append("SEM HAB.")
		if g.has_fx(u, "mark"):
			fl.append("ALVO")
		d["flags"].text = " ".join(fl)
		var sprite = d["sprite"]
		var selected = state.get("sel_uid", -1) == u.uid
		if sprite != null:
			sprite.flip_h = d["flip"]
			var base_mod = Color(0.55, 0.55, 0.55) if (u.activated and not u.barrier) else Color(1, 1, 1)
			if d["hurt"] > 0.0:
				d["hurt"] = max(0.0, d["hurt"] - delta * 2.5)
				base_mod = base_mod.lerp(Color(1, 0.3, 0.2), d["hurt"])
			sprite.modulate = base_mod
			var bob = d["bob"] + t_now * 2.4
			var sy = 1.0 + 0.025 * sin(bob)
			if walking:
				sprite.rotation = Vector3(0, 0, 0.07 * sin(t_now * 30.0))
			else:
				sprite.rotation = Vector3.ZERO
			if selected:
				sprite.position = Vector3(0, 0.08 + 0.06 * sin(t_now * 6.0), 0)
			else:
				sprite.position = Vector3.ZERO
			if d["lunge"] > 0.0:
				d["lunge"] = max(0.0, d["lunge"] - delta * 3.0)
				sy *= 1.0 + 0.15 * sin(d["lunge"] * PI)
			sprite.scale = Vector3(1.0, sy, 1.0)
		d["ring"].material_override.albedo_color = Color("#ffffff") if selected else (Color("#3d8bff") if u.owner == 0 else Color("#ff7a2f"))
		# etiqueta de dano previsto / motivo
		var tg = state.get("tags", {}).get(u.uid, null)
		if tg != null:
			d["tag"].visible = true
			d["tag"].text = tg["text"]
			d["tag"].modulate = tg["color"]
		else:
			d["tag"].visible = false


# ================= destaques =================
func set_state(s: Dictionary) -> void:
	state = s
	refresh_terrain()
	sync_units()
	for h in tiles.keys():
		_apply_overlay(h)


func _apply_overlay(h: Vector2i) -> void:
	var tile = tiles[h]
	var hl = state.get("hl", {}).get(h, "")
	var col = Color(0, 0, 0, 0)
	match hl:
		"mv":
			col = Color(0.30, 0.85, 0.39, 0.62)
		"at":
			col = Color(1.0, 0.30, 0.30, 0.68)
		"pk":
			col = Color(0.69, 0.42, 1.0, 0.66)
		"sel":
			col = Color(0.31, 0.82, 1.0, 0.6)
		"prev":
			col = Color(0.49, 0.55, 0.95, 0.3)
		"no":
			col = Color(1.0, 0.25, 0.2, 0.45)
		"tgt":
			col = Color(1.0, 0.48, 0.24, 0.7)
		"trem":
			col = Color(1.0, 0.48, 0.24, 0.45)
		"dnext":
			col = Color(0.62, 0.94, 1.0, 0.35)
		"deploy":
			col = Color(0.13, 0.83, 0.77, 0.45 + 0.3 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)))
		"entry0":
			col = Color(0.24, 0.55, 1.0, 0.28)
		"entry1":
			col = Color(1.0, 0.48, 0.18, 0.28)
	if hover != null and hover == h:
		col = Color(1, 1, 1, 0.55)
	if tile["flash"] > 0.0:
		col = col.lerp(Color(1, 1, 0.85, 0.85), tile["flash"])
	tile["hl"].visible = col.a > 0.01
	tile["hl"].material_override.albedo_color = col
	var lit = state.get("lit", null)
	tile["dim"].visible = lit != null and not lit.has(h)
	var lab_txt = state.get("labels", {}).get(h, "")
	tile["label"].visible = lab_txt != ""
	if lab_txt != "":
		tile["label"].text = lab_txt
		tile["label"].modulate = state.get("label_colors", {}).get(h, Color.WHITE)


# ================= efeitos =================
func float_text(h: Vector2i, text: String, col: Color) -> void:
	var l = Label3D.new()
	l.text = text
	l.font_size = 96
	l.outline_size = 24
	l.pixel_size = 0.007
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	var wp = world_xz(h)
	l.position = Vector3(wp.x, top_y(h) + 2.3, wp.y)
	add_child(l)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.0, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func boom(h: Vector2i) -> void:
	var mi = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 0.4
	tor.outer_radius = 0.55
	mi.mesh = tor
	var m = _overlay_mat(Color(1.0, 0.69, 0.3, 0.9))
	mi.material_override = m
	var wp = world_xz(h)
	mi.position = Vector3(wp.x, top_y(h) + 0.3, wp.y)
	add_child(mi)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(3, 1, 3), 0.55)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(mi.queue_free)


func hurt(uid: int) -> void:
	if unit_nodes.has(uid):
		unit_nodes[uid]["hurt"] = 1.0


func lunge(uid: int) -> void:
	if unit_nodes.has(uid):
		unit_nodes[uid]["lunge"] = 1.0


# vermes saem dos buracos que acabaram de abrir e voltam para baixo
func worm_emerge(hexes: Array) -> void:
	for h in hexes:
		var holder = Node3D.new()
		var wp = world_xz(h)
		holder.position = Vector3(wp.x, top_y(h) - 2.2, wp.y)
		add_child(holder)
		if not _model(holder, "vermes", Vector3.ZERO, 1.7, randf() * TAU):
			holder.queue_free()
			continue
		var tw = create_tween()
		tw.tween_property(holder, "position:y", top_y(h) - 0.2, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(holder, "rotation:y", holder.rotation.y + 0.6, 1.2)
		tw.tween_property(holder, "position:y", top_y(h) - 2.4, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(holder.queue_free)


func quake() -> void:
	shake = 1.0


# ================= câmera =================
func fit_camera(snap: bool) -> void:
	var goal = {"yaw": 0.0, "pitch": 0.85, "dist": PLAT * 2.45, "target": Vector3(0, 0, 1.5)}
	var vp = get_viewport().get_visible_rect().size
	if vp.y > vp.x * 1.1:
		goal["yaw"] = PI / 2.0
		goal["dist"] = PLAT * 3.25
		goal["target"] = Vector3(-1.5, 0, 0)
	if snap:
		cam_yaw = goal["yaw"]
		cam_pitch = goal["pitch"]
		cam_dist = goal["dist"]
		cam_target = goal["target"]
	else:
		cam_goal = goal


func rotate_cam(dir: int) -> void:
	cam_goal = {"yaw": cam_yaw + dir * PI / 3.0, "pitch": cam_pitch, "dist": cam_dist, "target": cam_target}


func zoom_cam(f: float) -> void:
	cam_goal = {"yaw": cam_yaw, "pitch": cam_pitch, "dist": clamp(cam_dist * f, ZOOM_MIN, ZOOM_MAX), "target": cam_target}


func _update_camera(delta: float) -> void:
	if cam_goal != null:
		var k = min(1.0, delta * cam_speed)
		cam_yaw = lerp(cam_yaw, cam_goal["yaw"], k)
		cam_pitch = lerp(cam_pitch, cam_goal["pitch"], k)
		cam_dist = lerp(cam_dist, cam_goal["dist"], k)
		cam_target = cam_target.lerp(cam_goal["target"], k)
		if abs(cam_yaw - cam_goal["yaw"]) < 0.002 and abs(cam_dist - cam_goal["dist"]) < 0.01:
			cam_goal = null
	# perto dos personagens a câmera abaixa (visão mais cinematográfica)
	var pe = cam_pitch
	if cam_dist < 18.0:
		pe = lerp(0.32, cam_pitch, clamp((cam_dist - ZOOM_MIN) / (18.0 - ZOOM_MIN), 0.0, 1.0))
	var off = Vector3(sin(cam_yaw) * cos(pe), sin(pe), cos(cam_yaw) * cos(pe)) * cam_dist
	var tgt = cam_target
	if shake > 0.0:
		shake = max(0.0, shake - delta * 1.4)
		var t = Time.get_ticks_msec() / 1000.0
		tgt += Vector3(sin(t * 43.0), cos(t * 31.0) * 0.5, 0) * 0.18 * shake
	cam.look_at_from_position(tgt + off, tgt, Vector3.UP)


# ================= toque, arraste e câmera =================
func pick_hex(screen: Vector2) -> Variant:
	var o = cam.project_ray_origin(screen)
	var dir = cam.project_ray_normal(screen)
	var best: Variant = null
	var best_t = 1e9
	# peças (cilindro vertical aproximado)
	for uid in unit_nodes.keys():
		var nd = unit_nodes[uid]["node"]
		if not is_instance_valid(nd):
			continue
		if drag != null and drag["on"] and drag["uid"] == uid:
			continue
		for i in range(6):
			var yy = nd.position.y + 0.15 + i * 0.25
			if abs(dir.y) < 0.0001:
				continue
			var t = (yy - o.y) / dir.y
			if t <= 0:
				continue
			var p = o + dir * t
			if Vector2(p.x - nd.position.x, p.z - nd.position.z).length() < 0.42 and t < best_t:
				best_t = t
				best = unit_nodes[uid]["hex"]
	# casas (plano do topo de cada uma)
	for h in tiles.keys():
		var y = top_y(h)
		if abs(dir.y) < 0.0001:
			continue
		var t2 = (y - o.y) / dir.y
		if t2 <= 0 or t2 >= best_t:
			continue
		var p2 = o + dir * t2
		if hex_from_world(p2.x, p2.z) == h:
			best_t = t2
			best = h
	return best


func ground_point(screen: Vector2, y: float) -> Vector3:
	var o = cam.project_ray_origin(screen)
	var dir = cam.project_ray_normal(screen)
	if abs(dir.y) < 0.0001:
		return o
	var t = (y - o.y) / dir.y
	return o + dir * t


func _touch_pair() -> Array:
	var ks = touches.keys()
	ks.sort()
	return [touches[ks[0]], touches[ks[1]]]


func _gest_state() -> Dictionary:
	var p = _touch_pair()
	var a: Vector2 = p[0]
	var b: Vector2 = p[1]
	return {"d": max(a.distance_to(b), 1.0), "ang": (b - a).angle(), "mid": (a + b) * 0.5}


func _touch_event(event: InputEvent) -> bool:
	# true = evento consumido pelo controle de toque
	if event is InputEventScreenTouch:
		var st = event as InputEventScreenTouch
		if st.pressed:
			touches[st.index] = st.position
		else:
			touches.erase(st.index)
		if touches.size() >= 2:
			if drag != null and drag["on"]:
				return true
			if not multi:
				multi = true
				pan = null
				drag = null
			gest = _gest_state()
		elif touches.size() == 0:
			multi = false
			gest = null
		else:
			gest = null
		return true
	if event is InputEventScreenDrag:
		var sd = event as InputEventScreenDrag
		touches[sd.index] = sd.position
		if multi and touches.size() >= 2:
			var now = _gest_state()
			if gest != null:
				cam_goal = null
				# pinça = zoom
				cam_dist = clamp(cam_dist * gest["d"] / now["d"], ZOOM_MIN, ZOOM_MAX)
				# giro com dois dedos = girar a câmera
				cam_yaw += wrapf(now["ang"] - gest["ang"], -PI, PI)
				# arrastar dois dedos para cima/baixo = inclinar
				var dm: Vector2 = now["mid"] - gest["mid"]
				cam_pitch = clamp(cam_pitch + dm.y * 0.006, 0.45, 1.4)
			gest = now
		return true
	# mouse emulado pelo 1º dedo fica bloqueado durante gestos de dois dedos
	if multi and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if g == null:
		return
	if _touch_event(event):
		return
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_goal = null
			cam_dist = clamp(cam_dist * 0.88, ZOOM_MIN, ZOOM_MAX)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_goal = null
			cam_dist = clamp(cam_dist * 1.14, ZOOM_MIN, ZOOM_MAX)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var h = pick_hex(mb.position) if picking_enabled else null
				var u = g.unit_at(h) if h != null else null
				drag = null
				if u != null and picking_enabled and get_parent().has_method("can_drag_unit") and get_parent().can_drag_unit(u):
					drag = {"uid": u.uid, "start": mb.position, "on": false}
				pan = {"start": mb.position, "target": cam_target, "moved": false}
			else:
				if drag != null and drag["on"]:
					var h2 = pick_hex(mb.position)
					var uid = drag["uid"]
					drag = null
					hover = null
					unit_dropped.emit(uid, h2)
				elif pan != null and not pan["moved"] and picking_enabled:
					var h3 = pick_hex(mb.position)
					if h3 != null:
						hex_tapped.emit(h3)
				drag = null
				pan = null
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			pan = null
	elif event is InputEventMouseMotion:
		var mm = event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			cam_goal = null
			cam_yaw -= mm.relative.x * 0.008
			cam_pitch = clamp(cam_pitch + mm.relative.y * 0.005, 0.45, 1.4)
		elif mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if drag != null:
				if not drag["on"] and mm.position.distance_to(drag["start"]) > 7.0:
					drag["on"] = true
					unit_drag_started.emit(drag["uid"])
				if drag["on"]:
					var u2 = g.by_uid(drag["uid"])
					drag["world"] = ground_point(mm.position, top_y(u2.pos()) + 0.2)
					var hv = pick_hex(mm.position)
					if hv != hover:
						var old = hover
						hover = hv
						if old != null:
							_apply_overlay(old)
						if hv != null:
							_apply_overlay(hv)
					return
			if pan != null:
				if mm.position.distance_to(pan["start"]) > 6.0:
					pan["moved"] = true
				if pan["moved"]:
					cam_goal = null
					var a = ground_point(pan["start"], 0.0)
					var b = ground_point(mm.position, 0.0)
					var target_now = pan["target"] + (a - b)
					var m = 1.5 * DB.R + 2.0
					target_now.x = clamp(target_now.x, -m, m)
					target_now.z = clamp(target_now.z, -m, m)
					cam_target = target_now
					pan["start"] = mm.position
					pan["target"] = target_now
	elif event is InputEventMagnifyGesture:
		cam_dist = clamp(cam_dist / (event as InputEventMagnifyGesture).factor, ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventKey and event.pressed:
		var ke = event as InputEventKey
		if ke.keycode == KEY_Q:
			rotate_cam(-1)
		elif ke.keycode == KEY_E:
			rotate_cam(1)
