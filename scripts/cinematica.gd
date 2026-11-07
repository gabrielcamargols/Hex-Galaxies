extends Node3D
## Cinemática do round 4: antes de entrarem, os comandantes assistem à batalha de longe.
## - Rhazur: diante do trono no reino abissal, vê o campo dentro de uma pérola.
## - Comandante Krieg: na heli-nave tática, vê o campo num holograma.
## - Outros comandantes: sala de comando com holograma na cor da facção.
## O cenário é montado longe do tabuleiro (no alto, dentro de uma esfera de fundo) e a vista
## ao vivo do campo vem de uma câmera própria num SubViewport que enxerga o mesmo mundo.

const ORIGIN = Vector3(0, 420, 0)
const LAYER = 2            # camada de render do cenário (o tabuleiro fica na camada 1)
const DUR = 7.0            # duração de cada comandante

var main
var board
var cam: Camera3D
var sub: SubViewport
var sub_cam: Camera3D
var stage: Node3D
var overlay: CanvasLayer
var bars: Array = []
var fade_rect: ColorRect
var name_l: Label
var line_l: Label
var skip := false
var t := 0.0
var scene_t := 0.0
var path: Dictionary = {}
var shake := 0.0
var anims: Array = []      # Callable(t) chamadas a cada quadro
var saved_mask := 0
var saved_scale := 1.0
var loop_name := ""


func run(m, cmds: Array) -> void:
	main = m
	board = m.board
	_setup()
	for c in cmds:
		if skip:
			break
		await _scene(c)
	await _teardown()


# ================= montagem geral =================
func _setup() -> void:
	saved_scale = Engine.time_scale
	Engine.time_scale = 1.0
	if board.sun_light != null:
		saved_mask = board.sun_light.light_cull_mask
		board.sun_light.light_cull_mask = saved_mask & ~LAYER
	# vista ao vivo do campo de batalha
	sub = SubViewport.new()
	sub.size = Vector2i(768, 768)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.msaa_3d = Viewport.MSAA_2X
	add_child(sub)
	sub_cam = Camera3D.new()
	sub_cam.cull_mask = 1
	sub_cam.fov = 48.0
	sub.add_child(sub_cam)
	sub_cam.current = true
	# câmera da cena
	cam = Camera3D.new()
	cam.fov = 52.0
	cam.near = 0.05
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	# faixas de cinema, legenda e botão de pular
	overlay = CanvasLayer.new()
	overlay.layer = 25
	add_child(overlay)
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root)
	for top in [true, false]:
		var b = ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(b)
		b.anchor_left = 0.0
		b.anchor_right = 1.0
		if top:
			b.anchor_top = 0.0
			b.anchor_bottom = 0.0
		else:
			b.anchor_top = 1.0
			b.anchor_bottom = 1.0
		bars.append(b)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)
	var tv = VBoxContainer.new()
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_theme_constant_override("separation", 2)
	root.add_child(tv)
	tv.anchor_left = 0.0
	tv.anchor_right = 1.0
	tv.anchor_top = 1.0
	tv.anchor_bottom = 1.0
	tv.offset_top = -118
	tv.offset_bottom = -12
	name_l = Label.new()
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 20)
	if main.font_title != null:
		name_l.add_theme_font_override("font", main.font_title)
	tv.add_child(name_l)
	line_l = Label.new()
	line_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_l.add_theme_font_size_override("font_size", 24)
	line_l.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	line_l.add_theme_constant_override("outline_size", 6)
	line_l.add_theme_color_override("font_outline_color", Color.BLACK)
	tv.add_child(line_l)
	var sk = Button.new()
	sk.text = "Pular ▶"
	sk.focus_mode = Control.FOCUS_NONE
	sk.add_theme_font_size_override("font_size", 16)
	root.add_child(sk)
	sk.anchor_left = 1.0
	sk.anchor_right = 1.0
	sk.offset_left = -130
	sk.offset_right = -16
	sk.offset_top = 14
	sk.offset_bottom = 54
	sk.pressed.connect(func(): skip = true)
	_bars(0.0)
	var tw = create_tween()
	tw.tween_method(_bars, 0.0, 1.0, 0.5)


