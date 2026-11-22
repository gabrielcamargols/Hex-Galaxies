extends Node
## Fotos da Barreira de Valak (com tela): godot --path . -- --teste=muro   (SAIDA=pasta)
var m


func foto(nome: String) -> void:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SAIDA") + "/" + nome + ".png")
	print("FOTO ", nome)


func espera(t: String) -> bool:
	for i in 600:
		if m.asking != null and m.asking["q"]["t"] == t:
			return true
		await get_tree().process_frame
	return false


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
	var rei = g.units.filter(func(x): return x.owner == 0 and x.cid == "rei_mina")[0]
	# limpa a volta do Rei e põe ele em campo, perto do meio
	var casa = Vector2i(-3, 4)
	for u in g.units.duplicate():
		if u.st == "field" and DB.dist(u.pos(), casa) <= 4 and u != rei:
			if u.barrier:
				g.units.erase(u)
			else:
				u.q = 5
				u.r = -5 + (u.uid % 3)
	rei.st = "field"
	rei.q = casa.x
	rei.r = casa.y
	g.cur = 0
	g.act = null
	rei.activated = false
	g.start_activation(rei)
	m.sel = rei.uid
	m.refresh()
	g.act_ult(rei)
	var cam = [Vector2i(-1, 3), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, 0)]
	var cores = [0, 2, 1, 2, 0]
	for k in range(cam.size()):
		if not await espera("hex"):
			print("SEM HEX ", k)
			break
		var ops: Array = m.asking["q"]["opts"]
		var alvo = cam[k] if ops.has(cam[k]) else ops[0]
		if k == 1:
			await foto("m0_proximo")
		m._answer(alvo)
		if not await espera("choice"):
			print("SEM COR ", k)
			break
		if k == 0:
			await foto("m1_cor_no_mapa")
		m._answer(cores[k])
	for i in 90:
		await get_tree().process_frame
	await foto("m2_muro")
	get_tree().quit()
