extends Node
## Custo dos VFX DENTRO da partida (com o cenário inteiro): chamadas de desenho extras de um golpe
## com luz e sem luz. No renderizador do navegador cada luz pontual redesenha tudo o que ela alcança.
##   MAPA=abnara godot --path . -- --teste=vfxtabuleiro
var m


func _pico(f: Callable, quadros: int = 50) -> int:
	var base = 0
	for i in 8:
		await RenderingServer.frame_post_draw
		base = max(base, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	f.call()
	var pico = 0
	for i in quadros:
		await RenderingServer.frame_post_draw
		pico = max(pico, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	for i in 90:
		await get_tree().process_frame
	return pico - base


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
	var vfx = m.vfx
	var at = m.board.global_position
	var so_luz = await _pico(func(): vfx._fx_light({"luz": "#f438a9", "energia": 4.0, "alcance": 4.5, "dur": 0.3, "y": 1.0}, at))
	var impacto = await _pico(func(): vfx.play_fx("aby_impacto", at + Vector3(1.7, 0, 0), at, Color.WHITE))
	var sem = OS.get_environment("SEM_LUZ")
	print("VFX_TAB mapa=%s luz_sozinha=+%d aby_impacto=+%d" % [m.setup_cfg["map"], so_luz, impacto])
