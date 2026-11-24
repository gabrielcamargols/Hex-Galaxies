extends SkeletonModifier3D
## EMPUNHAR uma arma de duas mãos (a broca do Perfurador): a arma vai presa ao tronco e as duas mãos
## FECHAM nas pegas dela — braços por IK de dois ossos (cotovelo para fora, para baixo e para trás),
## mão orientada pela pega (o eixo da pega passa por dentro dos dedos dobrados, indicador em cima)
## e dedos/polegar fechados em volta. Roda por último, depois de toda pose (andar, gestos, folga).
## Tudo no espaço do esqueleto. A arma (nó filho do esqueleto) é reposicionada aqui a cada quadro.

var arma: Node3D
var osso_base := -1                # osso que carrega a arma (tronco)
var base_rest := Transform3D()     # pose global de repouso desse osso
var arma_rest := Transform3D()     # onde a arma fica, no repouso, no espaço do esqueleto
var lados: Array = []              # um por mão: {up, fore, hand, pega, eixo, dedos, polegar, d, p, z, h, a, b, palma, polo}
var fecha := 1.0                   # 0..1 quanto os dedos fecham
var solta := 0.0                   # 0..1 solta a pega (gesto que precisa dos braços livres)
var ponta: Node3D = null           # parte da arma que gira (a broca), em torno do Z da arma
var giro := 0.0
var vel_giro := 0.0
var ataque_t0 := -99.0             # golpe: estocada para a frente com a broca girando
var _ms := -1
var alcance_falta := -1.0          # teste: quanto faltou de braço para a mão chegar na pega (<= 0: chegou)


static func _rest_dir(sk: Skeleton3D, a: int, b: int) -> Vector3:
	return (sk.get_bone_global_rest(b).origin - sk.get_bone_global_rest(a).origin)


# cfg: {"osso", "escala", "yaw", "pitch", "pega_R", "pega_L" (na malha da arma), "mao_R" (pega direita no
# repouso, espaço do esqueleto), "eixo" (eixo das pegas na arma), "palma": [ao longo, para dentro]}
func prepara(sk: Skeleton3D, no_arma: Node3D, cfg: Dictionary) -> bool:
	arma = no_arma
	var pn = arma.find_child("eixo_ponta", true, false)
	if pn is Node3D:
		ponta = pn
	osso_base = sk.find_bone(str(cfg.get("osso", "Spine01")))
	if osso_base < 0:
		return false
	base_rest = sk.get_bone_global_rest(osso_base)
	var s = float(cfg.get("escala", 0.45))
	var yaw = deg_to_rad(float(cfg.get("yaw", 0.0)))
	var pitch = deg_to_rad(float(cfg.get("pitch", 0.0)))
	var f = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var x = Vector3.UP.cross(f).normalized()
	var y = f.cross(x)
	var B = Basis(x, y, f)
	var pr = _v3(cfg["pega_R"]) * s
	var pl = _v3(cfg["pega_L"]) * s
	var GR = _v3(cfg["mao_R"])
	var O = GR - B * pr
	arma_rest = Transform3D(B.scaled(Vector3.ONE * s), O)
	var eixo = _v3(cfg.get("eixo", [0, 1, 0]))
	var palma: Array = cfg.get("palma", [0.05, 0.02])
	var centro = sk.get_bone_global_rest(osso_base).origin
	for lado in [["R", pr / s, -1.0], ["L", pl / s, 1.0]]:
		var pre = lado[0] + "_"
		var up = sk.find_bone(pre + "Upperarm")
		var fo = sk.find_bone(pre + "Forearm")
		var ha = sk.find_bone(pre + "Hand")
		if up < 0 or fo < 0 or ha < 0:
			return false
		var d = _rest_dir(sk, fo, ha).normalized()
		var i1 = sk.find_bone(pre + "Index1")
		var p1 = sk.find_bone(pre + "Pinky1")
		var z = Vector3(0, 0, 1)
		if i1 >= 0 and p1 >= 0:
			z = (sk.get_bone_global_rest(i1).origin - sk.get_bone_global_rest(p1).origin)
			z = (z - d * z.dot(d)).normalized()
		var p = d.cross(z).normalized()
		if p.dot(centro - sk.get_bone_global_rest(ha).origin) < 0.0:
			p = -p
		var h = 1.0 if d.dot(z.cross(p)) > 0.0 else -1.0
		var dedos: Array = []
		for nm in ["Index", "Mid", "Ring", "Pinky"]:
			for k in [1, 2, 3]:
				var bi = sk.find_bone("%s%s%d" % [pre, nm, k])
				if bi >= 0:
					dedos.append(bi)
		var pol: Array = []
		for k in [1, 2, 3]:
			var bi = sk.find_bone("%sThumb%d" % [pre, k])
			if bi >= 0:
				pol.append(bi)
		lados.append({"up": up, "fore": fo, "hand": ha, "clav": sk.find_bone(pre + "Clavicle"), "pega": lado[1], "eixo": eixo, "dedos": dedos, "polegar": pol,
			"d": d, "p": p, "z": z, "h": h, "lado": lado[2],
			"a": _rest_dir(sk, up, fo).length(), "b": _rest_dir(sk, fo, ha).length(),
			"palma": d * float(palma[0]) + p * float(palma[1])})
	return true


