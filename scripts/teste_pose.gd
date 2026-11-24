extends Node
## Vitrine de um modelo 3D (CID): parado de frente, de lado e andando. Quadros em PASTA (--fixed-fps 30).
func run() -> void:
	var m = get_parent()
	var b = m.board
	m.ui.visible = false
	var sv = SubViewport.new()
	sv.size = Vector2i(960, 720)
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
	pm.size = Vector2(20, 10)
	chao.mesh = pm
	var cm = StandardMaterial3D.new()
	cm.albedo_color = Color("#e9a35c")
	chao.material_override = cm
	w.add_child(chao)
	var cam = Camera3D.new()
	cam.fov = 38
	w.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(0, 1.4, 4.6), Vector3(0, 0.95, 0), Vector3.UP)
	if OS.get_environment("PERTO") != "":
		# de perto, 3/4: confere mãos e arma
		var ang = float(OS.get_environment("PERTO"))
		cam.look_at_from_position(Vector3(sin(ang) * 1.9, 1.25, cos(ang) * 1.9), Vector3(0, 0.95, 0), Vector3.UP)
	var hr = Node3D.new()
	w.add_child(hr)
	var fr: Node3D = b._figure3d(OS.get_environment("CID"), 2.0)
	hr.add_child(fr)
	await get_tree().process_frame
	var o = OS.get_environment("PASTA")
	var t = 0.0
	var dt = 1.0 / 30.0
	for k in 150:
		var anda = k >= 80
		if k < 40:
			fr.set_meta("olha", Vector3(0, 0, 10))           # de frente para a câmera
		elif k < 80:
			fr.set_meta("olha", Vector3(10, 0, 0))           # de lado
		if anda:
			hr.position = Vector3(-2.2 + (k - 80) * dt * 1.9, 0, 0)
		fr.position = Vector3.ZERO
		b._fig3d_tick(fr, dt, t, false, Color.WHITE, anda, 0.0, 0.0, false, Vector3(1, 0, 0) if anda else Vector3.ZERO)
		t += dt
		await RenderingServer.frame_post_draw
		sv.get_texture().get_image().save_png("%s/f%03d.png" % [o, k])
	if fr.has_meta("empunha"):
		print("ALCANCE falta=%.4f" % fr.get_meta("empunha").alcance_falta)
