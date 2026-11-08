extends Node3D
## Galáxia do menu: estrela central, planetas em órbita, cinturão de asteroides.
## Modos de câmera: "title" (visão ampla girando), "select" (escolher planeta),
## "focus" (planeta escolhido à esquerda, tela de exército), "dive" (mergulho no planeta).

signal planet_hover(id: String)
signal planet_click(id: String)

const PLANETS = [
	{"id": "valak", "map": "posto", "name": "Valak", "sub": "Mina de cristais dos Terramorfos",
		"desc": "Caverna de cristais numa mina abandonada pelos Terramorfos. O labirinto muda a cada partida e algo vive no buraco do centro.",
		"r": 21.0, "size": 2.3, "speed": 0.055, "a0": 0.9, "tex": "valak",
		"atm": Color(0.45, 0.8, 1.0, 0.9), "dive": Color("#2aa6c8"), "pick": true, "moon": true},
	{"id": "tarhut", "map": "tarhut", "name": "Tarhut", "sub": "O planeta dos 5 sóis",
		"desc": "Deserto de dunas que mudam a cada 5 rounds. Vermes gigantes abrem buracos.",
		"r": 37.0, "size": 3.0, "speed": 0.034, "a0": 2.3, "tex": "tarhut",
		"atm": Color(1.0, 0.78, 0.45, 0.9), "dive": Color("#e0b070"), "pick": true, "suns": 5},
	{"id": "gigante", "r": 56.0, "size": 5.4, "speed": 0.017, "a0": 4.6, "tex": "gigante", "atm": Color(0.7, 0.5, 1.0, 0.7), "ring": true},
]

