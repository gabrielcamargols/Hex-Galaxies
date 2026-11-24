extends Node
## Filminho do ataque do Sniper Valakiano: a bola elétrica condensa entre os dedos e é lançada da mão.
## Grava os quadros em PASTA (rodar com --fixed-fps 30).
var shake: float = 0.0          # a vfx.gd escreve aqui (finge ser o tabuleiro)


func run() -> void:
	var m = get_parent()
	var b = m.board
	m.ui.visible = false
	var sv = SubViewport.new()
	sv.size = Vector2i(1280, 720)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var w = Node3D.new()
	sv.add_child(w)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#2a2340")
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	w.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	w.add_child(sun)
	var chao = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(14, 8)
	chao.mesh = pm
	var cm = StandardMaterial3D.new()
	cm.albedo_color = Color("#e9a35c")
	chao.material_override = cm
	w.add_child(chao)
	var cam = Camera3D.new()
	cam.fov = 40
	w.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(0.0, 1.7, 5.6), Vector3(0.0, 1.0, 0), Vector3.UP)
	if OS.get_environment("CAM") == "rosto":
		cam.look_at_from_position(Vector3(-1.0, 1.4, -0.3), Vector3(-1.75, 1.35, 0), Vector3.UP)
	# Rhazur à esquerda olhando para a direita; alvo a 3 casas
	var pr = Vector3(-2.0, 0, 0)
	var pa = Vector3(2.0, 0, 0)
	var hr = Node3D.new()
	hr.position = pr
	w.add_child(hr)
	var fr: Node3D = b._figure3d("t_sniper", 2.0)
	hr.add_child(fr)
	var ha = Node3D.new()
	ha.position = pa
	w.add_child(ha)
	var fa: Node3D = b._figure3d(OS.get_environment("ALVO") if OS.get_environment("ALVO") != "" else "k_cmd", 2.0)
	ha.add_child(fa)
	var vfx = Node3D.new()
	vfx.set_script(load("res://scripts/vfx.gd"))
	w.add_child(vfx)
	vfx.board = self
	await get_tree().process_frame
	var mao = func() -> Vector3:
		var sk: Skeleton3D = fr.get_meta("skel")
		var bn: Dictionary = fr.get_meta("bones")
		var ph = sk.global_transform * sk.get_bone_global_pose(int(bn["RightHand"])).origin
		return ph + (ph - sk.global_transform * sk.get_bone_global_pose(int(bn["RightForeArm"])).origin) * 0.55
	var o = OS.get_environment("PASTA")
	var t = 0.0
	var dt = 1.0 / 30.0
	var feito = {}
	var k0 = 15
	var R = vfx.raios()
	var RO = m.SNIPER_RAIO
	var corpo = func() -> Array:
		var sk2: Skeleton3D = fa.get_meta("skel")
		var bn2: Dictionary = fa.get_meta("bones")
		var out = []
		for nm in ["Head", "Spine2", "Spine1", "Hips", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "LeftHand", "RightHand", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"]:
			if bn2.has(nm):
				out.append(sk2.global_transform * sk2.get_bone_global_pose(bn2[nm]).origin)
		return out
	var b_alvo = pa + Vector3(0, 0.8, 0)
	var voo = 0.0
	var k_hit = 9999
	for k in 120:
		if k == k0:
			fr.set_meta("gesto", "eletro")
			fr.set_meta("gesto_t0", b.relogio)
			fr.set_meta("gesto_alvo", pa)
		if k == k0 + int(b.ELETRO_CARGA * 30):
			vfx.play_fx("ter_sniper_carga", mao.call() - Vector3(0, 1.0, 0), null, Color.WHITE, null, {"de_f": mao, "nucleo": Color("#4cd4bd")})
			R.coroa(mao, 0.32, b.ELETRO_SOLTA - b.ELETRO_CARGA + 0.05, RO.merged({"n": 2, "largura": 0.03}))
		if k == k0 + int(b.ELETRO_SOLTA * 30):
			var a0 = mao.call()
			voo = clamp(a0.distance_to(b_alvo) / (30.0 / vfx.TEMPO), 0.15 * vfx.TEMPO, 0.9 * vfx.TEMPO)
			vfx.play_fx("ter_sniper_tiro", pa, a0 - Vector3(0, 1.0, 0), Color.WHITE, null, {"de_f": mao, "nucleo": Color("#4cd4bd")})
			var t0 = Time.get_ticks_msec()
			var kk = k
			R.coroa(func() -> Vector3: return a0.lerp(b_alvo, clamp((float(b.relogio) - float(fr.get_meta("_t_solta", 0.0))) / voo, 0.0, 1.0)), 0.45, voo, RO.merged({"n": 4, "largura": 0.055}))
			fr.set_meta("_t_solta", b.relogio)
			k_hit = k + int(round(voo * 30))
		if k == k_hit:
			R.espalha(pa + Vector3(0, 0.85, 0), 0.0, 0.55, RO.merged({"n": 8, "alcance": 1.5, "largura": 0.04}))
			R.eletrocuta(corpo, m.SNIPER_CHOQUE, RO.merged({"n": 5, "largura": 0.045, "flick": 0.06, "frente": true}))
			vfx.play_fx("ter_sniper_choque", pa, null, Color.WHITE)
			fa.set_meta("choque_ate", b.relogio + m.SNIPER_CHOQUE)
		# como no tabuleiro: a posição do boneco volta a zero a cada quadro e cada um olha para o outro
		fr.position = Vector3.ZERO
		fa.position = Vector3.ZERO
		fr.set_meta("olha", ha.global_position - hr.global_position)
		fa.set_meta("olha", hr.global_position - ha.global_position)
		b._fig3d_tick(fr, dt, t, false, Color.WHITE, false, 0.0, 0.0, false, Vector3.ZERO)
		b._fig3d_tick(fa, dt, t, false, Color.WHITE, false, 0.0, 0.0, false, Vector3.ZERO)
		t += dt
		await RenderingServer.frame_post_draw
		sv.get_texture().get_image().save_png("%s/f%03d.png" % [o, k])
