extends SceneTree
## Gera as árvores dos planetas com o Cosmo Tree Gen (addons/cosmo_tree_gen) e salva como cenas leves.
## godot --headless --path . --script res://tools/gerar_arvores.gd
## Abnara: árvores frondosas verdes; Gor'Aida: árvores de copa nevada. Cores em tom de guache (toon).

const VARIANTES = [
	# nome, preset, semente, tronco, copa
	["arvore_abnara_0", "low_poly_tree", 11, "#6b4a2e", "#5fae4a"],
	["arvore_abnara_1", "ash", 23, "#5e4128", "#78c25a"],
	["arvore_abnara_2", "low_poly_tree", 37, "#6b4a2e", "#4a9a52"],
	["arvore_goraida_0", "low_poly_tree", 41, "#4a3a34", "#e8f2ff"],
	["arvore_goraida_1", "ash", 53, "#4a3a34", "#d4e6f6"],
	["arvore_goraida_2", "low_poly_tree", 67, "#4a3a34", "#bcd8ee"],
]


func _toon(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


func _initialize() -> void:
	await process_frame
	for v in VARIANTES:
		var gen = CosmoTreeGen.new()
		gen.auto_generate = false
		root.add_child(gen)
		await process_frame
		gen.apply_preset(load("res://addons/cosmo_tree_gen/presets/%s.tres" % v[1]))
		gen.noise_seed = int(v[2])
		gen.combine_trunk_and_foliage = true
		gen.generate()
		var out = Node3D.new()
		out.name = v[0]
		var n = 0
		for mi in gen.get_meshes(0):
			var novo = MeshInstance3D.new()
			novo.name = "malha%d" % n
			novo.mesh = mi.mesh
			out.add_child(novo)
			novo.owner = out
			# superfície 0 = tronco, 1 = copa (malha combinada); tons chapados no estilo do jogo
			for si in range(mi.mesh.get_surface_count()):
				novo.set_surface_override_material(si, _toon(Color(v[3]) if si == 0 else Color(v[4])))
			n += 1
		var ps = PackedScene.new()
		ps.pack(out)
		var err = ResourceSaver.save(ps, "res://scenes/entornos/arvores/%s.tscn" % v[0])
		print("árvore ", v[0], " malhas=", n, " err=", err)
		gen.queue_free()
		out.free()
	quit()
