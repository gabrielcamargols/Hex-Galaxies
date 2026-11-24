extends Node3D
## Verme Gigante de Tarhut. Com o modelo do Gabriel (models/vermes.glb, com esqueleto) a coluna de ossos
## segue o rastro da cabeça e as mandíbulas em volta da boca abrem no rugido; o que fica abaixo da areia
## some (recorte no shader). Sem esqueleto, cai no verme antigo de partes (tools/wormgen.py).
## A cabeça segue uma trajetória (sai do buraco, ergue-se muito acima do tabuleiro, ruge com a boca
## aberta e dá o bote mergulhando de volta) e cada segmento do corpo segue o rastro da cabeça.

signal roared      # boca escancarada: rugido, tremor forte
signal bit         # cabeça volta para o buraco: impacto

const DUR = 4.8
const TOP = 11.0              # altura máxima da cabeça (os personagens têm ~1,8)

var segs: Array = []
var spacing: Array = []
var head: Node3D
var petals: Array = []
var petal_base: Array = []
var hole: Vector3
var fwd: Vector3 = Vector3.FORWARD
var side: Vector3 = Vector3.RIGHT
var t: float = 0.0
var trail: Array = []          # posições da cabeça, a mais recente primeiro
var fired_roar := false
var fired_bite := false
var delay: float = 0.0
var seed_f: float = 0.0
# modelo com esqueleto
var sk: Skeleton3D = null
var coluna: Array = []          # ossos da boca para a cauda
var coluna_dist: Array = []     # distância (no mundo) de cada osso até a ponta da cabeça, ao longo do corpo
var coluna_rest: Array = []     # posição de repouso de cada osso (espaço do esqueleto)
var coluna_rest_b: Array = []   # base de repouso global de cada osso
var coluna_frame_rest: Array = []
var coluna_tg_rest: Array = []   # tangente de repouso (para a cauda) de cada osso
var coluna_costas_rest := Vector3.UP
var petalas: Array = []         # [osso, eixo no espaço do pai, rotação de repouso]
var escala: float = 3.0
var raiz := -1                  # Bone_000: pai do osso do meio do corpo
var raiz_pai_de := -1
const COLUNA_NOMES = ["Bone_010", "Bone_011", "Bone_012", "Bone_013", "Bone_014", "Bone_015", "Bone_016", "Bone_017", "Bone_001", "Bone_008", "Bone_007", "Bone_006", "Bone_005", "Bone_004", "Bone_003", "Bone_002"]
const CABECA = "Bone_009"
const VERME_ESCALA = 3.1        # o modelo tem ~4,6 de comprimento: ~14 no tabuleiro


func setup(scene: PackedScene, hole_pos: Vector3, toward: Vector3, outline: Material, start_delay: float = 0.0) -> void:
	var inst: Node3D = scene.instantiate()
	add_child(inst)
	var sks = inst.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		_rig_setup(inst, sks[0], hole_pos, toward, start_delay)
		return
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
		mi.material_overlay = outline
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	head = inst.find_child("head", true, false)
	for i in range(64):
		var s = inst.find_child("seg_%02d" % i, true, false)
		if s == null:
			break
		segs.append(s)
		var ab: AABB = (s as MeshInstance3D).get_aabb() if s is MeshInstance3D else AABB(Vector3.ZERO, Vector3.ONE)
		spacing.append(ab.size.y * 0.78)
	for k in range(8):
		var p = head.find_child("petal_%d" % k, true, false)
		if p == null:
			break
		petals.append(p)
		petal_base.append(p.transform)
	hole = hole_pos
	var d = toward - hole_pos
	d.y = 0.0
	fwd = d.normalized() if d.length() > 0.1 else Vector3.FORWARD
	side = fwd.cross(Vector3.UP).normalized()
	delay = start_delay
	seed_f = randf() * 10.0
	# rastro inicial: reto para baixo do buraco (o corpo começa enterrado)
	for i in range(260):
		trail.append(hole + Vector3(0, -2.0 - i * 0.2, 0))
	_apply(0.0)


func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clamp(x, 0.0, 1.0), 3.0)


func _ease_in(x: float) -> float:
	return pow(clamp(x, 0.0, 1.0), 2.2)


