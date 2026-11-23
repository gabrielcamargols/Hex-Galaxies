extends Node
## Grava a locomoção do Comandante Krieg (a mesma do jogo, tique a tique) como CLIPES EDITÁVEIS:
##  - entregas/locomocao_krieg/krieg_comandante_locomocao.glb  (modelo + esqueleto + clipes; abre no Blender)
##  - entregas/locomocao_krieg/krieg_comandante_locomocao.tres (AnimationLibrary do Godot, texto)
## Clipes: "andar_1casa" e "andar_2casas" (repouso -> transfere o peso -> anda -> absorve -> repouso),
## com o deslocamento no nó raiz ("root motion" de uma e de duas casas do tabuleiro).
##   godot --headless --path . -- --teste=clipe
const FPS = 30.0
const PASTA = "res://entregas/locomocao_krieg"


func _simula(b, casas: int) -> Dictionary:
	var casa = Node3D.new()      # como no tabuleiro: o boneco mora dentro do nó da peça
	add_child(casa)
	var fig: Node3D = b._figure3d("k_cmd", 1.75 * 1.08)
	casa.add_child(fig)
	var sk: Skeleton3D = fig.get_meta("skel")
	var giro: Node3D = fig.get_node("giro")
	var dirm = Vector3(0, 0, 1)
	fig.set_meta("olha", dirm)
	var passo_casa = b.S3 * b.HX
	var dist = passo_casa * casas
	var vl: Array = fig.get_meta("vel")
	var spd = float(vl[1] if casas >= 3 else vl[0])
	var dt = 1.0 / FPS
	var quadros: Array = []
	var t = 0.0
	var fase = "repouso"
	var prep = 0.0
	var seg_i = 0
	var seg_t = 0.0
	var pos = Vector3.ZERO
	var t_fim = -1.0
	# deixa a respiração assentar antes de começar a gravar
	for i in 20:
		b.relogio = t
		fig.position = pos
		b._fig3d_tick(fig, dt, t, false, Color.WHITE, false, 0.0, 0.0, false, Vector3.ZERO)
		t += dt
	var t0 = t
	while true:
		var tl = t - t0
		var andando = false
		if fase == "repouso" and tl >= 0.4:
			fase = "preparo"
			prep = b.PREPARO_T
			fig.set_meta("parte", {"t0": t, "dist": dist})
		if fase == "preparo":
			andando = true
			prep -= dt
			if prep <= 0.0:
				fase = "anda"
		elif fase == "anda":
			andando = true
			seg_t += dt * spd
			var tt = min(1.0, seg_t)
			var primeiro = seg_i == 0
			var ultimo = seg_i == casas - 1
			var e = tt
			if primeiro and ultimo:
				e = tt * tt * (3.0 - 2.0 * tt)
			elif primeiro:
				e = tt * tt * (2.0 - tt)
			elif ultimo:
				e = tt + tt * tt - tt * tt * tt
			pos = dirm * passo_casa * (seg_i + e)
			if tt >= 1.0:
				seg_i += 1
				seg_t = 0.0
				if seg_i >= casas:
					fase = "chegou"
					andando = false
					fig.set_meta("chega_t0", t)
					t_fim = t
		if fase == "chegou" and t - t_fim > 1.3:
			break
		b.relogio = t
		fig.position = pos
		b._fig3d_tick(fig, dt, t, false, Color.WHITE, andando, 0.0, 0.0, casas >= 3, dirm if andando else Vector3.ZERO)
		var q = {"t": t - t0, "pos": fig.position, "giro": giro.quaternion, "ossos": []}
		for bi in sk.get_bone_count():
			q["ossos"].append([sk.get_bone_pose_position(bi), sk.get_bone_pose_rotation(bi)])
		quadros.append(q)
		t += dt
	var r = {"fig": fig, "quadros": quadros, "dist": dist}
	return r


