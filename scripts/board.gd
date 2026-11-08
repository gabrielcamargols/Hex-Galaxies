extends Node3D
## Tabuleiro 3D (2.5D): casas em prisma com altura, cenário, câmera e peças com as artes.

signal hex_tapped(h)                 # clique/toque numa casa (Vector2i)
signal hex_hovered(h)                # mouse passou sobre uma casa (sem clicar)
signal unit_dropped(uid, h)          # soltou uma peça arrastada (h pode ser null)
signal unit_drag_started(uid)
signal worm_roar(pos)                 # o verme rugiu lá do alto (posição do buraco)
signal worm_bite(pos)                 # o verme mergulhou de volta

const S3 = 1.7320508
const HS = 0.55          # altura de cada nível
const BASE_Y = -0.6
const TILE = 1.0          # casas encostadas: o tabuleiro vira um chão contínuo
const INNER = 0.95        # aro bem fino, só para dar para contar as casas
# [centro, borda, lateral] — cada tipo de terreno tem uma cor própria para não se confundir
const PAL = {
	"grass": ["#3c9a44", "#2c7a36", "#184a22"], "grass2": ["#52aa44", "#3c8834", "#22521e"],
	"sand": ["#e09a48", "#c27a32", "#6e3a1a"], "dune": ["#f07c4a", "#d05a32", "#7a2a1a"],
	"wood": ["#b07840", "#8c5a2c", "#4e3018"], "ramp": ["#d09a58", "#b07a3a", "#5e3e20"],
	"mud": ["#6a5238", "#4e3c28", "#2e2214"], "rubble": ["#8c8c9a", "#70707e", "#44444e"],
	"quick": ["#8e8040", "#6e6230", "#3e3618"], "stone": ["#8e827c", "#726862", "#4a4240"],
	"bone": ["#d8ccb0", "#bcae90", "#7e7058"], "cracked": ["#e0a058", "#c4803e", "#6e3a1a"],
	"hole": ["#3a2418", "#24140c", "#120a04"],
	"cave": ["#7a64e0", "#5a48c0", "#24186a"], "cave2": ["#6c56d4", "#4e3cb0", "#20145e"], "pit": ["#140a24", "#0c0618", "#05020a"],
	"rubble_g": ["#6aa040", "#548232", "#2c4a1c"], "sand2": ["#d8903e", "#b8702c", "#6e3a1a"], "grass3": ["#389444", "#2a7434", "#184a22"],
}
const ELEV = {"tarhut": "#c0583a", "posto": "#e0c060"}  # tom que as casas altas puxam
# planeta: o tabuleiro fica num platô e o chão se curva em volta (deserto contínuo)
var PLAT = 18.5       # raio plano em volta do tabuleiro (ajustado ao tamanho do mapa)
var RIM = 12.0         # raio da borda arredondada (onde o deserto se curva)
var UNDER = 34.0       # altura da base rochosa por baixo do planetoide
const ZOOM_MIN = 4.0
const ZOOM_MAX = 140.0
const BIG = ["moby", "balu", "banker", "l_behemot", "l_leviathan", "z_dragao", "golk", "w_mamute", "k_tank", "z_tank", "l_tank", "l_colosso", "sismico", "rhombo", "tork", "w_tric", "z_meca", "t_fendas", "t_raiz", "t_basalto", "t_carrinho", "t_sentinela", "t_britadeira", "a_garra", "k_escudeiro", "w_urso", "w_gorila", "w_javali"]

var me: int = 0   # jogador deste aparelho (cores: você azul, oponente laranja)
var flip_view := false   # online: gira a câmera para o próprio lado ficar à direita
var g: Game = null
var cam: Camera3D
var cam_yaw: float = 0.0
var cam_pitch: float = 0.95
var cam_dist: float = 26.0
var cam_target: Vector3 = Vector3(0, 0, 1.0)
var cam_goal: Variant = null
var cam_speed: float = 8.0      # mais baixo = câmera mais lenta (chegada no planeta)
var shake: float = 0.0

var cz_nodes: Dictionary = {}       # casa -> cristais da Zona de Cristal (Lithari)
var res_nodes: Dictionary = {}      # casa -> modelo do recurso (some quando é coletado)
var active_tiles: Dictionary = {}   # casas animando (relevo/brilho): só estas são varridas todo quadro
var scan_n: int = 0
var tiles: Dictionary = {}       # Vector2i -> {node, disp_h, props, hl, dim, label, flash}
var tile_mat: Material
var unit_nodes: Dictionary = {}  # uid -> {node, sprite, hp, label, path, ...}
var state: Dictionary = {}       # destaques vindos do controlador
var built_ver: int = -1
var heart_tex: ImageTexture
var scenery_root: Node3D
var ground: MeshInstance3D
var env: Environment
var sun_light: DirectionalLight3D

var drag: Variant = null                  # {uid, start, on}
var pan: Variant = null
# toque: dedos ativos e gesto de dois dedos (pinça/giro/inclinação)
var touches: Dictionary = {}
var multi: bool = false
var gest: Variant = null
var hover: Variant = null
var picking_enabled: bool = true
var hidden_uids: Dictionary = {}      # peças ainda não mostradas (cena de entrada)
var outline_mat: StandardMaterial3D
var model_cache: Dictionary = {}   # nome -> PackedScene (ou null se não existir)


func _ready() -> void:
	outline_mat = StandardMaterial3D.new()
	outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_mat.albedo_color = Color("#16110c")
	outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	outline_mat.grow = true
	outline_mat.grow_amount = 0.025
	# sombreado de quadrinho leve (retícula na sombra), sem filtro de tela
	tile_mat = _hq_mat()
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
	sun_light = sun
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
	claw = null
	claw_fingers = []
	for cn in cart_nodes:
		if is_instance_valid(cn):
			cn.queue_free()
	cart_nodes = []
	banana_nodes.clear()
	core_node = null
	core_next_node = null
	core_at = null
	core_next_at = null
	var desert = g.map_id == "tarhut"
	# planetoide do tamanho do tabuleiro
	var far = 0.0
	for h in DB.hexes:
		far = max(far, world_xz(h).length())
	PLAT = far + 2.0
	RIM = PLAT * 0.68
	UNDER = PLAT * 1.85
	var cave = DB.maps[g.map_id].get("cave", false)
	if cave:
		_setup_cave_env()
	else:
		_setup_sky()
		ground.mesh = _planet_mesh(desert)
		ground.position = Vector3.ZERO
		ground.material_override = _hq_mat()
		sun_light.light_energy = 0.55
		sun_light.light_color = Color.WHITE
		env.ambient_light_color = Color(0.85, 0.88, 0.95)
		env.ambient_light_energy = 0.32
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
	if cave:
		_build_cave()
	else:
		_build_scenery(desert)
		_build_far(desert)
	built_ver = -1
	refresh_terrain()
	_build_rails()
	fit_camera(true)


# ================= céu de galáxias e planeta =================
func _setup_sky() -> void:
	# mesmo céu do menu: espaço escuro com nebulosas e galáxias distantes
	var path = "res://sky/espaco.jpg"
	if not ResourceLoader.exists(path):
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("#070b18")
		return
	if sky_cache == null:
		var sm = PanoramaSkyMaterial.new()
		sm.panorama = load(path)
		sky_cache = Sky.new()
		sky_cache.sky_material = sm
	env.sky = sky_cache
	env.background_mode = Environment.BG_SKY
	env.sky_rotation = Vector3(0, 0.6, 0)
	_build_backdrop()


var sky_cache: Sky = null
var backdrop: Node3D = null


