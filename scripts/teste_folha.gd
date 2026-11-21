extends Node
## Folha de conferência: cada modelo parado (frente e lado), andando, correndo e no golpe.
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
	var so = OS.get_environment("SO")
	for c in b.FIG3D.keys():
		if so != "" and not so.split(",").has(c):
			continue
		var holder = Node3D.new()
		w.add_child(holder)
		var fig: Node3D = b._figure3d(c, 2.0)
		holder.add_child(fig)
		await get_tree().process_frame
		var ab = AABB()
		var first = true
		for mi in fig.find_children("*", "MeshInstance3D", true, false):
			var a = mi.global_transform * mi.get_aabb()
			ab = a if first else ab.merge(a)
			first = false
		var H = ab.size.y
		print("modelo ", c, " H ", H)
		var n = 0
		for cena in [["parado", 0.0, 2.0], ["parado", PI / 2.0, 2.0], ["andando", float(OS.get_environment("YW")) if OS.has_environment("YW") else PI / 2.0, 1.33], ["andando", float(OS.get_environment("YW")) if OS.has_environment("YW") else PI / 2.0, 1.55], ["correndo", PI / 2.0, 1.4], ["golpe", 0.6, 0.35]]:
			for mm in ["walk_w", "run_w", "fase", "cj_t", "cj_w"]:
				fig.set_meta(mm, 0.0)
			var t = 0.0
			var giro: Node3D = fig.get_node("giro")
			for k in int(cena[2] * 30.0) + 30:
				t += 1.0 / 30.0
				fig.position = Vector3.ZERO
				var walk = cena[0] == "andando" or cena[0] == "correndo"
				var lunge = 0.0
				if cena[0] == "golpe":
					lunge = clamp(1.0 - t / 0.9, 0.0, 1.0) if t > 0.6 else 0.0
				if fig.has_meta("dragao"):
					b._dragao_tick(fig, 1.0 / 30.0, t, walk, cena[0] == "correndo", lunge, 0.0)
				else:
					b._fig3d_tick(fig, 1.0 / 30.0, t, false, Color.WHITE, walk, lunge, 0.0, cena[0] == "correndo", Vector3.ZERO)
				giro.rotation.y = cena[1]
			var ce = Vector3(0, H * 0.5, 0)
			cam.look_at_from_position(ce + Vector3(0, H * 0.08, H * 2.1), ce)
			await get_tree().process_frame
			await get_tree().process_frame
			sv.get_texture().get_image().save_png("%s/%s_%d.png" % [o, c, n])
			n += 1
		holder.queue_free()
		await get_tree().process_frame
