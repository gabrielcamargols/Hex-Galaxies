extends Node
## Locomoção do Comandante Krieg numa partida de verdade, na câmera de jogo: anda 1 casa, para,
## depois anda 2 casas. Mede o pé deslizando quando deveria estar apoiado (cm/s do pé mais baixo
## enquanto ele está no chão). Grave com --write-movie para ver; sem vídeo só mede.
##   godot --path . --fixed-fps 30 [--write-movie x.avi] -- --teste=passos
var m
var fig: Node3D
var desl: Array = []         # velocidade horizontal do pé de apoio a cada quadro (m/s)
var pe_ant: Variant = null
var medir := false
var ref_pe := 0.0            # altura do tornozelo parado (acima disso o pé está no ar)


func _pe_apoio() -> Array:
	var sk: Skeleton3D = fig.get_meta("skel")
	var bn: Dictionary = fig.get_meta("bones")
	var pl = sk.global_transform * sk.get_bone_global_pose(int(bn["LeftFoot"])).origin
	var pr = sk.global_transform * sk.get_bone_global_pose(int(bn["RightFoot"])).origin
	return [pl, pr]


var corpo_ant: Variant = null


func _physics_process(delta: float) -> void:
	if not medir or fig == null:
		return
	var pes = _pe_apoio()
	var chao = fig.get_parent().global_position.y
	var corpo: Vector3 = fig.get_parent().global_position
	# só conta enquanto a peça se desloca pelo chão (sem subir/descer degrau)
	var anda = corpo_ant != null and Vector2(corpo.x - corpo_ant.x, corpo.z - corpo_ant.z).length() > 0.0005 and abs(corpo.y - corpo_ant.y) < 0.001
	if pe_ant != null and anda:
		for i in 2:
			if pes[i].y - chao < ref_pe + 0.02 and pe_ant[i].y - chao < ref_pe + 0.02:
				desl.append(Vector2(pes[i].x - pe_ant[i].x, pes[i].z - pe_ant[i].z).length() / delta)
	if OS.get_environment("DEPURA") != "" and pe_ant != null and corpo_ant != null:
		var dv = Vector2(corpo.x - corpo_ant.x, corpo.z - corpo_ant.z)
		if dv.length() > 0.0001:
			var dn = dv.normalized()
			var fl = Vector2(pes[0].x - pe_ant[0].x, pes[0].z - pe_ant[0].z).dot(dn) / delta
			var fr = Vector2(pes[1].x - pe_ant[1].x, pes[1].z - pe_ant[1].z).dot(dn) / delta
			print("Q %.2f %.2f %.2f %.3f %.3f" % [dv.length() / delta, fl, fr, pes[0].y - chao, pes[1].y - chao])
	pe_ant = pes
	corpo_ant = corpo


func _espera(seg: float) -> void:
	for i in int(seg * 30):
		await get_tree().process_frame


func run() -> void:
	m = get_parent()
	m.setup_cfg["map"] = OS.get_environment("MAPA") if OS.get_environment("MAPA") != "" else "tarhut"
	m.setup_cfg["modo"] = ""
	m.setup_cfg["fac"] = "KRI"
	m._set_papel(0)
	m._start_match(null)
	await _espera(1.0)
	m.skip_entry = true
	await _espera(6.0)
	if m.asking != null:
		m._answer(false)
	var g = m.game
	var cmd = g.commander(0)
	var base: Vector2i = DB.entry_c[0]
	# direção em que cabem 4 casas livres e planas a partir da base, de preferência de lado para a câmera
	m.board.fit_camera(true)
	await _espera(0.5)
	var cf = get_viewport().get_camera_3d().global_transform.basis.z
	var cf2 = Vector2(cf.x, cf.z).normalized()
	var dir = DB.DIRS[0]
	var melhor = 9.0
	for d in DB.DIRS:
		var ok = true
		for k in range(1, 5):
			var h = base + d * k
			if not DB.in_board(h) or g.unit_at(h) != null or abs(m.board.top_y(h) - m.board.top_y(base + d)) > 0.05:
				ok = false
		var w = m.board.world_xz(base + d * 4) - m.board.world_xz(base + d)
		var lado = abs(w.normalized().dot(cf2))
		if ok and lado < melhor:
			melhor = lado
			dir = d
	cmd.st = "field"
	cmd.q = (base + dir).x
	cmd.r = (base + dir).y
	m.refresh()
	await _espera(2.0)
	fig = m.board.unit_nodes[cmd.uid]["sprite"]
	# câmera de jogo, um pouco mais perto do Comandante
	m.board.fit_camera(true)
	m.board.cam_goal = null
	m.board.cam_target = m._hex_pos(base + dir * 2, 0.0).lerp(m._hex_pos(base + dir * 3, 0.0), 0.5)
	m.board.cam_dist = float(OS.get_environment("DIST")) if OS.get_environment("DIST") != "" else 16.0
	await _espera(1.0)
	ref_pe = min(_pe_apoio()[0].y, _pe_apoio()[1].y) - fig.get_parent().global_position.y
	medir = true
	# 1 casa
	cmd.q = (base + dir * 2).x
	cmd.r = (base + dir * 2).y
	m.refresh()
	await _espera(2.6)
	# 2 casas
	cmd.q = (base + dir * 4).x
	cmd.r = (base + dir * 4).y
	m.refresh()
	await _espera(3.4)
	medir = false
	desl.sort()
	var med = 0.0
	for v in desl:
		med += v
	med /= max(1, desl.size())
	printerr("PASSOS pe_apoio mediana=%.1f cm/s " % (desl[desl.size() / 2] * 100.0 if not desl.is_empty() else 0.0) + " amostras=%d media=%.1f cm/s p90=%.1f cm/s" % [desl.size(), med * 100.0, desl[int(desl.size() * 0.9)] * 100.0 if not desl.is_empty() else 0.0])
	get_tree().quit()
