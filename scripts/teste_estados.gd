extends Node
## Foto dos ícones de estado sobre as peças (com tela): godot --path . -- --teste=estados  (SAIDA=pasta)
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
	var meus = g.field().filter(func(x): return x.owner == 0 and not x.barrier)
	var deles = g.field().filter(func(x): return x.owner == 1 and not x.barrier)
	var r = g.round_no
	if meus.size() > 0:
		meus[0].fx.append({"k": "armadura", "v": 2, "till": r + 1})
		meus[0].fx.append({"k": "atk", "v": 2, "till": r + 1, "src": -78})
		meus[0].fx.append({"k": "golpe_stun", "till": r + 1})
	if meus.size() > 1:
		meus[1].fx.append({"k": "semcura", "until": "end"})
		meus[1].fx.append({"k": "root", "end": r + 1})
	if deles.size() > 0:
		deles[0].fx.append({"k": "stun", "end": r + 1})
		deles[0].fx.append({"k": "mark", "end": r})
	if deles.size() > 1:
		deles[1].fx.append({"k": "venom", "end": r + 2})
	m.inspect = meus[0].uid if meus.size() > 0 else -1
	m.refresh()
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SAIDA") + "/estados.png")
	print("FOTO estados")
	get_tree().quit()
