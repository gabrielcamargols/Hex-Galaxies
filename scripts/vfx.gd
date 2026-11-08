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


var dark_bg: bool = false


func _pmat(additive: bool) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = soft_tex
	# soma de luz some em cima da areia/grama clara: só usa em fundo escuro
	if additive and dark_bg:
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
func projectile(src: Vector3, to: Vector3, col: Color, style: String, k: float = 1.0) -> float:
	var dist = src.distance_to(to)
	var dur = clamp(dist * 0.1, 0.35, 0.9)
	if style == "laser" or style == "bala":
		dur *= 0.6
	var ball = Node3D.new()
	ball.position = src
	add_child(ball)
	var core = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = (0.2 if style != "cristal" else 0.15) * (1.0 + (k - 1.0) * 0.8) * (0.7 if style == "bala" else 1.0)
	sm.height = sm.radius * 2.0
	core.mesh = sm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col.lightened(0.15)
	core.material_override = m
	if style == "cristal" or style == "laser":
		core.scale = Vector3(0.7, 0.7, 2.4 if style == "cristal" else 4.0)
	ball.add_child(core)
	# brilho em volta do projétil
	var glow = MeshInstance3D.new()
	var gq = QuadMesh.new()
	gq.size = Vector2(1.2, 1.2) * k
	glow.mesh = gq
	var gm = _pmat(true)
	gm.vertex_color_use_as_albedo = false
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gm.albedo_color = Color(col.lightened(0.35), 0.75)
	glow.material_override = gm
	ball.add_child(glow)
	# desenho animado do disparo (mesmo estilo dos outros VFX) viajando junto
	var ftex = _flip_tex({"cristal": "crystal", "laser": "beam", "energia": "bolt", "bala": "bolt"}.get(style, "bolt"))
	if ftex != null:
		var sp = Sprite3D.new()
		sp.texture = ftex
		sp.hframes = FLIP_FRAMES
		sp.pixel_size = 2.0 * k / 256.0
		sp.modulate = Color("#ffb040") if style == "bala" else col.lightened(0.2)
		sp.shaded = false
		sp.no_depth_test = true
		sp.render_priority = 21
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.position = Vector3(0, -0.2 * k, 0)
		ball.add_child(sp)
		var ft = sp.create_tween().set_loops(int(ceil(dur / 0.3)) + 1)
		ft.tween_property(sp, "frame", 5, 0.3).from(2)
	var trail = CPUParticles3D.new()
	trail.amount = 60
	trail.lifetime = 0.45
	trail.local_coords = false
	trail.mesh = _quad(0.42 * k, true)
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.2
	trail.color_ramp = _ramp(col)
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.0
	ball.add_child(trail)
	trail.emitting = true
	var h = 0.4 + dist * 0.06
	if style == "laser" or style == "bala":
		h = 0.05
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
func slash(at: Vector3, src: Vector3, col: Color, k: float = 1.0) -> void:
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
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col.lightened(0.25), 0.95)
	mi.material_override = m
	mi.position = at
	add_child(mi)
	var flat = Vector3(src.x, at.y, src.z)
	if flat.distance_to(at) > 0.01:
		mi.look_at(flat, Vector3.UP)
	mi.rotate_object_local(Vector3.FORWARD, randf_range(-0.6, 0.6))
	mi.scale = Vector3.ONE * 0.7 * k
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.6 * k, 0.3)
	tw.tween_property(mi, "rotation:z", mi.rotation.z + 1.4, 0.3)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.38).set_delay(0.12)
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
		# caverna de Valak: poeira de cristal cintilando (roxa e ciano) e névoa baixa lilás
		ambient.append(_field(Color(0.85, 0.55, 1.0, 0.75), 140, 9.0, 0.07, Vector3(0.05, 0.12, 0.05), Vector3(span, 2.5, span), 1.4, true))
		ambient.append(_field(Color(0.45, 0.95, 1.0, 0.6), 70, 9.0, 0.06, Vector3(-0.05, 0.1, 0.05), Vector3(span, 2.5, span), 1.6, true))
		ambient.append(_field(Color(0.6, 0.45, 0.95, 0.14), 50, 12.0, 2.8, Vector3(0.15, 0.0, 0.1), Vector3(span + 4.0, 0.4, span + 4.0), -0.3, false))


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
var cam_k: float = 1.0          # câmera longe = efeitos maiores (main.gd atualiza)
const SIZE_MUL = 1.35           # todos os desenhos de efeito um pouco maiores
const DUR_MUL = 1.2             # e um pouco mais lentos, para dar tempo de ver