# ao fundo: o sol da galáxia (na direção da luz) e os outros planetas, bem longe
func _build_backdrop() -> void:
	if backdrop != null:
		backdrop.queue_free()
	backdrop = Node3D.new()
	add_child(backdrop)
	cam.far = 3000.0
	var sun_dir = -sun_light.global_transform.basis.z
	var to_sun = -sun_dir
	var glow_tex = load("res://planets/estrela.png") if ResourceLoader.exists("res://planets/estrela.png") else null
	for gl in [[420.0, Color(1.0, 0.72, 0.35, 0.9)], [170.0, Color(1.0, 0.96, 0.85, 1.0)]]:
		var q = MeshInstance3D.new()
		var qm = QuadMesh.new()
		qm.size = Vector2(gl[0], gl[0])
		q.mesh = qm
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_texture = glow_tex
		m.albedo_color = gl[1]
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = to_sun * 1800.0
		backdrop.add_child(q)
	# planetas vizinhos (os mesmos do menu)
	var other = "valak" if (g != null and g.map_id == "tarhut") else "tarhut"
	var list = [[other, 70.0, 0.9, 0.18], ["gigante", 160.0, 2.4, 0.12], ["gelo", 40.0, -1.9, 0.3], ["lava", 55.0, 3.6, 0.05]]
	for pl in list:
		var tpath = "res://planets/%s.png" % pl[0]
		if not ResourceLoader.exists(tpath):
			continue
		var mi = MeshInstance3D.new()
		var sp = SphereMesh.new()
		sp.radius = pl[1]
		sp.height = pl[1] * 2.0
		sp.radial_segments = 48
		sp.rings = 24
		mi.mesh = sp
		var pm = StandardMaterial3D.new()
		pm.albedo_texture = load(tpath)
		pm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		pm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mi.material_override = pm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang = pl[2]
		var dir = Vector3(cos(ang), pl[3], sin(ang)).normalized()
		mi.position = dir * 1500.0
		mi.rotation = Vector3(0.3, ang, 0.2)
		backdrop.add_child(mi)
		if pl[0] == "gigante":
			var ring = MeshInstance3D.new()
			var tm = TorusMesh.new()
			tm.inner_radius = pl[1] * 1.5
			tm.outer_radius = pl[1] * 2.1
			tm.rings = 64
			tm.ring_segments = 3
			ring.mesh = tm
			ring.scale = Vector3(1, 0.04, 1)
			var rm = StandardMaterial3D.new()
			rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rm.albedo_color = Color(0.85, 0.75, 1.0, 0.45)
			rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ring.material_override = rm
			ring.position = mi.position
			ring.rotation = Vector3(0.35, 0, 0.25)
			backdrop.add_child(ring)


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
		var c = Color("#d8893e").lerp(Color("#f4b45e"), crest)
		return c.lerp(Color("#9a6440"), clamp(d / RIM, 0.0, 0.45))
	return Color("#1d86c8").lerp(Color("#0e3a78"), clamp(d / RIM, 0.0, 1.0))


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
		if not desert:
			# ilhas de Valak: o cenário fica em cima de uma ilhota
			var isl0 = _mesh(holder, _cyl(1.2 * s * 0.6, 1.6 * s * 0.6, 0.6, 9), Color("#e8d29a"), Vector3(0, 0.15, 0))
			isl0.material_overlay = outline_mat
			_mesh(holder, _cyl(0.9 * s * 0.6, 1.2 * s * 0.6, 0.4, 9), Color("#7fb54a"), Vector3(0, 0.45, 0))
			if _prop(holder, desert, h, Vector3(0, 0.6, 0), s * 0.55, 9):
				continue
		elif _prop(holder, desert, h, Vector3.ZERO, s * 0.7, 9):
			continue
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
	if DB.maps[g.map_id].get("cave", false):
		if t["k"] == "fosso":
			return "pit"
		return "cave" if (h.x * 3 + h.y * 7) % 5 != 0 else "cave2"
	var desert = g.map_id == "tarhut"
	match t["k"]:
		"duna":
			return "dune"
		"rocha", "ruina", "galpao", "ossada", "ossada_c":
			# o modelo em cima já mostra o que é: o chão continua o mesmo do terreno
			return "sand2" if desert else "grass3"
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
			return "rubble" if desert else "rubble_g"
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
		active_tiles[h] = true
		tile["sig"] = sig
		if first:
			tile["disp_h"] = float(t["h"])
		if tile["body"] != null:
			tile["body"].queue_free()
		if tile["props"] != null:
			tile["props"].queue_free()
		var pal = PAL[pal_of(t, h)]
		var ec = Color(ELEV.get(g.map_id, "#c0583a"))
		var lv = clamp(float(t["h"]) * 0.16, 0.0, 0.8)
		# variação suave por casa: o chão parece natural, não um quadriculado
		var jit = (_rnd(h, 7) - 0.5) * 0.08
		var c0 = Color(pal[0]).lerp(ec, lv).lightened(lv * 0.25)
		c0 = c0.lightened(jit) if jit > 0 else c0.darkened(-jit)
		var c1 = c0.lerp(Color(pal[1]).lerp(ec, lv), 0.35)
		var cs = c0.lerp(Color(pal[2]).lerp(ec.darkened(0.3), lv), 0.45)
		var body = MeshInstance3D.new()
		body.mesh = _tile_mesh(c0, c1, cs)
		body.material_override = tile_mat
		tile["node"].add_child(body)
		tile["body"] = body
		if t["k"] == "fosso":
			body.visible = false
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
	var rim = c1.darkened(0.06)
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
		var bot_c = cs.darkened(0.2)
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


func _hq_mat() -> Material:
	if ResourceLoader.exists("res://shaders/hq_toon.gdshader"):
		var m = ShaderMaterial.new()
		m.shader = load("res://shaders/hq_toon.gdshader")
		return m
	var f = StandardMaterial3D.new()
	f.vertex_color_use_as_albedo = true
	f.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	f.cull_mode = BaseMaterial3D.CULL_DISABLED
	return f


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


var crack_mats: Array = []


func _crack_mat(i: int) -> Material:
	if crack_mats.is_empty():
		for k in range(3):
			var path = "res://ui/terreno/rachadura_%d.png" % k
			if not ResourceLoader.exists(path):
				crack_mats.append(null)
				continue
			var m = StandardMaterial3D.new()
			m.albedo_texture = load(path)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.4
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			crack_mats.append(m)
	return crack_mats[i]


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
	if DB.maps[g.map_id].get("cave", false):
		return   # caverna: chão de pedra limpo (os cristais são peças)
	if _cen_tile(root, h, t["k"]):
		pass
	else:
		_add_props_old(root, h, t)
	_add_marks(root, h)


# peças das casas feitas pela ferramenta de cenário (tools/cenario.py), cada mapa com as suas
func _cen_tile(root: Node3D, h: Vector2i, k: String) -> bool:
	var desert = g.map_id == "tarhut"
	var v = int(_rnd(h, 21) * 3) % 3
	var yaw = _rnd(h, 2) * TAU
	if desert:
		match k:
			"rocha":
				# mesas de arenito e pilhas de rocha se alternam, para a crista não ficar repetida
				if (h.x * 3 + h.y * 5 + 99) % 2 == 0:
					return _model(root, "tarhut_arenito_%d" % v, Vector3.ZERO, 1.6, yaw, true)
				return _model(root, "cen_tarhut_rocha_%d" % v, Vector3.ZERO, 1.45, yaw, true)
			"ossada", "ossada_c":
				# o esqueleto do centro é uma peça só, gigante, sobre as casas do meio
				if DB.dist(h, Vector2i.ZERO) <= 1:
					if h == Vector2i.ZERO:
						return _model(root, "cen_tarhut_ossada_0", Vector3(0, 0, 0), 5.2, 0.5, true)
					return true
				return _model(root, "cen_tarhut_ossada_%d" % v, Vector3.ZERO, 1.7, yaw, true)
			"buraco":
				return _model(root, "cen_tarhut_buraco_%d" % v, Vector3(0, -0.05, 0), 1.55, yaw, true)
		return false
	match k:
		"rocha":
			return _model(root, "cen_valak_rocha_%d" % v, Vector3.ZERO, 1.45, yaw, true)
		"floresta":
			var ok = false
			for sp in [Vector3(-0.32, 0, -0.2), Vector3(0.32, 0, -0.25), Vector3(0.02, 0, 0.28)]:
				ok = _model(root, "cen_valak_pinheiro_%d" % int(_rnd(h, int(sp.x * 10) + 30) * 3), sp, 0.72 + _rnd(h, int(sp.z * 10) + 5) * 0.15, _rnd(h, 7) * TAU, true) or ok
			return ok
		"galpao":
			return _model(root, "cen_valak_domo_%d" % v, Vector3.ZERO, 1.65, yaw, true)
		"ruina":
			var a = _model(root, "cen_valak_caixa_%d" % v, Vector3(-0.15, 0, 0.1), 0.85, yaw, true)
			_model(root, "cen_valak_barril_%d" % v, Vector3(0.38, 0, -0.25), 0.5, yaw, true)
			return a
		"escombros":
			_model(root, "cen_valak_barril_%d" % v, Vector3(-0.3, 0, 0.0), 0.45, yaw, true)
			return _model(root, "cen_valak_vagonete_%d" % v, Vector3(0.2, 0, 0.2), 0.9, yaw, true)
	return false


func _add_props_old(root: Node3D, h: Vector2i, t: Dictionary) -> void:
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
			# rachadura pintada no estilo HQ do jogo (tools/rachadura.py): 3 variações, giradas em passos de 60°
			var cm = _crack_mat(int(_rnd(h, 21) * 3) % 3)
			if cm != null:
				var qd = MeshInstance3D.new()
				var pm2 = PlaneMesh.new()
				pm2.size = Vector2(1.96, 1.96)
				qd.mesh = pm2
				qd.material_override = cm
				qd.position = Vector3(0, 0.025, 0)
				qd.rotation = Vector3(0, int(_rnd(h, 22) * 6) * PI / 3.0, 0)
				qd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(qd)
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