# trajetória da cabeça ao longo do tempo
func head_path(tt: float) -> Vector3:
	var sway = side * sin(tt * 3.1 + seed_f) * 0.7 + fwd * cos(tt * 2.3 + seed_f) * 0.35
	if tt < 1.0:
		# sai do buraco de uma vez, em espiral
		var u = _ease_out(tt / 1.0)
		return hole + Vector3(0, lerp(-2.0, TOP, u), 0) + sway * u - fwd * 0.6 * u
	if tt < 2.5:
		# no alto: balança, se inclina para trás e treme ao rugir
		var u2 = (tt - 1.0) / 1.5
		var shake = Vector3(sin(tt * 47.0), sin(tt * 39.0), cos(tt * 43.0)) * 0.12 * sin(u2 * PI)
		return hole + Vector3(0, TOP + 0.6 * sin(u2 * PI), 0) + sway - fwd * (0.6 + 1.2 * sin(u2 * PI * 0.5)) + shake
	if tt < 3.7:
		# o bote: arco para a frente e mergulho de volta no buraco
		var u3 = (tt - 2.5) / 1.2
		var y = lerp(TOP + 0.4, -2.5, _ease_in(u3))
		var fw = -1.8 + 5.0 * sin(u3 * PI) * (1.0 - u3 * 0.4)
		return hole + Vector3(0, y, 0) + fwd * fw * (1.0 - _ease_in(u3)) + sway * (1.0 - u3)
	# desce todo para dentro da areia
	var u4 = (tt - 3.7) / (DUR - 3.7)
	return hole + Vector3(0, lerp(-2.5, -26.0, u4), 0)


func _process(delta: float) -> void:
	if delay > 0.0:
		delay -= delta
		return
	t += delta
	_apply(delta)
	if t >= 0.95 and not fired_roar:
		fired_roar = true
		roared.emit()
	if t >= 3.45 and not fired_bite:
		fired_bite = true
		bit.emit()
	if t >= DUR:
		queue_free()


func _apply(_delta: float) -> void:
	if sk != null:
		_rig_apply()
		return
	var hp = head_path(t)
	if trail.is_empty() or hp.distance_to(trail[0]) > 0.04:
		trail.push_front(hp)
		if trail.size() > 600:
			trail.pop_back()
	# boca: fechada ao sair, escancarada no alto e no bote
	var opn = 0.0
	if t < 1.0:
		opn = 0.25 * t
	elif t < 2.5:
		opn = clamp((t - 1.0) / 0.25, 0.0, 1.0) * (0.92 + 0.08 * sin(t * 30.0))
	elif t < 3.4:
		opn = 1.0
	else:
		opn = clamp(1.0 - (t - 3.4) / 0.25, 0.0, 1.0)
	for k in range(petals.size()):
		var tr: Transform3D = petal_base[k]
		petals[k].transform = tr * Transform3D(Basis(Vector3.RIGHT, -0.55 + opn * 1.75), Vector3.ZERO)
	# cabeça: a boca (+Y) aponta para onde está indo; no alto, para cima e para a frente
	var vel = hp - (trail[1] if trail.size() > 1 else hp - Vector3.UP)
	var look = vel.normalized() if vel.length() > 0.001 else Vector3.UP
	if t >= 1.0 and t < 2.5:
		var u = (t - 1.0) / 1.5
		look = (Vector3.UP * 1.0 + fwd * (0.5 + 0.6 * sin(u * PI))).normalized()
	elif t >= 2.5 and t < 2.8:
		look = look.lerp((Vector3.UP + fwd).normalized(), 1.0 - (t - 2.5) / 0.3).normalized()
	head.global_transform = Transform3D(_basis_y(look), hp)
	# corpo: cada segmento numa distância fixa atrás da cabeça, ao longo do rastro
	var targets = []
	var acc_t = 0.0
	for i in range(segs.size()):
		acc_t += spacing[i] * (0.9 if i == 0 else 1.0)
		targets.append(acc_t)
	var pts = [hp]
	var ti = 0
	var walked = 0.0
	var k = 0
	var a: Vector3 = trail[0]
	while ti < targets.size() and k < trail.size() - 1:
		var b: Vector3 = trail[k + 1]
		var L = a.distance_to(b)
		if walked + L >= targets[ti]:
			var f = (targets[ti] - walked) / max(L, 0.0001)
			var p = a.lerp(b, f)
			pts.append(p)
			walked = targets[ti]
			a = p
			ti += 1
		else:
			walked += L
			a = b
			k += 1
	while pts.size() < segs.size() + 1:
		pts.append(pts[pts.size() - 1] + Vector3(0, -1, 0))
	for i in range(segs.size()):
		var front: Vector3 = pts[i]
		var back: Vector3 = pts[i + 1]
		var tang = front - back
		var sb = _basis_y(tang.normalized() if tang.length() > 0.001 else Vector3.UP)
		segs[i].global_transform = Transform3D(sb, (front + back) * 0.5)
		# enterrado bem fundo: some (não aparece por baixo do planetoide)
		segs[i].visible = front.y > hole.y - 3.0


