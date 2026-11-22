extends Node
## Foto da escolha no tabuleiro e da janela da carta: godot --path . -- --teste=ui_escolha (SAIDA=pasta)

var m


func foto(nome: String) -> void:
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SAIDA") + "/" + nome + ".png")
	print("FOTO ", nome)


func run() -> void:
	m = get_parent()
	m.setup_cfg["map"] = "posto"
	m.setup_cfg["modo"] = ""
	m.setup_cfg["fac"] = "ABY"
	m.setup_cfg["cpu"] = "FAU"
	m._set_papel(0)
	m._start_match(null)
	print("INICIO")
	for i in 300:
		await get_tree().process_frame
	var g = m.game
	print("CAMPO ", g.field().size(), " asking=", m.asking)
	if m.asking != null:
		m._answer(false)
		for i in 60:
			await get_tree().process_frame
	var u = g.field().filter(func(x): return x.owner == 0 and not x.barrier)[0]
	var hs = DB.nbrs(u.pos()).filter(func(h): return g.is_free(h))
	g.pick_hex(0, "Impulso! %s derrubou um inimigo: avançar 1 casa grátis?" % g.nm(u), hs, "move", true)
	await foto("e1_escolha_tabuleiro")
	m._answer(null)
	for i in 30:
		await get_tree().process_frame
	m._card_info("onda")
	await foto("e2_janela_carta")
	get_tree().quit()