func flip(fname: String, pos: Vector3, size: float = 1.8, dur: float = 0.55, tint: Color = Color.WHITE, ground: bool = false, delay: float = 0.0) -> void:
	size *= SIZE_MUL * cam_k
	dur *= DUR_MUL
	var tex = _flip_tex(fname)
	if tex == null:
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if sfx != null:
		var now = Time.get_ticks_msec()
		if now - int(last_snd.get(fname, -1000)) > 70:
			last_snd[fname] = now
			sfx.play("vfx_" + ("hit" if fname.begins_with("imp_") else fname), clamp(-10.0 + (size - 2.0) * 2.5, -14.0, -2.0), 1.0, 0.1)
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


# =====================================================================
# RECEITAS DE VFX (Forja): efeitos 2D pintados montados em camadas 3D.
# As tiras de quadros saem de tools/forja_vfx.py (vfx/<fac>/<nome>.png);
# a montagem (tamanho, tempo, atraso, gotas, projétil, tremor) fica em data/vfx_receitas.json.
# =====================================================================
var receitas: Dictionary = {}
var _fx_shader: Shader = null
var _fx_shader_chao: Shader = null
var _quad_cache: Dictionary = {}


func _receitas_load() -> void:
	if not receitas.is_empty():
		return
	var f = FileAccess.open("res://data/vfx_receitas.json", FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) == TYPE_DICTIONARY:
		receitas = d
	_fx_shader = load("res://shaders/vfx_flip.gdshader")
	_fx_shader_chao = load("res://shaders/vfx_flip_chao.gdshader")


func has_fx(id: String) -> bool:
	_receitas_load()
	return receitas.has(id)


func _rnd(v: Variant, def: float = 0.0) -> float:
	if v == null:
		return def
	if typeof(v) == TYPE_ARRAY:
		return randf_range(float(v[0]), float(v[1]))
	return float(v)


# quad pintado: devolve [nó, material]. size = largura em metros; altura sai da proporção do quadro
func _fx_sprite(texname: String, n: int, size: float, mode: int, base: bool) -> Array:
	var path = "res://vfx/%s.png" % texname
	var tex = flip_cache.get(path)
	if tex == null:
		if not ResourceLoader.exists(path):
			return []
		tex = load(path)
		flip_cache[path] = tex
	var fw = float(tex.get_width()) / float(n)
	var asp = float(tex.get_height()) / fw
	var mi = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(1, asp)
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * size
	var m = ShaderMaterial.new()
	m.shader = _fx_shader_chao if mode == 2 else _fx_shader
	m.render_priority = 21 if mode != 2 else 2
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("hframes", float(n))
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("base_lift", asp * 0.5 if base else 0.0)
	mi.material_override = m
	mi.extra_cull_margin = 8.0
	return [mi, m]


func _screen_angle(a: Vector3, b: Vector3) -> float:
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var pa = cam.unproject_position(a)
	var pb = cam.unproject_position(b)
	return atan2(-(pb.y - pa.y), pb.x - pa.x)


## toca uma receita. at = onde acontece; from = de onde veio (ataque/tiro). Devolve o tempo até o impacto.
func play_fx(id: String, at: Vector3, from: Variant = null, tint: Color = Color.WHITE) -> float:
	_receitas_load()
	if not receitas.has(id):
		return 0.0
	var r: Dictionary = receitas[id]
	var hit_t = 0.0
	if r.has("proj") and from != null:
		hit_t = _fx_proj2(r["proj"], from, at, tint) if r["proj"].has("parts") else _fx_proj(r["proj"], from, at)
		if r.has("hit"):
			_fx_after(hit_t, func(): play_fx(str(r["hit"]), at, from, tint))
		return hit_t
	for L in r.get("layers", []):
		var dl = _rnd(L.get("delay", 0.0))
		if L.has("sub"):
			_fx_after(dl, play_fx.bind(str(L["sub"]), at, from, tint))
		elif L.has("drops"):
			_fx_after(dl, _fx_drops.bind(L, at, from))
		elif L.has("p"):
			_fx_after(dl, _fx_part.bind(L, at, from, tint))
		else:
			_fx_after(dl, _fx_layer.bind(L, at, from, tint))
	if r.has("shake") and board != null:
		_fx_after(_rnd(r.get("shake_delay", 0.0)), func(): board.shake = max(board.shake, float(r["shake"])))
	return float(r.get("hit_t", 0.0))


