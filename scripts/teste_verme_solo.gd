extends Node
## O Verme Gigante sozinho (sem partida): sai do buraco, ruge e dá o bote. Quadros em PASTA (--fixed-fps 30).
func run() -> void:
	var m = get_parent()
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
	pm.size = Vector2(30, 30)
	chao.mesh = pm
	var cm = StandardMaterial3D.new()
	cm.albedo_color = Color("#e9a35c")
	chao.material_override = cm
	w.add_child(chao)
	var cam = Camera3D.new()
	cam.fov = 45
	w.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(14, 9, 22), Vector3(0, 5, 0), Vector3.UP)
	var verme = Node3D.new()
	verme.set_script(load("res://scripts/worm.gd"))
	w.add_child(verme)
	verme.setup(load("res://models/vermes.glb"), Vector3.ZERO, Vector3(5, 0, 0), m.board.outline_mat, 0.3)
	var o = OS.get_environment("PASTA")
	for k in 160:
		await RenderingServer.frame_post_draw
		sv.get_texture().get_image().save_png("%s/f%03d.png" % [o, k])
