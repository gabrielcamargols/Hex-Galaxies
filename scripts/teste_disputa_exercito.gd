extends Node
## Foto da montagem do exército na Disputa (com tela): godot --path . -- --teste=disputa_exercito
func run() -> void:
	var m = get_parent()
	for i in 60:
		await get_tree().process_frame
	m.stage = "select"
	m._choose_planet("valak", "galeria")
	for i in 200:
		await get_tree().process_frame
	m._army_random()
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SAIDA"))
	get_tree().quit()
