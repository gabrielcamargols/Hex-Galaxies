extends Node
## Foto do cenário de um planeta (com tela): MAPA=abnara godot --path . -- --teste=planeta  (SAIDA=arquivo.png)
var m


func run() -> void:
	m = get_parent()
	m.setup_cfg["map"] = OS.get_environment("MAPA") if OS.get_environment("MAPA") != "" else "abnara"
	m.setup_cfg["modo"] = ""
	m._set_papel(0)
	m._start_match(null)
	for i in 320:
		await get_tree().process_frame
	if m.asking != null:
		m._answer(false)
	m.board.cam_speed = 100.0
	m.board.fit_camera(true)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SAIDA"))
	print("FOTO ", m.setup_cfg["map"], " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	get_tree().quit()
