extends Node
## Buracos do Verme em Tarhut: põe três buracos, mostra a casa de perto e de cima (câmera de jogo).
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
	var hs = [Vector2i(1, 0), Vector2i(2, -2), Vector2i(-1, 2)]
	for h in hs:
		g.holes.append({"h": h, "until": 99})
	g.load_map()
	m.refresh()
	m.board.refresh_terrain()
	await _espera(1.0)
	# câmera própria, de cima (ortográfica), centrada no buraco: contorno do buraco x contorno da casa
	var c = Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	c.size = 5.0
	m.board.add_child(c)
	for i in 3:
		var p: Vector3 = m._hex_pos(hs[i], 0.0)
		c.global_position = p + Vector3(0, 30, 0)
		c.look_at(p, Vector3(0, 0, -1))
		c.make_current()
		await _espera(0.6)
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SAIDA") + "_cima%d.png" % i)
	var c2 = Camera3D.new()
	m.board.add_child(c2)
	var p2: Vector3 = m._hex_pos(hs[0], 0.0)
	c2.global_position = p2 + Vector3(0, 4.5, 4.5)
	c2.look_at(p2, Vector3.UP)
	c2.make_current()
	await _espera(0.6)
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SAIDA") + "_lado.png")
	get_tree().quit()