func _bars(k: float) -> void:
	var h = get_viewport().get_visible_rect().size.y * 0.13 * k
	bars[0].offset_top = 0
	bars[0].offset_bottom = h
	bars[1].offset_top = -h
	bars[1].offset_bottom = 0


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
		skip = true


func _process(dt: float) -> void:
	t += dt
	scene_t += dt
	# câmera ao vivo dá a volta devagar sobre o campo
	if sub_cam != null:
		var r = clamp(board.cam_dist * 0.62, 9.0, 30.0)
		var a = 0.6 + t * 0.16
		sub_cam.look_at_from_position(Vector3(sin(a) * r, r * 0.72, cos(a) * r), Vector3(0, 0, 0))
	for f in anims:
		f.call(t)
	if path.is_empty() or cam == null:
		return
	var k = clamp(scene_t / path["d"], 0.0, 1.0)
	var e = k * k * (3.0 - 2.0 * k)
	var pos: Vector3 = path["p0"].lerp(path["p1"], e)
	var look: Vector3 = path["l0"].lerp(path["l1"], e)
	# mergulho final para dentro da pérola / do holograma
	var k2 = clamp((scene_t - path["d"]) / 1.1, 0.0, 1.0)
	if k2 > 0.0:
		pos = pos.lerp(path["p2"], k2 * k2)
		look = look.lerp(path["l1"], k2)
	if shake > 0.0:
		pos += Vector3(sin(t * 31.0) * 0.6 + sin(t * 17.0) * 0.4, sin(t * 27.0) * 0.7, 0.0) * shake
	cam.look_at_from_position(ORIGIN + pos, ORIGIN + look)


# ================= uma cena por comandante =================
func _scene(c: Dictionary) -> void:
	stage = Node3D.new()
	add_child(stage)
	stage.position = ORIGIN
	anims.clear()
	shake = 0.0
	var info: Dictionary
	match c["cid"]:
		"rhazur":
			info = _build_abyss(c["cid"])
		"k_cmd":
			info = _build_heli(c["cid"])
		_:
			info = _build_room(c["cid"])
	path = info["path"]
	scene_t = 0.0
	_process(0.0)
	if loop_name != "":
		main.sfx.has_sound(loop_name)
		main.sfx.loop(loop_name, -6.0, 0.6)
	var mine = c["owner"] == main.me
	name_l.text = info["name"] + ("" if mine else "  ·  inimigo")
	name_l.add_theme_color_override("font_color", info["col"])
	line_l.text = info["line"]
	line_l.visible_ratio = 0.0
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.6)
	var tl = create_tween()
	tl.tween_interval(0.9)
	tl.tween_property(line_l, "visible_ratio", 1.0, info["line"].length() * 0.035)
	main.sfx.play_later("v_%s_fala" % c["cid"], 1.0, 2.0)
	if info.has("voice2"):
		main.sfx.play_later(info["voice2"], info.get("voice2_at", 3.2), 0.0)
	var total = path["d"] + 1.1
	while scene_t < total - 0.5 and not skip:
		await get_tree().process_frame
	var tf = create_tween()
	tf.tween_property(fade_rect, "color:a", 1.0, 0.25 if skip else 0.5)
	await tf.finished
	if loop_name != "":
		main.sfx.stop_loop(loop_name, 0.4)
		loop_name = ""
	anims.clear()
	stage.queue_free()
	stage = null


func _teardown() -> void:
	var tw = create_tween()
	tw.tween_method(_bars, 1.0, 0.0, 0.3)
	path = {}
	board.cam.make_current()
	if board.sun_light != null:
		board.sun_light.light_cull_mask = saved_mask
	var tf = create_tween()
	tf.tween_property(fade_rect, "color:a", 0.0, 0.5)
	await tf.finished
	Engine.time_scale = saved_scale


# ================= peças de montar =================
func _mat(col: Color, emit: Color = Color.BLACK, energy: float = 0.0, metal: float = 0.0, rough: float = 0.8) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	return m


func _shader(code: String) -> ShaderMaterial:
	var s = Shader.new()
	s.code = code
	var m = ShaderMaterial.new()
	m.shader = s
	return m


