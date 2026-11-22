extends SceneTree
## Gera as peças que o ProtonScatter espalha pelo cenário de Valak (cristais de enfeite e estalagmites).
## godot --headless --path . --script res://tools/gerar_itens_scatter.gd

const CORES = {"verde": ["#4f9a3a", "#2a5e28"], "azul": ["#3f7fa0", "#244c78"], "roxo": ["#9a4a8e", "#5a2a72"]}


func _mat(c: Color, brilho: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = brilho
	return m


func _cyl(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var c = CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func _peca(root: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3) -> void:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	root.add_child(mi)
	mi.owner = root


func _salva(root: Node3D, nome: String) -> void:
	var ps = PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "res://scenes/entornos/%s.tscn" % nome)
	print("salvo ", nome)


func _initialize() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 77
	# cristais de enfeite: cor apagada (não confundir com os do tabuleiro, que se quebram)
	for cor in CORES:
		var root = Node3D.new()
		root.name = "cristal_" + cor
		var n = 4
		for i in range(n):
			var hgt = rng.randf_range(0.6, 1.4) * (1.3 if i == 0 else 1.0)
			var rad = rng.randf_range(0.12, 0.2) * (1.3 if i == 0 else 1.0)
			var a = TAU * i / n
			var off = Vector3(cos(a), 0, sin(a)) * (0.0 if i == 0 else 0.25)
			var rot = Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35)) if i > 0 else Vector3.ZERO
			var col = Color(CORES[cor][i % 2])
			_peca(root, _cyl(rad * 0.85, rad, hgt, 6), _mat(col, 0.25), off + Vector3(0, hgt * 0.5, 0), rot)
			_peca(root, _cyl(0.0, rad * 0.85, rad * 1.6, 6), _mat(col.lightened(0.2), 0.3), off + Vector3(0, hgt + rad * 0.8, 0), rot)
		_salva(root, "cristal_" + cor)
	# estalagmite de pedra roxa
	var est = Node3D.new()
	est.name = "estalagmite"
	_peca(est, _cyl(0.0, 0.45, 1.8, 7), _mat(Color("#3a2470"), 0.0), Vector3(0, 0.9, 0), Vector3.ZERO)
	_peca(est, _cyl(0.0, 0.25, 1.0, 6), _mat(Color("#2e1a5e"), 0.0), Vector3(0.35, 0.5, 0.1), Vector3(0, 0, -0.3))
	_salva(est, "estalagmite")
	quit()
