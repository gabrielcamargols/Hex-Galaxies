# Reduz um modelo pesado (Meshy) para uma cena leve: pega o nível de LOD que o Godot gerou na importação
# com o número de triângulos mais próximo do alvo, compacta os vértices e salva malha + material numa .scn.
# Uso: godot --headless --path . -s res://tools/decima_modelo.gd -- <origem.fbx> <destino.scn> <triangulos>
extends SceneTree


func _init() -> void:
	var a = OS.get_cmdline_user_args()
	var src: String = a[0]
	var dst: String = a[1]
	var alvo := int(a[2])
	var cena: Node3D = load(src).instantiate()
	var raiz := Node3D.new()
	raiz.name = dst.get_file().get_basename()
	for mi in cena.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		var nova := ArrayMesh.new()
		for s in m.get_surface_count():
			var arr: Array = m.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var melhor := idx
			var d = RenderingServer.mesh_get_surface(m.get_rid(), s)
			for lod in d.get("lods", []):
				var li: PackedInt32Array = _bytes_to_idx(lod["index_data"], arr[Mesh.ARRAY_VERTEX].size())
				if abs(li.size() / 3 - alvo) < abs(melhor.size() / 3 - alvo):
					melhor = li
			arr = _compacta(arr, melhor)
			nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mat = mi.get_active_material(s)
			if mat != null:
				nova.surface_set_material(s, mat)
			print("superfície %d: %d -> %d triângulos" % [s, idx.size() / 3, melhor.size() / 3])
		var n := MeshInstance3D.new()
		n.name = str(mi.name)
		n.mesh = nova
		n.transform = cena.global_transform.affine_inverse() * mi.global_transform if cena.is_inside_tree() else _rel(cena, mi)
		raiz.add_child(n)
		n.owner = raiz
	var ps := PackedScene.new()
	ps.pack(raiz)
	print("salvo ", dst, " -> ", ResourceSaver.save(ps, dst, ResourceSaver.FLAG_COMPRESS))
	quit()


func _rel(root: Node, n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != root and c != null:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


func _bytes_to_idx(b: PackedByteArray, nv: int) -> PackedInt32Array:
	# índices de 16 bits quando a malha tem poucos vértices, senão 32
	if nv <= 65535:
		var out := PackedInt32Array()
		out.resize(b.size() / 2)
		for i in out.size():
			out[i] = b.decode_u16(i * 2)
		return out
	return b.to_int32_array()


func _compacta(arr: Array, idx: PackedInt32Array) -> Array:
	var mapa := {}
	var novo_idx := PackedInt32Array()
	novo_idx.resize(idx.size())
	var usados := PackedInt32Array()
	for i in idx.size():
		var v := idx[i]
		if not mapa.has(v):
			mapa[v] = usados.size()
			usados.append(v)
		novo_idx[i] = mapa[v]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for k in Mesh.ARRAY_MAX:
		var src = arr[k]
		if k == Mesh.ARRAY_INDEX or src == null:
			continue
		var comp := 1
		var n: int = arr[Mesh.ARRAY_VERTEX].size()
		if src.size() != n and n > 0:
			comp = src.size() / n
		var dst = src.duplicate()
		dst.resize(usados.size() * comp)
		for j in usados.size():
			for c in comp:
				dst[j * comp + c] = src[usados[j] * comp + c]
		out[k] = dst
	out[Mesh.ARRAY_INDEX] = novo_idx
	return out
