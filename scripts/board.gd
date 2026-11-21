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
	"sand": ["#ecb870", "#cf9250", "#6c3c3a"], "dune": ["#e8845e", "#c45f4a", "#62303e"],
	"wood": ["#b07840", "#8c5a2c", "#4e3018"], "ramp": ["#d09a58", "#b07a3a", "#5e3e20"],
	"mud": ["#6a5238", "#4e3c28", "#2e2214"], "rubble": ["#8c8c9a", "#70707e", "#44444e"],
	"quick": ["#8e8040", "#6e6230", "#3e3618"], "stone": ["#8e827c", "#726862", "#4a4240"],
	"bone": ["#d8ccb0", "#bcae90", "#7e7058"], "cracked": ["#e6ac66", "#c88a4c", "#643638"],
	"hole": ["#3a2418", "#24140c", "#120a04"],
	"cave": ["#6a6cd2", "#4c52b2", "#1c2068"], "cave2": ["#5c5ec4", "#4146a2", "#181c5c"], "pit": ["#140a24", "#0c0618", "#05020a"],
	"rubble_g": ["#6aa040", "#548232", "#2c4a1c"], "sand2": ["#d8903e", "#b8702c", "#6e3a1a"], "grass3": ["#389444", "#2a7434", "#184a22"],
	# Abnara (selva viva)
	"trilha": ["#7fb04a", "#639238", "#2e4e22"], "clareira": ["#cdb86e", "#ad9a52", "#5a4a2a"], "mata": ["#217044", "#185a36", "#0c3222"],
	"raiz": ["#6a7a3a", "#4e5e2c", "#2a3416"], "rio": ["#2f76d8", "#2358b0", "#102e72"], "ponte": ["#c0723a", "#9a5428", "#52301a"],
	"pedra": ["#8e8aa8", "#726e8c", "#3c3a54"],
	# Gor'Aida (gelo instável)
	"neve": ["#eef4ff", "#cddcf2", "#7c94c4"], "neve_base": ["#fff0cc", "#ead6aa", "#9a8a6a"], "gelo": ["#8ed8f4", "#62b0e2", "#306aa0"],
	"gelo_f": ["#4f9fd0", "#3a80b8", "#1c4a7a"], "fenda": ["#102a66", "#1b4aa0", "#2f6fc0"], "gelo_alto": ["#c4e2f6", "#9cc6e6", "#4e7ea6"],
	"aval": ["#f8e8f4", "#e6cce0", "#9a7a98"],
}
const ELEV = {"tarhut": "#b8664e", "posto": "#e0c060", "abnara": "#b6d88a", "goraida": "#ffffff"}  # tom que as casas altas puxam
# planeta: o tabuleiro fica num platô e o chão se curva em volta (deserto contínuo)
var PLAT = 18.5       # raio plano em volta do tabuleiro (ajustado ao tamanho do mapa)
var HX: float = 1.0          # espaçamento das casas (mapas com "hex_scale": casas mais largas, mais respiro)
var bio: String = "desert"   # ambiente do planeta: desert (Tarhut), sea (Valak), jungle (Abnara), ice (Gor'Aida)
var RIM = 12.0         # raio da borda arredondada (onde o deserto se curva)
var UNDER = 34.0       # altura da base rochosa por baixo do planetoide
const ZOOM_MIN = 4.0
const ZOOM_MAX = 140.0
# personagens que já têm modelo 3D com esqueleto (Tripo): entram no lugar da arte 2D
const FIG3D = {
	"k_cmd": {"path": "res://models/personagens/k_cmd.glb", "visor": true, "punho": true, "jeito": "militar"},
	"rhazur": {"path": "res://models/personagens/rhazur.glb", "visor": false, "punho": false, "jeito": "bruto", "giro": 0.0, "cauda": [0.09, 0.32, -0.02]},
	"rei_mina": {"path": "res://models/personagens/rei_mina.glb", "visor": false, "punho": false, "jeito": "rei", "brilho": "rachaduras", "cintila": true, "pegadas": "LeftFoot", "conjura": [0.07, 0.035, 0.032]},
	"z_dragao": {"path": "res://models/personagens/z_dragao.glb", "corpo": "dragao", "escala": 1.35, "brilho": "gemas"},
	"w_mamute": {"path": "res://models/personagens/w_mamute.glb", "visor": false, "punho": false, "jeito": "mamute", "escala": 1.12, "giro": 0.0, "brilho": "gemas_laranja", "anims": {"correr": "run"}},
	# Lithari Líder: parado na pose da ilustração (mão direita erguida e aberta, energia na palma;
	# braço esquerdo baixo e afastado, mão fechada, onde vai entrar o escudo)
	"l_general": {"path": "res://models/personagens/l_general.glb", "visor": false, "punho": false, "jeito": "cristal", "brilho": "gemas",
		"dedos": {"Left": 1.0, "Right": 0.22}, "pose_arte": {
			"Right": [[0.05, -0.7, -0.7], [0.25, -0.55, 0.8], [0.25, -0.45, 0.85]],
			"Left": [[0.0, 0.5, -0.85], [0.1, 0.45, -0.88], [0.05, 0.35, -0.93]]}},
	"karo": {"path": "res://models/personagens/karo.glb", "visor": false, "punho": true, "jeito": "malandro", "bracos": "bolso", "cauda": [-0.05, 0.45, 0.0]},
}
# padrão de tinta de cada facção (data/vfx_paletas.json "pattern") -> pat do hq_personagem
const PADROES = ["reticula", "hachura", "pixel", "entalhe", "poeira", "facetas", "pop"]
# jeito de cada personagem 3D: parado, andar e correr diferentes
#   resp: respiração (amplitude, velocidade) · olha: vigia em volta · peso: troca de perna
#   cad: cadência da passada (andar, correr) · passo / joelho / bal: amplitude de perna, joelho e balanço dos braços
#   quica: sobe e desce · ginga: rebola ombros e quadril · incl: inclina o tronco (andar, correr)
#   vel: velocidade no tabuleiro, casas por segundo (andar, correr) · tique: gesto de vez em quando parado
const JEITOS = {
	"padrao": {"resp": [0.05, 2.2], "olha": [0.2, 0.42], "peso": 0.035, "cad": [7.0, 12.5], "passo": [0.42, 0.78],
		"joelho": [0.55, 1.15], "bal": [0.32, 0.65], "quica": [0.035, 0.1], "ginga": 0.0, "incl": [0.04, 0.24],
		"vel": [2.1, 4.0], "tique": ""},
	# Krieg: postura de sentido, marcha firme e cadenciada, olhar que varre o campo de tempos em tempos
	"militar": {"resp": [0.03, 1.8], "olha": [0.1, 0.3], "peso": 0.01, "cad": [6.8, 10.5], "passo": [0.4, 0.62],
		"joelho": [0.45, 0.8], "bal": [0.55, 0.7], "quica": [0.03, 0.06], "ginga": 0.0, "incl": [0.0, 0.06],
		"vel": [2.0, 3.6], "tique": "vigia", "marcha": true},
	# Karo: malandro, mãos no bolso, gingado nos ombros, passada solta e quicada, corre rápido e baixo
	"malandro": {"resp": [0.05, 2.0], "olha": [0.28, 0.6], "peso": 0.07, "cad": [8.4, 13.5], "passo": [0.46, 0.85],
		"joelho": [0.6, 1.25], "bal": [0.0, 0.75], "quica": [0.06, 0.13], "ginga": 0.14, "incl": [0.02, 0.34],
		"vel": [2.4, 4.6], "tique": "pe"},
	# Rei da Mina: majestoso, passo lento e solene, tronco ereto, olhar altivo de cima para baixo
	"rei": {"resp": [0.04, 1.5], "olha": [0.16, 0.28], "peso": 0.02, "cad": [5.6, 9.6], "passo": [0.34, 0.62],
		"joelho": [0.38, 0.9], "bal": [0.16, 0.42], "quica": [0.012, 0.05], "ginga": 0.0, "incl": [-0.02, 0.12],
		"vel": [1.8, 3.4], "tique": "altivo"},
	# Mamute dos Wächter: colosso, passos pesados e lentos que balançam o corpo todo, respiração funda
	"mamute": {"resp": [0.06, 1.2], "olha": [0.12, 0.25], "peso": 0.06, "cad": [4.8, 8.0], "passo": [0.3, 0.55],
		"joelho": [0.35, 0.8], "bal": [0.22, 0.45], "quica": [0.025, 0.05], "ginga": 0.12, "incl": [0.06, 0.18],
		"vel": [1.6, 3.0], "tique": ""},
	# Lithari Líder: leve e cortante, quase flutua, passos longos e precisos, olhar frio
	"cristal": {"resp": [0.03, 1.4], "olha": [0.14, 0.32], "peso": 0.015, "cad": [6.2, 11.0], "passo": [0.4, 0.8],
		"joelho": [0.45, 1.05], "bal": [0.12, 0.5], "quica": [0.01, 0.04], "ginga": 0.0, "incl": [0.02, 0.3],
		"vel": [2.2, 4.4], "tique": "vigia"},
	# Rhazur: pesado, passada larga e lenta, balança o corpo todo, respiração funda
	"bruto": {"resp": [0.07, 1.5], "olha": [0.14, 0.3], "peso": 0.05, "cad": [5.4, 9.0], "passo": [0.38, 0.62],
		"joelho": [0.4, 0.9], "bal": [0.28, 0.5], "quica": [0.03, 0.06], "ginga": 0.1, "incl": [0.08, 0.22],
		"vel": [1.7, 3.2], "tique": ""},
}
const BIG = ["moby", "balu", "banker", "l_behemot", "l_leviathan", "z_dragao", "w_mamute", "t_feram", "k_tank", "z_tank", "l_tank", "l_colosso", "sismico", "rhombo", "tork", "w_tric", "z_meca", "t_fendas", "t_raiz", "t_basalto", "t_carrinho", "t_sentinela", "t_britadeira", "a_garra", "k_escudeiro", "w_urso", "w_gorila", "w_javali"]

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
var touch_t: Dictionary = {}
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
	swirl_nodes = []
	banana_nodes.clear()
	trap_nodes.clear()
	bleed_nodes.clear()
	star_nodes.clear()
	core_node = null
	core_next_node = null
	core_at = null
	core_next_at = null
	var desert = g.map_id == "tarhut"
	bio = str(DB.maps[g.map_id].get("biome", "desert" if desert else "sea"))
	HX = float(DB.maps[g.map_id].get("hex_scale", 1.0))
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
		var pl = PLANET_LIGHT.get(g.map_id, [Color.WHITE, 0.55, Color(0.85, 0.88, 0.95)])
		sun_light.light_energy = pl[1]
		sun_light.light_color = pl[0]
		env.ambient_light_color = pl[2]
		env.ambient_light_energy = 0.32
	_apply_planet_tint()
	_apply_atmosphere()
	for h in DB.hexes:
		var node = Node3D.new()
		var wp = world_xz(h)
		node.position = Vector3(wp.x, 0, wp.y)
		add_child(node)
		var hl = MeshInstance3D.new()
		# marca de HQ (borda grossa + retícula), tingida pela cor do destaque
		if mark_tex == null and ResourceLoader.exists("res://ui/terreno/marca.png"):
			mark_tex = load("res://ui/terreno/marca.png")
		var hom = _overlay_mat(Color(0, 0, 0, 0))
		if mark_tex != null:
			var pq = PlaneMesh.new()
			pq.size = Vector2(INNER * 2.0 / 0.97, INNER * 2.0 / 0.97)
			hl.mesh = pq
			hom.albedo_texture = mark_tex
		else:
			hl.mesh = _disc(INNER, 6)
		hl.material_override = hom
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
		var wsp = Sprite3D.new()
		wsp.texture = _warn_tex()
		wsp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		wsp.no_depth_test = true
		wsp.shaded = false
		wsp.pixel_size = 0.0062
		wsp.render_priority = 9
		wsp.visible = false
		node.add_child(wsp)
		tiles[h] = {"node": node, "disp_h": _disp_of(h), "body": null, "props": null, "hl": hl, "dim": dim, "label": lab, "warn": wsp, "flash": 0.0, "sig": ""}
	if cave:
		_build_cave()
	elif bio == "jungle" or bio == "ice":
		_build_wild(bio)
	else:
		_build_scenery(desert)
		_build_far(desert)
	built_ver = -1
	refresh_terrain()
	_build_rails()
	fit_camera(true)
	_build_ships()


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


# ================= naves das facções no céu =================
# cada facção com nave aparece de lado (perfil) no céu, atrás do lado dela; as demais entram aqui depois
# nose: -1 = o nariz do modelo aponta para -X (o desenho fica de proa para o tabuleiro)
const FAC_SHIPS = {
	"ABY": {"path": "res://models/nave_aby.glb", "nose": -1.0},
	"FAU": {"path": "res://models/nave_fau.glb", "nose": -1.0},
	"KRI": {"path": "res://models/nave_kri.glb", "nose": -1.0},
	"WAC": {"path": "res://models/nave_wac.glb", "nose": -1.0},
	"TER": {"path": "res://models/nave_ter.glb", "nose": -1.0},
	"LIT": {"path": "res://models/nave_lit.glb", "nose": -1.0},
	"ZUK": {"path": "res://models/nave_zuk.glb", "nose": -1.0},
}
var ships_root: Node3D = null
var ship_nodes: Array = []


# a nave fica de frente para o jogador: o nariz aponta para a câmera (no plano do chão),
# e acompanha quando a câmera gira
func _orient_ship(ship: Node3D) -> void:
	var toward = Vector2(sin(cam_yaw), cos(cam_yaw))      # direção da câmera no plano do chão
	var nose = float(ship.get_meta("nose"))
	var axis = -toward * (-nose)                          # direção em que o X local deve apontar
	ship.rotation.y = atan2(-axis.y, axis.x)


