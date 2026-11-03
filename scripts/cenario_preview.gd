extends Node3D
## Vitrine dos assets de cenário (tools/cenario.py): todos lado a lado, com o sombreado e o contorno do jogo.
## godot --path . -- --cenario=/pasta/saida    (salva vitrine_tarhut.png e vitrine_valak.png)

var board


func run(out_dir: String, b) -> void:
	board = b
	var cam = Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	add_child(sun)
	var we = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2a2140")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.32
	env.ambient_light_color = Color(0.85, 0.88, 0.95)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	cam.make_current()
	for planet in ["tarhut", "valak"]:
		var root = Node3D.new()
		add_child(root)
		var kinds = []
		var dir = DirAccess.open("res://models")
		for f in dir.get_files():
			if f.begins_with("cen_%s_" % planet) and f.ends_with("_0.glb"):
				kinds.append(f.trim_prefix("cen_%s_" % planet).trim_suffix("_0.glb"))
		kinds.sort()
		for i in range(kinds.size()):
			for v in range(3):
				var holder = Node3D.new()
				root.add_child(holder)
				board._model(holder, "cen_%s_%s_%d" % [planet, kinds[i], v], Vector3(v * 3.2, 0, i * 3.4), 2.4, 0.5, true)
		var w = 2 * 3.2
		var d = (kinds.size() - 1) * 3.4
		cam.look_at_from_position(Vector3(w / 2 + 20, 16, d / 2 + 2), Vector3(w / 2, 0.6, d / 2), Vector3.UP)
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir + "/vitrine_%s.png" % planet)
		root.queue_free()
		await get_tree().process_frame
