extends Node
## Filminho do golpe do Perfurador: vira o corpo para a ponta da broca mirar o inimigo e estoca girando.
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
	if OS.get_environment("CAM") == "cima":
		cam.look_at_from_position(Vector3(0.0, 5.0, 3.2), Vector3(0.0, 0.6, 0), Vector3.UP)
	if OS.get_environment("CAM") == "rosto":
		cam.look_at_from_position(Vector3(-1.0, 1.4, -0.3), Vector3(-1.75, 1.35, 0), Vector3.UP)
	# Rhazur à esquerda olhando para a direita; alvo a 3 casas
	var pr = Vector3(-2.0, 0, 0)
	var pa = Vector3(2.0, 0, 0)
	var hr = Node3D.new()
	hr.position = pr
	w.add_child(hr)
	var fr: Node3D = b._figure3d("perfurador", 2.0)
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
	for k in 120:
		if k == 30 or k == 80:
			fr.get_meta("empunha").ataque()
			fr.set_meta("golpe_alvo", pa)
			fr.set_meta("golpe_ate", b.relogio + 1.1)
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
