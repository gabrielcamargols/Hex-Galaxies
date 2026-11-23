extends Node
## Catálogo do cenário de um planeta (com tela): MAPA=abnara godot --path . -- --teste=catalogo (SAIDA=pasta)
## Cada modelo aparece com o material do jogo, numerado, em páginas de 12.
var m

const LISTAS = {
	"abnara": [["k", "jungle", ["tree_detailed", "tree_fat", "tree_blocks", "tree_default", "tree_oak", "tree_tall", "tree_palmDetailedTall", "tree_palmBend", "tree_palmTall",
		"plant_bushLarge", "plant_bushDetailed", "plant_bush", "grass_leafsLarge", "flower_purpleA", "flower_redB", "flower_yellowA", "mushroom_redGroup", "mushroom_tanTall", "mushroom_red",
		"statue_columnDamaged", "statue_column", "statue_head", "statue_ring", "rock_largeA", "rock_largeC", "stump_oldTall", "log_large"]],
		["m", "", ["arvore_abnara_0", "arvore_abnara_1", "arvore_abnara_2"]]],
	"goraida": [["k", "snow", ["tree_pineTallA_detailed", "tree_pineTallB_detailed", "tree_pineRoundC", "tree_pineSmallB", "tree_pineGroundA", "tree_pineDefaultA",
		"stone_tallC", "stone_tallF", "stone_largeB", "stone_largeD", "tent_detailedClosed", "log_stackLarge", "campfire_stones", "stump_round"]],
		["m", "", ["arvore_goraida_0", "arvore_goraida_1", "arvore_goraida_2"]]],
	"tarhut": [["m", "", ["cen_tarhut_rocha_0", "cen_tarhut_rocha_1", "cen_tarhut_cacto_0", "cen_tarhut_cacto_bola_0", "cen_tarhut_ossada_0", "cen_tarhut_cristal_0", "cen_tarhut_buraco_0",
		"tarhut_arenito_0", "tarhut_ossos_0", "tarhut_cacto_0", "tarhut_fossil", "tarhut_flor"]]],
	"posto": [["m", "", ["cen_valak_pinheiro_0", "cen_valak_rocha_0", "cen_valak_barril_0", "cen_valak_caixa_0", "cen_valak_vagonete_0", "cen_valak_domo_0",
		"valak_torre_0", "valak_guindaste_0", "valak_tanque_0", "valak_pinheiro_0", "valak_rocha_0"]]],
}


func run() -> void:
	m = get_parent()
	var mapa = OS.get_environment("MAPA") if OS.get_environment("MAPA") != "" else "abnara"
	m.setup_cfg["map"] = mapa
	m.setup_cfg["modo"] = ""
	m._set_papel(0)
	m._start_match(null)
	for i in 300:
		await get_tree().process_frame
	var b = m.board
	m.ui.visible = false
	var itens = []
	for grp in LISTAS[mapa]:
		for n in grp[2]:
			itens.append([grp[0], grp[1], n])
	var cam = Camera3D.new()
	b.add_child(cam)
	cam.fov = 40.0
	var base = Vector3(400, 0, 0)
	cam.position = base + Vector3(0, 9.0, 13.0)
	cam.look_at(base + Vector3(0, 0.5, 0))
	cam.make_current()
	var luz = DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, -30, 0)
	b.add_child(luz)
	var pag = 0
	var i0 = 0
	while i0 < itens.size():
		var raiz = Node3D.new()
		b.add_child(raiz)
		var chao = MeshInstance3D.new()
		var pm = PlaneMesh.new()
		pm.size = Vector2(26, 18)
		chao.mesh = pm
		var cm = StandardMaterial3D.new()
		cm.albedo_color = Color("#7a8a6a") if mapa == "abnara" else (Color("#e8eef8") if mapa == "goraida" else (Color("#d8a878") if mapa == "tarhut" else Color("#3a2a6a")))
		chao.material_override = cm
		chao.position = base
		raiz.add_child(chao)
		for k in range(12):
			if i0 + k >= itens.size():
				break
			var it = itens[i0 + k]
			var p = base + Vector3((k % 4 - 1.5) * 5.0, 0, (k / 4 - 1) * 4.6)
			var h = Node3D.new()
			h.position = p
			raiz.add_child(h)
			var ok = b._kenney(h, it[2], Vector3.ZERO, 2.4, 0.6, it[1]) if it[0] == "k" else b._model(h, it[2], Vector3.ZERO, 2.4, 0.6, true)
			var lb = Label3D.new()
			lb.text = "%d %s%s" % [i0 + k + 1, it[2], "" if ok else " (FALTA)"]
			lb.font_size = 64
			lb.outline_size = 12
			lb.pixel_size = 0.006
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.no_depth_test = true
			lb.position = p + Vector3(0, -0.2, 1.3)
			raiz.add_child(lb)
		for f in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SAIDA") + "/%s_%d.png" % [mapa, pag])
		print("FOTO %s_%d" % [mapa, pag])
		raiz.queue_free()
		pag += 1
		i0 += 12
	get_tree().quit()