# monta a Animation; caminhos relativos ao nó raiz do boneco ("fig3d" no jogo, "KriegComandante" no glb)
func _anima(sim: Dictionary, nome: String, cam_esq: String) -> Animation:
	var fig: Node3D = sim["fig"]
	var sk: Skeleton3D = fig.get_meta("skel")
	var qs: Array = sim["quadros"]
	var a = Animation.new()
	a.resource_name = nome
	a.length = float(qs[-1]["t"])
	a.loop_mode = Animation.LOOP_NONE
	var tp = a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(tp, ".")
	var tg = a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(tg, "giro")
	for q in qs:
		a.position_track_insert_key(tp, q["t"], q["pos"])
		a.rotation_track_insert_key(tg, q["t"], q["giro"])
	for bi in sk.get_bone_count():
		var bnome = sk.get_bone_name(bi)
		# só grava o que mexe (economiza e deixa o clipe limpo para editar)
		var mexe_r = false
		var mexe_p = false
		var r0: Quaternion = qs[0]["ossos"][bi][1]
		var p0: Vector3 = qs[0]["ossos"][bi][0]
		for q in qs:
			if q["ossos"][bi][1].angle_to(r0) > 0.002:
				mexe_r = true
			if q["ossos"][bi][0].distance_to(p0) > 0.0005:
				mexe_p = true
		var rr = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(rr, "%s:%s" % [cam_esq, bnome])
		for q in (qs if mexe_r else [qs[0]]):
			a.rotation_track_insert_key(rr, q["t"], q["ossos"][bi][1])
		if mexe_p:
			var pp = a.add_track(Animation.TYPE_POSITION_3D)
			a.track_set_path(pp, "%s:%s" % [cam_esq, bnome])
			for q in qs:
				a.position_track_insert_key(pp, q["t"], q["ossos"][bi][0])
	a.optimize(0.0005, 0.0005, 0.0005)
	return a


func run() -> void:
	var m = get_parent()
	var b = m.board
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var gi = FileAccess.open(PASTA + "/.gdignore", FileAccess.WRITE)
	gi.store_string("")
	gi.close()
	var s1 = _simula(b, 1)
	var s2 = _simula(b, 2)
	var fig: Node3D = s1["fig"]
	var sk: Skeleton3D = fig.get_meta("skel")
	var inst: Node3D = fig.get_node("giro").get_child(0)
	# 1) biblioteca do Godot: caminhos a partir do boneco do jogo (fig3d)
	var lib = AnimationLibrary.new()
	var cam_jogo = str(fig.get_path_to(sk))
	lib.add_animation("andar_1casa", _anima(s1, "andar_1casa", cam_jogo))
	lib.add_animation("andar_2casas", _anima(s2, "andar_2casas", cam_jogo))
	var e1 = ResourceSaver.save(lib, ProjectSettings.globalize_path(PASTA + "/krieg_comandante_locomocao.tres"))
	# 2) glb para o Blender: o modelo original (materiais do glb), o mesmo giro e escala do jogo
	var cena = Node3D.new()
	cena.name = "KriegComandante"
	var g2 = Node3D.new()
	g2.name = "giro"
	cena.add_child(g2)
	g2.owner = cena
	var orig: Node3D = load(b.FIG3D["k_cmd"]["path"]).instantiate()
	orig.name = "modelo"
	orig.transform = inst.transform
	g2.add_child(orig)
	orig.owner = cena
	for n in orig.find_children("*", "", true, false):
		n.owner = cena
	var sk2: Skeleton3D = orig.find_children("*", "Skeleton3D", true, false)[0]
	var ap = AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	cena.add_child(ap)
	ap.owner = cena
	ap.root_node = NodePath("..")
	var lib2 = AnimationLibrary.new()
	var cam_glb = str(cena.get_path_to(sk2))
	lib2.add_animation("andar_1casa", _anima(s1, "andar_1casa", cam_glb))
	lib2.add_animation("andar_2casas", _anima(s2, "andar_2casas", cam_glb))
	ap.add_animation_library("", lib2)
	add_child(cena)
	var doc = GLTFDocument.new()
	var st = GLTFState.new()
	var e2 = doc.append_from_scene(cena, st)
	var e3 = doc.write_to_filesystem(st, ProjectSettings.globalize_path(PASTA + "/krieg_comandante_locomocao.glb"))
	printerr("CLIPE lib=%d glb=%d/%d quadros1=%d quadros2=%d dur1=%.2fs dur2=%.2fs dist1=%.2f esqueleto=%s ossos=%d" % [e1, e2, e3,
		s1["quadros"].size(), s2["quadros"].size(), s1["quadros"][-1]["t"], s2["quadros"][-1]["t"], s1["dist"], cam_glb, sk.get_bone_count()])
