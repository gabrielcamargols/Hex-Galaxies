extends Node
## Fotos do fluxo da Disputa (com tela): godot --path . -- --teste=disputa_ui   (salva em SAIDA/*.png)

var m
var dir := ""


func foto(nome: String) -> void:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/" + nome + ".png")
	print("FOTO ", nome)


func espera_pergunta(t: String, max_f: int = 900) -> bool:
	for i in max_f:
		if m.asking != null and m.asking["q"]["t"] == t:
			return true
		await get_tree().process_frame
	return false


func run() -> void:
	dir = OS.get_environment("SAIDA")
	m = get_parent()
	m.setup_cfg["map"] = "posto"
	m.setup_cfg["modo"] = "disputa"
	m.setup_cfg["fac"] = "KRI"
	m.setup_cfg["cpu"] = "WAC"
	m._set_papel(0)
	m._start_match(null)
	# 1) exclusivas
	if await espera_pergunta("excl"):
		var ops = m.asking["q"]["opts"]
		m._excl_toggle(ops[0], 3)
		m._excl_toggle(ops[2], 3)
		await foto("d1_exclusivas")
		m._excl_toggle(ops[3], 3)
		await foto("d2_exclusivas_ok")
		var r = m.excl_sel.duplicate()
		m.excl_sel = []
		m._answer(r)
	else:
		print("SEM PERGUNTA excl")
	# 2) draft (o 1º par é dos Guardiões = CPU; o 2º é nosso)
	if await espera_pergunta("draft"):
		await foto("d3_draft")
		m._answer(m.asking["q"]["opts"][0])
	else:
		print("SEM PERGUNTA draft")
	for i in 240:
		await get_tree().process_frame
	await foto("d4_campo")
	print("MAO ", m.game.P[0]["hand"])
	# 3) extração: põe uma tropa nossa no núcleo e extrai
	var g = m.game
	var tropa = g.field().filter(func(x): return x.owner == 0 and not x.barrier)[0]
	var oc = g.unit_at(g.core)
	if oc != null:
		oc.q = 6
		oc.r = 0
	tropa.q = g.core.x
	tropa.r = g.core.y
	g.cur = 0
	g.act = null
	tropa.activated = false
	g.start_activation(tropa)
	m.sel = tropa.uid
	m.refresh()
	await foto("d5_extrair_botao")
	await g.act_extract(tropa)
	m.refresh()
	for i in 60:
		await get_tree().process_frame
	await foto("d6_extraindo")
	# 4) fim: os Guardiões seguram até o prazo
	g.winner = 1 - g.inv
	g.win_cause = "prazo"
	m.refresh()
	m._game_over()
	for i in 60:
		await get_tree().process_frame
	await foto("d7_resultado")
	# 5) revanche: papéis trocados, preparação de novo
	m.w["over"].queue_free()
	m.w.erase("over")
	m.setup_cfg["inv"] = 1 - g.inv
	m._start_match(m.last_sides)
	if await espera_pergunta("excl"):
		await foto("d8_revanche_exclusivas")
		print("REVANCHE inv=", m.game.inv, " eu=", m.me)
	get_tree().quit()
