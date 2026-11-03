extends Node3D
## Efeitos visuais: projéteis, cortes, faíscas, cura, escudo, poder, morte, invocação,
## areia no ar e tempestade (Tarhut), névoa e pólen (Posto).

var board = null
var soft_tex: ImageTexture
var mat_add: StandardMaterial3D      # partículas que brilham (somam luz)
var mat_alpha: StandardMaterial3D    # partículas foscas (poeira, fumaça)
var ambient: Array = []
var storm: Array = []
var storm_on: bool = false
var env_fog_target: float = 0.0


func _ready() -> void:
	soft_tex = _make_soft()
	mat_add = _pmat(true)
	mat_alpha = _pmat(false)


func _make_soft() -> ImageTexture:
	var s = 32
	var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in range(s):
		for x in range(s):
			var d = Vector2(x - s / 2.0 + 0.5, y - s / 2.0 + 0.5).length() / (s / 2.0)
			var a = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _pmat(additive: bool) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = soft_tex
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	return m


func _quad(size: float, additive: bool) -> QuadMesh:
	var q = QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat_add if additive else mat_alpha
	return q


func _ramp(c: Color, end_alpha: float = 0.0) -> Gradient:
	var g = Gradient.new()
	g.set_color(0, c)
	g.set_color(1, Color(c.r, c.g, c.b, end_alpha))
	return g


# partículas de uma vez (explosão de faíscas, poeira, etc.)
func burst(pos: Vector3, col: Color, amount: int, speed: float, life: float, size: float, additive: bool = true, dir: Vector3 = Vector3.UP, spread: float = 180.0, grav: float = -6.0, radius: float = 0.15) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.mesh = _quad(size, additive)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = dir
	p.spread = spread
	p.gravity = Vector3(0, grav, 0)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.color_ramp = _ramp(col)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)
	return p


func _flash(pos: Vector3, col: Color, r0: float, r1: float, dur: float) -> void:
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	mi.mesh = sm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = col
	mi.material_override = m
	mi.position = pos
	mi.scale = Vector3.ONE * r0
	add_child(mi)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * r1, dur)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)


func _ring(pos: Vector3, col: Color, r0: float, r1: float, dur: float, rise: float = 0.0) -> void:
	var mi = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 0.42
	tor.outer_radius = 0.5
	mi.mesh = tor
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = col
	mi.material_override = m
	mi.position = pos
	mi.scale = Vector3(r0, 0.3, r0)
	add_child(mi)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(r1, 0.3, r1), dur)
	tw.tween_property(mi, "position:y", pos.y + rise, dur)
	tw.tween_property(m, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


# ---------------- ataques ----------------
# projétil em arco do atacante até o alvo; devolve quanto tempo leva
func projectile(src: Vector3, to: Vector3, col: Color, style: String) -> float:
	var dist = src.distance_to(to)
	var dur = clamp(dist * 0.06, 0.18, 0.45)
	var ball = Node3D.new()
	ball.position = src
	add_child(ball)
	var core = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.13 if style != "cristal" else 0.1
	sm.height = sm.radius * 2.0
	core.mesh = sm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col.lightened(0.5)
	core.material_override = m
	if style == "cristal":
		core.scale = Vector3(0.7, 0.7, 2.4)
	ball.add_child(core)
	var trail = CPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.mesh = _quad(0.22, true)
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.2
	trail.color_ramp = _ramp(col)
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.0
	ball.add_child(trail)
	trail.emitting = true
	var h = 0.4 + dist * 0.06
	var tw = create_tween()
	tw.tween_method(func(v): _arc_step(ball, src, to, h, v), 0.0, 1.0, dur)
	tw.tween_callback(func(): core.visible = false)
	tw.tween_callback(func(): trail.emitting = false)
	tw.tween_interval(0.4)
	tw.tween_callback(ball.queue_free)
	return dur


func _arc_step(ball: Node3D, src: Vector3, to: Vector3, h: float, v: float) -> void:
	var p = src.lerp(to, v)
	p.y += sin(v * PI) * h
	var nxt = src.lerp(to, min(1.0, v + 0.05))
	nxt.y += sin(min(1.0, v + 0.05) * PI) * h
	ball.position = p
	if p.distance_to(nxt) > 0.001:
		ball.look_at(nxt, Vector3.UP)


# corte em arco na frente do alvo
func slash(at: Vector3, src: Vector3, col: Color) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg = 16
	for i in range(seg):
		var a1 = lerp(-1.1, 1.1, float(i) / seg)
		var a2 = lerp(-1.1, 1.1, float(i + 1) / seg)
		var w1 = sin(float(i) / seg * PI) * 0.16
		var w2 = sin(float(i + 1) / seg * PI) * 0.16
		var o1 = Vector3(cos(a1), sin(a1), 0) * (0.7 + w1)
		var i1 = Vector3(cos(a1), sin(a1), 0) * (0.7 - w1)
		var o2 = Vector3(cos(a2), sin(a2), 0) * (0.7 + w2)
		var i2 = Vector3(cos(a2), sin(a2), 0) * (0.7 - w2)
		st.add_vertex(o1)
		st.add_vertex(o2)
		st.add_vertex(i2)
		st.add_vertex(o1)
		st.add_vertex(i2)
		st.add_vertex(i1)
	var mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col.lightened(0.6), 1.0)
	mi.material_override = m
	mi.position = at
	add_child(mi)
	var flat = Vector3(src.x, at.y, src.z)
	if flat.distance_to(at) > 0.01:
		mi.look_at(flat, Vector3.UP)
	mi.rotate_object_local(Vector3.FORWARD, randf_range(-0.6, 0.6))
	mi.scale = Vector3.ONE * 0.6
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.25, 0.22)
	tw.tween_property(mi, "rotation:z", mi.rotation.z + 1.2, 0.22)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.28).set_delay(0.06)
	tw.chain().tween_callback(mi.queue_free)