func _basis_y(y: Vector3) -> Basis:
	var ref = Vector3.UP if abs(y.dot(Vector3.UP)) < 0.95 else fwd
	var z = (ref - y * y.dot(ref)).normalized()
	# as costas (+Z, com espinhos) ficam para cima/para trás
	if z.dot(Vector3.UP) < 0.0 and abs(y.dot(Vector3.UP)) < 0.95:
		z = -z
	var x = y.cross(z).normalized()
	return Basis(x, y, z)



# ---------------- modelo com esqueleto (models/vermes.glb) ----------------
func _arco(a: Vector3, b: Vector3) -> Quaternion:
	if a.dot(b) < -0.9999:
		var ax = a.cross(Vector3.UP if abs(a.y) < 0.9 else Vector3.RIGHT).normalized()
		return Quaternion(ax, PI)
	return Quaternion(a, b)


func _frame(tg: Vector3, ref: Vector3) -> Basis:
	var up = ref - tg * ref.dot(tg)
	if up.length() < 0.001:
		up = Vector3.FORWARD - tg * Vector3.FORWARD.dot(tg)
	up = up.normalized()
	return Basis(up.cross(tg).normalized(), up, tg)


func _rig_setup(inst: Node3D, skel: Skeleton3D, hole_pos: Vector3, toward: Vector3, start_delay: float) -> void:
	sk = skel
	hole = hole_pos
	var d = toward - hole_pos
	d.y = 0.0
	fwd = d.normalized() if d.length() > 0.1 else Vector3.FORWARD
	side = fwd.cross(Vector3.UP).normalized()
	delay = start_delay
	seed_f = randf() * 10.0
	escala = VERME_ESCALA
	inst.scale = Vector3.ONE * escala
	inst.global_position = hole
	# mesmo sombreado de quadrinho dos personagens (cor do modelo, retícula hexagonal, contorno), recortado na areia
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.extra_cull_margin = 64.0
		for si in mi.mesh.get_surface_count():
			var src = mi.mesh.surface_get_material(si)
			var m = ShaderMaterial.new()
			m.shader = load("res://shaders/hq_personagem.gdshader")
			if src is BaseMaterial3D and src.albedo_texture != null:
				m.set_shader_parameter("tex", src.albedo_texture)
			m.set_shader_parameter("glow_on", 0.0)
			m.set_shader_parameter("shadow_tint", Color("#4a2418"))
			m.set_shader_parameter("hi_col", Color("#ffd9a0"))
			m.set_shader_parameter("fac_col", Color("#c8502a"))
			m.set_shader_parameter("pat", 0)
			m.set_shader_parameter("clip_y", hole.y + 0.02)
			var o = ShaderMaterial.new()
			o.shader = load("res://shaders/hq_contorno3d.gdshader")
			o.set_shader_parameter("ink", Color("#1a0a08"))
			o.set_shader_parameter("clip_y", hole.y + 0.02)
			m.next_pass = o
			mi.set_surface_override_material(si, m)
	# coluna: posição de repouso, distâncias ao longo do corpo (a ponta da cabeça é a boca)
	var boca_rest = Vector3.ZERO
	var cab = sk.find_bone(CABECA)
	var n_p = 0
	for i in sk.get_bone_count():
		if sk.get_bone_parent(i) == cab:
			boca_rest += sk.get_bone_global_rest(i).origin
			n_p += 1
	boca_rest = boca_rest / max(1, n_p)
	var acc = 0.0
	var ant = boca_rest
	for nm in COLUNA_NOMES:
		var bi = sk.find_bone(nm)
		if bi < 0:
			continue
		var p = sk.get_bone_global_rest(bi).origin
		acc += ant.distance_to(p) * escala
		ant = p
		coluna.append(bi)
		coluna_dist.append(acc)
		coluna_rest.append(p)
		coluna_rest_b.append(sk.get_bone_global_rest(bi).basis)
	raiz = sk.find_bone("Bone_000")
	raiz_pai_de = sk.find_bone("Bone_001")
	for i in coluna.size():
		var tg = (coluna_rest[min(i + 1, coluna.size() - 1)] - coluna_rest[i]) if i < coluna.size() - 1 else (coluna_rest[i] - coluna_rest[i - 1])
		coluna_frame_rest.append(_frame(tg.normalized(), Vector3.UP))
		coluna_tg_rest.append(tg.normalized())
	# mandíbulas em volta da boca: giram para fora
	var cab_b = sk.get_bone_global_rest(cab)
	var dir_boca = (boca_rest - sk.get_bone_global_rest(coluna[1]).origin).normalized()
	for i in sk.get_bone_count():
		if sk.get_bone_parent(i) != cab:
			continue
		var r = sk.get_bone_global_rest(i).origin - boca_rest
		r = r - dir_boca * r.dot(dir_boca)
		if r.length() < 0.001:
			continue
		var eixo_g = dir_boca.cross(r.normalized()).normalized()
		petalas.append([i, (cab_b.basis.inverse() * eixo_g).normalized(), sk.get_bone_rest(i).basis.get_rotation_quaternion()])
	for i in range(400):
		trail.append(hole + Vector3(0, -2.0 - i * 0.2, 0))
	_rig_apply()


