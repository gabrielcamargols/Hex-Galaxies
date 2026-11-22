extends Node
## Foto da Estrela Hexa (Esterina): godot --path . -- --teste=estrela  (com tela; salva em SAIDA)
func run() -> void:
	var m = get_parent()
	m._start_deus()
	for i in 200:
		await get_tree().process_frame
	var g = m.game
	var b = m.board
	var livre = func(h): return g.is_free(h) and not g.blocks.has(h)
	var cs = DB.hexes.filter(func(h): return g.star_hexes(h).size() == 13 and g.star_hexes(h).all(func(x): return livre.call(x)))
	var c = cs[cs.size() / 2]
	var pos = [c, c + DB.DIRS[0], c + DB.DIRS[2] * 2]
	var ids = ["sterina", "balu", "strahl"]
	for i in 3:
		var u = g._mk(ids[i], 0, "field")
		u.q = pos[i].x
		u.r = pos[i].y
	g.stars.append({"owner": 0, "c": c, "hexes": g.star_hexes(c), "till": g.round_no + 2, "src": 999})
	m.refresh()
	b.cam_goal = null
	b.cam_target = Vector3(b.world_xz(c).x, b.top_y(c) + 0.5, b.world_xz(c).y)
	b.cam_dist = 19.0
	for i in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SAIDA"))
	get_tree().quit()