func _add_marks(root: Node3D, h: Vector2i) -> void:
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
		var rn = Node3D.new()
		root.add_child(rn)
		res_nodes[h] = rn
		root = rn
		var rt = g.res[h]
		var rc = Color("#b07a3a")
		if rt == "agua":
			rc = Color("#5ec8f0")
		elif rt == "sucata":
			rc = Color("#c9c2b4")
		elif rt == "escaravelho":
			rc = Color("#2fd04f")
		if rt == "escaravelho":
			_build_beetle(root)
		else:
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
		if rt == "escaravelho":
			rl.visible = false
			rl.position = Vector3(0.0, 2.5, 0.0)
			rl.font_size = 60
			rl.modulate = Color("#8dff9f")
		root.add_child(rl)


# escaravelho verde: modelo 3D com brilho (emissão na própria textura + halo aditivo que pulsa)
var halo_tex: GradientTexture2D = null


func _build_beetle(root: Node3D) -> void:
	var holder = Node3D.new()
	holder.position = Vector3(0, 0.34, 0)
	root.add_child(holder)
	var ps = load("res://models/escaravelho.glb")
	if ps is PackedScene:
		var inst = ps.instantiate()
		holder.add_child(inst)
		inst.rotation_degrees = Vector3(-90, 0, 0)
		inst.scale = Vector3.ONE * 0.95
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var mat = mi.get_active_material(0)
			if mat is StandardMaterial3D:
				mat = mat.duplicate()
				mat.emission_enabled = true
				mat.emission_texture = mat.albedo_texture
				mat.emission_energy_multiplier = 0.8
				mi.material_override = mat
	if halo_tex == null:
		halo_tex = GradientTexture2D.new()
		var gr = Gradient.new()
		gr.set_color(0, Color(0.35, 1.0, 0.5, 0.75))
		gr.set_color(1, Color(0.1, 0.9, 0.35, 0.0))
		gr.set_offset(0, 0.0)
		halo_tex.gradient = gr
		halo_tex.fill = GradientTexture2D.FILL_RADIAL
		halo_tex.fill_from = Vector2(0.5, 0.5)
		halo_tex.fill_to = Vector2(1.0, 0.5)
		halo_tex.width = 128
		halo_tex.height = 128
	var halo = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(2.2, 2.2)
	halo.mesh = q
	var hm = StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_texture = halo_tex
	hm.no_depth_test = true
	hm.render_priority = -1
	halo.material_override = hm
	halo.position = Vector3(0, 0.1, 0)
	holder.add_child(halo)
	# pulsa o brilho e balança o besouro
	var tw = halo.create_tween().set_loops()
	tw.tween_property(halo, "scale", Vector3(1.25, 1.25, 1.25), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(halo, "scale", Vector3(0.85, 0.85, 0.85), 0.9).set_trans(Tween.TRANS_SINE)
	var tw2 = holder.create_tween().set_loops()
	tw2.tween_property(holder, "rotation_degrees:y", 14.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(holder, "rotation_degrees:y", -14.0, 1.6).set_trans(Tween.TRANS_SINE)


# ---------- modelos 3D da Meshy (res://models/<nome>.glb) ----------
# cenário gerado por tools/propgen.py (models/<planeta>_<peça>_<n>.glb)
const PROPS = {
	# [modelo (sem _n), peso, diâmetro, pode ficar colado no tabuleiro]
	"tarhut": [["cen_tarhut_rocha", 3.0, 1.6, true], ["cen_tarhut_cacto_bola", 1.6, 0.9, true], ["cen_tarhut_cacto", 1.6, 1.0, true],
		["cen_tarhut_ossada", 1.4, 2.0, true], ["cen_tarhut_cristal", 1.2, 1.0, true], ["tarhut_arenito", 1.5, 1.6, false], ["tarhut_destroco", 0.8, 2.0, false]],
	"valak": [["cen_valak_pinheiro", 3.2, 1.2, true], ["cen_valak_rocha", 2.0, 1.3, true], ["cen_valak_barril", 1.2, 0.55, true], ["cen_valak_caixa", 1.0, 0.8, true],
		["cen_valak_vagonete", 0.6, 1.0, false], ["cen_valak_domo", 0.8, 2.2, false], ["valak_torre", 0.6, 1.6, false], ["valak_guindaste", 0.4, 2.4, false]],
}
var prop_mat: StandardMaterial3D = null
var paint_mat: ShaderMaterial = null
var outline_cache: Dictionary = {}


func _paint_mat() -> ShaderMaterial:
	if paint_mat == null:
		paint_mat = ShaderMaterial.new()
		paint_mat.shader = load("res://shaders/pintado.gdshader")
	return paint_mat


func _outline_thick(grow: float) -> StandardMaterial3D:
	var key = snappedf(grow, 0.005)
	if not outline_cache.has(key):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color("#1a0e08")
		m.cull_mode = BaseMaterial3D.CULL_FRONT
		m.grow = true
		m.grow_amount = key
		outline_cache[key] = m
	return outline_cache[key]


func _prop(parent: Node3D, desert: bool, h: Vector2i, pos: Vector3, size: float, ring: int) -> bool:
	var list = PROPS["tarhut" if desert else "valak"]
	var tot = 0.0
	for e in list:
		if ring >= 2 or e[3]:
			tot += e[1]
	var roll = _rnd(h, 11) * tot
	var pick: Variant = null
	for e in list:
		if ring >= 2 or e[3]:
			roll -= e[1]
			if roll <= 0.0:
				pick = e
				break
	if pick == null:
		return false
	var mname = "%s_%d" % [pick[0], int(_rnd(h, 12) * 3) % 3]
	return _model(parent, mname, pos, pick[2] * size, _rnd(h, 13) * TAU, true)


# modelos novos (com textura própria) que substituem os antigos de ossada e cacto
const MODEL_SWAP = {"cen_tarhut_ossada": "tarhut_fossil", "ossada": "tarhut_fossil", "cen_tarhut_cacto": "tarhut_flor", "cen_tarhut_cacto_bola": "tarhut_flor"}
const TEXTURED = ["tarhut_fossil", "tarhut_flor"]


func _swap_name(mname: String) -> String:
	if MODEL_SWAP.has(mname):
		return MODEL_SWAP[mname]
	var cut = mname.rfind("_")
	if cut > 0 and mname.substr(cut + 1).is_valid_int() and MODEL_SWAP.has(mname.substr(0, cut)):
		return MODEL_SWAP[mname.substr(0, cut)]
	return mname


func _scene_of(mname: String) -> Variant:
	mname = _swap_name(mname)
	if not model_cache.has(mname):
		var path = "res://models/%s.glb" % mname
		model_cache[mname] = load(path) if ResourceLoader.exists(path) else null
	return model_cache[mname]


# coloca o modelo com a base no chão, cabendo num círculo de "footprint" de diâmetro
func _model(parent: Node3D, mname: String, pos: Vector3, footprint: float, yaw: float, toon: bool = false) -> bool:
	var sc = _scene_of(mname)
	if sc == null:
		return false
	var inst: Node3D = sc.instantiate()
	var meshes = inst.find_children("*", "MeshInstance3D", true, false)
	if toon and TEXTURED.has(_swap_name(mname)):
		toon = false
	if toon:
		if prop_mat == null:
			prop_mat = StandardMaterial3D.new()
			prop_mat.vertex_color_use_as_albedo = true
			prop_mat.vertex_color_is_srgb = true
			prop_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			prop_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			prop_mat.roughness = 1.0
			prop_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var pm: Material = prop_mat
		if mname.begins_with("cen_"):
			pm = _paint_mat()
		for mi in meshes:
			mi.material_override = pm
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
	if mname.begins_with("cen_"):
		# contorno grosso de desenho: a espessura acompanha o tamanho final da peça
		var om = _outline_thick(0.035 / max(k, 0.05))
		for mi2 in meshes:
			mi2.material_overlay = om
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


# ---------- entorno do planeta: regiões temáticas em volta do tabuleiro ----------
# cada região tem um tema (ângulo relativo à base do jogador 0, em graus) e o mesmo modelo
# não se repete em casas vizinhas. Os temas se espelham do outro lado (simetria do mapa).
const BIOMES = {
	"valak": [[0, 42, "camp"], [70, 30, "forest"], [122, 22, "rocks"]],
	"tarhut": [[0, 45, "mesa"], [72, 26, "bones"], [124, 24, "crystal"]],
}
# [modelo (sem _n), peso, diâmetro, distância mínima do tabuleiro]
const THEMES = {
	"camp": [["cen_valak_caixa", 2.0, 0.8, 1], ["cen_valak_barril", 2.0, 0.55, 1], ["cen_valak_vagonete", 1.2, 1.0, 1], ["valak_tanque", 0.8, 1.6, 2]],
	"forest": [["cen_valak_pinheiro", 5.0, 1.2, 1], ["cen_valak_rocha", 0.7, 1.1, 1]],
	"rocks": [["cen_valak_rocha", 4.0, 1.4, 1], ["cen_valak_pinheiro", 1.0, 1.1, 1]],
	"sea": [["cen_valak_pinheiro", 1.0, 1.0, 2], ["cen_valak_rocha", 1.0, 1.0, 2]],
	"mesa": [["tarhut_arenito", 3.0, 1.9, 2], ["cen_tarhut_rocha", 1.0, 1.5, 2], ["cen_tarhut_cacto", 0.4, 0.9, 2]],
	"bones": [["cen_tarhut_ossada", 1.0, 1.9, 2], ["tarhut_ossos", 0.8, 1.6, 2], ["cen_tarhut_cacto_bola", 1.0, 0.8, 2]],
	"crystal": [["cen_tarhut_cristal", 3.0, 1.0, 1], ["tarhut_cristal", 1.5, 1.2, 2], ["cen_tarhut_rocha", 0.6, 1.2, 1]],
	"open": [["cen_tarhut_cacto", 1.0, 0.95, 1], ["cen_tarhut_cacto_bola", 1.0, 0.85, 1]],
}
const DENSITY = {"camp": 0.5, "forest": 0.85, "rocks": 0.55, "sea": 0.1, "mesa": 0.2, "bones": 0.1, "crystal": 0.16, "open": 0.05}
# peças únicas de cada região (uma só, em lugar de destaque)
const LANDMARKS = {
	"camp": [["cen_valak_domo", 2.4, 2, -12.0], ["valak_guindaste", 2.4, 3, 14.0], ["valak_torre", 1.7, 2, 26.0]],
	"bones": [["tarhut_destroco", 2.6, 3, 0.0]],
}


func _ang_diff(a: float, b: float) -> float:
	return abs(wrapf(a - b, -PI, PI))


func _biome_of(h: Vector2i, desert: bool) -> Array:
	var wp = world_xz(h)
	var ang = atan2(wp.y, wp.x)
	var e0 = world_xz(DB.entry_c[0])
	var a0 = atan2(e0.y, e0.x)
	for side in [0.0, PI]:
		for bdef in BIOMES["tarhut" if desert else "valak"]:
			var c = a0 + side + deg_to_rad(float(bdef[0]))
			var d = _ang_diff(ang, c)
			if d <= deg_to_rad(float(bdef[1])):
				return [bdef[2], c, d]
	return ["open" if desert else "sea", 0.0, 1.0]


func _ground_at(p: Vector3, desert: bool, foot: float) -> Vector3:
	if desert:
		return p
	# Valak é cercado de água: cada peça fica numa ilhota de areia e grama
	var r = max(0.7, foot * 0.62)
	var isl = _mesh(scenery_root, _cyl(r, r * 1.22, 0.35, 9), Color("#e8d29a"), p + Vector3(0, 0.05, 0))
	isl.material_overlay = outline_mat
	_mesh(scenery_root, _cyl(r * 0.8, r, 0.2, 9), Color("#7fb54a"), p + Vector3(0, 0.3, 0))
	return p + Vector3(0, 0.4, 0)


func _build_scenery(desert: bool) -> void:
	var placed = {}
	var used_marks = {}
	var cells = []
	for q in range(-DB.R - 4, DB.R + 5):
		for r in range(-DB.R - 4, DB.R + 5):
			var h = Vector2i(q, r)
			var d = DB.out_dist(h)
			if d >= 1 and d <= 4:
				cells.append(h)
	# marcos primeiro: um por região, na distância e ângulo definidos
	for side in [0.0, PI]:
		for bdef in BIOMES["tarhut" if desert else "valak"]:
			var theme = bdef[2]
			if not LANDMARKS.has(theme):
				continue
			for lm in LANDMARKS[theme]:
				var e0 = world_xz(DB.entry_c[0])
				var want = atan2(e0.y, e0.x) + side + deg_to_rad(float(bdef[0]) + float(lm[3]))
				var best: Variant = null
				var bd = 1e9
				for h in cells:
					if DB.out_dist(h) != int(lm[2]) or placed.has(h):
						continue
					var wp = world_xz(h)
					var dd = _ang_diff(atan2(wp.y, wp.x), want)
					if dd < bd:
						bd = dd
						best = h
				if best == null:
					continue
				var wpb = world_xz(best)
				var pb = Vector3(wpb.x, planet_y(wpb.x, wpb.y), wpb.y)
				pb = _ground_at(pb, desert, float(lm[1]))
				var toward = atan2(-wpb.x, -wpb.y)
				if _model(scenery_root, "%s_%d" % [lm[0], int(side > 0)], pb, float(lm[1]), toward + _rnd(best, 3) * 0.6 - 0.3, true):
					placed[best] = lm[0]
					for n in DB.DIRS:
						placed[best + n] = "_livre"
	# o resto: cada casa segue o tema da sua região, sem repetir o vizinho
	for h in cells:
		if placed.has(h):
			continue
		var d = DB.out_dist(h)
		var bio = _biome_of(h, desert)
		var theme = bio[0]
		var dens = DENSITY[theme]
		# as bordas da região ficam mais ralas: transição natural para a próxima
		dens *= clamp(1.25 - float(bio[2]) * 1.4, 0.35, 1.0) if theme != "sea" and theme != "open" else 1.0
		if d == 1:
			dens *= 0.55
		if _rnd(h, 9) > dens:
			continue
		var near = []
		for n in DB.DIRS:
			if placed.has(h + n):
				near.append(placed[h + n])
		var opts = THEMES[theme].filter(func(e): return d >= int(e[3]) and not near.has(e[0]))
		if opts.is_empty():
			continue
		var tot = 0.0
		for e in opts:
			tot += float(e[1])
		var roll = _rnd(h, 11) * tot
		var pick = opts[0]
		for e in opts:
			roll -= float(e[1])
			if roll <= 0.0:
				pick = e
				break
		var wp = world_xz(h)
		var px = wp.x + (_rnd(h, 5) - 0.5) * 0.7
		var pz = wp.y + (_rnd(h, 6) - 0.5) * 0.7
		var sz = float(pick[2]) * (0.85 + _rnd(h, 8) * 0.35) * (0.85 if d == 1 else 1.0)
		var p = Vector3(px, planet_y(px, pz), pz)
		p = _ground_at(p, desert, sz)
		if _model(scenery_root, "%s_%d" % [pick[0], int(_rnd(h, 12) * 3) % 3], p, sz, _rnd(h, 13) * TAU, true):
			placed[h] = pick[0]


# trilhos da mina (Valak): ligam as bases ao poço central
func _build_rails() -> void:
	var rails = DB.maps[g.map_id].get("rails", [])
	var set = {}
	for e in rails:
		set[Vector2i(int(e[0]), int(e[1]))] = true
		set[Vector2i(-int(e[0]), -int(e[1]))] = true
	for tr in g.tracks:
		for th in tr:
			set[th] = true
	if set.is_empty():
		return
	var wood = Color("#6e4a2a")
	var steel = Color("#9aa2ae")
	for h in set.keys():
		var c = world_xz(h)
		var y = top_y(h) + 0.03
		for n in DB.DIRS:
			if not set.has(h + n):
				continue
			var o = world_xz(h + n)
			var mid = (c + o) * 0.5
			var dirv = (mid - c)
			var ang = atan2(dirv.x, dirv.y)
			var seg = Node3D.new()
			seg.position = Vector3(c.x, y, c.y)
			seg.rotation = Vector3(0, ang, 0)
			scenery_root.add_child(seg)
			var L = dirv.length()
			for k in range(3):
				var sl = _mesh(seg, _box(Vector3(0.62, 0.05, 0.12)), wood, Vector3(0, 0, L * (k + 0.5) / 3.0))
				sl.material_overlay = outline_mat
			for sx in [-0.2, 0.2]:
				_mesh(seg, _box(Vector3(0.05, 0.06, L + 0.02)), steel, Vector3(sx, 0.04, L * 0.5))


# bananas do Karo: cada uma com a cor do bônus (verde cura, vermelho força, azul mira)
var banana_nodes: Dictionary = {}
var hover_seen: Variant = null
var core_node: Node3D = null
var core_next_node: Node3D = null
var core_at: Variant = null
var core_next_at: Variant = null


# núcleo de energia: orbe brilhante girando; o próximo aparece como um anel fantasma
func sync_core(c: Variant, nxt: Variant) -> void:
	if c != core_at:
		if core_node != null:
			core_node.queue_free()
			core_node = null
		core_at = c
		if c != null and tiles.has(c):
			core_node = Node3D.new()
			core_node.position = Vector3(world_xz(c).x, top_y(c), world_xz(c).y)
			scenery_root.add_child(core_node)
			var orb = MeshInstance3D.new()
			var sm = SphereMesh.new()
			sm.radius = 0.24
			sm.height = 0.48
			orb.mesh = sm
			var om = StandardMaterial3D.new()
			om.albedo_color = Color("#bff8ff")
			om.emission_enabled = true
			om.emission = Color("#3fd8ff")
			om.emission_energy_multiplier = 2.2
			orb.material_override = om
			orb.position = Vector3(0, 0.75, 0)
			orb.name = "orb"
			core_node.add_child(orb)
			for i in range(3):
				var ring = _mesh(core_node, _cyl(0.5 - i * 0.12, 0.5 - i * 0.12, 0.05, 6), Color("#7ff0ff"), Vector3(0, 0.08 + i * 0.05, 0))
				ring.material_override = _mat(Color("#7ff0ff", 0.55 - i * 0.12), true)
				ring.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var lt = OmniLight3D.new()
			lt.light_color = Color("#7ff0ff")
			lt.light_energy = 1.6
			lt.omni_range = 3.0
			lt.position = Vector3(0, 0.8, 0)
			core_node.add_child(lt)
	if nxt != core_next_at:
		if core_next_node != null:
			core_next_node.queue_free()
			core_next_node = null
		core_next_at = nxt
		if nxt != null and tiles.has(nxt):
			core_next_node = Node3D.new()
			core_next_node.position = Vector3(world_xz(nxt).x, top_y(nxt) + 0.04, world_xz(nxt).y)
			scenery_root.add_child(core_next_node)
			var gr = _mesh(core_next_node, _disc(0.62, 6), Color("#7ff0ff"), Vector3.ZERO)
			gr.material_override = _mat(Color("#7ff0ff", 0.22), true)
			gr.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func sync_bananas(b: Dictionary, viewer: int) -> void:
	for h in banana_nodes.keys():
		if not b.has(h):
			banana_nodes[h].queue_free()
			banana_nodes.erase(h)
	for h in b.keys():
		if banana_nodes.has(h) or not tiles.has(h):
			continue
		var col = {"cura": Color("#5bd46a"), "dano": Color("#ff6a4a"), "alcance": Color("#5ec8f0")}.get(b[h]["t"], Color.WHITE)
		var n = Node3D.new()
		n.position = Vector3(world_xz(h).x, top_y(h) + 0.05, world_xz(h).y)
		scenery_root.add_child(n)
		var ring = _mesh(n, _disc(0.42, 16), col, Vector3(0, 0.02, 0))
		ring.material_override = _mat(Color(col, 0.55), true)
		ring.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# banana: dois gomos curvos amarelos
		for i in range(3):
			var a = -0.5 + i * 0.5
			var seg = _mesh(n, CapsuleMesh.new(), Color("#ffd23a"), Vector3(sin(a) * 0.16, 0.22 + cos(a) * 0.05, 0), Vector3(0, 0, PI / 2 + a))
			seg.scale = Vector3(0.11, 0.14, 0.11)
			seg.material_overlay = outline_mat
		var tip = _mesh(n, _cyl(0.02, 0.03, 0.08, 6), Color("#5a3a18"), Vector3(-0.26, 0.28, 0))
		tip.rotation = Vector3(0, 0, 0.9)
		var lab = Label3D.new()
		lab.text = {"cura": "CURA", "dano": "FORÇA", "alcance": "MIRA"}.get(b[h]["t"], "")
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.font_size = 34
		lab.outline_size = 10
		lab.pixel_size = 0.006
		lab.modulate = col.lightened(0.3)
		lab.position = Vector3(0, 0.62, 0)
		n.add_child(lab)
		banana_nodes[h] = n


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
	ring.material_override = _mat(Color("#3d8bff") if u.owner == me else Color("#ff7a2f"), true)
	ring.position = Vector3(0, 0.04, 0)
	ring.scale = Vector3(1, 0.4, 1)
	node.add_child(ring)
	var sprite: Variant = null
	var body_h = 1.75 * sc
	if u.crystal != "":
		shadow.visible = false
		ring.visible = false
		_crystal_cluster(node, u.crystal, u.uid)
		body_h = 1.6
	elif u.barrier:
		_mesh(node, _cyl(0.4, 0.5, 0.7, 6), Color("#6d6250"), Vector3(0, 0.35, 0))
		body_h = 0.8
	elif DB.art.has(u.cid):
		sprite = _figure(u.cid, body_h)
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
	heart.modulate = Color("#3d8bff") if u.owner == me else Color("#ff7a2f")
	heart.position = Vector3(0, body_h + 0.25, 0)
	heart.visible = false   # a vida agora é a placa 2D da HUD (main.gd)
	node.add_child(heart)
	var hp = Label3D.new()
	hp.font_size = 56
	hp.outline_size = 14
	hp.pixel_size = 0.0065
	hp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp.no_depth_test = true
	hp.render_priority = 6
	hp.position = Vector3(0, body_h + 0.27, 0)
	hp.visible = false
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
	flags.visible = false
	node.add_child(flags)
	var wp = world_xz(u.pos())
	var start = Vector3(wp.x, top_y(u.pos()), wp.y)
	node.position = start
	node.scale = Vector3(0.01, 0.01, 0.01)
	unit_nodes[u.uid] = {"node": node, "sprite": sprite, "hp": hp, "heart": heart, "tag": tag, "flags": flags, "ring": ring,
		"top": body_h, "hex": u.pos(), "path": [], "seg_t": 0.0, "from": start, "pop": 0.0, "flip": u.owner == 1, "bob": randf() * TAU, "hurt": 0.0, "lunge": 0.0}


# personagem: a arte num cartão que encara a câmera, com as cores originais e sombra no chão
func _figure(cid: String, body_h: float) -> MeshInstance3D:
	var tex: Texture2D = DB.art[cid]
	var mi = MeshInstance3D.new()
	var q = QuadMesh.new()
	var asp = float(tex.get_width()) / float(tex.get_height())
	q.size = Vector2(body_h * asp, body_h)
	q.center_offset = Vector3(0, body_h * 0.5, 0)
	mi.mesh = q
	var m = StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# a arte aparece com as cores originais: sem luz, relevo, brilho ou bordas extras
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


func _figure_look(fig: MeshInstance3D, flip: bool, mod: Color) -> void:
	var m: StandardMaterial3D = fig.material_override
	var sx = -1.0 if flip else 1.0
	if m.uv1_scale.x != sx:
		m.uv1_scale = Vector3(sx, 1, 1)
		m.uv1_offset = Vector3(1.0 if flip else 0.0, 0, 0)
	m.albedo_color = mod


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
	if core_node != null and is_instance_valid(core_node):
		var orb = core_node.get_node_or_null("orb")
		if orb != null:
			orb.position.y = 0.75 + sin(Time.get_ticks_msec() / 300.0) * 0.08
			orb.rotation.y += delta * 2.0
	if g != null:
		_update_claw(delta)
	if not cz_nodes.is_empty():
		var pulse = 0.35 + 0.15 * sin(Time.get_ticks_msec() / 350.0)
		for nd in cz_nodes.values():
			if is_instance_valid(nd) and nd.has_meta("disk"):
				nd.get_meta("disk").albedo_color.a = pulse
	if g == null:
		return
	_update_camera(delta)
	# casas de entrada piscando quando dá para colocar reserva
	for dh in state.get("hl", {}).keys():
		if state["hl"][dh] == "deploy" and tiles.has(dh):
			_apply_overlay(dh)
	# relevo animado (dunas sobem e descem): confere todas as casas só de vez em quando
	scan_n += 1
	var cand = tiles.keys() if scan_n % 20 == 0 else active_tiles.keys()
	for h in cand:
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
		if tile["flash"] <= 0.0 and tile["disp_h"] == tgt:
			active_tiles.erase(h)
		else:
			active_tiles[h] = true
	_update_units(delta)


func _update_units(delta: float) -> void:
	var t_now = Time.get_ticks_msec() / 1000.0
	for u in g.units:
		if u.st != "field" or not unit_nodes.has(u.uid):
			continue
		var d = unit_nodes[u.uid]
		var node: Node3D = d["node"]
		# escondido até a cena de entrada mostrar a chegada
		if hidden_uids.has(u.uid):
			node.visible = false
			d["pop"] = 0.0
			node.scale = Vector3.ONE * 0.01
			continue
		node.visible = true
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
		d["heart"].modulate = (Color("#ff2a2a") if u.hp <= u.maxhp / 3 else (Color("#3d8bff") if u.owner == me else Color("#ff7a2f")))
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
			var base_mod = Color(0.55, 0.55, 0.55) if (u.activated and not u.barrier) else Color(1, 1, 1)
			if d["hurt"] > 0.0:
				d["hurt"] = max(0.0, d["hurt"] - delta * 2.5)
				base_mod = base_mod.lerp(Color(1, 0.3, 0.2), d["hurt"])
			_figure_look(sprite, d["flip"], base_mod)
			var bob = d["bob"] + t_now * 2.4
			var sy = 1.0 + 0.025 * sin(bob)
			var pos = Vector3.ZERO
			if walking:
				pos.y += abs(sin(t_now * 15.0)) * 0.08
			if selected:
				pos.y += 0.08 + 0.06 * sin(t_now * 6.0)
			sprite.position = pos
			if d["lunge"] > 0.0:
				d["lunge"] = max(0.0, d["lunge"] - delta * 3.0)
				sy *= 1.0 + 0.15 * sin(d["lunge"] * PI)
			sprite.scale = Vector3(1.0, sy, 1.0)
		d["ring"].material_override.albedo_color = Color("#ffffff") if selected else (Color("#3d8bff") if u.owner == me else Color("#ff7a2f"))
		# etiqueta de dano previsto / motivo
		var tg = state.get("tags", {}).get(u.uid, null)
		if tg != null:
			d["tag"].visible = true
			d["tag"].text = tg["text"]
			d["tag"].modulate = tg["color"]
		else:
			d["tag"].visible = false


# ================= destaques =================
# ---- Zona de Cristal: aglomerado de cristais brilhantes no chão da casa ----
func _build_czone(h: Vector2i) -> Node3D:
	var root = Node3D.new()
	var xz = world_xz(h)
	root.position = Vector3(xz.x, top_y(h), xz.y)
	var disk = MeshInstance3D.new()
	disk.mesh = _cyl(0.78, 0.78, 0.02, 6)
	var dm = StandardMaterial3D.new()
	dm.albedo_color = Color(0.1, 0.55, 1.0, 0.30)
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disk.material_override = dm
	disk.position = Vector3(0, 0.04, 0)
	root.add_child(disk)
	root.set_meta("disk", dm)
	for i in range(5):
		var a = _rnd(h, i + 40) * TAU
		var rr = 0.12 + _rnd(h, i + 50) * 0.42
		var hh = 0.32 + _rnd(h, i + 60) * 0.42
		var sh = MeshInstance3D.new()
		sh.mesh = _cyl(0.0, 0.11 + _rnd(h, i + 70) * 0.06, hh, 5)
		var purple = _rnd(h, i + 80) > 0.6
		var m = StandardMaterial3D.new()
		m.albedo_color = Color("#1fb8e8") if not purple else Color("#8a4cf0")
		m.emission_enabled = true
		m.emission = Color("#0a7fc0") if not purple else Color("#5a22c8")
		m.emission_energy_multiplier = 0.9
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.roughness = 0.2
		sh.material_override = m
		# contorno escuro (casca invertida) para destacar em qualquer chão
		var ol = StandardMaterial3D.new()
		ol.albedo_color = Color("#0b1030")
		ol.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ol.cull_mode = BaseMaterial3D.CULL_FRONT
		ol.grow = true
		ol.grow_amount = 0.025
		m.next_pass = ol
		# brilho interno mais claro na ponta
		var tip = MeshInstance3D.new()
		tip.mesh = _cyl(0.0, 0.05, hh * 0.45, 5)
		var tm = StandardMaterial3D.new()
		tm.albedo_color = Color("#d8f8ff")
		tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tip.material_override = tm
		tip.position = Vector3(0, hh * 0.2, 0.03)
		sh.add_child(tip)
		sh.position = Vector3(cos(a) * rr, hh * 0.5, sin(a) * rr)
		sh.rotation = Vector3((_rnd(h, i + 90) - 0.5) * 0.35, a, (_rnd(h, i + 100) - 0.5) * 0.35)
		root.add_child(sh)
	root.scale = Vector3(0.01, 0.01, 0.01)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root


func _sync_czones() -> void:
	var want: Dictionary = {}
	for z in g.czones:
		if int(z["until"]) >= g.round_no:
			want[z["h"]] = true
	for u in g.units:
		if u.st == "field" and not u.barrier and g.K(u).has("zoneAura") and not g.silenced(u):
			for n in DB.nbrs(u.pos()):
				if DB.in_board(n):
					want[n] = true
	for h in cz_nodes.keys():
		var nd = cz_nodes[h]
		if not want.has(h) or not is_instance_valid(nd):
			if is_instance_valid(nd):
				var tw = nd.create_tween()
				tw.tween_property(nd, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
				tw.tween_callback(nd.queue_free)
			cz_nodes.erase(h)
	for h in want.keys():
		if not cz_nodes.has(h) and tiles.has(h):
			var nd2 = _build_czone(h)
			add_child(nd2)
			cz_nodes[h] = nd2


func set_state(s: Dictionary) -> void:
	state = s
	refresh_terrain()
	sync_units()
	_sync_czones()
	for rh in res_nodes.keys():
		var rnode = res_nodes[rh]
		if not is_instance_valid(rnode):
			res_nodes.erase(rh)
		elif not g.res.has(rh):
			rnode.queue_free()
			res_nodes.erase(rh)
	# só repinta a casa cujo destaque, etiqueta ou escurecimento mudou (os que pulsam continuam no _process)
	var hls: Dictionary = s.get("hl", {})
	var labs: Dictionary = s.get("labels", {})
	var labc: Dictionary = s.get("label_colors", {})
	var lit = s.get("lit", null)
	for h in tiles.keys():
		var tile = tiles[h]
		var k = "%s|%s|%s|%s" % [hls.get(h, ""), labs.get(h, ""), str(labc.get(h, "")), "-" if lit == null else ("1" if lit.has(h) else "0")]
		if tile.get("ovk", "") == k and tile["flash"] <= 0.0:
			continue
		tile["ovk"] = k
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
			col = Color(0.02, 0.0, 0.05, 0.82)
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
		"danger":
			col = Color(1.0, 0.12, 0.25, 0.35 + 0.25 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)))
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
func float_text(h: Vector2i, text: String, col: Color, scale: float = 1.0) -> void:
	var l = Label3D.new()
	l.text = text
	l.font_size = 96
	l.outline_size = 24
	l.pixel_size = 0.007 * scale
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


# Verme Gigante: sai de cada buraco (um depois do outro), ruge lá do alto e mergulha de volta

func worm_emerge(hexes: Array) -> void:
	var sc = _scene_of("verme_gigante")
	if sc == null:
		return
	var i = 0
	for h in hexes:
		var wp = world_xz(h)
		var w = Node3D.new()
		w.set_script(load("res://scripts/worm.gd"))
		add_child(w)
		var hp = Vector3(wp.x, top_y(h) - 0.1, wp.y)
		w.setup(sc, hp, Vector3(0, 0, 0) if hp.length() > 2.0 else Vector3(3, 0, 0), outline_mat, i * 0.45)
		w.roared.connect(func(): worm_roar.emit(hp))
		w.bit.connect(func(): worm_bite.emit(hp))
		i += 1


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
	if (me == 1) != flip_view:
		# gira 180°: no online cada um vê o próprio lado à direita
		goal["yaw"] += PI
		goal["target"] = -goal["target"]
	if snap:
		cam_yaw = goal["yaw"]
		cam_pitch = goal["pitch"]
		cam_dist = goal["dist"]
		cam_target = goal["target"]
		cam_goal = null
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
		if mm.button_mask == 0:
			var hh = pick_hex(mm.position)
			if hh != hover_seen:
				hover_seen = hh
				hex_hovered.emit(hh)
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



# ================= Valak: caverna de cristais =================
const CRYSTAL_COL = {"verde": ["#7dff4a", "#2fbf3a"], "azul": ["#5ae8ff", "#2a86e8"], "roxo": ["#ff5ae0", "#a83ae0"]}
var cart_nodes: Array = []
var claw: Node3D = null
var claw_fingers: Array = []
var claw_t: float = 0.0
var claw_hit: float = 0.0
var claw_rest: Vector3 = Vector3.ZERO


func _ink() -> StandardMaterial3D:
	return _outline_thick(0.045)


func _glow_mat(c: Color, e: float = 1.2) -> StandardMaterial3D:
	var m = _mat(c)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


func _setup_cave_env() -> void:
	# sem céu nem espaço: só a escuridão da caverna, luz roxa e brilho dos cristais
	env.sky = null
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0c0518")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a90f0")
	env.ambient_light_energy = 0.55
	sun_light.light_energy = 0.75
	sun_light.light_color = Color("#ffe8d0")
	ground.mesh = _disc(PLAT + 9.0, 48)
	ground.position = Vector3(0, BASE_Y + 0.01, 0)
	ground.material_override = _mat(Color("#2a1650"))