func impact(pos: Vector3, col: Color, strength: float = 1.0) -> void:
	burst(pos, col.lightened(0.3), int(18 + 10 * strength), 4.0 * strength, 0.5, 0.18, true, Vector3.UP, 180.0, -9.0)
	burst(pos, Color(1, 1, 0.9, 0.9), 6, 1.5, 0.25, 0.5, true)
	_flash(pos, Color(col.lightened(0.4), 0.8), 0.2, 1.2 * strength, 0.22)


func block(pos: Vector3) -> void:
	burst(pos, Color("#cfe8ff"), 10, 2.0, 0.35, 0.15, true)
	_flash(pos, Color(0.7, 0.85, 1.0, 0.5), 0.3, 0.9, 0.2)


# ---------------- habilidades e passivas ----------------
func heal_fx(pos: Vector3) -> void:
	burst(pos, Color("#9cff7a"), 26, 1.2, 1.1, 0.2, true, Vector3.UP, 25.0, 1.5, 0.45)
	_ring(pos + Vector3(0, 0.1, 0), Color(0.5, 1.0, 0.4, 0.8), 0.6, 1.6, 0.8, 0.6)


func shield_fx(pos: Vector3) -> void:
	_flash(pos + Vector3(0, 0.8, 0), Color(0.45, 0.75, 1.0, 0.45), 1.2, 2.0, 0.45)
	burst(pos + Vector3(0, 0.8, 0), Color("#a8d8ff"), 14, 1.0, 0.6, 0.16, true, Vector3.UP, 180.0, 0.0, 0.8)


func power_fx(pos: Vector3) -> void:
	_ring(pos + Vector3(0, 0.05, 0), Color(1.0, 0.8, 0.3, 0.9), 0.5, 1.4, 0.6, 1.4)
	burst(pos, Color("#ffd36a"), 20, 2.2, 0.8, 0.16, true, Vector3.UP, 20.0, 0.5, 0.4)


func curse_fx(pos: Vector3) -> void:
	_ring(pos + Vector3(0, 1.6, 0), Color(0.7, 0.3, 1.0, 0.9), 1.4, 0.5, 0.7, -1.4)
	burst(pos + Vector3(0, 1.4, 0), Color("#b06aff"), 20, 1.4, 0.8, 0.18, true, Vector3.DOWN, 30.0, -2.0, 0.4)