func _build_ships() -> void:
	if ships_root != null and is_instance_valid(ships_root):
		ships_root.queue_free()
	ship_nodes = []
	ships_root = null
	if g == null or DB.maps[g.map_id].get("cave", false):
		return   # a mina de Valak não tem céu
	ships_root = Node3D.new()
	add_child(ships_root)
	for p in range(2):
		var fac = String(g.P[p]["fac"])
		if not FAC_SHIPS.has(fac) or not ResourceLoader.exists(FAC_SHIPS[fac]["path"]):
			continue
		var ps = load(FAC_SHIPS[fac]["path"])
		var ship: Node3D = ps.instantiate()
		var ec = world_xz(DB.entry_c[p])
		var out = ec.normalized()
		var len_w = PLAT * 1.0
		ship.scale = Vector3.ONE * len_w
		var c2 = out * (PLAT + len_w * 2.3)   # bem atrás da borda: não tapa a visão do mapa (cosmético)
		ship.position = Vector3(c2.x, PLAT * 0.9, c2.y)
		ship.set_meta("out", out)
		ship.set_meta("nose", float(FAC_SHIPS[fac]["nose"]))
		_orient_ship(ship)
		for mi in ship.find_children("*", "MeshInstance3D", true, false):
			var m = (mi as MeshInstance3D).mesh
			for i in m.get_surface_count():
				var mat = m.surface_get_material(i)
				if mat is StandardMaterial3D:
					var m2 = mat.duplicate()
					m2.emission_enabled = true
					m2.emission_texture = m2.albedo_texture
					m2.emission_energy_multiplier = 0.9
					(mi as MeshInstance3D).set_surface_override_material(i, m2)
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ships_root.add_child(ship)
		var base_y = ship.position.y
		var tw = ship.create_tween().set_loops()
		tw.tween_property(ship, "position:y", base_y + 0.6, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(ship, "position:y", base_y - 0.6, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ship_nodes.append(ship)


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
	elif bio == "jungle" or bio == "ice":
		# morros suaves em volta da arena
		var amp2 = min(1.0, d / 6.0) * (0.9 if bio == "jungle" else 1.2)
		y += amp2 * (0.5 + 0.5 * sin(x * 0.23 + sin(z * 0.11) * 2.0)) * (0.5 + 0.5 * sin(z * 0.19 - x * 0.07))
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
		var rock_j = [Color("#5a4a2c"), Color("#463a22"), Color("#6e5a36")]
		var rock_i = [Color("#6a86a8"), Color("#56708e"), Color("#86a2c2")]
		var rc = rock_d[band] if desert else (rock_j[band] if bio == "jungle" else (rock_i[band] if bio == "ice" else rock_g[band]))
		return rc.darkened(clamp(under * 0.7, 0.0, 0.6))
	var r = sqrt(x * x + z * z)
	var d = max(0.0, r - PLAT)
	if desert:
		var ground = BASE_Y - 0.1 - (RIM - sqrt(max(0.0, RIM * RIM - min(d, RIM) * min(d, RIM))))
		var crest = clamp((y - ground) / 1.3, 0.0, 1.0)
		var c = Color("#d89a5c").lerp(Color("#f0c27e"), crest)
		return c.lerp(Color("#8a5a58"), clamp(d / RIM, 0.0, 0.55))
	if bio == "jungle":
		var gj = Color("#4c9e3c").lerp(Color("#2f7a34"), clamp(0.5 + 0.5 * sin(x * 0.31 + z * 0.17), 0.0, 1.0) * 0.6)
		return gj.lerp(Color("#1d4a24"), clamp(d / RIM, 0.0, 0.7))
	if bio == "ice":
		var gi = Color("#eef4ff").lerp(Color("#c4d6f2"), clamp(0.5 + 0.5 * sin(x * 0.27 - z * 0.21), 0.0, 1.0) * 0.7)
		return gi.lerp(Color("#7f9ccc"), clamp(d / RIM, 0.0, 0.75))
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
			isl0.material_overlay = null  # cores chapadas, sem contorno
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
				isl.material_overlay = null  # cores chapadas, sem contorno
				_mesh(holder, _cyl(0.9 * s, 1.2 * s, 0.4, 9), Color("#7fb54a"), Vector3(0, 0.45, 0))
				for j in range(2 + int(_rnd(h, 6) * 3)):
					_pine(holder, Vector3((_rnd(h, j + 10) - 0.5) * 1.4 * s, 0.6, (_rnd(h, j + 20) - 0.5) * 1.4 * s), 0.9 + _rnd(h, j) * 0.5)


# para onde cada peça 3D olha parada: o último inimigo com quem trocou golpes (se ainda em campo),
# senão o inimigo mais próximo, senão a base inimiga
var foco: Dictionary = {}          # uid -> uid do último inimigo que atacou ou que o atacou


func foco_par(a: int, b: int) -> void:
	foco[a] = b
	foco[b] = a


func _olhar_de(u, node: Node3D) -> Vector3:
	if g == null:
		return _dir_inimigo(u.owner)
	var alvo = null
	if foco.has(u.uid):
		var f = g.by_uid(foco[u.uid])
		if f != null and f.st == "field" and f.owner != u.owner and f.owner < 2:
			alvo = f
		else:
			foco.erase(u.uid)
	if alvo == null:
		var best = 999
		for e in g.units:
			if e.st != "field" or e.owner == u.owner or e.owner > 1 or e.barrier or e.crystal != "":
				continue
			var dd = DB.dist(u.pos(), e.pos())
			if dd < best:
				best = dd
				alvo = e
	if alvo == null:
		return _dir_inimigo(u.owner)
	var a = world_xz(u.pos())
	var b = world_xz(alvo.pos())
	if unit_nodes.has(alvo.uid):
		var an: Node3D = unit_nodes[alvo.uid]["node"]
		b = Vector2(an.global_position.x, an.global_position.z)
		a = Vector2(node.global_position.x, node.global_position.z)
	var dv = b - a
	return Vector3(dv.x, 0.0, dv.y) if dv.length() > 0.01 else _dir_inimigo(u.owner)


# direção no mundo de uma base para a base inimiga (para onde as peças 3D olham paradas)
func _dir_inimigo(owner: int) -> Vector3:
	if DB.entry_c.size() < 2 or owner < 0 or owner > 1:
		return Vector3.ZERO
	var a = world_xz(DB.entry_c[owner])
	var b = world_xz(DB.entry_c[1 - owner])
	var dv = b - a
	return Vector3(dv.x, 0.0, dv.y)


func world_xz(h: Vector2i) -> Vector2:
	return Vector2(1.5 * h.y, -S3 * (h.x + h.y / 2.0)) * HX


func hex_from_world(x: float, z: float) -> Vector2i:
	var r = x / HX / 1.5
	var q = -z / HX / S3 - r / 2.0
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
			# quem sobe numa estrutura pisa no topo do modelo que está ali (pés no chão, sem flutuar)
			var st = _topo_props(h)
			if st >= 0.0:
				return tiles[h]["disp_h"] * HS + st
			extra = float(g.tt_of(g.terr(h)["k"]).get("top", 0)) * 0.55
		return (tiles[h]["disp_h"] + extra) * HS
	return 0.0


# altura (acima do chão da casa) do topo dos modelos de cenário no meio da casa; -1 se não há nada ali
func _topo_props(h: Vector2i) -> float:
	var tile: Dictionary = tiles[h]
	var ja: float = float(tile.get("stand", -2.0))
	if ja > -2.0:
		return ja
	var pr = tile["props"]
	if pr == null or not pr.is_inside_tree():
		return -1.0
	var inv = pr.global_transform.affine_inverse()
	var raio = 0.45 * HX
	var topo = -1.0
	for gi in pr.find_children("*", "GeometryInstance3D", true, false):
		if not gi.visible:
			continue
		var xf: Transform3D = inv * gi.global_transform
		var ab: AABB = xf * gi.get_aabb()
		if ab.size.y < 0.05:
			continue
		# só o que está no meio da casa, onde o personagem fica
		if ab.position.x > raio or ab.end.x < -raio or ab.position.z > raio or ab.end.z < -raio:
			continue
		topo = max(topo, ab.end.y)
	tile["stand"] = topo
	return topo
	return 0.0


func pal_of(t: Dictionary, h: Vector2i) -> String:
	if DB.maps[g.map_id].get("cave", false):
		if t["k"] == "fosso":
			return "pit"
		return "cave" if (h.x * 3 + h.y * 7) % 5 != 0 else "cave2"
	var desert = g.map_id == "tarhut"
	match t["k"]:
		"trilha", "planta":
			return "trilha"
		"clareira":
			return "clareira"
		"mata":
			return "mata"
		"raiz":
			return "raiz"
		"correnteza":
			return "rio"
		"ponte":
			return "ponte"
		"ruina_alta":
			return "trilha"
		"neve", "parede_gelo":
			return "neve"
		"neve_base":
			return "neve_base"
		"gelo":
			return "gelo"
		"gelo_fragil":
			return "gelo_f"
		"fenda":
			return "fenda"
		"avalanche":
			return "aval"
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
			tile["disp_h"] = _disp_of(h)
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
		if t["k"] == "fosso" or t["k"] == "ponte":
			body.visible = false   # ponte: sem chão, a água passa por baixo
		var props = Node3D.new()
		tile["node"].add_child(props)
		tile["props"] = props
		tile["stand"] = -2.0   # topo dos modelos recalculado quando alguém subir
		_add_props(props, h, t)
		_place_tile(h)


# fenda de gelo: o chão afunda no relevo, então as paredes das casas vizinhas, a luz e a sombra do jogo fazem o buraco
const PIT_DEPTH = 0.95
const RIVER_DROP = 0.8   # níveis que o leito do rio afunda em relação às margens


func _disp_of(h: Vector2i) -> float:
	var v = float(g.h_of(h))
	var kk = g.terr(h)["k"]
	if kk == "fenda":
		v -= PIT_DEPTH
	elif kk == "correnteza":
		v -= RIVER_DROP   # o rio corre num leito afundado
	elif kk == "ruina_alta":
		# a ruína fica rente à grama em volta (média das vizinhas de chão)
		var sm = 0.0
		var cn = 0
		for n in DB.DIRS:
			var nb = h + n
			if tiles.has(nb):
				var k2 = g.terr(nb)["k"]
				if k2 in ["trilha", "clareira", "mata", "raiz", "planta"]:
					sm += float(g.h_of(nb))
					cn += 1
		v = round(sm / cn) if cn > 0 else min(v, 1.0)
	return v


func _place_tile(h: Vector2i) -> void:
	var tile = tiles[h]
	var y = tile["disp_h"] * HS
	# o corpo vai da base até o topo: escala vertical
	var height = y - BASE_Y
	tile["body"].scale = Vector3(HX, height, HX)
	tile["hl"].scale = Vector3(HX, 1, HX)
	tile["dim"].scale = Vector3(HX, 1, HX)
	tile["body"].position = Vector3(0, BASE_Y, 0)
	tile["props"].position = Vector3(0, y, 0)
	tile["hl"].position = Vector3(0, y + 0.03, 0)
	tile["dim"].position = Vector3(0, y + 0.035, 0)
	tile["label"].position = Vector3(0, y + 0.35, 0)
	if tile.get("warn") != null:
		tile["warn"].position = Vector3(0, y + 1.15, 0)


# prisma unitário (altura 1 a partir de 0); topo com aro claro e centro colorido
# tinta da cor do terreno: o mesmo tom, mais escuro e mais saturado
func _ink_of(c: Color) -> Color:
	return c.darkened(0.13)   # costura quase imperceptível, tom sobre tom (cores chapadas, sem contorno)


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
	# tinta: aro externo do topo e quinas verticais (contorno de HQ nas arestas)
	var ink = _ink_of(c1)
	# traço de tinta feito à mão: espessura diferente em cada vértice, cor de tinta escura (quase preto-violeta)
	var rim_ink = _ink_of(c1)
	var wob = []
	for k in range(6):
		wob.append(0.945 + randf() * 0.02)
	for k in range(6):
		var o1b = pts_o[k]
		var o2b = pts_o[(k + 1) % 6]
		var e1 = o1b * wob[k]
		var e2 = o2b * wob[(k + 1) % 6]
		_tri(st, Vector3(o1b.x, 1.002, o1b.y), rim_ink, Vector3(o2b.x, 1.002, o2b.y), rim_ink, Vector3(e2.x, 1.002, e2.y), rim_ink)
		_tri(st, Vector3(o1b.x, 1.002, o1b.y), rim_ink, Vector3(e2.x, 1.002, e2.y), rim_ink, Vector3(e1.x, 1.002, e1.y), rim_ink)
	for k in range(6):
		var a3 = pts_o[k]
		var b3 = pts_o[(k + 1) % 6]
		var c3 = pts_o[(k + 5) % 6]
		var nm = Vector3(a3.x, 0, a3.y).normalized()
		st.set_normal(nm)
		var w1 = a3 + (b3 - a3) * 0.04 + Vector2(nm.x, nm.z) * 0.004
		var w2 = a3 + (c3 - a3) * 0.04 + Vector2(nm.x, nm.z) * 0.004
		var a4 = a3 + Vector2(nm.x, nm.z) * 0.006
		for wv in [w1, w2]:
			_tri(st, Vector3(a4.x, 1, a4.y), ink, Vector3(wv.x, 1, wv.y), ink, Vector3(wv.x, 0, wv.y), ink)
			_tri(st, Vector3(a4.x, 1, a4.y), ink, Vector3(wv.x, 0, wv.y), ink, Vector3(a4.x, 0, a4.y), ink)
	st.set_normal(Vector3.UP)
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


# sombra de cada planeta (mesma em chão, cenário e modelos): Tarhut vinho-violeta, Valak azul-violeta
const PLANET_SHADOW = {"tarhut": Color(0.52, 0.30, 0.52), "valak": Color(0.26, 0.26, 0.66), "abnara": Color(0.30, 0.34, 0.62), "goraida": Color(0.36, 0.46, 0.80)}
# luz do sol e do ambiente de cada planeta: [cor do sol, energia, cor ambiente]
const PLANET_LIGHT = {"tarhut": [Color("#ffe2bc"), 0.62, Color("#d8b8d8")], "goraida": [Color("#f2f6ff"), 0.58, Color("#b8cdf2")], "abnara": [Color("#fff4d8"), 0.55, Color("#c4d0f0")]}
var tex_mats: Dictionary = {}


# perspectiva atmosférica (guache): o fundo esfria e some numa névoa azul-violeta; só em planetas com ar
func _apply_atmosphere() -> void:
	var fog = {"abnara": [Color("#6f7bb8"), 0.0085], "tarhut": [Color("#c98aa8"), 0.0075], "goraida": [Color("#9fb8e8"), 0.009], "posto": [Color("#3a3a9a"), 0.012]}
	if g != null and fog.has(g.map_id):
		env.fog_enabled = true
		env.fog_light_color = fog[g.map_id][0]
		env.fog_density = fog[g.map_id][1]
		env.fog_sky_affect = 0.0
	else:
		env.fog_enabled = false


func _planet_shadow() -> Color:
	return PLANET_SHADOW.get(g.map_id if g != null else "", Color(0.5, 0.4, 0.68))


# aplica a sombra do planeta em todos os materiais de quadrinho já criados
func _apply_planet_tint() -> void:
	var c = _planet_shadow()
	var mats = [tile_mat, ground.material_override if ground != null else null, prop_mat, paint_mat]
	mats.append_array(tex_mats.values())
	for m in mats:
		if m is ShaderMaterial:
			m.set_shader_parameter("shadow_tint", c)


func _tex_mat(t: Texture2D) -> ShaderMaterial:
	if not tex_mats.has(t):
		var m = ShaderMaterial.new()
		m.shader = load("res://shaders/hq_tex.gdshader")
		m.set_shader_parameter("tex", t)
		m.set_shader_parameter("shadow_tint", _planet_shadow())
		tex_mats[t] = m
	return tex_mats[t]


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


# peças feitas de formas simples ficam pintadas em guache: manchas de hexágonos em 3 tons da própria cor
var paint_cols: Dictionary = {}


func _gouache(col: Color) -> ShaderMaterial:
	var key = col.to_html(false)
	if not paint_cols.has(key):
		var m = ShaderMaterial.new()
		m.shader = load("res://shaders/pincel.gdshader")
		m.set_shader_parameter("seed", float(key.hash() % 97))
		m.set_shader_parameter("c_dark", col.darkened(0.22))
		m.set_shader_parameter("c_mid", col)
		m.set_shader_parameter("c_light", col.lightened(0.16))
		m.set_shader_parameter("edge", 0.0)
		m.set_shader_parameter("patch_scale", 4.5)
		m.set_shader_parameter("shadow_tint", _planet_shadow())
		paint_cols[key] = m
	return paint_cols[key]


func _mesh(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _gouache(col) if (g != null and g.map_id != "abnara" and col.a > 0.99) else _mat(col)
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
var terr_mats: Dictionary = {}
var swirl_nodes: Array = []
var mark_tex: Texture2D = null
var warn_tiles: Dictionary = {}
var warn_tex_cache: Texture2D = null


# balão de HQ para os avisos: estrela amarela com contorno grosso, retícula no canto e "!" em tinta
func _warn_tex() -> Texture2D:
	if warn_tex_cache != null:
		return warn_tex_cache
	var S = 192
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	var ink = Color("#1a0e14")
	var fill = Color("#ffc928")
	var shade = Color("#f08a14")
	var half = S * 0.5
	var N = 9.0
	for py in range(S):
		for px in range(S):
			var x = (px + 0.5 - half) / half
			var y = (py + 0.5 - half) / half
			var d = sqrt(x * x + y * y)
			var th = atan2(y, x) + PI / 2.0
			var tri = abs(fposmod(th * N / TAU, 1.0) * 2.0 - 1.0)
			var rr = lerp(0.56, 0.96, pow(1.0 - tri, 1.4))
			if d > rr:
				continue
			var c = fill
			# retícula de HQ no lado de baixo
			if x * 0.5 + y * 0.9 > 0.12:
				var gx = fposmod(px, 12.0) - 6.0
				var gy = fposmod(py + (6 if int(px / 12.0) % 2 == 1 else 0), 12.0) - 6.0
				var rad = clamp((x * 0.5 + y * 0.9 - 0.12) * 5.0, 0.0, 1.0) * 4.2
				if gx * gx + gy * gy < rad * rad:
					c = shade
			if d > rr - 0.085:
				c = ink
			# o "!" em tinta, com a base mais grossa que o topo
			var bar_w = lerp(0.075, 0.15, clamp((y + 0.5) / 0.55, 0.0, 1.0))
			if y > -0.5 and y < 0.1 and abs(x) < bar_w:
				c = ink
			var dd = Vector2(x, y - 0.33).length()
			if dd < 0.115:
				c = ink
			img.set_pixel(px, py, c)
	warn_tex_cache = ImageTexture.create_from_image(img)
	return warn_tex_cache


func _terr_mat(path: String) -> Material:
	if not terr_mats.has(path):
		if not ResourceLoader.exists(path):
			terr_mats[path] = null
		else:
			var m = StandardMaterial3D.new()
			m.albedo_texture = load(path)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.4
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			terr_mats[path] = m
	return terr_mats[path]


func _crack_mat(i: int) -> Material:
	if crack_mats.is_empty():
		for k in range(9):
			var path = ("res://ui/terreno/rachadura_%d.png" % k) if k < 3 else ("res://ui/terreno/rachadura_gelo_%d.png" % (k - 3)) if k < 6 else ("res://ui/terreno/rachadura_gelo_linha_%d.png" % (k - 6))
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


func _crack_decal(root: Node3D, h: Vector2i, idx: int, size: float, y: float = 0.02) -> void:
	var cm = _crack_mat(idx)
	if cm == null:
		return
	var qd = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(size, size)
	qd.mesh = pm
	qd.material_override = cm
	qd.position = Vector3(0, y, 0)
	qd.rotation = Vector3(0, int(_rnd(h, 22) * 6) * PI / 3.0, 0)
	qd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(qd)


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
	if _wild_props(root, h, t["k"]):
		return
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
			# redemoinho pintado no estilo HQ (tools/marcas.py), girando devagar
			var qm = _terr_mat("res://ui/terreno/movedica.png")
			if qm != null:
				var qd2 = MeshInstance3D.new()
				var pm3 = PlaneMesh.new()
				pm3.size = Vector2(1.96, 1.96)
				qd2.mesh = pm3
				qd2.material_override = qm
				qd2.position = Vector3(0, 0.025, 0)
				qd2.rotation = Vector3(0, _rnd(h, 23) * TAU, 0)
				qd2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(qd2)
				swirl_nodes = swirl_nodes.filter(func(x): return is_instance_valid(x))
				swirl_nodes.append(qd2)
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
		inst.scale = Vector3.ONE * 1.35     # auditoria: maior, para não se perder no laranja
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
		gr.set_color(0, Color(0.35, 1.0, 0.5, 0.5))
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
	q.size = Vector2(1.9, 1.9)
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
	var anel = MeshInstance3D.new()
	anel.mesh = _hex_ring(0.62, 0.5)
	anel.material_override = _neon(Color("#5dff7a"), 0.85, 1.4)
	anel.position = Vector3(0, -0.3, 0)
	holder.add_child(anel)
	# pulsa o brilho e balança o besouro
	var tw = halo.create_tween().set_loops()
	tw.tween_property(halo, "scale", Vector3(1.12, 1.12, 1.12), 0.9).set_trans(Tween.TRANS_SINE)
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
var prop_mat: Material = null
var paint_mat: ShaderMaterial = null
var outline_cache: Dictionary = {}


func _paint_mat() -> ShaderMaterial:
	if paint_mat == null:
		paint_mat = ShaderMaterial.new()
		paint_mat.shader = load("res://shaders/pintado.gdshader")
		paint_mat.set_shader_parameter("shadow_tint", _planet_shadow())
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
		for mi in meshes:
			for si in range(mi.mesh.get_surface_count()):
				var sm = mi.mesh.surface_get_material(si)
				if sm is BaseMaterial3D and sm.albedo_texture != null:
					mi.set_surface_override_material(si, _tex_mat(sm.albedo_texture))
	if toon:
		if prop_mat == null:
			prop_mat = _hq_mat()
			if prop_mat is ShaderMaterial:
				prop_mat.set_shader_parameter("gamma", 2.2)
				prop_mat.set_shader_parameter("shadow_tint", _planet_shadow())
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
		mi.material_overlay = null  # cores chapadas, sem contorno
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
	isl.material_overlay = null  # cores chapadas, sem contorno
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
				sl.material_overlay = null  # cores chapadas, sem contorno
			for sx in [-0.2, 0.2]:
				_mesh(seg, _box(Vector3(0.05, 0.06, L + 0.02)), steel, Vector3(sx, 0.04, L * 0.5))


# bananas do Karo: cada uma com a cor do bônus (verde cura, vermelho força, azul mira)
var banana_nodes: Dictionary = {}
var hover_seen: Variant = null
var core_node: Node3D = null
var core_next_node: Node3D = null
var core_at: Variant = null
var core_next_at: Variant = null


# HEX ENERGY: hexágono roxo neon que flutua, gira e pulsa, com coluna de luz e zumbido;
# o próximo local aparece como um contorno roxo fantasma que pulsa devagar
const HEX_ROXO = Color("#9d2cff")
const HEX_ROXO_CLARO = Color("#d48cff")
const HEX_ROXO_ESCURO = Color("#4a0e8f")


func _hex_ring(r_out: float, r_in: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in range(6):
		var a1 = TAU / 6 * k
		var a2 = TAU / 6 * (k + 1)
		var o1 = Vector3(cos(a1), 0, sin(a1))
		var o2 = Vector3(cos(a2), 0, sin(a2))
		st.add_vertex(o1 * r_in)
		st.add_vertex(o1 * r_out)
		st.add_vertex(o2 * r_out)
		st.add_vertex(o1 * r_in)
		st.add_vertex(o2 * r_out)
		st.add_vertex(o2 * r_in)
	return st.commit()


func _neon(c: Color, alpha: float = 1.0, energia: float = 2.5) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c, alpha)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energia
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA     # mistura normal: o roxo fica roxo em qualquer chão
	return m


func _hex_energy_node(h: Vector2i) -> Node3D:
	var n = Node3D.new()
	n.position = Vector3(world_xz(h).x, top_y(h), world_xz(h).y)
	n.scale = Vector3.ONE * HX
	scenery_root.add_child(n)
	# casa inteira acesa: aro neon na borda e miolo translúcido
	var aro = MeshInstance3D.new()
	aro.mesh = _hex_ring(TILE * 0.98, TILE * 0.8)
	aro.material_override = _neon(HEX_ROXO, 1.0, 1.4)
	aro.position.y = 0.12
	aro.name = "aro"
	n.add_child(aro)
	var miolo = MeshInstance3D.new()
	miolo.mesh = _disc(TILE * 0.8, 6)
	miolo.material_override = _neon(HEX_ROXO_ESCURO, 0.5, 0.8)
	miolo.position.y = 0.11
	miolo.name = "miolo"
	n.add_child(miolo)
	# onda que sai do centro a cada pulso
	if DB.maps[g.map_id].get("cave", false):
		# Valak é roxo: uma borda clara por fora para a Hex Energy não sumir no chão
		var borda_v = MeshInstance3D.new()
		borda_v.mesh = _hex_ring(TILE * 1.08, TILE * 0.98)
		borda_v.material_override = _neon(Color("#fff4ff"), 1.0, 1.6)
		borda_v.position.y = 0.125
		n.add_child(borda_v)
	var onda = MeshInstance3D.new()
	onda.mesh = _hex_ring(TILE * 0.5, TILE * 0.42)
	onda.material_override = _neon(HEX_ROXO_CLARO, 0.8, 1.2)
	onda.position.y = 0.13
	onda.name = "onda"
	n.add_child(onda)
	# o hexágono flutuante: cristal de 6 faces em pé (visto de cima é um hexágono) + casca translúcida
	var cris = Node3D.new()
	cris.name = "cristal"
	cris.position.y = 1.3
	n.add_child(cris)
	var corpo = MeshInstance3D.new()
	corpo.mesh = _cyl(0.42, 0.42, 0.5, 6)
	corpo.material_override = _neon(Color("#b44cff"), 1.0, 1.6)
	cris.add_child(corpo)
	for sy in [1.0, -1.0]:
		var ponta = MeshInstance3D.new()
		ponta.mesh = _cyl(0.0, 0.42, 0.42, 6)
		ponta.material_override = _neon(HEX_ROXO_CLARO, 1.0, 1.4)
		ponta.position.y = 0.46 * sy
		if sy < 0:
			ponta.rotation.x = PI
		cris.add_child(ponta)
	var casca = MeshInstance3D.new()
	casca.mesh = _cyl(0.6, 0.6, 0.7, 6)
	casca.material_override = _neon(HEX_ROXO, 0.35, 1.0)
	casca.name = "casca"
	cris.add_child(casca)
	# coluna de luz: dá para achar a Hex Energy de qualquer canto do mapa
	var feixe = MeshInstance3D.new()
	feixe.mesh = _cyl(0.4, 0.6, 7.0, 6)
	feixe.material_override = _neon(HEX_ROXO, 0.2, 1.0)
	feixe.position.y = 3.5
	feixe.name = "feixe"
	n.add_child(feixe)
	var lt = OmniLight3D.new()
	lt.light_color = HEX_ROXO
	lt.light_energy = 2.0
	lt.omni_range = 3.4
	lt.position = Vector3(0, 0.9, 0)
	lt.name = "luz"
	n.add_child(lt)
	# zumbido no lugar (some com a distância)
	var som = AudioStreamPlayer3D.new()
	if ResourceLoader.exists("res://sounds/hex_energy_loop.wav"):
		var st: AudioStreamWAV = load("res://sounds/hex_energy_loop.wav")
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = int(st.get_length() * st.mix_rate)
		som.stream = st
		som.bus = "Efeitos"
		som.volume_db = -6.0
		som.unit_size = 6.0
		som.max_distance = 40.0
		som.autoplay = true
		n.add_child(som)
	return n


func sync_core(c: Variant, nxt: Variant) -> void:
	if c != core_at:
		if core_node != null:
			core_node.queue_free()
			core_node = null
		core_at = c
		if c != null and tiles.has(c):
			core_node = _hex_energy_node(c)
	if nxt != core_next_at:
		if core_next_node != null:
			core_next_node.queue_free()
			core_next_node = null
		core_next_at = nxt
		if nxt != null and tiles.has(nxt):
			core_next_node = Node3D.new()
			core_next_node.position = Vector3(world_xz(nxt).x, top_y(nxt) + 0.11, world_xz(nxt).y)
			core_next_node.scale = Vector3.ONE * HX
			scenery_root.add_child(core_next_node)
			var gr = MeshInstance3D.new()
			gr.mesh = _hex_ring(TILE * 0.95, TILE * 0.82)
			gr.material_override = _neon(HEX_ROXO, 0.6, 1.0)
			gr.name = "aro"
			core_next_node.add_child(gr)
			var gm = MeshInstance3D.new()
			gm.mesh = _disc(TILE * 0.82, 6)
			gm.material_override = _neon(HEX_ROXO_ESCURO, 0.25, 0.6)
			core_next_node.add_child(gm)


func _pulse_hex_energy() -> void:
	var t = Time.get_ticks_msec() / 1000.0
	var p = pow(0.5 + 0.5 * cos(TAU * t / 0.8), 3.0)      # mesmo ritmo do zumbido (0,8 s)
	if core_node != null and is_instance_valid(core_node):
		var cris = core_node.get_node("cristal")
		cris.position.y = 1.3 + sin(t * 2.2) * 0.1
		cris.rotation.y = t * 1.3
		cris.scale = Vector3.ONE * (1.0 + 0.1 * p)
		core_node.get_node("aro").material_override.emission_energy_multiplier = 1.0 + 1.6 * p
		core_node.get_node("miolo").material_override.albedo_color.a = 0.35 + 0.3 * p
		core_node.get_node("feixe").material_override.albedo_color.a = 0.12 + 0.14 * p
		core_node.get_node("luz").light_energy = 1.4 + 2.0 * p
		var fase = fmod(t, 0.8) / 0.8
		var onda = core_node.get_node("onda")
		onda.scale = Vector3.ONE * (0.6 + 1.5 * fase)
		onda.material_override.albedo_color.a = 0.8 * (1.0 - fase)
	if core_next_node != null and is_instance_valid(core_next_node):
		var q = 0.5 + 0.5 * sin(t * 2.4)
		core_next_node.get_node("aro").material_override.albedo_color.a = 0.25 + 0.4 * q


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
			seg.material_overlay = null  # cores chapadas, sem contorno
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


# ---- armadilhas visíveis no terreno: modelo 3D flutuando na casa até explodir ----
# lista de {"k": chave única, "h": casa, "m": "mina" | "dinamite"}
const TRAP_MODELS = {
	"mina": {"cena": "res://models/aby_mina/mina.scn", "escala": 0.5, "y": 1.05, "cor": Color("#a957ec"), "giro": 18.0},
	"dinamite": {"cena": "res://models/dinamite/dinamite_leve.scn", "escala": 0.55, "y": 1.15, "cor": Color("#ff7a2a"), "giro": 0.0},
}
var trap_nodes: Dictionary = {}
var _trap_scenes: Dictionary = {}


func _trap_scene(path: String) -> PackedScene:
	if not _trap_scenes.has(path):
		_trap_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _trap_scenes[path]


func sync_traps(list: Array) -> void:
	var vivos = {}
	for t in list:
		vivos[t["k"]] = t
	for k in trap_nodes.keys():
		if not vivos.has(k):
			var n: Node3D = trap_nodes[k]
			trap_nodes.erase(k)
			var tw = n.create_tween()
			tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.12)
			tw.tween_callback(n.queue_free)
	for k in vivos.keys():
		var t = vivos[k]
		var h: Vector2i = t["h"]
		if not tiles.has(h):
			continue
		var base_y = top_y(h) + 0.05
		if trap_nodes.has(k):
			trap_nodes[k].position.y = base_y
			continue
		var cfg = TRAP_MODELS.get(t["m"], null)
		if cfg == null:
			continue
		var ps = _trap_scene(cfg["cena"])
		if ps == null:
			continue
		var n = Node3D.new()
		n.position = Vector3(world_xz(h).x, base_y, world_xz(h).y)
		scenery_root.add_child(n)
		# brilho no chão marcando a casa
		var col: Color = cfg["cor"]
		var ring = _mesh(n, _disc(0.62, 24), col, Vector3(0, 0.02, 0))
		ring.material_override = _mat(Color(col.lightened(0.15), 0.6), true)
		ring.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_overlay = null
		var rt = ring.create_tween().set_loops()
		rt.tween_property(ring, "scale", Vector3(1.15, 1, 1.15), 0.7).set_trans(Tween.TRANS_SINE)
		rt.tween_property(ring, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_SINE)
		# o modelo: cai do alto, para no ar e fica flutuando e balançando
		var bob = Node3D.new()
		n.add_child(bob)
		var m: Node3D = ps.instantiate()
		m.scale = Vector3.ONE * float(cfg["escala"])
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bob.add_child(m)
		var fy = float(cfg["y"])
		bob.position.y = fy + 2.6
		var tw = bob.create_tween()
		tw.tween_property(bob, "position:y", fy, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			var lp = bob.create_tween().set_loops()
			lp.tween_property(bob, "position:y", fy + 0.09, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			lp.tween_property(bob, "position:y", fy - 0.05, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))
		var g = float(cfg["giro"])
		if g > 0.0:
			var sp = m.create_tween().set_loops()
			sp.tween_property(m, "rotation:y", TAU, 360.0 / g).from(0.0)
		else:
			# dinamite: balança de leve, como um pavio prestes a acabar
			var sw = m.create_tween().set_loops()
			sw.tween_property(m, "rotation:z", 0.12, 0.5).set_trans(Tween.TRANS_SINE)
			sw.tween_property(m, "rotation:z", -0.12, 0.5).set_trans(Tween.TRANS_SINE)
		trap_nodes[k] = n


# ---- símbolos no chão sob uma peça, girando devagar ----
# bleed: Sangramento do Comandante Krieg (vermelho); amark: Marca Abyssal do Klang (roxo, gira ao contrário)
const GROUND_MARKS = {
	"bleed": {"tex": "res://vfx/tex/krieg_simbolo_chao", "cor": "#ff2434", "giro": 9.0, "tam": 2.15},
	"amark": {"tex": "res://vfx/tex/simbolo_aby_chao", "cor": "#c86bff", "giro": -12.0, "tam": 1.9},
}
var bleed_nodes: Dictionary = {}   # "tipo:uid" -> Node3D
var _gm_mats: Dictionary = {}


func _gm_mat(kind: String, i: int) -> StandardMaterial3D:
	var key = "%s%d" % [kind, i]
	if not _gm_mats.has(key):
		var cfg = GROUND_MARKS[kind]
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(0.06, 0.0, 0.04, 0.92) if i == 0 else Color(cfg["cor"])
		var path = cfg["tex"] + ("_sombra.png" if i == 0 else ".png")
		m.albedo_texture = load(path) if ResourceLoader.exists(path) else null
		m.render_priority = 2
		_gm_mats[key] = m
	return _gm_mats[key]


func sync_bleeds(list: Array) -> void:
	sync_ground_marks("bleed", list)


func sync_ground_marks(kind: String, list: Array) -> void:
	var cfg = GROUND_MARKS[kind]
	var vivos = {}
	for t in list:
		vivos["%s:%d" % [kind, int(t["uid"])]] = t["h"]
	for key in bleed_nodes.keys():
		if str(key).begins_with(kind + ":") and not vivos.has(key):
			var n: Node3D = bleed_nodes[key]
			bleed_nodes.erase(key)
			var tw = n.create_tween()
			tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.25)
			tw.tween_callback(n.queue_free)
	for key in vivos.keys():
		var h: Vector2i = vivos[key]
		if not tiles.has(h):
			continue
		var at = Vector3(world_xz(h).x, top_y(h) + (0.07 if kind == "bleed" else 0.09), world_xz(h).y)
		if bleed_nodes.has(key):
			var n0: Node3D = bleed_nodes[key]
			if n0.position.distance_to(at) > 0.01:
				n0.create_tween().tween_property(n0, "position", at, 0.3)
			continue
		var n = Node3D.new()
		n.position = at
		scenery_root.add_child(n)
		var spin = Node3D.new()
		n.add_child(spin)
		for i in range(2):
			var q = MeshInstance3D.new()
			var qm = QuadMesh.new()
			qm.size = Vector2.ONE * float(cfg["tam"]) * (1.0 if i == 0 else 0.9)
			qm.orientation = PlaneMesh.FACE_Y
			q.mesh = qm
			q.material_override = _gm_mat(kind, i)
			q.position.y = 0.005 * i
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			spin.add_child(q)
		n.set_meta("spin", spin)
		var g = float(cfg["giro"])
		var sp = spin.create_tween().set_loops()
		sp.tween_property(spin, "rotation:y", TAU * sign(g), abs(g)).from(0.0)
		n.scale = Vector3.ONE * 0.01
		n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bleed_nodes[key] = n


# quando o efeito acontece: o símbolo dá um pulo leve e cresce um pouco
func bleed_pop(h: Vector2i, kind: String = "bleed") -> void:
	for key in bleed_nodes:
		if not str(key).begins_with(kind + ":"):
			continue
		var n: Node3D = bleed_nodes[key]
		if Vector2(n.position.x, n.position.z).distance_to(world_xz(h)) < 0.3:
			var spin: Node3D = n.get_meta("spin")
			var tw = spin.create_tween().set_parallel(true)
			tw.tween_property(spin, "position:y", 0.32, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(spin, "scale", Vector3.ONE * 1.3, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.chain().tween_property(spin, "position:y", 0.0, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_property(spin, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---- Estrela Hexa (Esterina): casas da estrela brilhando em dourado ----
var star_nodes: Dictionary = {}


func sync_stars(list: Array) -> void:
	sync_zones("star", list, Color(1.0, 0.74, 0.18, 0.55), Color(1.0, 0.95, 0.7, 0.85))


# Cortina de Tinta (Inkshadow): rastro de tinta escura com borda roxa
func sync_inks(list: Array) -> void:
	sync_zones("ink", list, Color(0.08, 0.04, 0.16, 0.72), Color(0.66, 0.34, 0.95, 0.9))


func sync_zones(kind: String, list0: Array, cor: Color, cor_borda: Color) -> void:
	var list = list0.map(func(z): return {"k": kind + ":" + str(z["k"]), "hexes": z["hexes"]})
	var vivos = {}
	for st in list:
		vivos[str(st["k"])] = st["hexes"]
	for k in star_nodes.keys():
		if str(k).begins_with(kind + ":") and not vivos.has(k):
			var n: Node3D = star_nodes[k]
			star_nodes.erase(k)
			var tw = n.create_tween()
			tw.tween_property(n, "scale", Vector3(1, 0.01, 1), 0.3)
			tw.tween_callback(n.queue_free)
	for k in vivos.keys():
		if star_nodes.has(k):
			continue
		var root = Node3D.new()
		scenery_root.add_child(root)
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = cor
		mat.render_priority = 1
		var borda = StandardMaterial3D.new()
		borda.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		borda.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		borda.albedo_color = cor_borda
		borda.render_priority = 1
		var i = 0
		for h in vivos[k]:
			if not tiles.has(h):
				continue
			var at = Vector3(world_xz(h).x, top_y(h) + 0.05, world_xz(h).y)
			var hexm = _mesh(root, _disc(0.86, 6), Color.WHITE, at)
			hexm.rotation.y = PI / 6.0
			hexm.material_override = mat
			var anel = _mesh(root, _disc(0.94, 6), Color.WHITE, at - Vector3(0, 0.005, 0))
			anel.rotation.y = PI / 6.0
			anel.material_override = borda
			anel.scale = Vector3.ONE
			var tw = hexm.create_tween().set_loops()
			tw.tween_interval(0.08 * i)
			tw.tween_property(hexm, "scale", Vector3(1.08, 1, 1.08), 0.9).set_trans(Tween.TRANS_SINE)
			tw.tween_property(hexm, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_SINE)
			i += 1
		root.scale = Vector3(1, 0.01, 1)
		root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		star_nodes[k] = root


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
var tunnel_nodes: Dictionary = {}


# entradas dos túneis do Rei da Mina: visíveis para os dois jogadores
func _sync_tunnels() -> void:
	var want = {}
	for t in g.tunnels:
		want[t["a"]] = "TÚNEL"
		want[t["b"]] = "TÚNEL"
	for pt in g.live_portals():
		want[pt["a"]] = "ENTRADA"
		want[pt["b"]] = "SAÍDA"
	for h in tunnel_nodes.keys():
		if not want.has(h):
			tunnel_nodes[h].queue_free()
			tunnel_nodes.erase(h)
	for h in want.keys():
		if tunnel_nodes.has(h) and String(tunnel_nodes[h].get_meta("kind", "")) == String(want[h]):
			continue
		if tunnel_nodes.has(h):
			tunnel_nodes[h].queue_free()
			tunnel_nodes.erase(h)
		var n = Node3D.new()
		add_child(n)
		var wp = world_xz(h)
		n.position = Vector3(wp.x, top_y(h) + 0.03, wp.y)
		var hole_d = MeshInstance3D.new()
		hole_d.mesh = _disc(INNER * 0.6 * HX, 24)
		hole_d.material_override = _mat(Color("#07030c"), true)
		n.add_child(hole_d)
		var ring = MeshInstance3D.new()
		ring.mesh = _hex_band(INNER * 0.82 * HX, INNER * 0.62 * HX, Color("#0a0410"), 0.04)
		ring.material_override = _mat({"TÚNEL": Color("#ffd37a"), "ENTRADA": Color("#5ad7ff"), "SAÍDA": Color("#ff9a3a")}[String(want[h])], true)
		ring.material_override.vertex_color_use_as_albedo = true
		ring.position = Vector3(0, 0.02, 0)
		n.add_child(ring)
		var lab = Label3D.new()
		n.set_meta("kind", String(want[h]))
		lab.text = String(want[h])
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.font_size = 40
		lab.outline_size = 12
		lab.pixel_size = 0.006
		lab.modulate = {"TÚNEL": Color("#ffe39a"), "ENTRADA": Color("#8fe6ff"), "SAÍDA": Color("#ffb868")}[String(want[h])]
		lab.font_size = 56 if String(want[h]) != "TÚNEL" else 40
		lab.position = Vector3(0, 0.7, 0)
		n.add_child(lab)
		tunnel_nodes[h] = n


func sync_units() -> void:
	if g == null:
		return
	var seen = {}
	for u in g.units:
		if u.st != "field":
			continue
		seen[u.uid] = true
		if unit_nodes.has(u.uid) and u.crystal != "" and String(unit_nodes[u.uid].get("ckey", "")) != "%s%d" % [u.crystal, u.sp_owner]:
			unit_nodes[u.uid]["node"].queue_free()
			unit_nodes.erase(u.uid)
		if not unit_nodes.has(u.uid):
			_make_unit(u)
	_sync_tunnels()
	for uid in unit_nodes.keys():
		if not seen.has(uid):
			var n = unit_nodes[uid]
			n["node"].queue_free()
			unit_nodes.erase(uid)


func _unit_fac_col(u) -> Color:
	if u.barrier or u.crystal != "" or not DB.cards.has(u.cid):
		return Color("#d9c9a8")
	var f = DB.cards[u.cid]["f"]
	return DB.pal(f, "primary")


# faixa hexagonal (orientação igual à das casas): parte de fora em tinta, o resto branco
# (o material tinge a faixa com a cor da facção)
func _hex_band(ro: float, ri: float, ink: Color, ink_w: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var rm = ro - ink_w
	for band in [[ro, rm, ink], [rm, ri + ink_w * 0.6, Color.WHITE], [ri + ink_w * 0.6, ri, ink]]:
		for k in range(6):
			var a1 = PI / 3.0 * k
			var a2 = PI / 3.0 * (k + 1)
			var o1 = Vector3(cos(a1), 0, sin(a1)) * band[0]
			var o2 = Vector3(cos(a2), 0, sin(a2)) * band[0]
			var i1 = Vector3(cos(a1), 0, sin(a1)) * band[1]
			var i2 = Vector3(cos(a2), 0, sin(a2)) * band[1]
			_tri(st, o1, band[2], o2, band[2], i2, band[2])
			_tri(st, o1, band[2], i2, band[2], i1, band[2])
	return st.commit()


# camada 2 = personagens: a máscara do efeito RGB só enxerga essa camada
func _mask_layer(n: Node) -> void:
	if n is VisualInstance3D:
		n.layers = n.layers | 2
	for c in n.get_children():
		_mask_layer(c)


func _make_unit(u) -> void:
	var node = Node3D.new()
	add_child(node)
	var sc = 0.75 if u.barrier else (1.15 if BIG.has(u.cid) else (1.08 if u.is_cmd else 1.0))
	if HX > 1.0:
		sc *= HX * 1.15      # casas mais largas: personagens maiores para continuarem fáceis de ver
	# base hexagonal do tamanho da casa, na cor principal da facção: preenchimento translúcido,
	# aro grosso na cor e contorno de tinta (estilo HQ)
	var fcol = _unit_fac_col(u)
	var shadow = MeshInstance3D.new()
	shadow.mesh = _disc(INNER * 0.97 * HX, 6)
	shadow.material_override = _overlay_mat(Color(fcol.r, fcol.g, fcol.b, 0.30))
	shadow.position = Vector3(0, 0.02, 0)
	node.add_child(shadow)
	var ring = MeshInstance3D.new()
	ring.mesh = _hex_band(INNER * 0.97 * HX, INNER * 0.80 * HX, Color("#0a0410"), 0.045)
	ring.material_override = _mat(fcol, true)
	ring.material_override.vertex_color_use_as_albedo = true
	ring.position = Vector3(0, 0.035, 0)
	node.add_child(ring)
	ring.set_meta("fcol", fcol)
	var sprite: Variant = null
	var body_h = 1.75 * sc
	if u.crystal != "":
		shadow.visible = false
		ring.visible = false
		if u.sp_owner >= 0:
			ring.visible = true
			ring.material_override = _mat(Color("#ffe08a"), true)
			ring.material_override.vertex_color_use_as_albedo = true
		_crystal_cluster(node, u.crystal, u.uid)
		body_h = 1.6
	elif u.barrier:
		_mesh(node, _cyl(0.4, 0.5, 0.7, 6), Color("#6d6250"), Vector3(0, 0.35, 0))
		body_h = 0.8
	elif FIG3D.has(u.cid) and ResourceLoader.exists(FIG3D[u.cid]["path"]):
		sprite = _figure3d(u.cid, body_h)
		node.add_child(sprite)
		_mask_layer(sprite)
	elif DB.art.has(u.cid):
		sprite = _figure(u.cid, body_h)
		node.add_child(sprite)
		_mask_layer(sprite)
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
		"top": body_h, "hex": u.pos(), "path": [], "seg_t": 0.0, "from": start, "pop": 0.0, "flip": u.owner == 1, "bob": randf() * TAU, "hurt": 0.0, "lunge": 0.0, "ckey": "%s%d" % [u.crystal, u.sp_owner]}


# personagem: a arte num cartão que encara a câmera, com as cores originais e sombra no chão
# coluna de luz hexagonal sobre a casa do personagem selecionado (aditiva, some no alto)
var beam_tex: GradientTexture2D = null


func _sel_beam(fc: Color) -> MeshInstance3D:
	if beam_tex == null:
		beam_tex = GradientTexture2D.new()
		var gr = Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		beam_tex.gradient = gr
		beam_tex.fill_from = Vector2(0, 1)
		beam_tex.fill_to = Vector2(0, 0)
		beam_tex.width = 4
		beam_tex.height = 64
	var b = MeshInstance3D.new()
	var bm = _cyl(INNER * 0.9, INNER * 0.9, 2.6, 6)
	bm.cap_top = false
	bm.cap_bottom = false
	b.mesh = bm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = beam_tex
	m.albedo_color = Color(fc.r, fc.g, fc.b, 0.3)
	b.material_override = m
	b.position = Vector3(0, 1.3, 0)
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return b


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
	# contorno de seleção (escondido até o personagem ser escolhido)
	if ResourceLoader.exists("res://shaders/contorno_sel.gdshader"):
		var ol = MeshInstance3D.new()
		ol.name = "contorno"
		ol.mesh = q
		var om = ShaderMaterial.new()
		om.shader = load("res://shaders/contorno_sel.gdshader")
		om.set_shader_parameter("tex", tex)
		om.set_shader_parameter("center_y", body_h * 0.5)
		om.set_shader_parameter("px", 0.03 / max(asp, 0.4))
		ol.material_override = om
		ol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ol.visible = false
		mi.add_child(ol)
	# Lithari são cristais vivos: uma camada de luz brilha e cintila por cima da arte
	if DB.cards.has(cid) and DB.cards[cid]["f"] == "LIT":
		var br = MeshInstance3D.new()
		br.name = "brilho_lit"
		br.mesh = q
		var bm = ShaderMaterial.new()
		bm.shader = load("res://shaders/lithari_brilho.gdshader")
		bm.set_shader_parameter("tex", tex)
		bm.set_shader_parameter("hi_col", DB.pal("LIT", "highlight", Color(0.85, 0.95, 1.0)))
		bm.set_shader_parameter("fase", randf() * 50.0)
		br.material_override = bm
		br.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(br)
	return mi


func _figure_look(fig: MeshInstance3D, flip: bool, mod: Color) -> void:
	var m: StandardMaterial3D = fig.material_override
	var sx = -1.0 if flip else 1.0
	if m.uv1_scale.x != sx:
		m.uv1_scale = Vector3(sx, 1, 1)
		m.uv1_offset = Vector3(1.0 if flip else 0.0, 0, 0)
	m.albedo_color = mod
	var ol = fig.get_node_or_null("contorno")
	if ol != null:
		ol.material_override.set_shader_parameter("flip", 1.0 if flip else 0.0)
	var br = fig.get_node_or_null("brilho_lit")
	if br != null:
		br.material_override.set_shader_parameter("flip", 1.0 if flip else 0.0)
		br.material_override.set_shader_parameter("mod_col", mod)


# ---------- personagem 3D (modelo com esqueleto Mixamo) ----------
# sombreado de quadrinho (hq_personagem: 2 tons, retícula hexagonal, visor aceso) + contorno de tinta;
# poses feitas no código (respirar, andar, atacar, levar dano), sem arquivos de animação
var _fig3d_glow_tex: GradientTexture2D = null


func _figure3d(cid: String, body_h: float) -> Node3D:
	var root = Node3D.new()
	root.name = "fig3d"
	root.set_meta("fig3d", true)
	var giro = Node3D.new()
	giro.name = "giro"
	root.add_child(giro)
	var cfg: Dictionary = FIG3D[cid]
	var inst: Node3D = load(cfg["path"]).instantiate()
	giro.add_child(inst)
	inst.rotation.y = float(cfg.get("giro", -PI / 2.0))   # o Tripo entrega o boneco olhando para +X; o Meshy/Mixamo já olha para +Z
	var mats: Array = []
	var outl: Array = []
	var hgt = 1.0
	var sk: Skeleton3D = null
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		hgt = max(0.01, mi.mesh.get_aabb().size.y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for si in range(mi.mesh.get_surface_count()):
			var src = mi.mesh.surface_get_material(si)
			var m = ShaderMaterial.new()
			m.shader = load("res://shaders/hq_personagem.gdshader")
			if src is BaseMaterial3D and src.albedo_texture != null:
				m.set_shader_parameter("tex", src.albedo_texture)
			m.set_shader_parameter("glow_on", 1.0 if (cfg.get("visor", false) or cfg.has("brilho")) else 0.0)
			# sombra, padrão de tinta, brilho e contorno nas cores da facção (Manual de VFX e Sombras)
			var fac3: String = DB.cards[cid]["f"] if DB.cards.has(cid) else ""
			m.set_shader_parameter("shadow_tint", DB.pal(fac3, "shadow", Color(0.34, 0.30, 0.55)))
			m.set_shader_parameter("hi_col", DB.pal(fac3, "highlight", Color(1.0, 0.9, 0.7)))
			m.set_shader_parameter("pat", PADROES.find(String(DB.vfx_pal.get(fac3, {}).get("pattern", "reticula"))) if PADROES.has(String(DB.vfx_pal.get(fac3, {}).get("pattern", "reticula"))) else 0)
			if cfg.get("cintila", false):
				m.set_shader_parameter("cintila", 1.0)
			if fac3 == "LIT":
				m.set_shader_parameter("vivo", 1.0)   # Lithari: cristal vivo
			if cfg.get("brilho", "") == "gemas_laranja":
				m.set_shader_parameter("glow_mode", 1.0)
				m.set_shader_parameter("glow_col", Color(1.0, 0.6, 0.1))
			if cfg.get("brilho", "") == "gemas":
				m.set_shader_parameter("glow_mode", 2.0)
				m.set_shader_parameter("glow_col", Color(0.2, 0.95, 1.0))
			if cfg.get("brilho", "") == "rachaduras":
				m.set_shader_parameter("glow_mode", 1.0)
				m.set_shader_parameter("glow_col", Color(1.0, 0.45, 0.08))
			var o = ShaderMaterial.new()
			o.shader = load("res://shaders/hq_contorno3d.gdshader")
			o.set_shader_parameter("ink", DB.pal(DB.cards[cid]["f"] if DB.cards.has(cid) else "", "outline", Color(0.04, 0.016, 0.063)).darkened(0.45))
			if cfg.has("cauda"):
				for mm in [m, o]:
					mm.set_shader_parameter("tail_on", 1.0)
					mm.set_shader_parameter("tail_base", Vector3(cfg["cauda"][0], cfg["cauda"][1], cfg["cauda"][2]))
			m.next_pass = o
			mi.set_surface_override_material(si, m)
			mats.append(m)
			outl.append(o)
	for n in inst.find_children("*", "Skeleton3D", true, false):
		sk = n
		break
	inst.scale = Vector3.ONE * (body_h * 0.9 / hgt) * float(cfg.get("escala", 1.0))
	if sk != null:
		_centra_fig(inst, sk, cfg)
	if cfg.get("corpo", "") == "dragao" and sk != null:
		_dragao_setup(root, sk)
	root.set_meta("mats", mats)
	root.set_meta("outl", outl)
	root.set_meta("pegadas", cfg.get("pegadas", ""))
	# animações que vieram no próprio modelo (Meshy/Mixamo): andar e correr tocam o arquivo; o resto é no código
	if cfg.has("anims"):
		for ap in inst.find_children("*", "AnimationPlayer", true, false):
			var ok = {}
			for k in cfg["anims"].keys():
				var an: String = cfg["anims"][k]
				for nome in ap.get_animation_list():
					if String(nome).ends_with(an):
						ok[k] = nome
						var anm: Animation = ap.get_animation(nome)
						anm.loop_mode = Animation.LOOP_LINEAR
						# anda no lugar: tira o deslocamento do quadril (root motion) que levaria a peça para fora da casa
						for ti in range(anm.get_track_count() - 1, -1, -1):
							if anm.track_get_type(ti) != Animation.TYPE_POSITION_3D or anm.track_get_key_count(ti) < 2:
								continue
							var p0: Vector3 = anm.track_get_key_value(ti, 0)
							var p1: Vector3 = anm.track_get_key_value(ti, anm.track_get_key_count(ti) - 1)
							if Vector2(p1.x - p0.x, p1.z - p0.z).length() > 0.2 or abs(p1.y - p0.y) > 0.2:
								anm.remove_track(ti)
			if not ok.is_empty():
				root.set_meta("anim_p", ap)
				root.set_meta("anim_n", ok)
			break
	if cfg.has("conjura"):
		root.set_meta("conjura", true)
		root.set_meta("cj_t", 0.0)
		root.set_meta("cj_w", 0.0)
	root.set_meta("ink", DB.pal(DB.cards[cid]["f"] if DB.cards.has(cid) else "", "outline", Color(0.04, 0.016, 0.063)).darkened(0.45))
	root.set_meta("sel", false)
	var jt: Dictionary = JEITOS["padrao"].duplicate()
	jt.merge(JEITOS.get(cfg.get("jeito", "padrao"), {}), true)
	root.set_meta("jeito", jt)
	root.set_meta("bracos", cfg.get("bracos", ""))
	root.set_meta("vel", jt["vel"])
	if sk != null:
		var bones = {}
		for nm in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm",
				"LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot", "LeftHand", "RightHand",
				"LeftShoulder", "RightShoulder"]:
			var b = _osso(sk, nm)
			if b >= 0:
				bones[nm] = b
		if bones.has("Head") and bones.has("LeftUpLeg") and bones.has("RightUpLeg"):
			var fw = Vector3(1, 0, 0)
			var lf = _osso(sk, "LeftFoot")
			var lt = _osso(sk, "LeftToeBase")
			if lf >= 0 and lt >= 0:
				var dv = sk.get_bone_global_rest(lt).origin - sk.get_bone_global_rest(lf).origin
				dv.y = 0.0
				if dv.length() > 0.001:
					fw = dv.normalized()
			var up = Vector3.UP
			var left = up.cross(fw).normalized()
			root.set_meta("skel", sk)
			root.set_meta("bones", bones)
			root.set_meta("ax", [fw, left, up])
			if cfg.has("pose_arte"):
				root.set_meta("pose_arte", cfg["pose_arte"])
			# mãos fechadas (punho): cada falange dobra em direção à palma; a palma olha para o corpo
			# "dedos": quanto cada mão fecha (1 = punho, pouco = mão aberta e relaxada)
			var dedos: Dictionary = cfg.get("dedos", {"Left": 1.0, "Right": 1.0} if cfg.get("punho", false) else {})
			for side in dedos.keys():
				var fecha: float = float(dedos[side])
				var palm = -left if side == "Left" else left
				for fg in [["Index", 1.25], ["Middle", 1.35], ["Ring", 1.35], ["Pinky", 1.3], ["Thumb", 0.55]]:
					for j in range(1, 4):
						var b = _osso(sk, "%sHand%s%d" % [side, fg[0], j])
						var c = _osso(sk, "%sHand%s%d" % [side, fg[0], j + 1])
						if b < 0 or c < 0:
							continue
						var dv = (sk.get_bone_global_rest(c).origin - sk.get_bone_global_rest(b).origin).normalized()
						var ax_c = dv.cross(palm)
						if ax_c.length() < 0.01:
							continue
						var ang = fg[1] * (0.6 if (fg[0] == "Thumb" and j == 1) else 1.0) * fecha
						sk.set_bone_pose_rotation(b, sk.get_bone_rest(b).basis.get_rotation_quaternion() * _fig3d_q(sk, b, ax_c.normalized(), ang))
			# conjurar: mãos abertas, dedos esticados e afastados (controla os cristais)
			if cfg.has("conjura"):
				var garra = []
				for side in ["Left", "Right"]:
					var palm = -left if side == "Left" else left
					var sg = 1.0 if side == "Left" else -1.0
					for fg in [["Index", [0.05, 0.12, 0.08], -0.3], ["Middle", [0.06, 0.12, 0.08], -0.08],
							["Ring", [0.1, 0.16, 0.1], 0.14], ["Pinky", [0.14, 0.2, 0.12], 0.34], ["Thumb", [0.0, 0.1, 0.08], 0.5]]:
						for j in range(1, 4):
							var b = _osso(sk, "%sHand%s%d" % [side, fg[0], j])
							var c = _osso(sk, "%sHand%s%d" % [side, fg[0], j + 1])
							if b < 0 or c < 0:
								continue
							var dv = (sk.get_bone_global_rest(c).origin - sk.get_bone_global_rest(b).origin).normalized()
							var ax_c = dv.cross(palm)
							if ax_c.length() < 0.01:
								continue
							garra.append([b, ax_c.normalized(), fg[1][j - 1], palm, fg[2] * sg if j == 1 else 0.0])
				root.set_meta("garra", garra)
			if cfg.get("visor", false):
				# visor aceso: brilho aditivo preso à cabeça (o shader acende a textura; isto dá o halo)
				if _fig3d_glow_tex == null:
					_fig3d_glow_tex = GradientTexture2D.new()
					var gr = Gradient.new()
					gr.set_color(0, Color(1, 1, 1, 1))
					gr.set_color(1, Color(1, 1, 1, 0))
					gr.add_point(0.35, Color(1, 1, 1, 0.45))
					_fig3d_glow_tex.gradient = gr
					_fig3d_glow_tex.fill = GradientTexture2D.FILL_RADIAL
					_fig3d_glow_tex.fill_from = Vector2(0.5, 0.5)
					_fig3d_glow_tex.fill_to = Vector2(1.0, 0.5)
					_fig3d_glow_tex.width = 64
					_fig3d_glow_tex.height = 64
				var hb = bones["Head"]
				var att = BoneAttachment3D.new()
				att.bone_idx = hb
				sk.add_child(att)
				var hg = sk.get_bone_global_rest(hb)
				var vp = hg.origin + fw * 0.075 + up * 0.03
				# duas camadas aditivas: halo largo e suave + risco horizontal quente (como o visor da ilustração)
				var hp = hg.affine_inverse() * vp
				var halos = []
				for spec in [["visor_halo", 0.0024, Vector2(2.2, 1.0)], ["visor_risco", 0.0016, Vector2(2.8, 0.28)]]:
					var halo = Sprite3D.new()
					halo.name = spec[0]
					halo.texture = _fig3d_glow_tex
					halo.pixel_size = spec[1]
					halo.scale = Vector3(spec[2].x, spec[2].y, 1.0)
					halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					halo.position = hp
					att.add_child(halo)
					var am = StandardMaterial3D.new()
					am.albedo_texture = _fig3d_glow_tex
					am.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
					am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					am.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
					am.billboard_keep_scale = true
					am.render_priority = 2
					am.no_depth_test = true      # o brilho passa por cima do capacete, como o bloom da ilustração
					halo.material_override = am
					halos.append(am)
				root.set_meta("halos", halos)
				var lamp = OmniLight3D.new()
				lamp.light_color = Color(1.0, 0.18, 0.1)
				lamp.light_energy = 1.6
				lamp.omni_range = 0.8
				lamp.shadow_enabled = false
				lamp.position = hp
				att.add_child(lamp)
				root.set_meta("lamp", lamp)
	if cfg.has("conjura") and root.has_meta("skel"):
		_olhos_conjura(root, cfg["conjura"])
	return root


# dois brilhos presos à cabeça, na altura dos olhos: acendem quando o personagem conjura
func _olhos_conjura(root: Node3D, ofs: Array) -> void:
	var sk: Skeleton3D = root.get_meta("skel")
	var bn: Dictionary = root.get_meta("bones")
	var ax: Array = root.get_meta("ax")
	if not bn.has("Head"):
		return
	if _fig3d_glow_tex == null:
		_fig3d_glow_tex = GradientTexture2D.new()
		var gr = Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		gr.add_point(0.35, Color(1, 1, 1, 0.45))
		_fig3d_glow_tex.gradient = gr
		_fig3d_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_fig3d_glow_tex.fill_from = Vector2(0.5, 0.5)
		_fig3d_glow_tex.fill_to = Vector2(1.0, 0.5)
		_fig3d_glow_tex.width = 64
		_fig3d_glow_tex.height = 64
	var hb: int = bn["Head"]
	var att = BoneAttachment3D.new()
	att.bone_idx = hb
	sk.add_child(att)
	var hg = sk.get_bone_global_rest(hb)
	var mats = []
	for sgn in [-1.0, 1.0]:
		var wp = hg.origin + ax[0] * ofs[0] + ax[2] * ofs[1] + ax[1] * ofs[2] * sgn
		var sp = Sprite3D.new()
		sp.texture = _fig3d_glow_tex
		sp.pixel_size = 0.0016
		sp.position = hg.affine_inverse() * wp
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var am = StandardMaterial3D.new()
		am.albedo_texture = _fig3d_glow_tex
		am.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		am.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		am.billboard_keep_scale = true
		am.no_depth_test = true
		am.render_priority = 3
		am.albedo_color = Color(1.0, 0.75, 0.2, 0.0)
		sp.material_override = am
		att.add_child(sp)
		mats.append(am)
	var lamp = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.6, 0.15)
	lamp.light_energy = 0.0
	lamp.omni_range = 0.9
	lamp.position = hg.affine_inverse() * (hg.origin + ax[0] * ofs[0])
	att.add_child(lamp)
	root.set_meta("olhos", mats)
	root.set_meta("olhos_luz", lamp)


# centraliza o modelo na casa: o ponto entre os pés (o dragão: entre as quatro patas) fica no meio do
# hexágono; cauda e asas podem passar da borda. O giro do boneco acontece em volta desse ponto.
func _centra_fig(inst: Node3D, sk: Skeleton3D, cfg: Dictionary) -> void:
	var nomes = ["LeftFoot", "RightFoot"]
	if cfg.get("corpo", "") == "dragao":
		nomes = ["tripo__0_Left_Limb_3", "tripo__0_Right_Limb_2", "tripo__1_Left_Limb_3", "tripo__1_Right_Limb_3"]
	var ids = []
	for n in nomes:
		var i = sk.find_bone(n) if n.begins_with("tripo__") else _osso(sk, n)
		if i >= 0:
			ids.append(i)
	if ids.is_empty():
		var h = _osso(sk, "Hips")
		if h < 0:
			return
		ids.append(h)
	# transformação do esqueleto até o modelo (o nó ainda não está na árvore)
	var xf = Transform3D()
	var n: Node = sk
	while n != null and n != inst:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var c = Vector3.ZERO
	for i in ids:
		c += inst.transform * (xf * sk.get_bone_global_rest(i).origin)
	c /= float(ids.size())
	inst.position.x -= c.x
	inst.position.z -= c.z


# acha um osso pelo nome Mixamo; aceita também o esqueleto humanoide do Tripo (L_Upperarm, Spine01...)
const OSSOS_TRIPO = {"Hips": "Hip", "Spine": "Waist", "Spine1": "Spine01", "Spine2": "Spine02", "Neck": "NeckTwist01", "Head": "Head",
	"Shoulder": "Clavicle", "Arm": "Upperarm", "ForeArm": "Forearm", "Hand": "Hand", "UpLeg": "Thigh", "Leg": "Calf", "Foot": "Foot", "ToeBase": "ToeBase"}
const DEDOS_TRIPO = {"Index": "Index", "Middle": "Mid", "Ring": "Ring", "Pinky": "Pinky", "Thumb": "Thumb"}


func _osso(sk: Skeleton3D, nm: String) -> int:
	for pre in ["mixamorig_", "mixamorig:", ""]:
		var b = sk.find_bone(pre + nm)
		if b >= 0:
			return b
	var lado = ""
	var resto = nm
	if nm.begins_with("Left"):
		lado = "L_"
		resto = nm.substr(4)
	elif nm.begins_with("Right"):
		lado = "R_"
		resto = nm.substr(5)
	if resto.begins_with("Hand") and resto.length() > 4:
		for d in DEDOS_TRIPO.keys():
			if resto.begins_with("Hand" + d):
				return sk.find_bone(lado + DEDOS_TRIPO[d] + resto.substr(4 + d.length()))
	if OSSOS_TRIPO.has(resto):
		return sk.find_bone(lado + OSSOS_TRIPO[resto])
	return -1


# gira a parte "local" do osso em torno de um eixo do esqueleto (frente / esquerda / cima)
func _fig3d_q(sk: Skeleton3D, b: int, axis: Vector3, ang: float) -> Quaternion:
	var gb = sk.get_bone_global_rest(b).basis.orthonormalized()
	return Quaternion((gb.inverse() * axis).normalized(), ang)


func _fig3d_tick(fig: Node3D, delta: float, t: float, flip: bool, mod: Color, walking: bool, lunge: float, hurt: float, run: bool = false, mdir: Vector3 = Vector3.ZERO) -> void:
	var tw: float = fig.get_meta("walk_w", 0.0)
	var tr: float = fig.get_meta("run_w", 0.0) * tw
	var tt: float = fig.get_meta("tail_t", 0.0) + delta * (1.0 + 0.8 * tw + 1.0 * tr + 2.0 * hurt)
	fig.set_meta("tail_t", tt)
	for m in fig.get_meta("mats"):
		m.set_shader_parameter("mod_col", mod)
		m.set_shader_parameter("tail_t", tt)
		m.set_shader_parameter("tail_amp", 0.3 + 0.12 * tw + 0.1 * tr)
	for o in fig.get_meta("outl"):
		o.set_shader_parameter("mod_col", Color(1, 1, 1) if mod.r > 0.9 else mod)
		o.set_shader_parameter("tail_t", tt)
		o.set_shader_parameter("tail_amp", 0.3 + 0.12 * tw + 0.1 * tr)
	var pulse = 0.82 + 0.18 * sin(t * 3.2)
	if fig.has_meta("halos"):
		var hs: Array = fig.get_meta("halos")
		var flick = 0.94 + 0.06 * sin(t * 23.0) * sin(t * 7.3)     # tremidinha de luz viva
		var a = pulse * flick
		hs[0].albedo_color = Color(1.0 * mod.r, 0.1 * mod.g, 0.05 * mod.b, 0.8 * a)
		hs[1].albedo_color = Color(1.0 * mod.r, 0.62 * mod.g, 0.55 * mod.b, 1.0 * a)
		fig.get_meta("lamp").light_energy = 1.6 * a * mod.r
	# andando: olha para onde vai; parado: meio para a câmera, meio para o lado (como a arte 2D, que só espelhava)
	var giro: Node3D = fig.get_node("giro")
	var md = Vector3(mdir.x, 0.0, mdir.z)
	if walking and md.length() > 0.01 and fig.is_inside_tree():
		var yaw_m = atan2(md.x, md.z) - fig.get_parent().global_rotation.y
		giro.rotation.y = lerp_angle(giro.rotation.y, yaw_m, min(1.0, delta * 12.0))
	elif fig.is_inside_tree():
		# parado: virado para o lado inimigo, fixo no tabuleiro (girar a câmera não mexe as peças)
		var od: Vector3 = fig.get_meta("olha", Vector3.ZERO)
		if od.length() < 0.01 and cam != null and is_instance_valid(cam):
			od = cam.global_position - fig.global_position
		od.y = 0.0
		if od.length() > 0.01:
			var yaw = atan2(od.x, od.z) - fig.get_parent().global_rotation.y
			giro.rotation.y = lerp_angle(giro.rotation.y, yaw, min(1.0, delta * 6.0))
	if fig.has_meta("dragao"):
		_dragao_tick(fig, delta, t, walking, run, lunge, hurt)
		return
	if not fig.has_meta("skel"):
		return
	var sk: Skeleton3D = fig.get_meta("skel")
	var bn: Dictionary = fig.get_meta("bones")
	var ax: Array = fig.get_meta("ax")
	var F: Vector3 = ax[0]
	var S: Vector3 = ax[1]
	var U: Vector3 = ax[2]
	if fig.has_meta("anim_p"):
		var apl: AnimationPlayer = fig.get_meta("anim_p")
		var ann: Dictionary = fig.get_meta("anim_n")
		var quer = ""
		if walking and lunge <= 0.0:
			quer = ann.get("correr", ann.get("andar", "")) if run else ann.get("andar", "")
		if quer != "":
			if apl.current_animation != quer:
				apl.play(quer, 0.15)
				apl.speed_scale = 1.0
			fig.set_meta("walk_w", 1.0)
			# a animação do arquivo vem com o corpo no ar: assenta os pés no chão (com um voo curto da corrida)
			_assenta(fig, sk, ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"], 1.0, 0.015)
			return
		elif apl.is_playing():
			apl.stop()
			sk.reset_bone_poses()
			fig.set_meta("walk_w", 0.0)
	var J: Dictionary = fig.get_meta("jeito", JEITOS["padrao"])
	var ww: float = fig.get_meta("walk_w", 0.0)
	ww = move_toward(ww, 1.0 if walking else 0.0, delta * 6.0)
	fig.set_meta("walk_w", ww)
	var rw: float = fig.get_meta("run_w", 0.0)          # 0 = andando, 1 = correndo
	rw = move_toward(rw, 1.0 if (walking and run) else (0.0 if walking else rw), delta * 5.0)
	fig.set_meta("run_w", rw)
	# fase da passada acumulada (trocar de andar para correr não dá tranco)
	var ph: float = fig.get_meta("fase", 0.0) + delta * lerp(J["cad"][0], J["cad"][1], rw) * (1.0 if ww > 0.0 else 0.0)
	fig.set_meta("fase", fmod(ph, TAU * 100.0))
	var br = sin(t * J["resp"][1])                          # respiração
	var sh = sin(t * 0.55)                                  # troca o peso de uma perna para a outra, devagar
	var lk = sin(t * J["olha"][1]) + 0.35 * sin(t * J["olha"][1] * 2.7)   # olha em volta
	var idle = 1.0 - ww
	var sw = sin(ph)
	# pegadas: o pé escolhido toca o chão quando a passada troca de lado
	var pg: String = fig.get_meta("pegadas", "")
	if pg != "" and ww > 0.5:
		var sw_ant: float = fig.get_meta("sw_ant", 0.0)
		if sw_ant > 0.0 and sw <= 0.0:
			var fb = _osso(sk, pg)
			if fb >= 0:
				_pegada_cristal(sk.global_transform * sk.get_bone_global_pose(fb).origin, fig)
		fig.set_meta("sw_ant", sw)
	var k = sin(clamp(lunge, 0.0, 1.0) * PI)
	var ra: float = J["resp"][0]
	# tique de vez em quando (só parado): 0..1 durante ~1,5 s a cada ~7 s
	var tq = 0.0
	if J["tique"] != "":
		var cyc = fmod(t + 3.0, 7.0)
		tq = sin(clamp((cyc - 5.5) / 1.5, 0.0, 1.0) * PI) * idle * (1.0 - k)
	# amplitudes: andar -> correr
	var leg_a = lerp(J["passo"][0], J["passo"][1], rw) * ww
	var knee_a = lerp(J["joelho"][0], J["joelho"][1], rw) * ww
	var knee_0 = lerp(0.05, 0.3, rw) * ww
	var arm_a = lerp(J["bal"][0], J["bal"][1], rw) * ww
	var elbow = lerp(-0.30, -1.25, rw * ww)
	var lean = lerp(J["incl"][0], J["incl"][1], rw) * ww
	var gi = J["ginga"] * ww * (1.0 - rw * 0.6)
	# sobe e desce a cada passo (duas vezes por ciclo)
	fig.position.y += abs(sw) * lerp(J["quica"][0], J["quica"][1], rw) * ww
	var pose = {}
	# braços: do "A" do modelo para junto do corpo; respiram parado; balançam contra as pernas andando
	pose["LeftArm"] = [[F, -0.30 - ra * 1.2 * br * idle + 0.04 * sh * idle + 0.08 * rw * ww], [S, arm_a * sw + 0.06 * sin(t * 0.8) * idle]]
	pose["RightArm"] = [[F, 0.30 + ra * 1.2 * br * idle + 0.04 * sh * idle - 0.08 * rw * ww], [S, -arm_a * sw - 1.35 * k - 0.05 * sin(t * 0.8 + 1.0) * idle]]
	pose["LeftForeArm"] = [[S, elbow - ra * br * idle]]
	pose["RightForeArm"] = [[S, elbow - ra * br * idle - 0.35 * k]]
	# mãos no bolso do casaco (parado e andando; correndo ou golpeando, os braços saem)
	if fig.get_meta("bracos", "") == "bolso":
		# mãos enfiadas nos bolsos da frente: braços descem rentes ao corpo e um pouco à frente,
		# cotovelos levemente dobrados para dentro, ombros um pouco curvados (pose relaxada)
		var pk = (1.0 - rw * ww) * (1.0 - k)
		var bp: Array = fig.get_meta("bolso_p", [0.2, -0.2, -0.6, 0.2, 0.06])   # desce, frente, cotovelo, para dentro, ombro
		pose["LeftArm"] = [[F, -0.30 - bp[0] * pk + 0.02 * br * idle], [S, -bp[1] * pk + (arm_a * sw) * (1.0 - pk)]]
		pose["RightArm"] = [[F, 0.30 + bp[0] * pk - 0.02 * br * idle], [S, -bp[1] * pk - (arm_a * sw) * (1.0 - pk) - 1.35 * k]]
		pose["LeftForeArm"] = [[S, lerp(elbow, bp[2], pk)], [F, bp[3] * pk]]
		pose["RightForeArm"] = [[S, lerp(elbow, bp[2], pk) - 0.35 * k], [F, -bp[3] * pk]]
		pose["LeftShoulder"] = [[S, -bp[4] * pk]]
		pose["RightShoulder"] = [[S, -bp[4] * pk]]
		pose["LeftHand"] = [[S, -0.2 * pk]]
		pose["RightHand"] = [[S, -0.2 * pk]]
		# a mão some dentro do bolso (encolhe a partir do pulso)
		var hs = lerp(1.0, fig.get_meta("mao_esc", 0.45), pk)
		for hn in ["LeftHand", "RightHand"]:
			if bn.has(hn):
				sk.set_bone_pose_scale(bn[hn], Vector3.ONE * hs)
	# tronco: respira, balança o peso, ginga, inclina correndo, entra no golpe, recua no dano
	pose["Spine"] = [[F, J["peso"] * sh * idle + gi * 0.5 * sw], [U, 0.08 * sw * ww]]
	pose["Spine1"] = [[S, ra * br * idle + lean + 0.12 * k - 0.22 * hurt], [U, 0.3 * k + 0.25 * J["olha"][0] * lk * idle - 0.1 * sw * ww - gi * sw]]
	pose["Spine2"] = [[S, ra * 0.6 * br * idle], [F, -J["peso"] * 0.6 * sh * idle]]
	pose["Head"] = [[U, J["olha"][0] * lk * idle - 0.15 * k], [S, -ra * 0.8 * br * idle - 0.08 * hurt - lean * 0.6], [F, -J["peso"] * 0.8 * sh * idle + gi * 0.4 * sw]]
	# pernas: coxa vai e volta, joelho dobra quando a perna volta (mais ainda correndo)
	pose["LeftUpLeg"] = [[S, -leg_a * sw - knee_0 * 0.4]]
	pose["RightUpLeg"] = [[S, leg_a * sw - knee_0 * 0.4]]
	pose["LeftLeg"] = [[S, knee_0 + knee_a * max(0.0, sin(ph + 1.4))]]
	pose["RightLeg"] = [[S, knee_0 + knee_a * max(0.0, -sin(ph + 1.4))]]
	# marcha de soldado: joelho sobe alto na frente, pisa firme, braços retos no ritmo,
	# tronco e cabeça eretos (também no passo acelerado)
	if J.get("marcha", false):
		var up_l = max(0.0, sw)
		var up_r = max(0.0, -sw)
		var lift = lerp(1.35, 1.5, rw) * ww
		pose["LeftUpLeg"] = [[S, -lift * pow(up_l, 0.8) + 0.18 * ww * up_r]]
		pose["RightUpLeg"] = [[S, -lift * pow(up_r, 0.8) + 0.18 * ww * up_l]]
		pose["LeftLeg"] = [[S, lift * 1.15 * pow(up_l, 1.2)]]
		pose["RightLeg"] = [[S, lift * 1.15 * pow(up_r, 1.2)]]
		var arm_m = lerp(0.6, 0.75, rw) * ww
		pose["LeftArm"] = [[F, -0.30 - 0.04 * br * idle], [S, -arm_m * sw]]
		pose["RightArm"] = [[F, 0.30 + 0.04 * br * idle], [S, arm_m * sw - 1.35 * k]]
		pose["LeftForeArm"] = [[S, -0.12 * ww - 0.3 * idle]]
		pose["RightForeArm"] = [[S, -0.12 * ww - 0.3 * idle - 0.35 * k]]
		pose["Spine"] = [[F, J["peso"] * sh * idle]]
		pose["Spine1"] = [[S, ra * br * idle + 0.06 * ww + 0.12 * k - 0.22 * hurt], [U, 0.3 * k + 0.25 * J["olha"][0] * lk * idle]]
		pose["Head"][0][1] *= idle
		# pisada: corpo sobe quando o joelho sobe e desce de uma vez no pé
		fig.position.y += (abs(sw) * 0.06 - 0.03) * ww
	# conjurar: mãos estendidas para a frente, flutua e os olhos acendem
	if fig.has_meta("conjura"):
		var ct: float = max(0.0, fig.get_meta("cj_t", 0.0) - delta)
		fig.set_meta("cj_t", ct)
		var cw: float = move_toward(fig.get_meta("cj_w", 0.0), 1.0 if ct > 0.0 else 0.0, delta * (5.0 if ct > 0.0 else 2.5))
		fig.set_meta("cj_w", cw)
		if cw > 0.001:
			var e3 = cw * cw * (3.0 - 2.0 * cw)
			k = 0.0
			pose["Spine1"] = [[S, -0.1 * e3], [U, 0.0]]
			pose["Head"] = [[S, -0.12 * e3], [U, 0.0]]
			# pernas esticadas e juntas, pés em ponta para baixo (como quem levita)
			pose["LeftUpLeg"] = [[S, 0.03 * e3], [F, -0.07 * e3]]
			pose["RightUpLeg"] = [[S, 0.03 * e3], [F, 0.07 * e3]]
			pose["LeftLeg"] = [[S, 0.06 * e3]]
			pose["RightLeg"] = [[S, 0.06 * e3]]
			pose["LeftFoot"] = [[S, fig.get_meta("pe_ponta", 1.2) * e3]]
			pose["RightFoot"] = [[S, fig.get_meta("pe_ponta", 1.2) * e3]]
			fig.position.y += (0.32 + 0.04 * sin(t * 4.0)) * e3
		if fig.has_meta("olhos"):
			var fl = 0.9 + 0.1 * sin(t * 18.0)
			for om in fig.get_meta("olhos"):
				om.albedo_color = Color(1.0, 0.75, 0.2, cw * fl)
			fig.get_meta("olhos_luz").light_energy = 2.2 * cw
	# tiques
	if J["tique"] == "vigia":
		# Krieg varre o campo com a cabeça, rápido para um lado e para o outro, peito estufado
		pose["Head"][0][1] += 0.55 * sin(tq * PI * 2.0) * tq
		pose["Spine2"][0][1] -= 0.06 * tq
	elif J["tique"] == "altivo":
		# Rei da Mina ergue o queixo e olha o campo de cima, devagar
		pose["Head"].append([S, -0.18 * tq])
		pose["Spine2"].append([S, -0.05 * tq])
	elif J["tique"] == "pe":
		# Karo bate o pé, impaciente, e inclina a cabeça
		var tap = max(0.0, sin(t * 14.0)) * tq
		pose["RightFoot"] = [[S, -0.35 * tap]]
		pose["RightLeg"][0][1] += 0.12 * tq
		pose["RightUpLeg"][0][1] -= 0.08 * tq
		pose["Head"].append([F, 0.18 * tq])
	if fig.has_meta("pose_arte"):
		for hn in ["LeftHand", "RightHand"]:
			if not pose.has(hn):
				pose[hn] = []   # o pulso volta ao repouso antes de a pose da ilustração mirar a mão
	for nm in pose.keys():
		if not bn.has(nm):
			continue
		var b: int = bn[nm]
		var q: Quaternion = sk.get_bone_rest(b).basis.get_rotation_quaternion()
		for e in pose[nm]:
			q = q * _fig3d_q(sk, b, e[0], e[1])
		sk.set_bone_pose_rotation(b, q)
	var cjw: float = fig.get_meta("cj_w", 0.0)
	# pose da ilustração (parado): cada osso do braço aponta para uma direção dada em (frente, lado, cima)
	if fig.has_meta("pose_arte"):
		var wa = idle * (1.0 - k) * (1.0 - cjw)
		wa = wa * wa * (3.0 - 2.0 * wa)
		if wa > 0.001:
			var pa: Dictionary = fig.get_meta("pose_arte")
			for side in pa.keys():
				var dd: Array = pa[side]
				var cadeia = [side + "Arm", side + "ForeArm", side + "Hand"]
				var ponta = [side + "ForeArm", side + "Hand", side + "HandMiddle1"]
				for i in range(3):
					var bi: int = bn.get(cadeia[i], -1)
					var ci: int = bn.get(ponta[i], -1) if i < 2 else _osso(sk, ponta[i])
					if bi < 0 or ci < 0:
						continue
					var v: Array = dd[i]
					# respira: o braço sobe e desce de leve
					var alvo = (F * v[0] + S * v[1] + U * (v[2] + 0.03 * br)).normalized()
					var gb = sk.get_bone_global_pose(bi)
					var cur = (sk.get_bone_global_pose(ci).origin - gb.origin).normalized()
					var qr = Quaternion(cur, cur.slerp(alvo, wa).normalized())
					var par = sk.get_bone_parent(bi)
					var pg2 = sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
					sk.set_bone_pose_rotation(bi, (pg2.basis.inverse() * (Basis(qr) * gb.basis)).get_rotation_quaternion())
	# conjurar: aponta os braços para a frente (mira no espaço do esqueleto, não depende da pose de repouso)
	if cjw > 0.001:
		var e4 = cjw * cjw * (3.0 - 2.0 * cjw)
		for side in [["Left", 1.0], ["Right", -1.0]]:
			var an: String = side[0] + "Arm"
			var fn: String = side[0] + "ForeArm"
			var hn: String = side[0] + "Hand"
			if not (bn.has(an) and bn.has(fn) and bn.has(hn)):
				continue
			var ab: int = bn[an]
			var fb: int = bn[fn]
			var hb: int = bn[hn]
			var alvo_d = (F * 1.0 + S * (0.42 * side[1]) - U * 0.12).normalized()
			# braço
			var gp = sk.get_bone_global_pose(ab)
			var cur_d = (sk.get_bone_global_pose(fb).origin - gp.origin).normalized()
			var qa = Quaternion(cur_d, cur_d.slerp(alvo_d, e4).normalized())
			var par = sk.get_bone_parent(ab)
			var pgt = sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
			var ng = Basis(qa) * gp.basis
			sk.set_bone_pose_rotation(ab, (pgt.basis.inverse() * ng).get_rotation_quaternion())
			# antebraço reto na mesma direção
			var gf = sk.get_bone_global_pose(fb)
			var cur_f = (sk.get_bone_global_pose(hb).origin - gf.origin).normalized()
			var qf = Quaternion(cur_f, cur_f.slerp(alvo_d, e4).normalized())
			var pgf = sk.get_bone_global_pose(ab)
			sk.set_bone_pose_rotation(fb, (pgf.basis.inverse() * (Basis(qf) * gf.basis)).get_rotation_quaternion())
			# punho dobrado para trás: a palma fica de frente, como quem lança um feitiço
			var mid = _osso(sk, "%sHandMiddle1" % side[0])
			if mid >= 0:
				var gh = sk.get_bone_global_pose(hb)
				var cur_h = (sk.get_bone_global_pose(mid).origin - gh.origin).normalized()
				var alvo_h = (alvo_d * cos(0.85) + U * sin(0.85)).normalized()
				var qh = Quaternion(cur_h, cur_h.slerp(alvo_h, e4).normalized())
				var pgh = sk.get_bone_global_pose(fb)
				sk.set_bone_pose_rotation(hb, (pgh.basis.inverse() * (Basis(qh) * gh.basis)).get_rotation_quaternion())
	# pés no chão andando e correndo: o corpo desce o quanto o pé mais baixo ficou acima do chão
	# (o joelho dobrado e o quique deixavam todo mundo flutuando); correndo sobra um voo curtinho
	if ww > 0.001 and cjw < 0.999:
		_assenta(fig, sk, ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"], ww * (1.0 - cjw), 0.022 * rw * abs(sw))
	if fig.has_meta("garra"):
		var eg = cjw * cjw * (3.0 - 2.0 * cjw)
		for gd in fig.get_meta("garra"):
			var q0: Quaternion = sk.get_bone_rest(gd[0]).basis.get_rotation_quaternion()
			if eg > 0.001:
				q0 = q0 * _fig3d_q(sk, gd[0], gd[3], gd[4] * eg) * _fig3d_q(sk, gd[0], gd[1], gd[2] * eg)
			sk.set_bone_pose_rotation(gd[0], q0)


# desce (ou sobe) a figura para o pé mais baixo encostar no chão de repouso; "folga" = fração da altura
# que ele pode ficar no ar (voo da corrida); "peso" = quanto da correção vale (0 parado, 1 andando)
func _assenta(fig: Node3D, sk: Skeleton3D, nomes: Array, peso: float, folga: float) -> void:
	var ids: Array = fig.get_meta("pes_ids", [])
	if ids.is_empty():
		for n in nomes:
			var i = _osso(sk, n) if not n.begins_with("tripo__") else sk.find_bone(n)
			if i >= 0:
				ids.append(i)
		fig.set_meta("pes_ids", ids)
	if ids.is_empty():
		return
	sk.force_update_all_bone_transforms()   # a pose acabou de mudar neste quadro
	# tudo no espaço do mundo (o esqueleto pode estar girado ou escalado dentro do modelo)
	var gx = sk.global_transform
	var low = 1e9
	var rep = 1e9
	for i in ids:
		low = min(low, (gx * sk.get_bone_global_pose(i).origin).y)
		rep = min(rep, (gx * sk.get_bone_global_rest(i).origin).y)
	var alt = fig.get_meta("alt_mundo", -1.0)
	if alt < 0.0:
		var lo = 1e9
		var hi = -1e9
		for i in sk.get_bone_count():
			var y = (gx * sk.get_bone_global_rest(i).origin).y
			lo = min(lo, y)
			hi = max(hi, y)
		alt = max(0.001, hi - lo)
		fig.set_meta("alt_mundo", alt)
	var pai_esc = fig.get_parent().global_transform.basis.get_scale().y if fig.get_parent() is Node3D else 1.0
	# (low - rep) é quanto a pose ergueu o pé em relação ao boneco; fig.position.y é o quique do corpo
	var acima = (low - rep - folga * alt) / max(0.0001, pai_esc) + fig.position.y
	fig.position.y -= acima * peso


# ---------- dragão (esqueleto quadrúpede do Tripo, com asas, pescoço e cauda) ----------
const DRAGAO_OSSOS = {
	"sp0": "Spine_0", "sp1": "Spine_1", "sp2": "Spine_2", "h0": "Head_0", "h1": "Head_1", "h2": "Head_2", "h3": "Head_3",
	"fl0": "0_Left_Limb_1", "fl1": "0_Left_Limb_2", "fl2": "0_Left_Limb_3", "fr0": "0_Right_Limb_0", "fr1": "0_Right_Limb_1", "fr2": "0_Right_Limb_2",
	"hl0": "1_Left_Limb_0", "hl1": "1_Left_Limb_1", "hl2": "1_Left_Limb_2", "hr0": "1_Right_Limb_0", "hr1": "1_Right_Limb_1", "hr2": "1_Right_Limb_2",
	"t0": "Tail_0", "t1": "Tail_1", "t2": "Tail_2", "t3": "Tail_3", "tb": "bone_45",
	"wl0": "bone_20", "wl1": "bone_21", "wl2": "bone_22", "wl3": "bone_24", "wr0": "bone_27", "wr1": "bone_28", "wr2": "bone_29", "wr3": "bone_31",
}


func _dragao_setup(root: Node3D, sk: Skeleton3D) -> void:
	var bones = {}
	for k in DRAGAO_OSSOS.keys():
		var nm: String = DRAGAO_OSSOS[k]
		for cand in ["tripo::" + nm, "tripo__" + nm, "tripo_" + nm, nm]:
			var b = sk.find_bone(cand)
			if b >= 0:
				bones[k] = b
				break
	root.set_meta("dragao", true)
	root.set_meta("conjura", true)
	root.set_meta("cj_t", 0.0)
	root.set_meta("cj_w", 0.0)
	root.set_meta("skel", sk)
	root.set_meta("bones", bones)
	root.set_meta("vel", [1.4, 2.4])   # voo mais calmo que uma passada, para dar tempo de decolar e planar


func _dragao_tick(fig: Node3D, delta: float, t: float, walking: bool, run: bool, lunge: float, hurt: float) -> void:
	var sk: Skeleton3D = fig.get_meta("skel")
	var bn: Dictionary = fig.get_meta("bones")
	var F = Vector3(1, 0, 0)
	var U = Vector3(0, 1, 0)
	var S = Vector3(0, 0, -1)          # esquerda do dragão
	var ww: float = move_toward(fig.get_meta("walk_w", 0.0), 1.0 if walking else 0.0, delta * 5.0)
	fig.set_meta("walk_w", ww)
	var rw: float = move_toward(fig.get_meta("run_w", 0.0), 1.0 if (walking and run) else (0.0 if walking else fig.get_meta("run_w", 0.0)), delta * 4.0)
	fig.set_meta("run_w", rw)
	var ph: float = fig.get_meta("fase", 0.0) + delta * lerp(6.0, 10.0, rw) * (1.0 if ww > 0.0 else 0.0)
	fig.set_meta("fase", fmod(ph, TAU * 100.0))
	var ct: float = max(0.0, fig.get_meta("cj_t", 0.0) - delta)
	fig.set_meta("cj_t", ct)
	var cw: float = move_toward(fig.get_meta("cj_w", 0.0), 1.0 if ct > 0.0 else 0.0, delta * (4.0 if ct > 0.0 else 2.0))
	fig.set_meta("cj_w", cw)
	var e3 = cw * cw * (3.0 - 2.0 * cw)
	# o Dragão Zukunft não anda: para se deslocar ele decola, voa e pousa no destino
	var vw: float = move_toward(fig.get_meta("voo_w", 0.0), 1.0 if walking else 0.0, delta * (2.4 if walking else 1.6))
	fig.set_meta("voo_w", vw)
	var fv = vw * vw * (3.0 - 2.0 * vw)                 # decolagem e pouso suaves
	var idle = 1.0 - fv
	var br = sin(t * 1.6)
	var bat = t * 7.5                                     # batida das asas em voo
	var pose = {}
	# patas: paradas no chão; em voo a frente dobra junto ao peito e a de trás vai esticada para trás
	for lado in ["l", "r"]:
		pose["f%s0" % lado] = [[S, 0.3 * fv]]
		pose["f%s1" % lado] = [[S, 1.5 * fv]]
		pose["f%s2" % lado] = [[S, -0.9 * fv]]
		pose["h%s0" % lado] = [[S, 1.0 * fv]]
		pose["h%s1" % lado] = [[S, 0.35 * fv]]
		pose["h%s2" % lado] = [[S, 0.6 * fv]]
	# corpo: respira parado; em voo sobe e desce com as asas e embica de leve para a frente
	var bote = sin(clamp(lunge, 0.0, 1.0) * PI)
	pose["sp1"] = [[S, 0.02 * br * idle - 0.04 * sin(bat - 0.8) * fv]]
	pose["sp2"] = [[S, 0.03 * br * idle - 0.12 * e3]]
	# as patas da frente saem da coluna: desfaz o balanço do peito nelas para ficarem firmes no chão
	var peito_s = (0.02 * br + 0.03 * br) * idle - 0.12 * e3
	for fk in ["fl0", "fr0"]:
		pose[fk] = [[S, -peito_s]] + pose[fk]
	# pescoço em S e cabeça: olha em volta parado; em voo estica à frente; no ataque ergue e dá o bote
	var lk = sin(t * 0.45) + 0.4 * sin(t * 1.2)
	pose["h0"] = [[U, 0.12 * lk * idle], [S, 0.03 * br * idle - 0.1 * e3 + 0.2 * bote + 0.12 * fv]]
	pose["h1"] = [[U, 0.08 * lk * idle], [S, -0.06 * e3 + 0.14 * bote + 0.04 * sin(bat - 1.2) * fv]]
	pose["h2"] = [[U, 0.05 * lk * idle], [S, 0.02 * br * idle + 0.08 * e3 - 0.12 * bote - 0.1 * hurt - 0.1 * fv]]
	# cauda: onda lateral parada; em voo fica esticada atrás e ondula devagar como leme
	for i in range(4):
		pose["t%d" % i] = [[U, lerp(0.12, 0.07, fv) * sin(t * lerp(2.0, 2.6, fv) - i * 0.7)], [S, 0.04 * sin(t * 1.3 - i * 0.5) * idle - 0.08 * fv + 0.05 * sin(bat - 1.5 - i * 0.6) * fv]]
	# asas: dobradas respirando parado; no golpe abrem e batem; em voo batem cheias
	var flap_g = sin(t * 9.0)
	var fa_g = 0.05 * idle + 0.28 * e3
	var ga = fa_g * flap_g - 0.15 * e3 + 0.03 * br * idle
	var va = 0.62 * sin(bat) - 0.2                        # batida cheia, com as asas um pouco abertas
	var asa = lerp(ga, va, fv)
	var asa2 = lerp(0.5 * fa_g * sin(t * 9.0 - 0.6), 0.4 * sin(bat - 0.9) - 0.15, fv)
	pose["wl0"] = [[F, asa]]
	pose["wr0"] = [[F, -asa]]
	pose["wl1"] = [[F, asa2]]
	pose["wr1"] = [[F, -asa2]]
	# altura: em voo paira acima da casa (sobe na batida para baixo); no golpe sobe batendo as asas
	var alt_voo: float = fig.get_meta("alt_voo", 0.85)
	fig.position.y += alt_voo * fv + 0.07 * sin(bat + PI * 0.5) * fv + 0.18 * e3 * (0.6 + 0.4 * flap_g) * (1.0 - fv)
	for k in pose.keys():
		if not bn.has(k):
			continue
		var b: int = bn[k]
		var q: Quaternion = sk.get_bone_rest(b).basis.get_rotation_quaternion()
		for e in pose[k]:
			q = q * _fig3d_q(sk, b, e[0], e[1])
		sk.set_bone_pose_rotation(b, q)


# Rei da Mina: cada passo do pé de cristal deixa cristaizinhos que brotam do chão e somem
var _pegada_mat: StandardMaterial3D = null


func _pegada_cristal(pos: Vector3, fig: Node3D) -> void:
	if not is_inside_tree():
		return
	if _pegada_mat == null:
		_pegada_mat = StandardMaterial3D.new()
		_pegada_mat.albedo_color = Color("#b45cff")
		_pegada_mat.emission_enabled = true
		_pegada_mat.emission = Color("#9b3dff")
		_pegada_mat.emission_energy_multiplier = 1.4
		_pegada_mat.roughness = 0.2
		_pegada_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ground_y = fig.get_parent().global_position.y if fig.get_parent() is Node3D else pos.y
	var root = Node3D.new()
	add_child(root)
	root.global_position = Vector3(pos.x, ground_y + 0.01, pos.z)
	var n = 4 + randi() % 3
	for i in range(n):
		var mi = MeshInstance3D.new()
		var cy = CylinderMesh.new()
		cy.top_radius = 0.0
		var r0 = randf_range(0.04, 0.075)
		cy.bottom_radius = r0
		cy.height = randf_range(0.14, 0.3)
		cy.radial_segments = 5
		cy.rings = 1
		mi.mesh = cy
		mi.material_override = _pegada_mat
		var a = randf() * TAU
		var d = randf_range(0.0, 0.12)
		mi.position = Vector3(cos(a) * d, cy.height * 0.4, sin(a) * d)
		mi.rotation = Vector3(randf_range(-0.45, 0.45), randf() * TAU, randf_range(-0.45, 0.45))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	root.scale = Vector3.ONE * 0.05
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "scale", Vector3.ONE, 0.12)
	tw.tween_interval(2.2)
	tw.tween_property(root, "scale", Vector3(1.0, 0.02, 1.0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)


# selecionado: o contorno de tinta vira a cor da facção e engrossa
func _fig3d_select(fig: Node3D, selected: bool, fc: Color) -> void:
	var pul = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
	if not selected and not fig.get_meta("sel", false):
		return
	fig.set_meta("sel", selected)
	for o in fig.get_meta("outl"):
		if selected:
			o.set_shader_parameter("ink", fc.lerp(Color.WHITE, 0.25 * pul))
			o.set_shader_parameter("px", 4.0)
		else:
			o.set_shader_parameter("ink", fig.get_meta("ink", Color(0.04, 0.016, 0.063, 1.0)))
			o.set_shader_parameter("px", 2.2)


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
	for sh in ship_nodes:
		if is_instance_valid(sh):
			_orient_ship(sh)
	_pulse_hex_energy()
	if g != null:
		_update_claw(delta)
	if not swirl_nodes.is_empty():
		for sw in swirl_nodes:
			if is_instance_valid(sw):
				sw.rotation.y -= delta * 0.35
	if not cz_nodes.is_empty():
		var pulse = 0.35 + 0.15 * sin(Time.get_ticks_msec() / 350.0)
		for nd in cz_nodes.values():
			if is_instance_valid(nd) and nd.has_meta("disk"):
				nd.get_meta("disk").albedo_color.a = pulse
	if g == null:
		return
	if not warn_tiles.is_empty():
		var tw = Time.get_ticks_msec() / 1000.0
		for wh in warn_tiles.keys():
			if tiles.has(wh) and tiles[wh]["warn"] != null:
				var sp = tiles[wh]["warn"]
				var ph = float(wh.x * 7 + wh.y * 3)
				var yb = tiles[wh]["disp_h"] * HS + 1.15
				sp.position.y = yb + sin(tw * 4.2 + ph) * 0.07
				var pu = 1.0 + 0.06 * sin(tw * 8.0 + ph)
				sp.scale = Vector3(pu, pu, pu)
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
		var tgt = _disp_of(h)
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
			d["run"] = path.size() >= 3          # personagem 3D: perto anda, longe corre
			d["hex"] = goal
		if d["pop"] < 1.0:
			d["pop"] = min(1.0, d["pop"] + delta * 3.5)
			var e = 1.0 + 0.25 * sin(d["pop"] * PI) if d["pop"] < 1.0 else 1.0
			node.scale = Vector3.ONE * d["pop"] * e
		var walking = not d["path"].is_empty()
		if walking:
			var w2 = world_xz(d["path"][0])
			var w = Vector3(w2.x, top_y(d["path"][0]), w2.y)
			var is3d = d["sprite"] != null and d["sprite"].has_meta("fig3d")
			var lng = d.get("long", false)
			# 3D: passo contínuo (sem pulinho), andando ou correndo; 2D: salta de casa em casa
			var vl: Array = d["sprite"].get_meta("vel", [2.1, 4.0]) if is3d else [2.1, 4.0]
			var spd = 1.6 if lng else ((vl[1] if d.get("run", false) else vl[0]) if is3d else 5.0)
			d["seg_t"] += delta * spd
			var t = min(1.0, d["seg_t"])
			var e2 = t if (is3d and not lng) else (2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0)
			var p = d["from"].lerp(w, e2)
			var arc = 1.2 if lng else 0.3
			if is3d and not lng:
				arc = 0.3 if abs(w.y - d["from"].y) > 0.2 else 0.0     # só pula degrau
			p.y += sin(PI * t) * arc
			d["mdir"] = w - d["from"]
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
		if sprite != null and sprite.has_meta("fig3d"):
			var mod3 = Color(0.55, 0.55, 0.55) if (u.activated and not u.barrier) else Color(1, 1, 1)
			if d["hurt"] > 0.0:
				d["hurt"] = max(0.0, d["hurt"] - delta * 2.5)
				mod3 = mod3.lerp(Color(1, 0.3, 0.2), d["hurt"])
			if d["lunge"] > 0.0:
				d["lunge"] = max(0.0, d["lunge"] - delta * 1.6)
			var pos3 = Vector3.ZERO
			if selected:
				pos3.y += 0.06 + 0.05 * sin(t_now * 6.0)
			sprite.position = pos3
			sprite.set_meta("olha", _olhar_de(u, node))
			_fig3d_tick(sprite, delta, t_now + d["bob"], d["flip"], mod3, walking and not d.get("long", false), d["lunge"], d["hurt"], d.get("run", false), d.get("mdir", Vector3.ZERO))
			_fig3d_select(sprite, selected, d["ring"].get_meta("fcol", Color.WHITE))
		elif sprite != null:
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
		var fc: Color = d["ring"].get_meta("fcol", Color.WHITE)
		var pul = 0.5 + 0.5 * sin(t_now * 5.0)
		# selecionado: base acende e pulsa, contorno da arte na cor da facção, coluna de luz
		d["ring"].material_override.albedo_color = fc.lightened(0.25 + 0.3 * pul) if selected else fc
		d["ring"].scale = Vector3.ONE * (1.0 + (0.04 * pul if selected else 0.0))
		if d["sprite"] != null:
			var olc = d["sprite"].get_node_or_null("contorno")
			if olc != null:
				if olc.visible != selected:
					olc.visible = selected
				if selected:
					olc.material_override.set_shader_parameter("col", fc.lerp(Color.WHITE, 0.25 * pul))
		var beam = d.get("beam", null)
		if selected and beam == null:
			beam = _sel_beam(fc)
			d["node"].add_child(beam)
			d["beam"] = beam
		if beam != null:
			beam.visible = selected
			if selected:
				beam.material_override.albedo_color = Color(fc.r, fc.g, fc.b, 0.22 + 0.16 * pul)
				beam.rotation.y += delta * 0.8
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
			col = Color(0.80, 0.58, 1.0, 0.92)
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
	# aviso de evento do mapa: balão de HQ (estrela com "!") que balança sobre a casa
	var show_warn = lab_txt == "!" and (hl == "trem" or hl == "danger")
	if tile["warn"] != null:
		tile["warn"].visible = show_warn
		if show_warn:
			warn_tiles[h] = true
		else:
			warn_tiles.erase(h)
	# casa de escolha: hexágono roxo com um X preto no meio (fácil de achar)
	var is_pick = hl == "pk" and lab_txt == "" and hover != h
	var lb = tile["label"]
	lb.visible = (lab_txt != "" and not show_warn) or is_pick
	lb.font_size = 64
	lb.outline_modulate = Color.BLACK
	if is_pick:
		lb.text = "X"
		lb.font_size = 128
		lb.modulate = Color.BLACK
		lb.outline_modulate = Color(1, 1, 1, 0.9)
		lb.outline_size = 14
	elif lab_txt != "" and not show_warn:
		lb.outline_size = 18
		lb.text = lab_txt
		lb.modulate = state.get("label_colors", {}).get(h, Color.WHITE)


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


# personagem 3D que "conjura": ataque ou habilidade -> estende as mãos, flutua e os olhos acendem (~1,3 s)
func conjura(uid: int) -> void:
	if unit_nodes.has(uid):
		var sp = unit_nodes[uid]["sprite"]
		if sp != null and sp.has_meta("conjura"):
			sp.set_meta("cj_t", 1.3)


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
	# mapas desenhados com as bases em outra direção da grade (Abnara, Gor'Aida): a câmera gira junto
	var yo = deg_to_rad(float(DB.maps[g.map_id].get("cam_yaw", 0))) if g != null else 0.0
	if yo != 0.0:
		goal["yaw"] += yo
		goal["target"] = goal["target"].rotated(Vector3.UP, yo)
	if (me == 1) != flip_view:
		# gira 180°: no online cada um vê o próprio lado à direita
		goal["yaw"] += PI
		goal["target"] = -goal["target"]
	# celular em pé: a câmera fica atrás do SEU campo (sua entrada embaixo da tela, o inimigo em cima)
	if vp.y > vp.x * 1.1 and g != null:
		var mine = world_xz(DB.entry_c[me])
		if mine.length() > 0.1:
			var d = mine.normalized()
			goal["yaw"] = atan2(d.x, d.y)
			goal["target"] = Vector3(d.x, 0, d.y) * PLAT * 0.12
			goal["dist"] = PLAT * 3.1
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
		var now_ms = Time.get_ticks_msec()
		if st.pressed:
			# dedos "fantasma" (toque perdido fora da janela, p. ex.) travavam todos os cliques depois do zoom
			for ti in touches.keys():
				if ti != st.index and now_ms - int(touch_t.get(ti, 0)) > 1200:
					touches.erase(ti)
					touch_t.erase(ti)
			touches[st.index] = st.position
			touch_t[st.index] = now_ms
			if touches.size() < 2:
				multi = false
		else:
			touches.erase(st.index)
			touch_t.erase(st.index)
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
		touch_t[sd.index] = Time.get_ticks_msec()
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
				if mm.position.distance_to(pan["start"]) > 12.0:
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


func _crystal_cluster(parent: Node3D, kind: String, seed_v: int, enfeite: bool = false) -> void:
	var cc = CRYSTAL_COL.get(kind, ["#ffffff", "#999999"])
	if enfeite:
		# fora do tabuleiro: cor apagada e sem brilho, para não parecer um cristal que se pode quebrar
		cc = [Color(cc[0]).darkened(0.55).lerp(Color("#2a2050"), 0.45).to_html(false), Color(cc[1]).darkened(0.6).lerp(Color("#20183e"), 0.45).to_html(false)]
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
		shaft.material_override = _mat(col) if enfeite else _glow_mat(col, 0.85)
		shaft.material_overlay = _ink()
		shaft.position = Vector3(0, hgt * 0.5, 0)
		holder.add_child(shaft)
		var tip = MeshInstance3D.new()
		tip.mesh = _cyl(0.0, rad, rad * 1.6, 6)
		tip.material_override = _mat(col.lightened(0.15)) if enfeite else _glow_mat(col.lightened(0.35), 1.0)
		tip.material_overlay = _ink()
		tip.position = Vector3(0, hgt + rad * 0.8, 0)
		holder.add_child(tip)
	if enfeite:
		return
	# no tabuleiro: anel aceso na base, da cor do efeito (verde cura, azul movimento, roxo dano)
	var aro = MeshInstance3D.new()
	aro.mesh = _hex_ring(0.62, 0.5)
	aro.material_override = _neon(Color(cc[0]), 0.9, 1.3)
	aro.position = Vector3(0, 0.23, 0)
	parent.add_child(aro)
	var lt = OmniLight3D.new()
	lt.light_color = Color(cc[0])
	lt.light_energy = 0.9
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
	# cenário organizado: só duas entradas de mina, de lados opostos; cada uma ladeada por
	# um andaime; os cristais de enfeite ficam em dois grupos, nos lados livres entre elas
	var cands = []
	for ti in range(g.tracks.size()):
		var tr = g.tracks[ti]
		if tr.size() < 2:
			continue
		if g.track_loop[ti]:
			for k in [tr.size() / 12, tr.size() / 12 + tr.size() / 2]:
				cands.append(world_xz(tr[k]).normalized())
		else:
			var end = world_xz(tr[0])
			cands.append((end - world_xz(tr[1])).normalized())
	if cands.is_empty():
		cands = [Vector2(0, 1), Vector2(0, -1)]
	var pa = cands[0]
	var pb = cands[0]
	var best = -2.0
	for x in cands:
		for y in cands:
			var dd = -x.dot(y)
			if dd > best:
				best = dd
				pa = x
				pb = y
	if cands.size() == 1:
		pb = -pa
	for ov in [pa, pb]:
		var ang = atan2(ov.y, ov.x)
		var pe = ov * (PLAT + 0.6)
		_mine_entrance(Vector3(pe.x, BASE_Y, pe.y), atan2(ov.x, ov.y))
		for side in [-0.32, 0.32]:
			var a4 = ang + side
			var d4 = far + 0.2
			_scaffold(Vector3(cos(a4) * d4, BASE_Y, sin(a4) * d4), -a4 + PI * 0.5)
	var kinds = ["verde", "azul", "roxo"]
	var mid = atan2(pa.y, pa.x) + PI * 0.5
	for grp in [mid, mid + PI]:
		for i in range(7):
			var a3 = grp + rng.randf_range(-0.55, 0.55)
			var d3 = far + rng.randf_range(0.2, 1.4)
			var holder = Node3D.new()
			holder.position = Vector3(cos(a3) * d3, BASE_Y + rng.randf_range(0.0, 1.2), sin(a3) * d3)
			holder.scale = Vector3.ONE * rng.randf_range(0.9, 1.7)
			scenery_root.add_child(holder)
			_crystal_cluster(holder, kinds[i % 3], 900 + i + (0 if grp == mid else 50), true)
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


# ================= Abnara (selva viva) e Gor'Aida (gelo instável) =================
# peças feitas com formas simples no estilo HQ (contorno grosso). Quando houver modelos do Meshy,
# é só trocar aqui por _model(...), como em Tarhut.
var flow_dir: Dictionary = {}     # casa -> direção (no mundo) da correnteza/avalanche
var flow_map_id: String = ""


func _flow_of(h: Vector2i) -> Variant:
	if flow_map_id != g.map_id:
		flow_map_id = g.map_id
		flow_dir = {}
		for e in DB.maps[g.map_id].get("flow", []):
			var a = Vector2i(int(e[0]), int(e[1]))
			var b = Vector2i(int(e[2]), int(e[3]))
			flow_dir[a] = (world_xz(b) - world_xz(a)).normalized()
	return flow_dir.get(h, null)


func _inked(mi: MeshInstance3D) -> MeshInstance3D:
	return mi   # cores chapadas, sem contorno


func _sph(r: float, hgt: float = -1.0) -> SphereMesh:
	var sm = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 if hgt < 0.0 else hgt
	sm.radial_segments = 10
	sm.rings = 6
	return sm


var hex_flat_mesh: ArrayMesh = null
var water_mats: Dictionary = {}


func _hex_flat() -> ArrayMesh:
	if hex_flat_mesh == null:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		for k in range(6):
			var a = PI / 3.0 * k
			var b = PI / 3.0 * (k + 1)
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(Vector3(cos(b), 0, sin(b)) * TILE * 1.002)
			st.add_vertex(Vector3(cos(a), 0, sin(a)) * TILE * 1.002)
		hex_flat_mesh = st.commit()
	return hex_flat_mesh


# direção da correnteza de uma casa de água ou de ponte (a ponte herda a de uma vizinha de água)
func _river_dir(h: Vector2i) -> Vector2:
	var fd: Variant = _flow_of(h)
	if fd != null:
		return fd
	for n in DB.DIRS:
		var nb = h + n
		var f2: Variant = _flow_of(nb)
		if f2 != null and tiles.has(nb):
			return f2
	return Vector2(0, 1)


func _water(root: Node3D, h: Vector2i, y: float) -> void:
	var d = _river_dir(h)
	var key = "%.2f,%.2f" % [d.x, d.y]
	if not water_mats.has(key):
		var m = ShaderMaterial.new()
		m.shader = load("res://shaders/agua.gdshader")
		m.set_shader_parameter("flow", d)
		water_mats[key] = m
	var mi = MeshInstance3D.new()
	mi.mesh = _hex_flat()
	mi.scale = Vector3(HX, 1, HX)
	mi.position = Vector3(0, y, 0)
	mi.material_override = water_mats[key]
	root.add_child(mi)


# ponte: sem chão por baixo, água correndo no leito e tabuleiro de tábuas de borda a borda da casa
func _bank_score(n: Vector2i) -> int:
	if not tiles.has(n):
		return 0
	var k = g.terr(n)["k"]
	if k == "correnteza" or k == "fosso" or k == "buraco":
		return 0
	return 1 if k == "ponte" else 2


func _bridge(root: Node3D, h: Vector2i) -> void:
	_water(root, h, -RIVER_DROP * HS + 0.03)
	# eixo da ponte: o par de vizinhas opostas com mais chão (margem vale 2, outra ponte vale 1, água 0);
	# no empate, atravessa o rio (perpendicular à correnteza)
	var axis = Vector2(0, 1)
	var best = -999.0
	var fl = _river_dir(h)
	for i in range(3):
		var a = h + DB.DIRS[i]
		var b = h + DB.DIRS[i + 3]
		var ax = (world_xz(a) - world_xz(b)).normalized()
		var sc = float(_bank_score(a) + _bank_score(b)) - abs(ax.dot(fl)) * 0.5
		if sc > best:
			best = sc
			axis = ax
	# ilha de ponte cercada de água: o tabuleiro cruza as casas de água vizinhas até a margem, 2 casas adiante
	var span = 1.0
	if best <= 0.0:
		var fbest = -999.0
		for i in range(3):
			var a2 = h + DB.DIRS[i] * 2
			var b2 = h + DB.DIRS[i + 3] * 2
			var ax2 = (world_xz(a2) - world_xz(b2)).normalized()
			var sc2 = float(_bank_score(a2) + _bank_score(b2)) - abs(ax2.dot(fl)) * 0.5
			if sc2 > fbest:
				fbest = sc2
				axis = ax2
		span = 3.0   # a margem começa a 2,6 do centro: tabuleiro de 3 casas de comprimento
	var br = Node3D.new()
	br.rotation = Vector3(0, atan2(axis.x, axis.y), 0)
	br.scale = Vector3(HX, 1, HX)
	root.add_child(br)
	var L = S3 * TILE * (span + 0.16)     # de borda a borda e um pouco sobre as margens
	var W = 1.5
	var n = int(round(9.0 * L / (S3 * TILE * 1.16)))
	var pw = L / n
	for i in range(n):
		var c = Color("#c9824a").lerp(Color("#a8622e"), _rnd(h, i))
		_mesh(br, _box(Vector3(W, 0.09, pw * 0.88)), c, Vector3(0, 0.03, -L * 0.5 + pw * (i + 0.5)))
	for sx in [-1.0, 1.0]:
		_mesh(br, _box(Vector3(0.12, 0.1, L)), Color("#7a4a26"), Vector3(sx * W * 0.5, -0.04, 0))
		_mesh(br, _box(Vector3(0.07, 0.07, L)), Color("#8c5a2c"), Vector3(sx * W * 0.5, 0.36, 0))
		var np = int(L / 1.1) + 1
		for pi in range(np):
			var sz = (float(pi) / float(np - 1) - 0.5) * 0.92 if np > 1 else 0.0
			_mesh(br, _box(Vector3(0.09, 0.4, 0.09)), Color("#7a4a26"), Vector3(sx * W * 0.5, 0.17, sz * L))


func _arrow(root: Node3D, dir: Vector2, col: Color, y: float, s: float = 1.0) -> void:
	var arrow = Node3D.new()
	arrow.rotation = Vector3(0, -atan2(dir.y, dir.x), 0)
	root.add_child(arrow)
	_mesh(arrow, _box(Vector3(0.5 * s, 0.03, 0.09 * s)), col, Vector3(-0.1 * s, y, 0))
	_mesh(arrow, _cyl(0.0, 0.17 * s, 0.04, 3), col, Vector3(0.24 * s, y, 0), Vector3(0, PI / 2, 0))


var pincel_mats: Dictionary = {}


# copa pintada (shader pincel): cada árvore usa uma de 3 variações de verde para não repetir
func _pincel_mat(i: int) -> ShaderMaterial:
	var k = i % 3
	if not pincel_mats.has(k):
		var m = ShaderMaterial.new()
		m.shader = load("res://shaders/pincel.gdshader")
		m.set_shader_parameter("seed", float(k) * 4.7)
		var sets = [[Color("#1f4a3a"), Color("#3f6f32"), Color("#86a63c")],
			[Color("#27503a"), Color("#4a7a38"), Color("#9cb445")],
			[Color("#1a4448"), Color("#35703c"), Color("#7ea840")]]
		m.set_shader_parameter("c_dark", sets[k][0])
		m.set_shader_parameter("c_mid", sets[k][1])
		m.set_shader_parameter("c_light", sets[k][2])
		m.set_shader_parameter("shadow_tint", _planet_shadow())
		pincel_mats[k] = m
	return pincel_mats[k]


# musgo em camadas: cadeia de passes (next_pass), cada um uma camada mais alta dos tufos
var moss_chain: ShaderMaterial = null


func _moss_mat() -> ShaderMaterial:
	if moss_chain == null:
		var n = 5
		var prev: ShaderMaterial = null
		for i in range(n - 1, -1, -1):
			var m = ShaderMaterial.new()
			m.shader = load("res://shaders/musgo.gdshader")
			m.set_shader_parameter("layer", float(i) / float(n - 1))
			m.set_shader_parameter("shadow_tint", _planet_shadow())
			if prev != null:
				m.next_pass = prev
			prev = m
		moss_chain = prev
	return moss_chain


# material pintado com paleta própria (raízes, plantas...)
func _pincel_custom(key: String, dark: Color, mid: Color, light: Color, edge: float = 0.4, scale: float = 5.0) -> ShaderMaterial:
	if not pincel_mats.has(key):
		var m = ShaderMaterial.new()
		m.shader = load("res://shaders/pincel.gdshader")
		m.set_shader_parameter("seed", float(key.hash() % 97))
		m.set_shader_parameter("moss_top", 1.0 if key == "pedra_ruina" else 0.0)
		m.set_shader_parameter("c_dark", dark)
		m.set_shader_parameter("c_mid", mid)
		m.set_shader_parameter("c_light", light)
		m.set_shader_parameter("edge", edge)
		m.set_shader_parameter("patch_scale", scale)
		m.set_shader_parameter("shadow_tint", _planet_shadow())
		pincel_mats[key] = m
	return pincel_mats[key]


func _jungle_tree(root: Node3D, pos: Vector3, s: float, h: Vector2i, i: int) -> void:
	# tronco e galhos escuros e finos, como no guache; copa em três manchas sobrepostas
	_mesh(root, _cyl(0.05 * s, 0.1 * s, 0.7 * s, 6), Color("#2a1a1c"), pos + Vector3(0, 0.35 * s, 0))
	for j in range(2):
		var a = _rnd(h, i + 50 + j) * TAU
		_mesh(root, _cyl(0.02 * s, 0.04 * s, 0.5 * s, 4), Color("#2a1a1c"), pos + Vector3(cos(a) * 0.1 * s, 0.78 * s, sin(a) * 0.1 * s), Vector3(sin(a) * 0.7, 0, -cos(a) * 0.7))
	var mat = _pincel_mat(i)
	var blobs = [[Vector3(0, 0.86, 0), 0.46, 0.58], [Vector3(-0.2, 1.02, 0.1), 0.3, 0.4], [Vector3(0.2, 1.1, -0.1), 0.32, 0.42]]
	for b in blobs:
		var jit = Vector3((_rnd(h, i + 40) - 0.5) * 0.12, 0, (_rnd(h, i + 41) - 0.5) * 0.12)
		var mi = _mesh(root, _sph(b[1] * s, b[2] * s), Color.WHITE, pos + b[0] * s + jit * s)
		mi.material_override = mat


# ---- modelos do Nature Kit da Kenney (CC0), repintados com a paleta de cada bioma ----
# cada material do kit tem um nome (folhas, casca, pedra...); a paleta troca a cor e o jogo aplica a pintura do mapa
const KPAL = {
	"jungle": {"grass": "#3c9a44", "leafsGreen": "#2f8a3e", "leafsDark": "#236e36", "leafsFall": "#8abf4a",
		"dirt": "#6a4a3e", "dirtDark": "#4a3030", "woodBark": "#4a2e26", "woodBarkDark": "#3a2228", "wood": "#a07850", "woodDark": "#6a4a3e",
		"woodInner": "#d8b890", "woodBirch": "#e8dcc0", "stone": "#9a96b8", "stoneDark": "#76739a", "water": "#5ec8f0",
		"colorRed": "#f438a9", "colorRedDark": "#b0207a", "colorPurple": "#a957ec", "colorYellow": "#ffd12e", "colorWhite": "#fff0fa", "colorTan": "#e8c890", "_defaultMat": "#e8e0f0"},
	"snow": {"grass": "#f2f8ff", "leafsGreen": "#3c806a", "leafsDark": "#2f6a5a", "leafsFall": "#5a8a7a",
		"dirt": "#7a5a3e", "dirtDark": "#5a3d22", "woodBark": "#5a3d22", "woodBarkDark": "#4a301c", "wood": "#8a6040", "woodDark": "#5a3d22",
		"woodInner": "#d8c0a0", "woodBirch": "#efe8dc", "stone": "#d8f2ff", "stoneDark": "#9cd4f4", "water": "#9cd4f4",
		"colorRed": "#f438a9", "colorRedDark": "#b0207a", "colorPurple": "#a957ec", "colorYellow": "#ffd12e", "colorWhite": "#ffffff", "colorTan": "#e8c890", "_defaultMat": "#e8f4ff"},
}
var _kmats: Dictionary = {}


func _kmat(pal: String, mname: String, orig: Color) -> Material:
	var key = pal + ":" + mname
	if not _kmats.has(key):
		var col = Color(KPAL[pal][mname]) if KPAL[pal].has(mname) else orig
		_kmats[key] = _gouache(col)   # pincelada do jogo (manchas claras e escuras), igual às árvores antigas
	return _kmats[key]


# coloca o modelo com a base no chão e a altura "alt" (ou a largura, se "por_largura")
func _kenney(parent: Node3D, mname: String, pos: Vector3, alt: float, yaw: float, pal: String, por_largura: bool = false) -> bool:
	var sc = _scene_of("kenney/" + mname)
	if sc == null:
		return false
	var inst: Node3D = sc.instantiate()
	var meshes = inst.find_children("*", "MeshInstance3D", true, false)
	var box = AABB()
	var first = true
	for mi in meshes:
		var m: Mesh = mi.mesh
		for si in range(m.get_surface_count()):
			var sm = m.surface_get_material(si)
			var nm2 = sm.resource_name if sm != null else "_defaultMat"
			var oc = sm.albedo_color if sm is BaseMaterial3D else Color.WHITE
			mi.set_surface_override_material(si, _kmat(pal, nm2, oc))
		mi.material_overlay = null
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var ab = _rel_xf(inst, mi) * mi.get_aabb()
		box = ab if first else box.merge(ab)
		first = false
	var ref = max(box.size.x, box.size.z) if por_largura else box.size.y
	var k = alt / ref if ref > 0.0001 else 1.0
	var holder = Node3D.new()
	holder.position = pos
	holder.rotation = Vector3(0, yaw, 0)
	parent.add_child(holder)
	holder.add_child(inst)
	inst.scale = Vector3.ONE * k
	inst.position = Vector3(-(box.position.x + box.size.x / 2.0) * k, -box.position.y * k, -(box.position.z + box.size.z / 2.0) * k)
	return true


func _rel_xf(root: Node, n: Node) -> Transform3D:
	var t = Transform3D.IDENTITY
	var c = n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


const K_SELVA = ["tree_detailed", "tree_fat", "tree_blocks", "tree_default", "tree_oak", "tree_tall"]
const K_PALMA = ["tree_palmDetailedTall", "tree_palmBend", "tree_palmTall"]
const K_MOITA = ["plant_bushLarge", "plant_bushDetailed", "plant_bush", "grass_leafsLarge"]
const K_FLOR = ["flower_purpleA", "flower_redB", "flower_yellowA", "mushroom_redGroup", "mushroom_tanTall", "mushroom_red"]
const K_RUINA = ["statue_columnDamaged", "statue_column", "statue_head", "statue_ring"]
const K_PINHO = ["tree_pineTallA_detailed", "tree_pineTallB_detailed", "tree_pineRoundC", "tree_pineSmallB", "tree_pineGroundA", "tree_pineDefaultA"]
const K_PEDRA_NEVE = ["stone_tallC", "stone_tallF", "stone_largeB", "stone_largeD"]


func _kpick(list: Array, h: Vector2i, salt: int) -> String:
	return list[int(_rnd(h, salt) * list.size()) % list.size()]


func _wild_props(root: Node3D, h: Vector2i, k: String) -> bool:
	match k:
		"mata":
			# mata densa = CAPIM ALTO: dá para entrar (não é árvore, que parece parede), mas tapa a visão.
			# tufos de lâminas finas, mais claros que as árvores de enfeite, na borda da casa (quem está no meio aparece)
			var rr0 = 0.6 * HX
			var a0 = _rnd(h, 2) * TAU
			var cores_c = [Color("#7ed957"), Color("#5cc04a"), Color("#a8ec6e")]
			for i in range(7):
				var aa = a0 + TAU / 7.0 * i + (_rnd(h, i + 40) - 0.5) * 0.4
				var tufo = Vector3(cos(aa) * rr0, 0, sin(aa) * rr0)
				for j in range(4):
					var alt = 0.75 + _rnd(h, i * 7 + j) * 0.55
					var inc = (_rnd(h, i * 5 + j + 100) - 0.5) * 0.5
					var ang_l = _rnd(h, i * 3 + j + 200) * TAU
					var off_l = Vector3(cos(ang_l), 0, sin(ang_l)) * 0.09
					var lam = _mesh(root, _cyl(0.0, 0.075, alt, 4), cores_c[(i + j) % 3], tufo + off_l + Vector3(0, alt * 0.5, 0), Vector3(inc, ang_l, -inc))
					lam.material_override = _mat(cores_c[(i + j) % 3])
			_kenney(root, _kpick(K_MOITA, h, 70), Vector3((_rnd(h, 20) - 0.5) * 0.6, 0, (_rnd(h, 21) - 0.5) * 0.6), 0.18, _rnd(h, 23) * TAU, "jungle")
		"raiz":
			var holder = Node3D.new()
			holder.rotation = Vector3(0, _rnd(h, 2) * TAU, 0)
			root.add_child(holder)
			for i in range(4):
				var cap = CapsuleMesh.new()
				cap.radius = 0.12
				cap.height = 1.25
				var a = TAU / 4.0 * i
				var rm = _mesh(holder, cap, Color.WHITE, Vector3(cos(a) * 0.22, 0.45, sin(a) * 0.22), Vector3(sin(a) * 0.75, 0, -cos(a) * 0.75))
				rm.material_override = _pincel_custom("raiz", Color("#3a2430"), Color("#6a4a3e"), Color("#a07850"), 0.3, 7.0)
			var rb = _mesh(holder, _sph(0.3, 0.42), Color.WHITE, Vector3(0, 0.95, 0))
			rb.material_override = _pincel_custom("raiz", Color("#3a2430"), Color("#6a4a3e"), Color("#a07850"), 0.3, 7.0)
			_mesh(holder, _sph(0.16, 0.12), Color("#4ea844"), Vector3(0.05, 1.18, 0.02))
		"correnteza":
			var fd: Variant = _flow_of(h)
			_water(root, h, 0.03)
			if fd != null:
				_arrow(root, fd, Color("#ffffff"), 0.06)
		"ponte":
			_bridge(root, h)
		"ruina_alta":
			# ruínas esquecidas: restos de templo, quebrados e tombados, ligados às ruínas vizinhas por muros caídos
			var hb = Node3D.new()
			hb.rotation = Vector3(0, int(_rnd(h, 2) * 6) * PI / 3.0, 0)
			root.add_child(hb)
			var st_m = _pincel_custom("pedra_ruina", Color("#5f5d80"), Color("#76739a"), Color("#938fb4"), 0.0, 2.0)
			var mo_m = _pincel_custom("musgo", Color("#1f4a2a"), Color("#3f8a3a"), Color("#8abf4a"), 0.15, 6.0)
			var sh_m = _moss_mat()
			var parts = []
			# laje afundada e torta
			parts.append([_box(Vector3(1.45, 0.12, 1.2)), Vector3(0, 0.04, 0), Vector3(0.03, 0.1, -0.03), st_m])
			parts.append([_box(Vector3(1.0, 0.1, 0.8)), Vector3(0.1, 0.13, 0.0), Vector3(-0.04, -0.15, 0.05), st_m])
			# colunas quebradas em alturas diferentes (uma tombada, uma só tocos)
			parts.append([_cyl(0.15, 0.17, 0.95, 8), Vector3(-0.42, 0.62, -0.15), Vector3(0.06, 0, 0.08), st_m])
			parts.append([_box(Vector3(0.36, 0.1, 0.36)), Vector3(-0.42, 1.14, -0.15), Vector3(0.1, 0.3, 0.2), st_m])
			parts.append([_cyl(0.15, 0.17, 0.42, 8), Vector3(0.42, 0.3, -0.15), Vector3(0, 0, -0.05), st_m])
			parts.append([_cyl(0.13, 0.15, 0.7, 8), Vector3(0.3, 0.2, 0.42), Vector3(0.0, 0.5, PI / 2.0 - 0.1), st_m])
			parts.append([_cyl(0.1, 0.13, 0.28, 7), Vector3(-0.15, 0.22, 0.4), Vector3(0.1, 0.0, 0.5), st_m])
			# verga partida: metade caída no chão, metade ainda apoiada
			parts.append([_box(Vector3(0.55, 0.18, 0.32)), Vector3(-0.32, 1.28, -0.15), Vector3(0, 0.0, 0.35), st_m])
			parts.append([_box(Vector3(0.5, 0.18, 0.32)), Vector3(0.2, 0.18, -0.55), Vector3(0.12, 0.6, 0.15), st_m])
			# fragmentos de muro e entulho espalhado
			for i in range(3):
				parts.append([_box(Vector3(0.34, 0.2, 0.26)), Vector3(-0.5 + i * 0.38, 0.22, 0.46), Vector3(0, 0.08 * i, 0.04 * i), st_m])
			parts.append([_box(Vector3(0.34, 0.2, 0.26)), Vector3(-0.3, 0.42, 0.46), Vector3(0.1, 0.15, 0.25), st_m])
			for i in range(4):
				var rx = (_rnd(h, 40 + i) - 0.5) * 1.5
				var rz = (_rnd(h, 50 + i) - 0.5) * 1.3
				var sz = 0.1 + _rnd(h, 60 + i) * 0.16
				parts.append([_box(Vector3(sz * 1.3, sz, sz)), Vector3(rx, 0.1 + sz * 0.4, rz), Vector3(_rnd(h, 70 + i), _rnd(h, 80 + i) * 3.0, _rnd(h, 90 + i)), st_m])
			# musgo cobrindo o que sobrou
			parts.append([_box(Vector3(0.6, 0.04, 0.4)), Vector3(0.1, 0.2, 0.02), Vector3(0.03, 0.1, -0.03), sh_m])
			parts.append([_cyl(0.17, 0.19, 0.12, 8), Vector3(-0.42, 1.08, -0.15), Vector3(0.06, 0, 0.08), sh_m])
			parts.append([_cyl(0.17, 0.19, 0.08, 8), Vector3(0.42, 0.52, -0.15), Vector3(0, 0, -0.05), sh_m])
			parts.append([_cyl(0.025, 0.03, 0.8, 4), Vector3(-0.28, 0.7, -0.02), Vector3(0.1, 0, 0.1), mo_m])
			parts.append([_cyl(0.025, 0.03, 0.5, 4), Vector3(0.5, 0.3, -0.05), Vector3(-0.1, 0, -0.1), mo_m])
			for pt in parts:
				var mi = _mesh(hb, pt[0], Color.WHITE, pt[1], pt[2])
				mi.material_override = pt[3]
			# ligação com as ruínas vizinhas: calçada rachada e muro caído até a divisa da casa
			var c0 = world_xz(h)
			for di in range(6):
				var nb = h + DB.DIRS[di]
				if not tiles.has(nb) or g.terr(nb)["k"] != "ruina_alta":
					continue
				var dv = world_xz(nb) - c0
				var dist = dv.length()
				var d = dv / dist
				var yaw = atan2(-d.y, d.x)
				var half = dist * 0.5 + 0.06
				var lp = []
				lp.append([_box(Vector3(half, 0.07, 0.62)), Vector3(d.x * half * 0.5, 0.06, d.y * half * 0.5), Vector3(0, yaw + 0.04, 0.02), st_m])
				var nbk = int(half / 0.34)
				for j in range(nbk + 1):
					var t = 0.38 + j * 0.34
					if j == nbk:
						t = half - 0.12
					var r0 = _rnd(h + DB.DIRS[di], 100 + j)
					if j < nbk and r0 < 0.42:
						continue   # buraco no muro
					var side = 0.34 if (j % 2 == 0) else -0.34
					var bh = 0.12 + r0 * 0.32
					var base = Vector3(d.x * t - d.y * side * 0.0, 0.0, d.y * t)
					var off = Vector3(-d.y, 0, d.x) * side
					lp.append([_box(Vector3(0.34, bh, 0.24)), base + off + Vector3(0, bh * 0.5 + 0.06, 0), Vector3(r0 * 0.3, yaw + (r0 - 0.5) * 0.8, (r0 - 0.5) * 0.5), st_m])
					if r0 > 0.85:
						lp.append([_box(Vector3(0.34, 0.04, 0.24)), base + off + Vector3(0, bh + 0.08, 0), Vector3(r0 * 0.3, yaw + (r0 - 0.5) * 0.8, (r0 - 0.5) * 0.5), sh_m])
				for pt in lp:
					var mi2 = _mesh(root, pt[0], Color.WHITE, pt[1], pt[2])
					mi2.material_override = pt[3]
		"planta":
			for i in range(4):
				var a2 = TAU / 4.0 * i + _rnd(h, 1)
				var lf = _mesh(root, _sph(0.26, 0.08), Color.WHITE, Vector3(cos(a2) * 0.32, 0.04, sin(a2) * 0.32))
				lf.material_override = _pincel_custom("folha", Color("#1a4a3a"), Color("#2f7a44"), Color("#6aa84a"), 0.2, 6.0)
			var st2 = _mesh(root, _cyl(0.07, 0.1, 0.55, 6), Color.WHITE, Vector3(0, 0.28, 0))
			st2.material_override = _pincel_custom("folha", Color("#1a4a3a"), Color("#2f7a44"), Color("#6aa84a"), 0.2, 6.0)
			var head = Node3D.new()
			head.position = Vector3(0, 0.72, 0)
			head.rotation = Vector3(0, _rnd(h, 6) * TAU, 0)
			root.add_child(head)
			var hm1 = _mesh(head, _sph(0.34, 0.34), Color.WHITE, Vector3(0, 0.1, 0), Vector3(0.0, 0, 0.35))
			var hm2 = _mesh(head, _sph(0.34, 0.3), Color.WHITE, Vector3(0, -0.12, 0), Vector3(0.0, 0, -0.3))
			for hm in [hm1, hm2]:
				hm.material_override = _pincel_custom("petala", Color("#6a1660"), Color("#c02a98"), Color("#ff6ad0"), 0.25, 6.0)
			for i in range(5):
				var tx = -0.22 + i * 0.11
				_mesh(head, _cyl(0.0, 0.035, 0.12, 4), Color("#fff6e0"), Vector3(0.24, -0.02, tx), Vector3(0, 0, PI))
			for i in range(5):
				_mesh(head, _sph(0.035, 0.035), Color("#fff0fa"), Vector3(-0.05 + _rnd(h, i + 30) * 0.2, 0.32, -0.15 + i * 0.07))
		"trilha", "clareira":
			for i in range(2):
				_kenney(root, "grass_large" if k == "trilha" else "grass_leafsLarge", Vector3((_rnd(h, i) - 0.5) * 1.0, 0, (_rnd(h, i + 9) - 0.5) * 0.9), 0.14, _rnd(h, i + 4) * TAU, "jungle")
			if _rnd(h, 33) > 0.6:
				_kenney(root, _kpick(K_FLOR, h, 34), Vector3((_rnd(h, 35) - 0.5) * 0.9, 0, (_rnd(h, 36) - 0.5) * 0.9), 0.2, _rnd(h, 37) * TAU, "jungle")
		"neve", "neve_base":
			for i in range(2):
				if _rnd(h, i + 50) > 0.45:
					_mesh(root, _sph(0.18 + _rnd(h, i) * 0.1, 0.12), Color("#ffffff"), Vector3((_rnd(h, i + 1) - 0.5) * 1.0, 0.03, (_rnd(h, i + 2) - 0.5) * 0.9))
		"gelo":
			for i in range(3):
				_mesh(root, _box(Vector3(0.55, 0.012, 0.05)), Color("#ffffff"), Vector3((_rnd(h, i) - 0.5) * 0.8, 0.015, (_rnd(h, i + 6) - 0.5) * 0.8), Vector3(0, 0.6 + _rnd(h, 9) * 0.3, 0))
		"gelo_fragil":
			# gelo frágil: tom mais escuro, bolhas de ar presas e UMA rachadura fina atravessando (sem forma de X,
			# que parecia um "proibido"; tools/rachadura.py linha=True)
			_crack_decal(root, h, 6 + int(_rnd(h, 21) * 3) % 3, 1.5)
			for i in range(5):
				var a7 = _rnd(h, i + 80) * TAU
				var r7 = sqrt(_rnd(h, i + 90)) * 0.62
				var rb = 0.035 + _rnd(h, i + 95) * 0.045
				_mesh(root, _cyl(rb, rb, 0.008, 10), Color("#d8f4ff"), Vector3(cos(a7) * r7, 0.016, sin(a7) * r7))
		"fenda":
			# chão do buraco: rachaduras azul-claras, retícula e cacos de gelo nascendo do fundo (sem nada preto chapado)
			_crack_decal(root, h, 3 + int(_rnd(h, 24) * 3) % 3, 1.8, 0.013)
			for i in range(14):
				var a5 = _rnd(h, i + 30) * TAU
				var r5 = sqrt(_rnd(h, i + 50)) * 0.78
				_mesh(root, _cyl(0.035 + _rnd(h, i + 70) * 0.03, 0.035 + _rnd(h, i + 70) * 0.03, 0.01, 8), Color("#3f8fe6"), Vector3(cos(a5) * r5, 0.014, sin(a5) * r5))
			for i in range(3):
				var a6 = TAU / 3.0 * i + _rnd(h, 5) * 2.0
				var hh2 = 0.28 + _rnd(h, i + 9) * 0.22
				_inked(_mesh(root, _cyl(0.0, 0.1, hh2, 5), Color("#d6f1ff"), Vector3(cos(a6) * 0.38, hh2 * 0.5, sin(a6) * 0.38), Vector3(sin(a6) * 0.18, 0, -cos(a6) * 0.18)))
		"parede_gelo":
			for i in range(3):
				var px = (i - 1) * 0.36 + (_rnd(h, i) - 0.5) * 0.1
				var ht = 1.2 + _rnd(h, i + 3) * 0.5
				_inked(_mesh(root, _cyl(0.08, 0.3, ht, 5), Color("#9cd4f4").lerp(Color("#c8ecff"), _rnd(h, i + 6)), Vector3(px, ht * 0.5, (_rnd(h, i + 9) - 0.5) * 0.4), Vector3(0, _rnd(h, i + 12), (_rnd(h, i + 15) - 0.5) * 0.2)))
			_inked(_mesh(root, _box(Vector3(1.1, 0.5, 0.8)), Color("#b8e0f8"), Vector3(0, 0.25, 0)))
			_mesh(root, _box(Vector3(1.0, 0.08, 0.7)), Color("#ffffff"), Vector3(0, 0.52, 0))
		"avalanche":
			var fd2: Variant = _flow_of(h)
			if fd2 == null:
				fd2 = Vector2(0, 1)
			_arrow(root, fd2, Color("#f438a9"), 0.03, 1.1)
			_arrow(root, fd2, Color("#a957ec"), 0.03, 0.7)
			_mesh(root, _sph(0.2, 0.12), Color("#ffffff"), Vector3((_rnd(h, 1) - 0.5) * 0.8, 0.03, (_rnd(h, 2) - 0.5) * 0.8))
		_:
			return false
	return true


# entorno do planeta (fora do tabuleiro): floresta e ruínas em Abnara, picos de gelo em Gor'Aida
func _build_wild(kind: String) -> void:
	var cells = []
	for q in range(-DB.R - 5, DB.R + 6):
		for r in range(-DB.R - 5, DB.R + 6):
			var hh = Vector2i(q, r)
			var d = DB.out_dist(hh)
			if d >= 1 and d <= 5:
				cells.append(hh)
	for h in cells:
		var d = DB.out_dist(h)
		var dens = 0.35 if d == 1 else (0.6 if kind == "jungle" else 0.45)
		if _rnd(h, 9) > dens:
			continue
		var wp = world_xz(h)
		var px = wp.x + (_rnd(h, 5) - 0.5) * 0.8
		var pz = wp.y + (_rnd(h, 6) - 0.5) * 0.8
		var holder = Node3D.new()
		scenery_root.add_child(holder)
		holder.position = Vector3(px, planet_y(px, pz), pz)
		var s = (0.9 + _rnd(h, 8) * 0.6) * (0.8 if d == 1 else 1.0 + d * 0.08)
		var roll = _rnd(h, 11)
		if kind == "jungle":
			var yw = _rnd(h, 4) * TAU
			if roll < 0.62:
				var lj = K_PALMA if _rnd(h, 14) < 0.3 else K_SELVA
				if not _kenney(holder, _kpick(lj, h, 15), Vector3.ZERO, 1.9 * s, yw, "jungle"):
					_jungle_tree(holder, Vector3.ZERO, s * 1.3, h, int(_rnd(h, 3) * 3))
				if _rnd(h, 16) > 0.6:
					_kenney(holder, _kpick(K_FLOR, h, 17), Vector3(0.45 * s, 0, 0.2 * s), 0.3 * s, yw, "jungle")
			elif roll < 0.8:
				for i in range(2):
					_kenney(holder, _kpick(K_MOITA, h, i + 18), Vector3((_rnd(h, i + 1) - 0.5) * 0.8 * s, 0, (_rnd(h, i + 2) - 0.5) * 0.8 * s), (0.45 + _rnd(h, i + 3) * 0.25) * s, yw + i, "jungle")
				_kenney(holder, _kpick(K_FLOR, h, 24), Vector3(0.3 * s, 0, -0.3 * s), 0.28 * s, yw, "jungle")
			elif roll < 0.92:
				_kenney(holder, _kpick(K_RUINA, h, 25), Vector3.ZERO, 1.3 * s, yw, "jungle")
				if _rnd(h, 26) > 0.5:
					_kenney(holder, "grass_leafsLarge", Vector3(0.35 * s, 0, 0.1 * s), 0.25 * s, yw, "jungle")
			else:
				_kenney(holder, "rock_largeA" if _rnd(h, 27) > 0.5 else "rock_largeC", Vector3.ZERO, 1.1 * s, yw, "jungle", true)
				if _rnd(h, 28) > 0.5:
					_kenney(holder, "stump_oldTall" if _rnd(h, 29) > 0.5 else "log_large", Vector3(0.5 * s, 0, 0), 0.45 * s, yw, "jungle")
		else:
			var yw2 = _rnd(h, 4) * TAU
			if roll < 0.25:
				for i in range(3):
					var ht = (1.0 + _rnd(h, i + 3) * 1.4) * s
					_inked(_mesh(holder, _cyl(0.0, 0.32 * s, ht, 5), Color("#9cd4f4").lerp(Color("#d8f2ff"), _rnd(h, i + 6)), Vector3((_rnd(h, i) - 0.5) * 0.7 * s, ht * 0.5, (_rnd(h, i + 9) - 0.5) * 0.7 * s), Vector3((_rnd(h, i + 12) - 0.5) * 0.3, 0, (_rnd(h, i + 15) - 0.5) * 0.3)))
			elif roll < 0.42:
				# rochas cobertas de gelo e um monte de neve
				_kenney(holder, _kpick(K_PEDRA_NEVE, h, 30), Vector3.ZERO, (0.8 + _rnd(h, 31) * 0.6) * s, yw2, "snow")
				_inked(_mesh(holder, _sph(0.4 * s, 0.3 * s), Color("#ffffff"), Vector3(0.4 * s, 0.05, 0.2 * s)))
			elif roll < 0.92 or d < 2:
				# pinheiros: 1 a 3 juntos, de alturas diferentes
				var np = 1 + int(_rnd(h, 32) * 3)
				for i in range(np):
					var off = Vector3((_rnd(h, i + 33) - 0.5) * 0.9 * s, 0, (_rnd(h, i + 36) - 0.5) * 0.9 * s) if i > 0 else Vector3.ZERO
					if not _kenney(holder, _kpick(K_PINHO, h, i + 39), off, (1.5 + _rnd(h, i + 42) * 0.9) * s * (1.0 if i == 0 else 0.7), yw2 + i, "snow"):
						_mesh(holder, _cyl(0.0, 0.42 * s, 1.2 * s, 8), Color("#2f6a5a"), off + Vector3(0, 0.6 * s, 0))
			else:
				# acampamento abandonado na neve
				var acamp = ["tent_detailedClosed", "log_stackLarge", "campfire_stones", "stump_round"]
				_kenney(holder, acamp[int(_rnd(h, 45) * 4) % 4], Vector3.ZERO, 0.9 * s, yw2, "snow", true)