func _crystal_cluster(parent: Node3D, kind: String, seed_v: int) -> void:
	var cc = CRYSTAL_COL.get(kind, ["#ffffff", "#999999"])
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_v * 31 + 7
	var base = _mesh(parent, _cyl(0.48, 0.55, 0.22, 6), Color("#3a2468"), Vector3(0, 0.1, 0))
	base.material_overlay = _ink()
	var n = 3 + rng.randi() % 3
	for i in range(n):
		var hgt = rng.randf_range(0.7, 1.5) * (1.25 if i == 0 else 1.0)
		var rad = rng.randf_range(0.13, 0.22) * (1.25 if i == 0 else 1.0)
		var a = TAU * i / n + rng.randf_range(-0.4, 0.4)
		var off = Vector3(cos(a), 0, sin(a)) * (0.0 if i == 0 else rng.randf_range(0.18, 0.32))
		var holder = Node3D.new()
		holder.position = off + Vector3(0, 0.18, 0)
		holder.rotation = Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0, TAU), rng.randf_range(-0.35, 0.35))
		if i == 0:
			holder.rotation = Vector3(0, holder.rotation.y, 0)
		parent.add_child(holder)
		var col = Color(cc[0]) if i % 2 == 0 else Color(cc[1])
		var shaft = MeshInstance3D.new()
		shaft.mesh = _cyl(rad, rad * 1.05, hgt, 6)
		shaft.material_override = _glow_mat(col, 0.55)
		shaft.material_overlay = _ink()
		shaft.position = Vector3(0, hgt * 0.5, 0)
		holder.add_child(shaft)
		var tip = MeshInstance3D.new()
		tip.mesh = _cyl(0.0, rad, rad * 1.6, 6)
		tip.material_override = _glow_mat(col.lightened(0.35), 0.7)
		tip.material_overlay = _ink()
		tip.position = Vector3(0, hgt + rad * 0.8, 0)
		holder.add_child(tip)
	var lt = OmniLight3D.new()
	lt.light_color = Color(cc[0])
	lt.light_energy = 0.6
	lt.omni_range = 2.6
	lt.position = Vector3(0, 0.9, 0)
	parent.add_child(lt)


