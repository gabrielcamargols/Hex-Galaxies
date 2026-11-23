extends Node
## Close de um gesto de líder com o modelo 3D (ex.: CID=k_cmd GESTO=radio). Quadros em PASTA (--fixed-fps 30).
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
	cam.look_at_from_position(Vector3(1.2, 1.6, 3.4), Vector3(0.0, 1.0, 0), Vector3.UP)
	var fr: Node3D = b._figure3d(OS.get_environment("CID") if OS.get_environment("CID") != "" else "k_cmd", 2.0)
	var hr = Node3D.new()
	w.add_child(hr)
	hr.add_child(fr)
	var alvo = Vector3(4, 0, 4)     # três quartos para a câmera: dá para ver a mão no rádio
	await get_tree().process_frame
	var o = OS.get_environment("PASTA")
	var t = 0.0
	var dt = 1.0 / 30.0
	for k in 100:
		if k == 10:
			fr.set_meta("gesto", OS.get_environment("GESTO") if OS.get_environment("GESTO") != "" else "radio")
			fr.set_meta("gesto_t0", b.relogio)
			fr.set_meta("gesto_alvo", alvo)
		fr.position = Vector3.ZERO
		fr.set_meta("olha", alvo)
		b._fig3d_tick(fr, dt, t, false, Color.WHITE, false, 0.0, 0.0, false, Vector3.ZERO)
		t += dt
		await RenderingServer.frame_post_draw
		sv.get_texture().get_image().save_png("%s/f%03d.png" % [o, k])