# a palma encosta na pega do lado de onde o braço vem; eixo da pega pelo meio dos dedos (indicador em cima)
func alvo_mao_rot(L: Dictionary, G: Vector3, S: Vector3, A: Vector3) -> Basis:
	var ida = G - S
	var Pw = (ida - A * ida.dot(A)).normalized()
	var Zw = A
	var Dw = (Zw.cross(Pw) if L["h"] > 0.0 else Pw.cross(Zw)).normalized()
	var rest_m = Basis(L["d"], L["p"], L["z"])
	var alvo_m = Basis(Dw, Pw, Zw)
	return (alvo_m * rest_m.inverse()).orthonormalized()


func ataque() -> void:
	ataque_t0 = Time.get_ticks_msec() / 1000.0


static func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or arma == null or not is_instance_valid(arma):
		return
	var agora_ms = Time.get_ticks_msec()
	var dt = 0.0 if _ms < 0 else clamp((agora_ms - _ms) / 1000.0, 0.0, 0.1)
	_ms = agora_ms
	# golpe: estica para a frente rápido, segura girando e volta; a broca acelera e vai parando
	var ta = agora_ms / 1000.0 - ataque_t0
	var est = 0.0
	if ta >= 0.0 and ta < 1.0:
		est = smoothstep(0.0, 0.16, ta) * (1.0 - smoothstep(0.55, 1.0, ta))
		vel_giro = 32.0
	else:
		vel_giro = move_toward(vel_giro, 0.0, dt * 40.0)
	giro = fmod(giro + vel_giro * dt, TAU)
	if ponta != null:
		ponta.rotation.z = giro
	# a arma acompanha o tronco (e avança na estocada)
	var base_agora = sk.get_bone_global_pose(osso_base)
	var D: Transform3D = base_agora * base_rest.affine_inverse() * arma_rest
	# a broca morde o alvo: a arma inteira vibra (as mãos vão junto, pelo IK)
	if ta > 0.16 and ta < 0.72:
		var vib = 0.009 * (1.0 - smoothstep(0.5, 0.72, ta))
		D.origin += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * vib
		D.basis = D.basis * Basis(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(), randf_range(-0.04, 0.04) * (vib / 0.009))
	if est > 0.0:
		var frente = (base_agora.basis * Vector3(0, 0, 1)).normalized()
		var eixo_arma = D.basis.z.normalized()
		D.origin += (frente * 0.6 + eixo_arma * 0.4).normalized() * 0.03 * est   # o corpo já avança no golpe (lunge do tabuleiro)
	arma.transform = D
	if solta >= 0.999:
		return
	var esc = D.basis.get_scale().x
	var corpo_b: Basis = (base_agora * base_rest.affine_inverse()).basis.orthonormalized()
	for L in lados:
		var G: Vector3 = D * (L["pega"] as Vector3)
		var A: Vector3 = (D.basis * (L["eixo"] as Vector3)).normalized()
		var S: Vector3 = sk.get_bone_global_pose(L["up"]).origin
		# ombro vai à frente (clavícula) quando o braço não alcança: até ~8 cm, como quem estica para pegar
		if L["clav"] >= 0:
			var Wp = G - (alvo_mao_rot(L, G, S, A) * (L["palma"] as Vector3))
			var falta = (Wp - S).length() - (L["a"] + L["b"]) * 0.96
			if falta > 0.0:
				var cg = sk.get_bone_global_pose(L["clav"])
				var s2 = S + (Wp - S).normalized() * min(falta, 0.08)
				var qc = Quaternion((S - cg.origin).normalized(), (s2 - cg.origin).normalized())
				sk.set_bone_global_pose(L["clav"], Transform3D(Basis(qc) * cg.basis, cg.origin))
				S = sk.get_bone_global_pose(L["up"]).origin
		var Rh: Basis = alvo_mao_rot(L, G, S, A)
		var W: Vector3 = G - Rh * (L["palma"] as Vector3)
		# IK de dois ossos
		var a: float = L["a"]
		var b: float = L["b"]
		var tv = W - S
		alcance_falta = max(alcance_falta, tv.length() - (a + b))
		var c = clamp(tv.length(), 0.01, (a + b) * 0.999)
		var t = tv.normalized()
		W = S + t * c
		var cosA = clamp((a * a + c * c - b * b) / (2.0 * a * c), -1.0, 1.0)
		var polo = corpo_b * Vector3(float(L["lado"]) * 1.0, -0.7, -0.6)
		var pp = polo - t * polo.dot(t)
		pp = pp.normalized() if pp.length() > 0.001 else corpo_b * Vector3(float(L["lado"]), 0, 0)
		var E = S + t * a * cosA + pp * a * sqrt(max(0.0, 1.0 - cosA * cosA))
		var w = 1.0 - solta
		var g_up = sk.get_bone_global_pose(L["up"])
		var dir_up_rest = _rest_dir(sk, L["up"], L["fore"]).normalized()
		var dir_fo_rest = _rest_dir(sk, L["fore"], L["hand"]).normalized()
		var rest_up_b = sk.get_bone_global_rest(L["up"]).basis
		var rest_fo_b = sk.get_bone_global_rest(L["fore"]).basis
		var rest_ha_b = sk.get_bone_global_rest(L["hand"]).basis
		var q_up = Quaternion(dir_up_rest, (E - S).normalized())
		var q_fo = Quaternion(dir_fo_rest, (W - E).normalized())
		var novo_up = Transform3D(Basis(q_up) * rest_up_b, S)
		var novo_fo = Transform3D(Basis(q_fo) * rest_fo_b, E)
		var novo_ha = Transform3D(Rh * rest_ha_b, W)
		if w < 0.999:
			novo_up = g_up.interpolate_with(novo_up, w)
			novo_fo = sk.get_bone_global_pose(L["fore"]).interpolate_with(novo_fo, w)
			novo_ha = sk.get_bone_global_pose(L["hand"]).interpolate_with(novo_ha, w)
		sk.set_bone_global_pose(L["up"], novo_up)
		sk.set_bone_global_pose(L["fore"], novo_fo)
		sk.set_bone_global_pose(L["hand"], novo_ha)
		# dedos fecham em volta da pega
		var zl: Vector3 = L["z"]
		var sgn = -1.0 if zl.cross(L["d"]).dot(L["p"]) > 0.0 else 1.0
		var curl = [0.85, 0.95, 0.6]
		for i in (L["dedos"] as Array).size():
			var bi: int = L["dedos"][i]
			var ax_l = (sk.get_bone_global_rest(bi).basis.inverse() * zl).normalized()
			sk.set_bone_pose_rotation(bi, sk.get_bone_rest(bi).basis.get_rotation_quaternion() * Quaternion(ax_l, sgn * curl[i % 3] * fecha * w))
		# polegar: gira para a frente da palma e dobra por cima dos dedos
		var pol: Array = L["polegar"]
		for i in pol.size():
			var bi: int = pol[i]
			var gb = sk.get_bone_global_rest(bi).basis.inverse()
			var q = Quaternion.IDENTITY
			if i == 0:
				q = Quaternion((gb * (L["d"] as Vector3)).normalized(), -sgn * 0.7 * fecha * w)
			q = q * Quaternion((gb * zl).normalized(), sgn * 0.45 * fecha * w)
			sk.set_bone_pose_rotation(bi, sk.get_bone_rest(bi).basis.get_rotation_quaternion() * q)