func _add(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = LAYER
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(mi)
	return mi


func _box(size: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b = BoxMesh.new()
	b.size = size
	return _add(b, mat, pos, rot)


func _cyl(r_top: float, r_bot: float, h: float, mat: Material, pos: Vector3, seg: int = 32) -> MeshInstance3D:
	var c = CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	return _add(c, mat, pos)


func _ball(r: float, mat: Material, pos: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return _add(s, mat, pos, Vector3.ZERO, scl)


func _omni(col: Color, energy: float, rng: float, pos: Vector3) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.light_cull_mask = LAYER
	l.position = pos
	stage.add_child(l)
	return l


func _backdrop(code: String) -> void:
	var s = SphereMesh.new()
	s.radius = 45.0
	s.height = 90.0
	s.flip_faces = true
	_add(s, _shader(code), Vector3.ZERO)


func _figure(cid: String, h: float, pos: Vector3) -> MeshInstance3D:
	var tex: Texture2D = DB.art[cid]
	var q = QuadMesh.new()
	q.size = Vector2(h * float(tex.get_width()) / float(tex.get_height()), h)
	q.center_offset = Vector3(0, h * 0.5, 0)
	var m = StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _add(q, m, pos)


func _bubbles(area: Vector3, amount: int, col: Color) -> void:
	var p = CPUParticles3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 8
	sm.rings = 4
	p.mesh = sm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	p.material_override = m
	p.layers = LAYER
	p.amount = amount
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = area
	p.direction = Vector3(0, 1, 0)
	p.spread = 12.0
	p.gravity = Vector3(0, 0.35, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.scale_amount_min = 0.5
	p.scale_amount_max = 2.2
	p.position = Vector3(0, -0.5, 0)
	stage.add_child(p)


# ================= Rhazur: trono no reino abissal, vê pela pérola =================
const SH_ABYSS = """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 d = normalize(lp);
	float h = d.y * 0.5 + 0.5;
	vec3 c = mix(vec3(0.005, 0.01, 0.035), vec3(0.03, 0.09, 0.2), pow(h, 1.8));
	float a = atan(d.x, d.z);
	float rays = pow(max(0.0, sin(a * 11.0 + TIME * 0.21) * sin(a * 7.0 - TIME * 0.13)), 4.0);
	c += vec3(0.18, 0.4, 0.55) * rays * smoothstep(0.45, 1.0, h) * 0.6;
	c += vec3(0.22, 0.05, 0.3) * smoothstep(0.55, 0.0, h) * 0.25;
	ALBEDO = c;
}
"""

const SH_CAUSTIC = """
shader_type spatial;
uniform vec3 base : source_color = vec3(0.06, 0.06, 0.1);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz * 1.3;
	float c = sin(p.x * 2.1 + TIME * 0.9) + sin(p.y * 2.4 - TIME * 0.8) + sin((p.x + p.y) * 1.7 + TIME * 0.6) + sin(length(p) * 2.0 - TIME * 1.1);
	float k = pow(abs(sin(c * 1.4)), 10.0);
	ALBEDO = base;
	ROUGHNESS = 0.9;
	EMISSION = vec3(0.25, 0.55, 0.75) * k * 0.55;
}
"""

const SH_PEARL = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D view : source_color, filter_linear;
void fragment() {
	vec3 n = NORMAL;
	vec2 uv = vec2(0.5) + n.xy * vec2(0.5, -0.5) * 0.92;
	vec3 c = texture(view, uv).rgb;
	float fr = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 2.2);
	vec3 irid = 0.5 + 0.5 * cos(6.2831 * (fr * 1.3 + vec3(0.0, 0.33, 0.67)) + TIME * 0.6);
	float swirl = 0.5 + 0.5 * sin(n.x * 9.0 + n.y * 6.0 + TIME * 1.3);
	c = c * vec3(0.9, 0.93, 1.05) + vec3(0.85, 0.8, 0.95) * swirl * 0.06;
	c = mix(c, vec3(1.0, 0.95, 1.0) * 0.9 + irid * 0.4, fr * 0.85);
	ALBEDO = c;
}
"""


func _build_abyss(cid: String) -> Dictionary:
	loop_name = "abismo_loop"
	_backdrop(SH_ABYSS)
	var rock = _shader(SH_CAUSTIC)
	_cyl(11.0, 11.0, 0.4, rock, Vector3(0, -0.2, 0), 48)
	var obs = _mat(Color(0.07, 0.05, 0.11), Color.BLACK, 0.0, 0.3, 0.35)
	var gold = _mat(Color(0.85, 0.62, 0.22), Color(1.0, 0.6, 0.15), 0.35, 0.9, 0.3)
	var velvet = _mat(Color(0.25, 0.06, 0.32), Color(0.3, 0.05, 0.4), 0.15, 0.0, 0.9)
	var nacre = _mat(Color(0.82, 0.78, 0.9), Color(0.5, 0.35, 0.6), 0.25, 0.4, 0.25)
	# trono sobre um estrado, concha gigante atrás
	var tz = -2.6
	_cyl(2.6, 2.9, 0.5, obs, Vector3(0, 0.25, tz))
	var rim = TorusMesh.new()
	rim.inner_radius = 2.55
	rim.outer_radius = 2.72
	_add(rim, gold, Vector3(0, 0.5, tz))
	_ball(3.1, nacre, Vector3(0, 3.2, tz - 1.2), Vector3(1.0, 1.05, 0.22))
	for i in range(9):
		var a = lerp(-1.25, 1.25, i / 8.0)
		_box(Vector3(0.14, 2.6, 0.1), _mat(Color(0.6, 0.5, 0.7), Color(0.6, 0.3, 0.8), 0.4, 0.3, 0.3), Vector3(sin(a) * 1.6, 3.2 + cos(a) * 1.6 - 1.4, tz - 0.95), Vector3(0, 0, -a))
	_box(Vector3(1.9, 0.5, 1.3), velvet, Vector3(0, 0.95, tz))
	_box(Vector3(2.0, 3.6, 0.4), obs, Vector3(0, 2.6, tz - 0.6))
	_box(Vector3(1.5, 3.0, 0.1), velvet, Vector3(0, 2.5, tz - 0.38))
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.35, 0.5, 1.4), obs, Vector3(sx * 1.05, 1.35, tz))
		_ball(0.2, gold, Vector3(sx * 1.05, 1.65, tz + 0.6))
	for i in range(5):
		var x = lerp(-0.8, 0.8, i / 4.0)
		var pm = PrismMesh.new()
		pm.size = Vector3(0.36, 0.8 + (0.6 if i == 2 else (0.3 if i % 2 == 1 else 0.0)), 0.3)
		_add(pm, gold, Vector3(x, 4.8 + pm.size.y * 0.5, tz - 0.6))
	# algas que balançam e corais que brilham
	var kelp_m = _mat(Color(0.05, 0.25, 0.22), Color(0.1, 0.6, 0.5), 0.35, 0.0, 0.8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(14):
		var ang = rng.randf_range(0, TAU)
		var rr = rng.randf_range(4.5, 9.0)
		var hgt = rng.randf_range(3.0, 7.0)
		var kp = Node3D.new()
		kp.position = Vector3(cos(ang) * rr, 0, sin(ang) * rr - 1.0)
		stage.add_child(kp)
		var c = CylinderMesh.new()
		c.top_radius = 0.03
		c.bottom_radius = 0.12
		c.height = hgt
		c.radial_segments = 6
		var mi = MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = kelp_m
		mi.layers = LAYER
		mi.position = Vector3(0, hgt * 0.5, 0)
		kp.add_child(mi)
		var ph = rng.randf_range(0, TAU)
		anims.append(func(tt): kp.rotation = Vector3(sin(tt * 0.7 + ph) * 0.12, 0, cos(tt * 0.55 + ph) * 0.12))
	for i in range(22):
		var ang2 = rng.randf_range(0, TAU)
		var rr2 = rng.randf_range(3.5, 8.0)
		var col = [Color("#ff3fae"), Color("#47e6ff"), Color("#b36bff")][i % 3]
		var cm = _mat(col.darkened(0.4), col, 1.6, 0.0, 0.6)
		var hh = rng.randf_range(0.3, 1.1)
		_cyl(0.04, 0.12, hh, cm, Vector3(cos(ang2) * rr2, hh * 0.5, sin(ang2) * rr2 - 1.0), 6)
		_ball(0.09, cm, Vector3(cos(ang2) * rr2, hh, sin(ang2) * rr2 - 1.0))
	_bubbles(Vector3(8, 0.2, 7), 90, Color(0.75, 0.9, 1.0, 0.45))
	# Rhazur ao lado do trono
	_figure(cid, 3.5, Vector3(1.35, 0.0, -1.05))
	# a pérola: vista ao vivo do campo
	var pearl_pos = Vector3(-0.55, 2.05, -0.55)
	var pm2 = _shader(SH_PEARL)
	pm2.set_shader_parameter("view", sub.get_texture())
	var pearl = _ball(0.62, pm2, pearl_pos)
	var clam = _mat(Color(0.35, 0.2, 0.45), Color(0.4, 0.2, 0.6), 0.3, 0.3, 0.4)
	_ball(0.55, clam, pearl_pos - Vector3(0, 0.95, 0), Vector3(1.4, 0.35, 1.2))
	_cyl(0.08, 0.22, 1.0, obs, pearl_pos - Vector3(0, 1.55, 0), 8)
	var halo = _omni(Color(0.95, 0.85, 1.0), 2.4, 4.5, pearl_pos)
	anims.append(func(tt):
		pearl.position = pearl_pos + Vector3(0, sin(tt * 1.3) * 0.06, 0)
		pearl.rotation.y = tt * 0.2
		halo.light_energy = 2.2 + 0.4 * sin(tt * 2.1))
	_omni(Color(0.55, 0.2, 0.9), 3.0, 9.0, Vector3(0, 5.5, tz + 1.5))
	_omni(Color(0.2, 0.7, 0.9), 2.0, 10.0, Vector3(-4, 3.0, -4))
	_omni(Color(0.9, 0.4, 0.8), 1.4, 7.0, Vector3(3.5, 2.0, 2.5))
	return {
		"name": "RHAZUR  ·  REI DAS PROFUNDEZAS",
		"col": Color("#c78bff"),
		"line": "Lutem, criaturas... o abismo assiste. E logo... reivindica.",
		"path": {"d": DUR - 1.1,
			"p0": Vector3(0.6, 2.4, 8.5), "l0": Vector3(0.2, 2.2, -1.6),
			"p1": pearl_pos + Vector3(0.55, 0.25, 2.3), "l1": pearl_pos,
			"p2": pearl_pos + Vector3(0.0, 0.0, 0.95)},
	}


# ================= Comandante Krieg: heli-nave tática, vê pelo holograma =================
const SH_SKY = """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
varying vec3 lp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }
void fragment() {
	vec3 d = normalize(lp);
	float h = d.y * 0.5 + 0.5;
	vec3 c = mix(vec3(0.18, 0.16, 0.15), vec3(0.32, 0.36, 0.42), h);
	vec2 q = vec2(atan(d.x, d.z) * 3.0 + TIME * 0.9, d.y * 6.0);
	float cl = fbm(q * 1.6);
	c = mix(c, vec3(0.55, 0.55, 0.58), smoothstep(0.45, 0.8, cl) * 0.8);
	c = mix(c, vec3(0.25, 0.2, 0.18), smoothstep(0.55, 0.2, h) * 0.6);
	// clarões de batalha lá embaixo
	float fl = step(0.985, hash(vec2(floor(TIME * 3.0), floor(q.x)))) * smoothstep(0.45, 0.2, h);
	c += vec3(1.0, 0.5, 0.2) * fl * 0.5;
	ALBEDO = c * 1.5;
}
"""

const SH_HOLO = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D view : source_color, filter_linear;
uniform vec3 tint : source_color = vec3(0.25, 0.85, 1.0);
void fragment() {
	vec2 uv = UV;
	float g = step(0.96, fract(sin(floor(TIME * 9.0) * 43.1) * 9.3)) * (fract(sin(floor(uv.y * 30.0) + floor(TIME * 9.0)) * 99.0) - 0.5) * 0.05;
	vec3 c = texture(view, uv + vec2(g, 0.0)).rgb;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 holo = mix(c, tint * (0.35 + lum * 1.3), 0.55);
	float scan = 0.72 + 0.28 * sin(uv.y * 420.0 - TIME * 24.0);
	float edge = smoothstep(0.0, 0.07, uv.x) * smoothstep(1.0, 0.93, uv.x) * smoothstep(0.0, 0.07, uv.y) * smoothstep(1.0, 0.9, uv.y);
	float flick = 0.88 + 0.12 * sin(TIME * 47.0) * sin(TIME * 13.0);
	ALBEDO = holo * scan * edge * flick * 0.8 + tint * 0.04 * edge;
}
"""

const SH_BEAM = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 tint : source_color = vec3(0.25, 0.85, 1.0);
void fragment() {
	float a = (1.0 - UV.y) * 0.1 + 0.02;
	a *= 0.8 + 0.2 * sin(UV.x * 60.0 + TIME * 3.0);
	ALBEDO = tint * a;
}
"""


func _command_room(steel: StandardMaterial3D, accent: Color, windows: bool) -> void:
	var dark = _mat(Color(0.08, 0.08, 0.085), Color.BLACK, 0.0, 0.6, 0.5)
	_box(Vector3(9, 0.2, 7), steel, Vector3(0, -0.1, 0))
	for i in range(8):
		_box(Vector3(9, 0.03, 0.05), dark, Vector3(0, 0.01, -3.0 + i * 0.85))
	# parede do fundo com uma janela larga (o céu passa lá fora)
	_box(Vector3(9, 1.9, 0.25), steel, Vector3(0, 0.95, -3.5))
	_box(Vector3(9, 0.75, 0.25), steel, Vector3(0, 4.22, -3.5))
	for x0 in [-4.0, -1.35, 1.35, 4.0]:
		_box(Vector3(0.3, 2.0, 0.35), dark, Vector3(x0, 2.85, -3.5))
	_box(Vector3(9, 0.25, 7), dark, Vector3(0, 4.6, 0))
	for i in range(5):
		_box(Vector3(0.25, 0.35, 7), steel, Vector3(-3.6 + i * 1.8, 4.35, 0))
	for sx in [-1.0, 1.0]:
		var x = sx * 4.5
		if windows:
			_box(Vector3(0.25, 1.3, 7), steel, Vector3(x, 0.65, 0))
			_box(Vector3(0.25, 1.4, 7), steel, Vector3(x, 3.9, 0))
			for z in [-3.3, -1.1, 1.1, 3.3]:
				_box(Vector3(0.3, 2.0, 0.35), dark, Vector3(x, 2.25, z))
		else:
			_box(Vector3(0.25, 4.6, 7), steel, Vector3(x, 2.3, 0))
	# consoles com telas
	for i in range(4):
		var x2 = -3.3 + i * 2.2
		_box(Vector3(1.7, 1.0, 0.7), dark, Vector3(x2, 0.5, -3.0))
		var scr = _mat(Color.BLACK, [Color(0.3, 1.0, 0.4), accent, Color(1.0, 0.65, 0.2), accent][i].darkened(0.35), 0.55)
		_box(Vector3(1.4, 0.7, 0.04), scr, Vector3(x2, 1.55, -3.3), Vector3(-0.2, 0, 0))
	# faixa de luz no teto
	_box(Vector3(6, 0.06, 0.25), _mat(Color.BLACK, Color(1.0, 0.85, 0.6), 2.0), Vector3(0, 4.45, 0.6))


func _holo_table(accent: Color, pos: Vector3) -> Vector3:
	var dark = _mat(Color(0.1, 0.1, 0.11), Color.BLACK, 0.0, 0.7, 0.4)
	_cyl(1.0, 1.15, 0.9, dark, pos + Vector3(0, 0.45, 0))
	var ring = TorusMesh.new()
	ring.inner_radius = 0.82
	ring.outer_radius = 0.95
	_add(ring, _mat(Color.BLACK, accent, 1.1), pos + Vector3(0, 0.92, 0))
	var beam = _shader(SH_BEAM)
	beam.set_shader_parameter("tint", accent)
	var bc = CylinderMesh.new()
	bc.top_radius = 1.25
	bc.bottom_radius = 0.75
	bc.height = 1.5
	bc.cap_top = false
	bc.cap_bottom = false
	_add(bc, beam, pos + Vector3(0, 1.7, 0))
	var holo = _shader(SH_HOLO)
	holo.set_shader_parameter("view", sub.get_texture())
	holo.set_shader_parameter("tint", accent)
	var q = QuadMesh.new()
	q.size = Vector2(1.9, 1.9)
	var hp = pos + Vector3(0, 2.25, 0)
	var hq = _add(q, holo, hp)
	anims.append(func(tt): hq.position = hp + Vector3(0, sin(tt * 1.7) * 0.03, 0))
	_omni(accent, 2.5, 5.0, pos + Vector3(0, 1.6, 0))
	return hp


func _build_heli(cid: String) -> Dictionary:
	loop_name = "heli_loop"
	shake = 0.012
	_backdrop(SH_SKY)
	var steel = _mat(Color(0.2, 0.19, 0.18), Color.BLACK, 0.0, 0.7, 0.45)
	_command_room(steel, Color(1.0, 0.3, 0.2), true)
	# bandeiras xadrez da Krieg nas paredes
	for sx in [-1.0, 1.0]:
		for j in range(4):
			var col = Color(0.55, 0.2, 0.1) if j % 2 == 0 else Color(0.12, 0.1, 0.1)
			_box(Vector3(0.35, 0.35, 0.03), _mat(col), Vector3(sx * 3.2 + (j % 2) * 0.35 - 0.17, 3.3 - floor(j / 2.0) * 0.35, -3.36))
	var accent = Color(0.3, 0.9, 1.0)
	var hp = _holo_table(accent, Vector3(-0.4, 0, 0.6))
	_figure(cid, 3.4, Vector3(1.45, 0.0, -1.0))
	# luz de alerta vermelha girando e sombra das pás passando pela janela
	var alarm = _omni(Color(1.0, 0.15, 0.1), 0.0, 9.0, Vector3(3.2, 4.0, -2.8))
	var sunl = _omni(Color(1.0, 0.92, 0.8), 3.0, 14.0, Vector3(-6.5, 2.4, 0.5))
	_omni(Color(0.9, 0.8, 0.7), 0.9, 10.0, Vector3(0, 4.0, 2.5))
	anims.append(func(tt):
		alarm.light_energy = 2.2 * pow(max(0.0, sin(tt * 4.0)), 3.0)
		sunl.light_energy = 3.2 - 1.8 * pow(abs(sin(tt * 18.85)), 8.0))
	return {
		"name": "COMANDANTE KRIEG  ·  HELI-NAVE TÁTICA",
		"col": Color("#ff6a4a"),
		"line": "Linha de frente, avancem. Ninguém recua. Eu desço em seguida.",
		"path": {"d": DUR - 1.1,
			"p0": Vector3(-3.4, 2.3, 4.8), "l0": Vector3(0.3, 1.9, -0.5),
			"p1": hp + Vector3(0.35, 0.15, 2.4), "l1": hp,
			"p2": hp + Vector3(0.0, 0.0, 1.05)},
	}


# ================= demais comandantes: sala de comando com holograma =================
const SH_SPACE = """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
varying vec3 lp;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void fragment() {
	vec3 d = normalize(lp);
	vec3 c = vec3(0.01, 0.015, 0.04);
	float s = hash(floor(d * 220.0));
	c += vec3(0.9) * step(0.995, s);
	ALBEDO = c;
}
"""


func _build_room(cid: String) -> Dictionary:
	loop_name = ""
	_backdrop(SH_SPACE)
	var card = DB.cards[cid]
	var fac = DB.factions.get(card.get("f", ""), {})
	var accent = Color(fac.get("color", "#5ec8f0"))
	var steel = _mat(Color(0.14, 0.15, 0.18), Color.BLACK, 0.0, 0.6, 0.4)
	_command_room(steel, accent, true)
	var hp = _holo_table(accent, Vector3(-0.4, 0, 0.6))
	_figure(cid, 3.3, Vector3(1.45, 0.0, -1.0))
	_omni(accent.lightened(0.3), 1.2, 10.0, Vector3(0, 4.0, 2.5))
	_omni(Color(0.7, 0.75, 0.9), 1.2, 12.0, Vector3(-5, 2.5, 1))
	var line = "Mantenham a posição. Eu entro agora."
	var dl = main.dlg.get("personagem", {}).get(cid, {}).get("entrada", [])
	if not dl.is_empty():
		line = dl[0]
	return {
		"name": card["name"].to_upper(),
		"col": accent.lightened(0.2),
		"line": line,
		"path": {"d": DUR - 1.1,
			"p0": Vector3(-3.4, 2.3, 4.8), "l0": Vector3(0.3, 1.9, -0.5),
			"p1": hp + Vector3(0.35, 0.15, 2.4), "l1": hp,
			"p2": hp + Vector3(0.0, 0.0, 1.05)},
	}