func _fx_after(t: float, f: Callable) -> void:
	if t <= 0.0:
		f.call()
		return
	get_tree().create_timer(t).timeout.connect(f)


func _fx_layer(L: Dictionary, at: Vector3, from: Variant, tint: Color) -> void:
	var n = int(L.get("n", 16))
	var mode = {"bill": 0, "pe": 1, "chao": 2}.get(str(L.get("mode", "bill")), 0)
	var size = _rnd(L.get("size", 2.0), 2.0) * cam_k
	var sp = _fx_sprite(str(L["tex"]), n, size, mode, bool(L.get("base", false)))
	if sp.is_empty():
		return
	var mi: MeshInstance3D = sp[0]
	var m: ShaderMaterial = sp[1]
	var pos = at + Vector3(0, _rnd(L.get("y", 0.0)), 0)
	if mode == 2:
		pos.y = at.y + 0.04 + _rnd(L.get("y", 0.0))
	if L.has("toward") and from != null:
		# desloca na direção de quem atacou (ex.: garra aparece entre os dois)
		var d = (from - at) * Vector3(1, 0, 1)
		if d.length() > 0.01:
			pos += d.normalized() * float(L["toward"])
	mi.position = pos
	var roll = deg_to_rad(_rnd(L.get("roll", 0.0)))
	if bool(L.get("aim", false)) and from != null:
		var a = _screen_angle(from, at)
		if abs(a) > PI * 0.5:
			m.set_shader_parameter("flip_x", 1.0)
			a = a - PI if a > 0 else a + PI
		roll += a
	m.set_shader_parameter("roll", roll)
	var col = tint * Color(str(L.get("tint", "#ffffff")))
	m.set_shader_parameter("tint", col)
	if float(L.get("fps", 0.0)) > 0.0:
		m.set_shader_parameter("loop_fps", float(L["fps"]))
	add_child(mi)
	var dur = _rnd(L.get("dur", 0.6), 0.6) * DUR_MUL
	var tw = mi.create_tween()
	tw.tween_method(func(v): m.set_shader_parameter("frame", v), 0.0, float(n) - 0.01, dur)
	if L.has("grow"):
		var g = L["grow"]
		mi.scale = Vector3.ONE * size * float(g[0])
		tw.parallel().tween_property(mi, "scale", Vector3.ONE * size * float(g[1]), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if L.has("rise"):
		tw.parallel().tween_property(mi, "position:y", pos.y + float(L["rise"]), dur)
	tw.tween_callback(mi.queue_free)


# gotas de tinta: billboards com gravidade, encolhem no fim
func _fx_drops(L: Dictionary, at: Vector3, from: Variant) -> void:
	var cnt = int(L.get("count", 8))
	var away = Vector3.ZERO
	if from != null and bool(L.get("away", true)):
		away = ((at - from) * Vector3(1, 0, 1))
		away = away.normalized() if away.length() > 0.01 else Vector3.ZERO
	var g = float(L.get("grav", 12.0))
	for i in range(cnt):
		var size = _rnd(L.get("size", [0.18, 0.34])) * cam_k
		var sp = _fx_sprite(str(L["drops"]), int(L.get("n", 8)), size, 0, false)
		if sp.is_empty():
			return
		var mi: MeshInstance3D = sp[0]
		var m: ShaderMaterial = sp[1]
		m.set_shader_parameter("loop_fps", 14.0)
		m.set_shader_parameter("frame", float(randi() % 8))
		var a = randf() * TAU
		var hv = Vector3(cos(a), 0, sin(a)) * _rnd(L.get("speed", [2.0, 5.0])) + away * _rnd(L.get("push", 2.0))
		var v = hv + Vector3(0, _rnd(L.get("up", [2.5, 5.0])), 0)
		var p0 = at + Vector3(0, _rnd(L.get("y", 0.6)), 0)
		mi.position = p0
		add_child(mi)
		var life = _rnd(L.get("life", [0.5, 0.8])) * DUR_MUL
		var floor_y = at.y + 0.05
		var tw = mi.create_tween()
		tw.tween_method(func(t):
			var p = p0 + v * t + Vector3(0, -0.5 * g * t * t, 0)
			p.y = max(p.y, floor_y)
			mi.position = p
			var vel = v + Vector3(0, -g * t, 0)
			m.set_shader_parameter("roll", atan2(vel.y, Vector2(vel.x, vel.z).length()) - PI * 0.5)
			mi.scale = Vector3.ONE * size * clamp(1.4 - t / life, 0.0, 1.0), 0.0, life, life)
		tw.tween_callback(mi.queue_free)


# projétil pintado em laço voando em arco, soltando gotas; devolve o tempo de voo
func _fx_proj(P: Dictionary, from: Vector3, to: Vector3) -> float:
	var size = float(P.get("size", 1.0)) * cam_k
	var sp = _fx_sprite(str(P["tex"]), int(P.get("n", 8)), size, 0, false)
	if sp.is_empty():
		return 0.0
	var mi: MeshInstance3D = sp[0]
	var m: ShaderMaterial = sp[1]
	m.set_shader_parameter("loop_fps", float(P.get("fps", 16.0)))
	var a = from + Vector3(0, float(P.get("y", 0.9)), 0)
	var b = to + Vector3(0, float(P.get("y", 0.9)) * 0.7, 0)
	var dist = a.distance_to(b)
	var t = clamp(dist / float(P.get("speed", 12.0)), 0.18, 0.9)
	var arc = float(P.get("arc", 1.0)) * clamp(dist / 6.0, 0.3, 1.5)
	mi.position = a
	add_child(mi)
	var trail = str(P.get("trail", ""))
	var last = [0.0]
	var tw = mi.create_tween()
	tw.tween_method(func(u):
		var p = a.lerp(b, u) + Vector3(0, sin(u * PI) * arc, 0)
		mi.position = p
		mi.scale = Vector3.ONE * size * (0.7 + 0.3 * min(1.0, u * 4.0))
		if trail != "" and u - last[0] > 0.12:
			last[0] = u
			_fx_drops({"drops": trail, "count": 1, "speed": [0.2, 0.6], "up": [0.2, 0.8], "push": 0.0, "y": 0.0,
				"size": [size * 0.22, size * 0.32], "life": [0.3, 0.45], "away": false}, p - Vector3(0, 0.0, 0), null), 0.0, 1.0, t)
	tw.tween_callback(mi.queue_free)
	return t


# ---------------------------------------------------------------------
# PARTÍCULAS DA FORJA (estilo "Hits & Impacts" em tempo real)
# camada: {"p": textura em vfx/tex, "blend": add|mix|chao, "mode": bill|vel|chao, "amount", "life",
#  "speed":[a,b], "spread", "dir":[x,y,z]|"away"|"up", "grav", "damp":[a,b], "size":m|[w,h], "scale":[a,b],
#  "curve":[[t,v],...], "ramp":[cores borda->miolo], "alpha":[[t,a],...], "boost", "erode", "halftone",
#  "dot", "stretch", "angle":[a,b], "spin":[a,b], "radius", "y", "aim", "tint"}
# ---------------------------------------------------------------------
var _ramp_cache: Dictionary = {}
var _part_shaders: Dictionary = {}


func _ramp_tex(cols: Array) -> GradientTexture1D:
	var key = ",".join(cols)
	if _ramp_cache.has(key):
		return _ramp_cache[key]
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var cc = PackedColorArray()
	for i in range(cols.size()):
		offs.append(float(i) / max(1.0, cols.size() - 1.0))
		cc.append(Color(str(cols[i])))
	g.offsets = offs
	g.colors = cc
	var t = GradientTexture1D.new()
	t.gradient = g
	t.width = 128
	_ramp_cache[key] = t
	return t


func _curve(pts: Array) -> Curve:
	var c = Curve.new()
	c.max_value = 4.0
	for p in pts:
		c.add_point(Vector2(float(p[0]), float(p[1])))
	return c


func _part_shader(blend: String) -> Shader:
	if not _part_shaders.has(blend):
		_part_shaders[blend] = load("res://shaders/vfx_part_%s.gdshader" % blend)
	return _part_shaders[blend]


func _fx_part_node(L: Dictionary, tint: Color) -> CPUParticles3D:
	var path = "res://vfx/tex/%s.png" % str(L["p"])
	if not ResourceLoader.exists(path):
		return null
	var mode = {"bill": 0, "vel": 1, "chao": 2}.get(str(L.get("mode", "bill")), 0)
	var blend = str(L.get("blend", "add"))
	if mode == 2:
		blend = "chao"
	var cp = CPUParticles3D.new()
	var q = QuadMesh.new()
	var sz = L.get("size", 1.0)
	q.size = Vector2(float(sz[0]), float(sz[1])) if typeof(sz) == TYPE_ARRAY else Vector2(float(sz), float(sz))
	if mode == 2:
		q.orientation = PlaneMesh.FACE_Y
	cp.mesh = q
	var m = ShaderMaterial.new()
	m.shader = _part_shader(blend)
	m.render_priority = 22 if blend == "add" else (21 if blend == "mix" else 3)
	m.set_shader_parameter("tex", load(path))
	m.set_shader_parameter("ramp", _ramp_tex(L.get("ramp", ["#ffffff", "#ffffff"])))
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("boost", float(L.get("boost", 1.0)))
	m.set_shader_parameter("erode", float(L.get("erode", 0.0)))
	m.set_shader_parameter("erode_pow", float(L.get("erode_pow", 1.5)))
	m.set_shader_parameter("soft", float(L.get("soft", 0.12)))
	m.set_shader_parameter("halftone", float(L.get("halftone", 0.0)))
	m.set_shader_parameter("dot_px", float(L.get("dot", 7.0)))
	m.set_shader_parameter("stretch", float(L.get("stretch", 1.0)))
	cp.material_override = m
	cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cp.amount = max(1, int(L.get("amount", 1)))
	cp.lifetime = max(0.05, _rnd(L.get("life", 0.5), 0.5))
	cp.lifetime_randomness = float(L.get("life_rand", 0.3))
	cp.one_shot = true
	cp.explosiveness = float(L.get("explosive", 1.0))
	cp.local_coords = false
	cp.speed_scale = float(L.get("speed_scale", 1.0))
	var sp = L.get("speed", [0.0, 0.0])
	cp.initial_velocity_min = float(sp[0]) if typeof(sp) == TYPE_ARRAY else float(sp)
	cp.initial_velocity_max = float(sp[1]) if typeof(sp) == TYPE_ARRAY else float(sp)
	cp.spread = float(L.get("spread", 180.0))
	cp.flatness = float(L.get("flat", 0.0))
	var dm = L.get("damp", [0.0, 0.0])
	cp.damping_min = float(dm[0])
	cp.damping_max = float(dm[1])
	cp.gravity = Vector3(0, float(L.get("grav", 0.0)), 0)
	var scl = L.get("scale", [1.0, 1.0])
	cp.scale_amount_min = float(scl[0]) * cam_k
	cp.scale_amount_max = float(scl[1]) * cam_k
	if L.has("curve"):
		cp.scale_amount_curve = _curve(L["curve"])
	var ang = L.get("angle", [0.0, 360.0])
	cp.angle_min = float(ang[0])
	cp.angle_max = float(ang[1])
	var spin = L.get("spin", [0.0, 0.0])
	cp.angular_velocity_min = float(spin[0])
	cp.angular_velocity_max = float(spin[1])
	if mode == 1:
		cp.particle_flag_align_y = true
	if mode == 2:
		cp.particle_flag_rotate_y = true
	if float(L.get("ring", 0.0)) > 0.0:
		cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		cp.emission_ring_axis = Vector3.UP
		cp.emission_ring_radius = float(L["ring"]) * cam_k
		cp.emission_ring_inner_radius = float(L["ring"]) * 0.8 * cam_k
		cp.emission_ring_height = float(L.get("ring_h", 0.1))
	elif float(L.get("radius", 0.0)) > 0.0:
		cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		cp.emission_sphere_radius = float(L["radius"]) * cam_k
	# cor e alfa ao longo da vida
	var g = Gradient.new()
	var al = L.get("alpha", [[0.0, 1.0], [0.7, 1.0], [1.0, 0.0]])
	var offs = PackedFloat32Array()
	var cc = PackedColorArray()
	var tc = tint * Color(str(L.get("tint", "#ffffff")))
	for a in al:
		offs.append(float(a[0]))
		cc.append(Color(tc.r, tc.g, tc.b, float(a[1]) * tc.a))
	g.offsets = offs
	g.colors = cc
	cp.color_ramp = g
	return cp


func _fx_part(L: Dictionary, at: Vector3, from: Variant, tint: Color) -> void:
	var cp = _fx_part_node(L, tint)
	if cp == null:
		return
	var pos = at + Vector3(0, _rnd(L.get("y", 0.9)), 0)
	if str(L.get("mode", "")) == "chao":
		pos.y = at.y + 0.05 + _rnd(L.get("y", 0.0))
	var d = L.get("dir", [0, 1, 0])
	var away = Vector3.ZERO
	if from != null:
		away = (at - from) * Vector3(1, 0, 1)
		away = away.normalized() if away.length() > 0.01 else Vector3.ZERO
	if typeof(d) == TYPE_STRING and d == "away":
		cp.direction = (away + Vector3(0, float(L.get("lift", 0.4)), 0)).normalized() if away != Vector3.ZERO else Vector3.UP
	else:
		cp.direction = Vector3(float(d[0]), float(d[1]), float(d[2])).normalized()
	if L.has("toward") and from != null:
		pos -= away * float(L["toward"])
	if bool(L.get("aim", false)) and from != null:
		var a = rad_to_deg(_screen_angle(from, at))
		cp.angle_min = a + float(L.get("aim_off", 0.0))
		cp.angle_max = a + float(L.get("aim_off", 0.0))
	cp.position = pos
	add_child(cp)
	cp.emitting = true
	get_tree().create_timer(cp.lifetime * (1.0 + cp.lifetime_randomness) / max(0.01, cp.speed_scale) + 0.3).timeout.connect(cp.queue_free)


# projétil em partículas: miolo brilhando + rastro emitindo enquanto voa
func _fx_proj2(P: Dictionary, from: Vector3, to: Vector3, tint: Color) -> float:
	var a = from + Vector3(0, float(P.get("y", 0.9)), 0)
	var b = to + Vector3(0, float(P.get("y", 0.9)) * 0.8, 0)
	var dist = a.distance_to(b)
	var t = clamp(dist / float(P.get("speed", 12.0)), 0.15, 0.9)
	var arc = float(P.get("arc", 0.6)) * clamp(dist / 6.0, 0.3, 1.5)
	var holder = Node3D.new()
	holder.position = a
	add_child(holder)
	var emitters: Array = []
	for L in P["parts"]:
		var cp = _fx_part_node(L, tint)
		if cp == null:
			continue
		cp.one_shot = bool(L.get("one_shot", false))
		cp.explosiveness = float(L.get("explosive", 0.0 if L.get("trail", false) else 1.0))
		if bool(L.get("trail", false)):
			cp.position = a
			holder.get_parent().add_child(cp)     # no mundo: o rastro fica para trás
		else:
			cp.local_coords = true
			holder.add_child(cp)
		cp.emitting = true
		emitters.append([cp, bool(L.get("trail", false))])
	var tw = holder.create_tween()
	tw.tween_method(func(u):
		var p = a.lerp(b, u) + Vector3(0, sin(u * PI) * arc, 0)
		holder.position = p
		for e in emitters:
			if e[1]:
				e[0].position = p, 0.0, 1.0, t)
	tw.tween_callback(func():
		for e in emitters:
			e[0].emitting = false
			var life = e[0].lifetime + 0.4
			get_tree().create_timer(life).timeout.connect(e[0].queue_free)
		get_tree().create_timer(1.5).timeout.connect(holder.queue_free))
	return t