func _rockwall(pos: Vector3, h: float, w: float, col: Color, rng: RandomNumberGenerator) -> void:
	var r = MeshInstance3D.new()
	r.mesh = _cyl(w * rng.randf_range(0.45, 0.8), w, h, rng.randi_range(5, 7))
	r.material_override = _mat(col)
	r.material_overlay = _ink()
	r.position = pos + Vector3(0, h * 0.5, 0)
	r.rotation = Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(0, TAU), rng.randf_range(-0.12, 0.12))
	scenery_root.add_child(r)


func _build_cave() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 4242
	var far = PLAT + 0.3
	var wall_cols = [Color("#3d2280"), Color("#4a2a96"), Color("#2e1a66"), Color("#5a34b0")]
	# paredes da caverna: anel de rochas altas em volta da arena
	for i in range(64):
		var a = TAU * i / 64.0 + rng.randf_range(-0.03, 0.03)
		var d = far + rng.randf_range(0.3, 2.5)
		var pos = Vector3(cos(a) * d, BASE_Y, sin(a) * d)
		# anel de dentro baixo (não esconde o tabuleiro); o de fora, alto, fecha a caverna
		_rockwall(pos, rng.randf_range(1.2, 3.2), rng.randf_range(1.2, 2.2), wall_cols[rng.randi() % 4], rng)
	for i in range(40):
		var a2 = rng.randf() * TAU
		var d2 = far + 4.5 + rng.randf_range(0.0, 4.0)
		_rockwall(Vector3(cos(a2) * d2, BASE_Y, sin(a2) * d2), rng.randf_range(8.0, 16.0), rng.randf_range(2.2, 3.6), wall_cols[rng.randi() % 4].darkened(0.25), rng)
	# cristais de enfeite nas paredes (não são do jogo)
	var kinds = ["verde", "azul", "roxo"]
	for i in range(16):
		var a3 = rng.randf() * TAU
		var d3 = far + rng.randf_range(0.2, 1.4)
		var holder = Node3D.new()
		holder.position = Vector3(cos(a3) * d3, BASE_Y + rng.randf_range(0.0, 1.2), sin(a3) * d3)
		holder.scale = Vector3.ONE * rng.randf_range(0.9, 1.6)
		scenery_root.add_child(holder)
		_crystal_cluster(holder, kinds[rng.randi() % 3], 900 + i)
	# entradas de mina nas pontas de fora dos trilhos
	for ti in range(g.tracks.size()):
		var tr = g.tracks[ti]
		if tr.size() < 2:
			continue
		if g.track_loop[ti]:
			# trilho circular: duas entradas de mina na parede, de lados opostos
			for k in [tr.size() / 12, tr.size() / 12 + tr.size() / 2]:
				var wp = world_xz(tr[k])
				var ov = wp.normalized()
				var pe = ov * (PLAT + 0.6)
				_mine_entrance(Vector3(pe.x, BASE_Y, pe.y), atan2(ov.x, ov.y))
			continue
		var end = world_xz(tr[0])
		var prev = world_xz(tr[1])
		var dirv = (end - prev).normalized()
		var p = end + dirv * 1.7
		_mine_entrance(Vector3(p.x, BASE_Y, p.y), atan2(dirv.x, dirv.y))
	# andaimes amarelos na parede, entre as entradas
	for k in range(4):
		var a4 = PI * 0.5 * k + 0.6
		var d4 = far + 0.2
		_scaffold(Vector3(cos(a4) * d4, BASE_Y, sin(a4) * d4), -a4 + PI * 0.5)
	_build_pit()


