extends Node
## Fichas do tabuleiro (no lugar das palavras): Hex Energy que vai surgir, fogo, artilharia, mina, bomba, entrar.
##   SAIDA=/caminho/prefixo godot --path . -- --teste=fichas
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
	var c: Vector2i = g.core_next if g.core_next != null else Vector2i(0, 0)
	var viz = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		viz.append(c + d * 2)
	g.fires.append({"h": viz[0], "owner": 0, "until": 99})
	g.shells.append({"h": viz[1], "round": 99, "src": 0, "owner": 0})
	g.mines.append({"h": viz[2], "owner": m.me, "src": 0, "hidden": false})
	g.mines.append({"h": viz[3], "owner": m.me, "src": 0, "hidden": true})
	m.dsel = 0
	m.refresh()
	await _espera(1.0)
	var cam = Camera3D.new()
	m.board.add_child(cam)
	var p: Vector3 = m._hex_pos(c, 0.0)
	cam.global_position = p + Vector3(0, 9, 7)
	cam.look_at(p, Vector3.UP)
	cam.make_current()
	await _espera(1.2)
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SAIDA") + "_fichas.png")
	m._dica_casa(c)
	await _espera(0.3)
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SAIDA") + "_dica.png")
	printerr("FICHAS core_next=", g.core_next, " R", g.core_next_round, " viz=", viz)
	get_tree().quit()
