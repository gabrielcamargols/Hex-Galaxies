extends Node
## Filminho da Nave Krieg numa partida de verdade: o Comandante chama no rádio, a linha é marcada,
## a nave passa rasante soltando bombas casa a casa. Rodar com --write-movie (ou só olhar a cena).
##   MAPA=tarhut godot --path . --fixed-fps 30 --write-movie nave.avi -- --teste=nave
func run() -> void:
	var m = get_parent()
	m.setup_cfg["map"] = OS.get_environment("MAPA") if OS.get_environment("MAPA") != "" else "tarhut"
	m.setup_cfg["modo"] = ""
	m.setup_cfg["fac"] = "KRI"
	m._set_papel(0)
	m._start_match(null)
	for i in 30:
		await get_tree().process_frame
	m.skip_entry = true
	for i in 200:
		await get_tree().process_frame
	if m.asking != null:
		m._answer(false)
	var g = m.game
	g.pace_time = 0.0
	# Comandante em campo perto da base; inimigos espalhados numa linha à frente dele
	var cmd = g.commander(0)
	var base: Vector2i = DB.entry_c[0]
	var alvo_dir = DB.DIRS[0]
	var melhor = -1
	for d in DB.DIRS:
		var c = base + d * 4
		var dd = DB.dist(c, DB.entry_c[1])
		if melhor < 0 or dd < melhor:
			melhor = dd
			alvo_dir = d
	var hc: Vector2i = base + alvo_dir
	cmd.st = "field"
	cmd.q = hc.x
	cmd.r = hc.y
	var ini: Vector2i = base + alvo_dir * 3
	var lado = DB.DIRS[(DB.DIRS.find(alvo_dir) + 1) % 6]
	var dir = alvo_dir
	# coloca peças inimigas na linha para ver as bombas grandes
	var k = 0
	for e in g.units:
		if e.owner == 1 and e.st == "field":
			var hh = ini + dir * (4 + k * 3)
			if DB.in_board(hh) and g.unit_at(hh) == null:
				e.q = hh.x
				e.r = hh.y
			k += 1
	m.refresh()
	for i in 60:
		await get_tree().process_frame
	m.board.fit_camera(true)
	var meio = (m._hex_pos(ini, 0.0) + m._hex_pos(ini + dir * 9, 0.0)) * 0.5
	m.board.cam_goal = null
	m.board.cam_target = meio
	m.board.cam_dist = float(OS.get_environment("DIST")) if OS.get_environment("DIST") != "" else 30.0
	for i in 40:
		await get_tree().process_frame
	m._cena_nave(cmd, ini, dir)
	for i in int(6.5 * 30):
		await get_tree().process_frame
	get_tree().quit()