func _mine_entrance(pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	scenery_root.add_child(root)
	var dark = _mesh(root, _box(Vector3(2.4, 2.6, 1.2)), Color("#05020a"), Vector3(0, 1.3, 0.4))
	dark.material_overlay = _ink()
	var wood = Color("#f2b630")
	for sx in [-1.25, 1.25]:
		var post = _mesh(root, _box(Vector3(0.32, 3.0, 0.32)), wood, Vector3(sx, 1.5, -0.2))
		post.material_overlay = _ink()
	var beam = _mesh(root, _box(Vector3(3.2, 0.38, 0.4)), wood, Vector3(0, 3.0, -0.2))
	beam.material_overlay = _ink()
	for sx2 in [-1.0, 1.0]:
		var lamp = _mesh(root, SphereMesh.new(), Color("#ffe27a"), Vector3(sx2 * 1.55, 2.4, -0.45))
		lamp.scale = Vector3.ONE * 0.32
		lamp.material_override = _glow_mat(Color("#ffd24a"), 2.0)
		lamp.material_overlay = _ink()
		var lt = OmniLight3D.new()
		lt.light_color = Color("#ffc860")
		lt.light_energy = 1.4
		lt.omni_range = 6.0
		lt.position = Vector3(sx2 * 1.55, 2.4, -0.9)
		root.add_child(lt)


func _scaffold(pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	scenery_root.add_child(root)
	var wood = Color("#e8a828")
	for x in [-1.2, 1.2]:
		for z in [-0.5, 0.5]:
			var p = _mesh(root, _box(Vector3(0.18, 2.4, 0.18)), wood, Vector3(x, 1.2, z))
			p.material_overlay = _ink()
	var deck = _mesh(root, _box(Vector3(2.8, 0.16, 1.3)), Color("#c98a2a"), Vector3(0, 2.4, 0))
	deck.material_overlay = _ink()
	for x2 in [-1.2, 0.0, 1.2]:
		var rail = _mesh(root, _box(Vector3(0.1, 0.6, 0.1)), wood, Vector3(x2, 2.75, -0.6))
		rail.material_overlay = _ink()
	var top = _mesh(root, _box(Vector3(2.6, 0.1, 0.1)), wood, Vector3(0, 3.05, -0.6))
	top.material_overlay = _ink()


# buraco central e a garra (só a garra aparece: dedos roxos com unhas amarelas)
func _build_pit() -> void:
	if g.hole.is_empty():
		return
	var c = Vector2.ZERO
	for h in g.hole:
		c += world_xz(h)
	c /= float(g.hole.size())
	var rad = 0.0
	for h in g.hole:
		rad = max(rad, world_xz(h).distance_to(c))
	rad += 0.9
	var pit = MeshInstance3D.new()
	pit.mesh = _cyl(rad, rad * 0.75, 12.0, 24)
	pit.material_override = _mat(Color("#05020c"), true)
	pit.position = Vector3(c.x, BASE_Y - 6.0 + 0.05, c.y)
	scenery_root.add_child(pit)
	var lip = MeshInstance3D.new()
	lip.mesh = _disc(rad, 24)
	lip.material_override = _mat(Color("#030108"), true)
	lip.position = Vector3(c.x, 0.02, c.y)
	scenery_root.add_child(lip)
	# aro de metal amarelo com faixas de perigo
	var tor = TorusMesh.new()
	tor.inner_radius = rad
	tor.outer_radius = rad + 0.32
	tor.rings = 48
	var ring = MeshInstance3D.new()
	ring.mesh = tor
	ring.material_override = _mat(Color("#f2c22a"))
	ring.material_overlay = _ink()
	ring.position = Vector3(c.x, 0.1, c.y)
	ring.scale = Vector3(1, 0.6, 1)
	scenery_root.add_child(ring)
	for i in range(12):
		var a = TAU * i / 12.0
		var st = _mesh(scenery_root, _box(Vector3(0.36, 0.2, 0.14)), Color("#1a0a24"), Vector3(c.x + cos(a) * (rad + 0.16), 0.2, c.y + sin(a) * (rad + 0.16)), Vector3(0, -a, 0.6))
	var glow = OmniLight3D.new()
	glow.light_color = Color("#d04aff")
	glow.light_energy = 1.2
	glow.omni_range = rad * 2.5
	glow.position = Vector3(c.x, -1.5, c.y)
	scenery_root.add_child(glow)
	# a garra: palma escondida no fundo e 4 dedos longos saindo do buraco e se curvando sobre a borda
	claw = Node3D.new()
	claw_rest = Vector3(c.x, -1.2, c.y)
	claw.position = claw_rest
	scenery_root.add_child(claw)
	claw_fingers = []
	var skin = Color("#b03ad8")
	var nail = Color("#ffd23a")
	var palm = MeshInstance3D.new()
	palm.mesh = _sphere_mesh(1.2)
	palm.scale = Vector3(1.3, 0.7, 1.0)
	palm.material_override = _mat(skin.darkened(0.25))
	palm.material_overlay = _ink()
	claw.add_child(palm)
	var lens = [1.5, 1.15, 0.85]
	for f in range(4):
		var a = -1.05 + f * 0.7
		var root = Node3D.new()
		root.rotation = Vector3(0, a, 0)
		root.position = Vector3(sin(a), 0.3, cos(a)) * 0.75
		claw.add_child(root)
		var pivots = []
		var parent: Node3D = root
		for k in range(3):
			var piv = Node3D.new()
			piv.position = Vector3.ZERO if k == 0 else Vector3(0, lens[k - 1], 0)
			parent.add_child(piv)
			var cap = CapsuleMesh.new()
			cap.radius = 0.3 - k * 0.06
			cap.height = lens[k] + cap.radius
			var m = MeshInstance3D.new()
			m.mesh = cap
			m.material_override = _mat(skin.lightened(k * 0.06))
			m.material_overlay = _ink()
			m.position = Vector3(0, lens[k] * 0.5, 0)
			piv.add_child(m)
			# nó do dedo (articulação mais clara)
			if k > 0:
				var kn = MeshInstance3D.new()
				kn.mesh = _sphere_mesh(cap.radius * 1.15)
				kn.material_override = _mat(skin.lightened(0.15))
				piv.add_child(kn)
			pivots.append(piv)
			parent = piv
		var tip = MeshInstance3D.new()
		tip.mesh = _cyl(0.0, 0.17, 0.75, 8)
		tip.material_override = _glow_mat(nail, 0.35)
		tip.material_overlay = _ink()
		tip.position = Vector3(0, lens[2] + 0.3, 0.08)
		tip.rotation = Vector3(0.5, 0, 0)
		parent.add_child(tip)
		claw_fingers.append(pivots)


func _sphere_mesh(r: float) -> SphereMesh:
	var sm = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	return sm


# um dedo da garra se estica do buraco até a casa do personagem, agarra e recolhe
func claw_reach(h: Vector2i, kill: bool) -> void:
	if claw == null or not is_instance_valid(claw):
		return
	var c = Vector3(claw_rest.x, 0.25, claw_rest.z)
	var wp = world_xz(h)
	var tgt = Vector3(wp.x, top_y(h) + 0.6, wp.y)
	var dirv = tgt - c
	var dist = dirv.length()
	var root = Node3D.new()
	scenery_root.add_child(root)
	root.position = c
	root.look_at_from_position(c, tgt, Vector3.UP)
	var arm = Node3D.new()      # cresce ao longo de -Z (para onde olha)
	root.add_child(arm)
	var skin = Color("#b03ad8")
	var seg = MeshInstance3D.new()
	seg.mesh = _cyl(0.2, 0.34, 1.0, 10)
	seg.material_override = _mat(skin)
	seg.material_overlay = _ink()
	seg.rotation = Vector3(-PI / 2, 0, 0)
	seg.position = Vector3(0, 0, -0.5)
	arm.add_child(seg)
	for k in range(3):
		var kn = MeshInstance3D.new()
		kn.mesh = _sphere_mesh(0.3 - k * 0.04)
		kn.material_override = _mat(skin.lightened(0.15))
		kn.position = Vector3(0, 0, -0.25 - k * 0.3)
		arm.add_child(kn)
	var tip = MeshInstance3D.new()
	tip.mesh = _cyl(0.0, 0.2, 0.7, 8)
	tip.material_override = _glow_mat(Color("#ffd23a"), 0.4)
	tip.material_overlay = _ink()
	tip.rotation = Vector3(-PI / 2 - 0.6, 0, 0)
	var tip_h = Node3D.new()     # a unha anda na ponta (sem esticar)
	root.add_child(tip_h)
	tip.position = Vector3(0, 0.15, 0)
	tip_h.add_child(tip)
	arm.scale = Vector3(1, 1, 0.05)
	tip_h.position = Vector3(0, 0, -0.05)
	var tw = create_tween()
	tw.tween_property(arm, "scale", Vector3(1, 1, dist), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(tip_h, "position", Vector3(0, 0, -dist), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): shake = max(shake, 0.35))
	tw.tween_interval(0.25 if kill else 0.15)
	tw.tween_property(arm, "scale", Vector3(1, 1, 0.05), 0.35 if kill else 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tip_h, "position", Vector3(0, 0, -0.05), 0.35 if kill else 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	claw_t = max(claw_t, 1.0)


func claw_twitch(v: float) -> void:
	claw_t = max(claw_t, 0.4 + v * 0.1)


func claw_strike() -> void:
	claw_hit = 1.0
	shake = max(shake, 0.9)


func _update_claw(delta: float) -> void:
	if claw == null or not is_instance_valid(claw):
		return
	var tt = Time.get_ticks_msec() / 1000.0
	claw_t = max(0.0, claw_t - delta)
	claw_hit = max(0.0, claw_hit - delta * 0.7)
	var vibk = float(g.vib) / 5.0 if g != null else 0.0
	# respira devagar; treme com a vibração; no ataque sobe alto e fecha os dedos
	var rise = 0.12 * sin(tt * 1.2) + vibk * 0.35 + sin(claw_hit * PI) * 2.6
	claw.position = claw_rest + Vector3(0, rise, 0) + Vector3(sin(tt * 37.0), 0, cos(tt * 41.0)) * 0.04 * (claw_t + vibk)
	for f in range(claw_fingers.size()):
		var open_k = sin(claw_hit * PI)    # no ataque os dedos se abrem e depois fecham
		var wig = 0.06 * sin(tt * 1.6 + f * 1.3) + vibk * 0.05 * sin(tt * 30.0 + f)
		claw_fingers[f][0].rotation.x = 0.35 + wig - open_k * 0.25
		claw_fingers[f][1].rotation.x = 0.75 + wig * 1.5 - open_k * 0.5
		claw_fingers[f][2].rotation.x = 0.9 + wig * 2.0 - open_k * 0.6


func sync_carts(cs: Array) -> void:
	while cart_nodes.size() > cs.size():
		var n = cart_nodes.pop_back()
		if is_instance_valid(n):
			n.queue_free()
	for i in range(cs.size()):
		if i >= cart_nodes.size() or not is_instance_valid(cart_nodes[i]):
			var node = _make_cart(i)
			if i >= cart_nodes.size():
				cart_nodes.append(node)
			else:
				cart_nodes[i] = node
		var h: Vector2i = cs[i]["h"]
		var wp = world_xz(h)
		var goal = Vector3(wp.x, top_y(h), wp.y)
		if not cart_nodes[i].has_meta("moving"):
			cart_nodes[i].position = goal


func _make_cart(i: int) -> Node3D:
	var root = Node3D.new()
	add_child(root)
	var body = _mesh(root, _box(Vector3(0.8, 0.45, 0.6)), Color("#c8642a"), Vector3(0, 0.42, 0))
	body.material_overlay = _ink()
	var rim = _mesh(root, _box(Vector3(0.9, 0.08, 0.7)), Color("#7a3a18"), Vector3(0, 0.66, 0))
	rim.material_overlay = _ink()
	var kinds = ["roxo", "azul", "verde"]
	var cc = CRYSTAL_COL[kinds[i % 3]]
	for k in range(4):
		var ore = _mesh(root, SphereMesh.new(), Color(cc[k % 2]), Vector3(-0.22 + k * 0.15, 0.72, (k % 2) * 0.12 - 0.06))
		ore.scale = Vector3.ONE * 0.24
		ore.material_override = _glow_mat(Color(cc[k % 2]), 0.6)
	for x in [-0.28, 0.28]:
		for z in [-0.32, 0.32]:
			var wh = _mesh(root, _cyl(0.13, 0.13, 0.08, 10), Color("#2a2030"), Vector3(x, 0.14, z), Vector3(PI / 2, 0, 0))
			wh.material_overlay = _ink()
	return root


func move_cart(i: int, to: Vector2i) -> void:
	if i >= cart_nodes.size() or not is_instance_valid(cart_nodes[i]):
		return
	var n = cart_nodes[i]
	n.set_meta("moving", true)
	var wp = world_xz(to)
	var goal = Vector3(wp.x, top_y(to), wp.y)
	var tw = create_tween()
	tw.tween_property(n, "position", goal, 0.22)
	tw.tween_callback(func(): n.remove_meta("moving"))
