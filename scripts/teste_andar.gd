extends Node
## Filminho de conferência: os modelos parados, andando, correndo e parando de novo (lado a lado).
func run() -> void:
	var b = get_parent().board
	get_parent().ui.visible = false
	var sv = SubViewport.new()
	sv.size = Vector2i(360, 420)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var w = Node3D.new()
	sv.add_child(w)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.32, 0.38)
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	w.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	w.add_child(sun)
	var chao = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(6, 6)
	chao.mesh = pm
	var cm = StandardMaterial3D.new()
	cm.albedo_color = Color(0.55, 0.5, 0.45)
	chao.material_override = cm
	w.add_child(chao)
	var cam = Camera3D.new()
	cam.fov = 40
	w.add_child(cam)
	cam.current = true
	var o = OS.get_environment("PASTA")
	var lista = OS.get_environment("SO").split(",")
	var holders = []
	var figs = []
	var x = -float(lista.size() - 1) * 0.75
	for c in lista:
		var holder = Node3D.new()
		holder.position = Vector3(x, 0, 0)
		x += 1.5
		w.add_child(holder)
		var fig: Node3D = b._figure3d(c, 2.0)
		holder.add_child(fig)
		fig.get_node("giro").rotation.y = 0.75
		figs.append(fig)
		if OS.has_environment("SEMFOLGA") and fig.has_meta("folga"):
			fig.get_meta("folga").set_active(false)
	sv.size = Vector2i(320 * lista.size(), 420)
	await get_tree().process_frame
	cam.look_at_from_position(Vector3(0, 1.25, 3.4), Vector3(0, 0.85, 0))
	var t = 0.0
	for k in 150:
		t += 1.0 / 30.0
		for fig in figs:
			fig.position = Vector3.ZERO
			b._fig3d_tick(fig, 1.0 / 30.0, t, false, Color.WHITE, k >= 30 and k < 120, 0.0, 0.0, k >= 80 and k < 120, Vector3.ZERO)
		await get_tree().process_frame
		sv.get_texture().get_image().save_png("%s/f%03d.png" % [o, k])
