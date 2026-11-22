extends Node
## Quem gera draw calls no tabuleiro (godot-performance-export): godot --path . -- --teste=drawcalls
var m
var por: Dictionary = {}


func conta(n: Node, grupo: String) -> void:
	if n is Node3D and not n.visible:
		return
	if n is GeometryInstance3D:
		var surf = 1
		if n is MeshInstance3D and n.mesh != null:
			surf = n.mesh.get_surface_count()
		var passes = 1 + (1 if n.material_overlay != null else 0)
		if n is MeshInstance3D:
			for i in surf:
				var mt = n.get_active_material(i)
				if mt is BaseMaterial3D and mt.next_pass != null:
					passes += 1
				elif mt is ShaderMaterial and mt.next_pass != null:
					passes += 1
		var c = surf * passes
		if n is MultiMeshInstance3D:
			c = passes
		if not por.has(grupo):
			por[grupo] = [0, 0, ""]
		por[grupo][0] += c
		por[grupo][1] += 1
		if por[grupo][2] == "":
			por[grupo][2] = str(n.get_path()).substr(0, 90)
	for ch in n.get_children():
		conta(ch, grupo)


func run() -> void:
	m = get_parent()
	m.autotest = true
	Engine.time_scale = 25.0
	m.setup_cfg["map"] = "posto"
	m._start_match(null)
	Engine.time_scale = 1.0
	for i in 150:
		await get_tree().process_frame
	var sd = OS.get_environment("SAIDA")
	if sd != "":
		m.board.cam_speed = 100.0
		m.board.fit_camera(true)
		Engine.time_scale = 0.0001
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(sd)
	for ch in m.board.get_children():
		conta(ch, ch.name + ":" + ch.get_class())
	for ch in m.vfx.get_children():
		conta(ch, "vfx/" + ch.get_class())
	var ks = por.keys()
	ks.sort_custom(func(a, b): return por[a][0] > por[b][0])
	var tot = 0
	for k in ks:
		tot += por[k][0]
	print("DRAW total_estimado=%d medido=%d" % [tot, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	for k in ks.slice(0, 14):
		print("  %5d draws  %4d nós  %s   ex: %s" % [por[k][0], por[k][1], k, por[k][2]])
	get_tree().quit()