func phoenix_fx(pos: Vector3) -> void:
	burst(pos, Color("#ff9a3a"), 50, 3.5, 1.2, 0.28, true, Vector3.UP, 35.0, 1.0, 0.5)
	_flash(pos + Vector3(0, 0.8, 0), Color(1.0, 0.6, 0.2, 0.7), 0.4, 2.6, 0.6)


func trap_fx(pos: Vector3) -> void:
	burst(pos, Color("#ffcf6a"), 16, 3.0, 0.4, 0.14, true, Vector3.UP, 60.0, -9.0)


func death_fx(pos: Vector3, col: Color) -> void:
	burst(pos + Vector3(0, 0.6, 0), Color(0.25, 0.22, 0.2, 0.75), 24, 1.6, 1.2, 0.6, false, Vector3.UP, 70.0, 0.6, 0.4)
	burst(pos + Vector3(0, 0.8, 0), col.lightened(0.2), 20, 4.0, 0.8, 0.14, true, Vector3.UP, 160.0, -9.0)


func summon_fx(pos: Vector3, col: Color) -> void:
	var mi = MeshInstance3D.new()
	var cy = CylinderMesh.new()
	cy.top_radius = 0.5
	cy.bottom_radius = 0.6
	cy.height = 4.0
	cy.radial_segments = 16
	mi.mesh = cy
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col.lightened(0.4), 0.55)
	mi.material_override = m
	mi.position = pos + Vector3(0, 2.0, 0)
	add_child(mi)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.2, 1.2, 0.2), 0.7)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_callback(mi.queue_free)
	burst(pos, col.lightened(0.3), 30, 2.0, 0.9, 0.16, true, Vector3.UP, 30.0, 0.5, 0.5)


func explosion(pos: Vector3) -> void:
	_flash(pos + Vector3(0, 0.4, 0), Color(1.0, 0.7, 0.3, 0.9), 0.3, 2.4, 0.35)
	burst(pos, Color("#ffb04c"), 40, 6.0, 0.6, 0.2, true, Vector3.UP, 180.0, -9.0)
	burst(pos, Color(0.3, 0.27, 0.24, 0.7), 20, 1.6, 1.4, 0.7, false, Vector3.UP, 60.0, 0.5, 0.4)


func dust_burst(pos: Vector3, big: bool) -> void:
	var c = Color(0.85, 0.66, 0.4, 0.8)
	burst(pos, c, 40 if big else 14, 3.5 if big else 1.4, 1.6 if big else 1.0, 0.9 if big else 0.5, false, Vector3.UP, 70.0, -1.5, 0.6)
	if big:
		burst(pos, Color(0.6, 0.45, 0.3, 1.0), 24, 6.0, 1.0, 0.18, false, Vector3.UP, 45.0, -12.0, 0.4)


# ---------------- clima do mapa ----------------
func setup_ambient(map_id: String) -> void:
	for p in ambient + storm:
		p.queue_free()
	ambient = []
	storm = []
	storm_on = false
	if board != null and board.env != null:
		board.env.fog_density = 0.0
		board.env.fog_enabled = false
	if map_id == "":
		return
	var span = 1.5 * DB.R + 4.0
	if map_id == "tarhut":
		# grãos de areia sempre no ar
		ambient.append(_field(Color(0.95, 0.78, 0.5, 0.55), 420, 7.0, 0.09, Vector3(1.6, 0.05, 0.4), Vector3(span, 2.5, span), 1.5, false))
		ambient.append(_field(Color(0.85, 0.65, 0.4, 0.22), 40, 9.0, 1.4, Vector3(0.8, 0.0, 0.2), Vector3(span, 1.0, span), 0.6, false))
		# tempestade (liga quando o vento muda as dunas)
		var s1 = _field(Color(0.9, 0.7, 0.42, 0.7), 1200, 2.5, 0.12, Vector3(9.0, 0.3, 2.0), Vector3(span, 3.0, span), 2.0, false)
		var s2 = _field(Color(0.8, 0.6, 0.38, 0.35), 160, 3.0, 2.2, Vector3(7.0, 0.2, 1.5), Vector3(span, 2.0, span), 1.2, false)
		s1.emitting = false
		s2.emitting = false
		storm = [s1, s2]
	else:
		# pólen dourado e névoa baixa sobre a água
		ambient.append(_field(Color(1.0, 0.95, 0.6, 0.7), 160, 8.0, 0.08, Vector3(0.3, 0.15, 0.2), Vector3(span, 2.0, span), 1.2, true))
		ambient.append(_field(Color(0.9, 0.97, 1.0, 0.16), 50, 10.0, 2.6, Vector3(0.4, 0.0, 0.2), Vector3(span + 4.0, 0.4, span + 4.0), -0.3, false))