var cam: Camera3D
var mode: String = "title"
var focus_id: String = ""
var hover_id: String = ""
var nodes: Dictionary = {}       # id -> {body, atm, data, extra, sel}
var orbit_t: float = 0.0
var speed: float = 1.0
var speed_goal: float = 1.0
var clock: float = 0.0
var cam_pos: Vector3 = Vector3(0, 60, 120)
var cam_look: Vector3 = Vector3.ZERO
var h_off: float = 0.0
var dive_t: float = 0.0
var dive_from: Vector3
var belt: Node3D
var atm_shader: Shader
var env: Environment = null     # ambiente do mundo (do tabuleiro); a galáxia troca o céu
var sky_space: Sky = null


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.far = 2000.0
	add_child(cam)
	atm_shader = Shader.new()
	atm_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 col : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float power = 2.6;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	ALBEDO = col.rgb * f * col.a * 1.6;
}
"""
	# estrela central
	var light = OmniLight3D.new()
	light.omni_range = 400.0
	light.omni_attenuation = 0.15
	light.light_energy = 1.35
	light.light_color = Color("#fff0d8")
	add_child(light)
	var star = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 4.2
	sm.height = 8.4
	star.mesh = sm
	star.material_override = _unshaded(Color("#fff4dc"))
	add_child(star)
	add_child(_glow(34.0, Color(1.0, 0.72, 0.35, 0.95)))
	add_child(_glow(14.0, Color(1.0, 0.95, 0.8, 1.0)))
	# órbitas e planetas
	for p in PLANETS:
		_make_planet(p)
	# visual HQ: sem cinturão de asteroides (deixava a cena carregada)
	belt = Node3D.new()
	add_child(belt)


func _tex(n: String) -> Texture2D:
	var path = "res://planets/%s.png" % n
	return load(path) if ResourceLoader.exists(path) else null


func _unshaded(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _glow(size: float, c: Color) -> MeshInstance3D:
	var q = MeshInstance3D.new()
	var qm = QuadMesh.new()
	qm.size = Vector2(size, size)
	q.mesh = qm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	m.albedo_texture = _tex("estrela")
	m.albedo_color = c
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return q


func _sphere(r: float, seg: int = 48) -> SphereMesh:
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


func _make_planet(p: Dictionary) -> void:
	var pick = p.get("pick", false)
	# linha da órbita
	var ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	var th = 0.07 if pick else 0.04
	tm.inner_radius = p["r"] - th
	tm.outer_radius = p["r"] + th
	tm.rings = 160
	tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = _unshaded(Color(1.0, 0.88, 0.3, 0.28))
	ring.visible = pick
	add_child(ring)
	var body = MeshInstance3D.new()
	body.mesh = _sphere(p["size"])
	var m = StandardMaterial3D.new()
	m.albedo_texture = _tex(p["tex"])
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if p.has("glow"):
		m.emission_enabled = true
		m.emission_texture = _tex(p["glow"])
		m.emission = Color.WHITE
		m.emission_energy_multiplier = 1.6
	body.material_override = m
	body.rotation.z = 0.35
	add_child(body)
	var atm = MeshInstance3D.new()
	atm.mesh = _sphere(p["size"] * 1.13, 40)
	var am = ShaderMaterial.new()
	am.shader = atm_shader
	am.set_shader_parameter("col", p["atm"])
	atm.material_override = am
	body.add_child(atm)
	var extra: Array = []
	if p.get("ring", false):
		var rm = MeshInstance3D.new()
		rm.mesh = _annulus(p["size"] * 1.35, p["size"] * 2.3)
		var rmat = StandardMaterial3D.new()
		rmat.albedo_texture = _tex("anel")
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.material_override = rmat
		body.add_child(rm)
	if p.get("moon", false):
		var moon = MeshInstance3D.new()
		moon.mesh = _sphere(0.45, 24)
		var mm = StandardMaterial3D.new()
		mm.albedo_color = Color("#a8a0a0")
		mm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		moon.material_override = mm
		add_child(moon)
		extra.append({"node": moon, "r": 4.2, "sp": 0.6, "tilt": 0.3, "ph": 0.0})
		# (satélites removidos no visual HQ: poluíam a cena)
		for i in range(0):
			var sat = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.5, 0.18, 0.18)
			sat.mesh = bm
			var sm2 = StandardMaterial3D.new()
			sm2.albedo_color = Color("#b05a2c")
			sm2.emission_enabled = true
			sm2.emission = Color("#ff9a3a")
			sm2.emission_energy_multiplier = 0.4
			sat.material_override = sm2
			add_child(sat)
			extra.append({"node": sat, "r": 3.0 + i * 0.35, "sp": 1.1 - i * 0.2, "tilt": -0.5 + i * 0.5, "ph": i * 2.1})
	if p.has("suns"):
		# os 5 sóis de Tarhut girando em volta dele
		var cols = [Color("#ffd27a"), Color("#ff9a4a"), Color("#fff2b0"), Color("#ff7a5a"), Color("#ffe08a")]
		for i in range(p["suns"]):
			var holder = Node3D.new()
			add_child(holder)
			var s = MeshInstance3D.new()
			s.mesh = _sphere(0.32, 16)
			s.material_override = _unshaded(cols[i].lightened(0.4))
			holder.add_child(s)
			holder.add_child(_glow(3.2, cols[i]))
			extra.append({"node": holder, "r": 5.2 + i * 0.55, "sp": 0.5 + i * 0.13, "tilt": -0.6 + i * 0.3, "ph": i * 1.26})
	var sel = MeshInstance3D.new()
	var st = TorusMesh.new()
	st.inner_radius = p["size"] * 1.32
	st.outer_radius = p["size"] * 1.4
	st.rings = 64
	st.ring_segments = 4
	sel.mesh = st
	sel.material_override = _unshaded(Color(1.0, 0.75, 0.3, 0.0))
	add_child(sel)
	nodes[p["id"]] = {"body": body, "atm": atm, "data": p, "extra": extra, "sel": sel, "ring": ring, "hl": 0.0}


func _annulus(r0: float, r1: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg = 96
	for i in range(seg):
		var a0 = TAU * i / seg
		var a1 = TAU * (i + 1) / seg
		var p00 = Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p01 = Vector3(cos(a0) * r1, 0, sin(a0) * r1)
		var p10 = Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var p11 = Vector3(cos(a1) * r1, 0, sin(a1) * r1)
		for v in [[p00, 0.0], [p01, 1.0], [p11, 1.0], [p00, 0.0], [p11, 1.0], [p10, 0.0]]:
			st.set_uv(Vector2(v[1], 0.5))
			st.add_vertex(v[0])
	return st.commit()


func _make_belt() -> void:
	belt = Node3D.new()
	add_child(belt)
	var mmi = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var rock = SphereMesh.new()
	rock.radius = 0.22
	rock.height = 0.36
	rock.radial_segments = 6
	rock.rings = 3
	mm.mesh = rock
	mm.instance_count = 520
	var rng = RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(mm.instance_count):
		var a = rng.randf() * TAU
		var r = 28.0 + rng.randfn(0.0, 1.0) * 1.1
		var b = Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU).scaled(Vector3.ONE * (0.4 + rng.randf() * 1.3))
		mm.set_instance_transform(i, Transform3D(b, Vector3(cos(a) * r, rng.randfn(0.0, 0.35), sin(a) * r)))
	mmi.multimesh = mm
	var m = StandardMaterial3D.new()
	m.albedo_color = Color("#8a7a70")
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mmi.material_override = m
	belt.add_child(mmi)


# ---------------- posição dos planetas ----------------
func planet_pos(id: String) -> Vector3:
	var p = nodes[id]["data"]
	var a = p["a0"] + orbit_t * p["speed"]
	return Vector3(cos(a) * p["r"], sin(a * 1.0 + 0.7) * p["r"] * 0.04, sin(a) * p["r"])


func planet_size(id: String) -> float:
	return nodes[id]["data"]["size"]


func data(id: String) -> Dictionary:
	return nodes[id]["data"] if nodes.has(id) else {}


func pickable() -> Array:
	return PLANETS.filter(func(p): return p.get("pick", false)).map(func(p): return p["id"])


func screen_pos(id: String) -> Variant:
	var wp = planet_pos(id)
	if cam.is_position_behind(wp):
		return null
	return cam.unproject_position(wp)


func screen_radius(id: String) -> float:
	var wp = planet_pos(id)
	var r = planet_size(id)
	var a = cam.unproject_position(wp)
	var b = cam.unproject_position(wp + cam.global_transform.basis.x * r)
	return a.distance_to(b)


# ---------------- modos ----------------
func set_mode(m: String, id: String = "") -> void:
	mode = m
	if id != "":
		focus_id = id
	speed_goal = {"title": 1.0, "select": 0.25, "focus": 0.06, "dive": 0.0}.get(m, 1.0)
	if m == "dive":
		dive_t = 0.0
		dive_from = cam.global_position
	if m != "select":
		_set_hover("")


func activate() -> void:
	if env != null:
		if sky_space == null and ResourceLoader.exists("res://sky/espaco.jpg"):
			var sm = PanoramaSkyMaterial.new()
			sm.panorama = load("res://sky/espaco.jpg")
			sky_space = Sky.new()
			sky_space.sky_material = sm
		if sky_space != null:
			env.sky = sky_space
			env.background_mode = Environment.BG_SKY
			env.sky_rotation = Vector3.ZERO
	visible = true
	set_process(true)
	set_process_unhandled_input(true)
	cam.make_current()


func deactivate() -> void:
	visible = false
	set_process(false)
	set_process_unhandled_input(false)


func snap_camera() -> void:
	var g = _cam_goal()
	cam_pos = g[0]
	cam_look = g[1]
	h_off = g[2]
	_apply_cam()


func _cam_goal() -> Array:
	match mode:
		"title":
			var yaw = clock * 0.025 + 0.6
			return [Vector3(sin(yaw) * 96.0, 34.0, cos(yaw) * 96.0), Vector3(0, -15, 0), 0.0]
		"select":
			return [Vector3(0, 74, 58), Vector3(0, 0, 6), 0.0]
		"focus", "dive":
			var pp = planet_pos(focus_id)
			var r = planet_size(focus_id)
			# câmera do lado iluminado, um pouco acima
			var to_star = (-pp).normalized()
			var side = to_star.rotated(Vector3.UP, 0.75)
			var pos = pp + (side + Vector3(0, 0.3, 0)).normalized() * r * 5.6
			return [pos, pp, r * 1.75]
	return [cam_pos, cam_look, 0.0]


func _apply_cam() -> void:
	cam.h_offset = h_off
	if cam_pos.distance_to(cam_look) > 0.01:
		cam.look_at_from_position(cam_pos, cam_look, Vector3.UP)


func _process(delta: float) -> void:
	clock += delta
	speed = lerp(speed, speed_goal, min(1.0, delta * 2.0))
	orbit_t += delta * speed * 6.0
	belt.rotation.y = -orbit_t * 0.02
	for id in nodes.keys():
		var n = nodes[id]
		var pp = planet_pos(id)
		n["body"].position = pp
		n["body"].rotate_object_local(Vector3.UP, delta * 0.08)
		for e in n["extra"]:
			var a = e["ph"] + clock * e["sp"]
			var o = Vector3(cos(a) * e["r"], sin(a) * e["r"] * e["tilt"], sin(a) * e["r"])
			e["node"].position = pp + o
		var want = 1.0 if (id == hover_id) else 0.0
		n["hl"] = lerp(n["hl"], want, min(1.0, delta * 8.0))
		var sel: MeshInstance3D = n["sel"]
		sel.position = pp
		sel.look_at(cam.global_position, Vector3.UP)
		sel.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		var pulse = 0.75 + 0.25 * sin(clock * 5.0)
		var base_a = 0.0
		if mode == "select" and n["data"].get("pick", false):
			base_a = 0.25
		(sel.material_override as StandardMaterial3D).albedo_color.a = max(base_a, n["hl"] * pulse)
		var sc = 1.0 + n["hl"] * 0.08
		n["body"].scale = Vector3.ONE * sc
	# câmera
	if mode == "dive":
		dive_t = min(1.0, dive_t + delta / 1.7)
		var pp = planet_pos(focus_id)
		var r = planet_size(focus_id)
		var e = dive_t * dive_t * (3.0 - 2.0 * dive_t)
		var dir = (dive_from - pp).normalized()
		cam_pos = pp + dir * lerp(dive_from.distance_to(pp), r * 1.04, e)
		cam_look = pp
		h_off = lerp(h_off, 0.0, min(1.0, delta * 4.0))
		cam.fov = lerp(42.0, 62.0, e * e)
	else:
		var g = _cam_goal()
		var k = 1.0 - exp(-delta * (1.6 if mode != "focus" else 2.4))
		cam_pos = cam_pos.lerp(g[0], k)
		cam_look = cam_look.lerp(g[1], k)
		h_off = lerp(h_off, g[2], k)
		cam.fov = lerp(cam.fov, 42.0, k)
	_apply_cam()


# ---------------- escolha do planeta ----------------
func _pick(screen: Vector2) -> String:
	var o = cam.project_ray_origin(screen)
	var d = cam.project_ray_normal(screen)
	var best = ""
	var best_t = 1e9
	for id in pickable():
		var c = planet_pos(id)
		var r = planet_size(id) * 1.6
		var oc = o - c
		var b = oc.dot(d)
		var cc = oc.dot(oc) - r * r
		var disc = b * b - cc
		if disc < 0.0:
			continue
		var t = -b - sqrt(disc)
		if t > 0.0 and t < best_t:
			best_t = t
			best = id
	return best


func _set_hover(id: String) -> void:
	if id == hover_id:
		return
	hover_id = id
	planet_hover.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or mode != "select":
		return
	if event is InputEventMouseMotion:
		_set_hover(_pick((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var id = _pick((event as InputEventMouseButton).position)
		if id != "":
			_set_hover(id)
			planet_click.emit(id)