func _rig_apply() -> void:
	var hp = head_path(t)
	if trail.is_empty() or hp.distance_to(trail[0]) > 0.04:
		trail.push_front(hp)
		if trail.size() > 900:
			trail.pop_back()
	# pontos ao longo do rastro, cada osso na sua distância da ponta da cabeça
	var pts: Array = []
	var walked = 0.0
	var k = 0
	var a: Vector3 = trail[0]
	for ti in coluna_dist.size():
		var alvo: float = coluna_dist[ti]
		while k < trail.size() - 1:
			var b: Vector3 = trail[k + 1]
			var L = a.distance_to(b)
			if walked + L >= alvo:
				var f = (alvo - walked) / max(L, 0.0001)
				a = a.lerp(b, f)
				walked = alvo
				break
			walked += L
			a = b
			k += 1
		pts.append(a if k < trail.size() - 1 else a + Vector3(0, -(alvo - walked), 0))
	# tudo no espaço do esqueleto
	var inv = sk.global_transform.affine_inverse()
	var up_sk = (inv.basis * Vector3.UP).normalized()
	var fwd_sk = (inv.basis * fwd).normalized()
	var n = coluna.size()
	var ps: Array = []
	for p in pts:
		ps.append(inv * (p as Vector3))
	# rotação de cada osso por transporte paralelo ao longo do corpo (sem torção entre vizinhos): o primeiro
	# osso alinha a tangente e gira as costas (espinhos) para cima — ou para trás quando está de pé
	var Rs: Array = []
	var Q = Basis()
	for i in n:
		var tg: Vector3 = (ps[i + 1] - ps[i]) if i < n - 1 else (ps[i] - ps[i - 1])
		tg = tg.normalized() if tg.length() > 0.00001 else -up_sk
		var t0: Vector3 = coluna_tg_rest[i]
		if i == 0:
			Q = Basis(_arco(t0, tg))
			var vy = abs(tg.dot(up_sk))
			var ref = (up_sk * (1.0 - vy) - fwd_sk * vy)
			var costas = Q * (coluna_costas_rest as Vector3)
			var a1 = costas - tg * costas.dot(tg)
			var a2 = ref - tg * ref.dot(tg)
			if a1.length() > 0.001 and a2.length() > 0.001:
				Q = Basis(Quaternion(a1.normalized(), a2.normalized())) * Q
		else:
			var prev_t = Q * t0
			Q = Basis(_arco(prev_t.normalized(), tg)) * Q
		Rs.append(Q.orthonormalized())
	# pais antes dos filhos (a hierarquia nasce no meio do corpo e vai para a boca e para a cauda)
	var meio = coluna.find(raiz_pai_de)
	var ordem: Array = []
	if meio >= 0:
		ordem.append(meio)
		for i in range(meio - 1, -1, -1):
			ordem.append(i)
		for i in range(meio + 1, n):
			ordem.append(i)
	else:
		ordem = range(n)
	for i in ordem:
		var R: Basis = Rs[i]
		if i == meio and raiz >= 0:
			# a raiz (pai do osso do meio) vai junto, mantendo a posição relativa de repouso
			var rr = sk.get_bone_global_rest(raiz)
			sk.set_bone_global_pose(raiz, Transform3D(R * rr.basis, ps[i] + R * (rr.origin - (coluna_rest[i] as Vector3))))
		sk.set_bone_global_pose(coluna[i], Transform3D(R * (coluna_rest_b[i] as Basis), ps[i]))
	# boca: fechada ao sair, escancarada no alto e no bote
	var opn = 0.0
	if t < 1.0:
		opn = 0.25 * t
	elif t < 2.5:
		opn = clamp((t - 1.0) / 0.25, 0.0, 1.0) * (0.92 + 0.08 * sin(t * 30.0))
	elif t < 3.4:
		opn = 1.0
	else:
		opn = clamp(1.0 - (t - 3.4) / 0.25, 0.0, 1.0)
	for pe in petalas:
		sk.set_bone_pose_rotation(pe[0], Quaternion(pe[1], opn * 0.85) * (pe[2] as Quaternion))