func _field(col: Color, amount: int, life: float, size: float, wind: Vector3, extents: Vector3, y: float, additive: bool) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.mesh = _quad(size, additive)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = wind.normalized() if wind.length() > 0.001 else Vector3.RIGHT
	p.spread = 15.0
	p.gravity = Vector3(0, -0.05, 0)
	p.initial_velocity_min = wind.length() * 0.6
	p.initial_velocity_max = wind.length() * 1.2
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var g = Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	g.add_point(0.2, col)
	g.add_point(0.8, col)
	p.color_ramp = g
	p.position = Vector3(-wind.normalized().x * 3.0, y, 0)
	add_child(p)
	p.emitting = true
	return p


func sandstorm(on: bool) -> void:
	if on == storm_on or storm.is_empty():
		return
	storm_on = on
	for p in storm:
		p.emitting = on
	var env: Environment = board.env
	env.fog_enabled = true
	env.fog_light_color = Color(0.86, 0.68, 0.45)
	env.fog_light_energy = 1.0
	var tw = create_tween()
	tw.tween_property(env, "fog_density", 0.035 if on else 0.0, 1.5)
	if not on:
		tw.tween_callback(func(): env.fog_enabled = false)


# ================= flipbooks 2.5D (gerados por tools/vfxgen.py) =================
const FLIP_FRAMES = 12
var flip_cache: Dictionary = {}
var sfx = null                      # tocador de sons (definido pelo main)
var last_snd: Dictionary = {}       # evita o mesmo som duas vezes no mesmo instante


func _flip_tex(fname: String) -> Variant:
	if not flip_cache.has(fname):
		var path = "res://vfx/%s.png" % fname
		flip_cache[fname] = load(path) if ResourceLoader.exists(path) else null
	return flip_cache[fname]


# toca um efeito pintado: billboard de frente para a câmera, ou deitado no chão (ground)
func flip(fname: String, pos: Vector3, size: float = 1.8, dur: float = 0.55, tint: Color = Color.WHITE, ground: bool = false, delay: float = 0.0) -> void:
	var tex = _flip_tex(fname)
	if tex == null:
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if sfx != null:
		var now = Time.get_ticks_msec()
		if now - int(last_snd.get(fname, -1000)) > 70:
			last_snd[fname] = now
			sfx.play("vfx_" + fname, clamp(-10.0 + (size - 2.0) * 2.5, -14.0, -2.0), 1.0, 0.1)
	var s = Sprite3D.new()
	s.texture = tex
	s.hframes = FLIP_FRAMES
	s.frame = 0
	s.pixel_size = size / 256.0
	s.modulate = tint
	s.shaded = false
	s.double_sided = true
	s.no_depth_test = not ground
	s.render_priority = 20
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	if ground:
		s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		s.rotation_degrees = Vector3(-90, 0, 0)
		s.position = pos + Vector3(0, 0.06, 0)
	else:
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		# o "chão" do desenho fica a 56% da altura do quadro: alinha com a casa
		s.position = pos + Vector3(0, size * 0.22, 0)
	add_child(s)
	var tw = create_tween()
	tw.tween_property(s, "frame", FLIP_FRAMES - 1, dur)
	tw.tween_callback(s.queue_free)
