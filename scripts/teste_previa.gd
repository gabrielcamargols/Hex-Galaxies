extends Node
## Foto da prévia de cristais (com tela): godot --path . -- --teste=previa  (SAIDA=pasta)
var m


func run() -> void:
	m = get_parent()
	m.setup_cfg["map"] = "posto"
	m.setup_cfg["modo"] = ""
	m.setup_cfg["fac"] = "TER"
	m.setup_cfg["cpu"] = "KRI"
	m._set_papel(0)
	m._start_match(null)
	for i in 300:
		await get_tree().process_frame
	if m.asking != null:
		m._answer(false)
		for i in 30:
			await get_tree().process_frame
	var g = m.game
	# campo limpo perto da borda esquerda de baixo
	for u in g.units.duplicate():
		if u.barrier and u.st == "field" and DB.dist(u.pos(), Vector2i(-3, 4)) <= 3:
			g.units.erase(u)
	var meus = g.field().filter(func(x): return x.owner == 0 and not x.barrier)
	var deles = g.field().filter(func(x): return x.owner == 1 and not x.barrier)
	var eu = meus[0]
	eu.q = -4
	eu.r = 3
	if meus.size() > 1:
		meus[1].q = -2
		meus[1].r = 2
	if deles.size() > 0:
		deles[0].q = -3
		deles[0].r = 6
	var c1 = g._make_crystal(0, Vector2i(-3, 3), "preto")
	c1.muro = 999
	var c2 = g._make_crystal(0, Vector2i(-3, 4), "preto")
	c2.muro = 999
	g.cur = 0
	g.act = null
	eu.activated = false
	g.start_activation(eu)
	m.sel = eu.uid
	m.pend = {"kind": "attack", "tuid": c1.uid}
	m.refresh()
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SAIDA") + "/previa.png")
	print("FOTO previa")
	get_tree().quit()
