extends Node3D
## Verme Gigante de Tarhut: anima as partes de models/verme_gigante.glb (gerado por tools/wormgen.py).
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


func setup(scene: PackedScene, hole_pos: Vector3, toward: Vector3, outline: Material, start_delay: float = 0.0) -> void:
	var inst: Node3D = scene.instantiate()
	add_child(inst)
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
