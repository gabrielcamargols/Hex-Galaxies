extends Node
## O Verme Gigante de Tarhut (modelo do Gabriel) saindo dos buracos numa partida, na câmera de jogo.
##   godot --path . --fixed-fps 30 --write-movie verme.avi -- --teste=verme
func _espera(seg: float) -> void:
	for i in int(seg * 30):
		await get_tree().process_frame


func run() -> void:
	var m = get_parent()
	m.setup_cfg["map"] = "tarhut"
	m.setup_cfg["modo"] = ""
	m.setup_cfg["fac"] = "KRI"
	m._set_papel(0)
	m._start_match(null)
	await _espera(1.0)
	m.skip_entry = true
	await _espera(6.0)
	if m.asking != null:
		m._answer(false)
	var g = m.game
	var hs = []
	for b in g.holes:
		hs.append(b["h"])
	if hs.is_empty():
		hs = [Vector2i(0, 0), Vector2i(2, -1), Vector2i(-2, 1)]
	m.board.fit_camera(true)
	if OS.get_environment("DIST") != "":
		m.board.cam_goal = null
		m.board.cam_target = m._hex_pos(hs[0], 0.0)
		m.board.cam_dist = float(OS.get_environment("DIST"))
	await _espera(1.0)
	print("VERME buracos=", hs)
	m._on_fx_real({"t": "worm"})
	if g.holes.is_empty():
		# no começo da partida ainda não há buracos: chama o verme em três casas para ver
		hs = [Vector2i(0, 0), Vector2i(2, -1), Vector2i(-2, 1)]
		m.board.worm_emerge(hs)
	for i in 6:
		await _espera(0.5)
		for c in m.board.get_children():
			if c.get_script() == load("res://scripts/worm.gd"):
				print("VERME no ", c.global_position, " t=", c.t, " sk=", c.sk != null, " vis=", c.visible)
	await _espera(3.5)
	get_tree().quit()
