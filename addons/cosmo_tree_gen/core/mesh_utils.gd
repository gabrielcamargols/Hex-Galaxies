# Copyright © 2026 CosmonautFrog - MIT License

extends RefCounted
## Shared helpers.


static func _fill_flat(
	arrays: Array,
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs := PackedVector2Array(),
) -> void:
	var count := indices.size()
	var has_uvs := not uvs.is_empty()
	var flat_vertices := PackedVector3Array()
	var flat_normals := PackedVector3Array()
	var flat_uvs := PackedVector2Array()
	flat_vertices.resize(count)
	flat_normals.resize(count)
	if has_uvs:
		flat_uvs.resize(count)

	for t in range(0, count, 3):
		var a := vertices[indices[t]]
		var b := vertices[indices[t + 1]]
		var c := vertices[indices[t + 2]]
		var normal := (c - a).cross(b - a).normalized()
		for k in 3:
			flat_vertices[t + k] = vertices[indices[t + k]]
			flat_normals[t + k] = normal
			if has_uvs:
				flat_uvs[t + k] = uvs[indices[t + k]]

	arrays[Mesh.ARRAY_VERTEX] = flat_vertices
	arrays[Mesh.ARRAY_NORMAL] = flat_normals
	if has_uvs:
		arrays[Mesh.ARRAY_TEX_UV] = flat_uvs


## Returns a copy of the arrays without the vertices no index uses,
## otherwise each LOD keeps the whole LOD0 vertex buffer.
static func _remove_unused_vertices(arrays: Array) -> Array:
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var vertex_array: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var vertex_count := vertex_array.size()

	var index_map := PackedInt32Array()
	index_map.resize(vertex_count)
	index_map.fill(-1)
	var used := PackedInt32Array()
	var new_indices := PackedInt32Array()
	new_indices.resize(indices.size())

	for i in indices.size():
		var old := indices[i]
		if index_map[old] == -1:
			index_map[old] = used.size()
			used.push_back(old)
		new_indices[i] = index_map[old]

	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_INDEX] = new_indices
	for attribute: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV]:
		var old_values: Variant = arrays[attribute]
		if old_values == null:
			continue
		@warning_ignore("unsafe_method_access")
		var new_values: Variant = old_values.duplicate()
		@warning_ignore("unsafe_method_access")
		new_values.resize(used.size())
		for i in used.size():
			new_values[i] = old_values[used[i]]
		out[attribute] = new_values

	return out


static func _smooth_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())

	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		var face := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		normals[a] += face
		normals[b] += face
		normals[c] += face

	# Weld vertices sharing a position (UV seams) so they get the same normal
	var welded := {}
	for i in vertices.size():
		welded[vertices[i]] = welded.get(vertices[i], Vector3.ZERO) + normals[i]

	for i in normals.size():
		var normal: Vector3 = welded[vertices[i]]
		normals[i] = normal.normalized()
	return normals


static func append_tube(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	points: PackedVector3Array,
	radii: PackedFloat32Array,
	radial: int,
	close_end: bool = false,
) -> void:
	var base := vertices.size()
	var count := points.size()
	var ring := radial + 1  # extra vertex per ring for the UV seam
	var tangent := (points[1] - points[0]).normalized()
	# the UV seam is at angle 0, start it underneath unless the tube is near vertical
	var normal := tangent.cross(Vector3.RIGHT) if absf(tangent.y) > 0.9 else Vector3.DOWN + tangent * tangent.y
	normal = normal.normalized()

	for i in count:
		tangent = (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
		normal = (normal - tangent * normal.dot(tangent)).normalized()
		var binormal := normal.cross(tangent)
		var first := vertices.size()
		for j in radial:
			var angle := TAU * j / radial
			vertices.push_back(points[i] + (normal * cos(angle) + binormal * sin(angle)) * radii[i])
		vertices.push_back(vertices[first])

	for i in count - 1:
		for j in radial:
			var a := base + i * ring + j
			var b := a + 1
			var c := a + ring
			var d := c + 1
			indices.append_array(PackedInt32Array([d, c, a, d, a, b]))

	# close tube with a cap
	var tip_radius := radii[count - 1]
	if close_end and tip_radius > 0.0:
		var apex := vertices.size()
		var last := base + (count - 1) * ring
		vertices.push_back(points[count - 1] + tangent * tip_radius)
		for j in radial:
			indices.append_array(PackedInt32Array([apex, last + j, last + j + 1]))


## World space UVs for the tube append_tube added at `first`, `density` texture repeats per meter,
## so every tube gets the same texel size. Run it after deforming the tube, it measures the final shape.
static func append_tube_uvs(
	uvs: PackedVector2Array,
	vertices: PackedVector3Array,
	first: int,
	rings: int,
	radial: int,
	density: float,
	offset := Vector2.ZERO,
) -> void:
	var ring := radial + 1
	var length := 0.0

	for i in rings:
		var start := first + i * ring
		# measured on the surface so the flare slope counts, averaged so the columns don't shear
		if i > 0:
			var step := 0.0
			for j in radial:
				step += vertices[start + j].distance_to(vertices[start + j - ring])
			length += step / radial

		var perimeter := 0.0
		for j in radial:
			perimeter += vertices[start + j].distance_to(vertices[start + j + 1])

		# centered on the top, so where the tube narrows the texture skews at the seam underneath
		# u and v decrease so the texture is upright and not mirrored seen from outside
		var arc := perimeter * 0.5
		for j in ring:
			if j > 0:
				arc -= vertices[start + j].distance_to(vertices[start + j - 1])
			uvs.push_back(Vector2(arc, -length) * density + offset)

	# cap apex
	var apex := first + rings * ring
	if apex < vertices.size():
		var slant := 0.0
		for j in radial:
			slant += vertices[apex].distance_to(vertices[apex - ring + j])
		uvs.push_back(Vector2(0.0, -(length + slant / radial)) * density + offset)


## The albedo texture of a BaseMaterial3D, or the `albedo_texture` uniform of a ShaderMaterial.
static func get_albedo_texture(material: Material) -> Texture2D:
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).albedo_texture
	if material is ShaderMaterial:
		var texture: Texture2D = (material as ShaderMaterial).get_shader_parameter("albedo_texture")
		return texture
	return null


static func build_mesh(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	flat_shading: bool,
	uvs := PackedVector2Array(),
) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	if flat_shading:
		_fill_flat(arrays, vertices, indices, uvs)
	else:
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = _smooth_normals(vertices, indices)
		arrays[Mesh.ARRAY_INDEX] = indices
		if not uvs.is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = uvs

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func combine_meshes(array_meshes: Array[ArrayMesh]) -> ArrayMesh:
	# could use SurfaceTool but couldn't find out how to maintain separated materials
	var out := ArrayMesh.new()

	for am: ArrayMesh in array_meshes:
		for i in range(am.get_surface_count()):
			out.add_surface_from_arrays(
				am.surface_get_primitive_type(i),
				am.surface_get_arrays(i)
			)
			var new_idx := out.get_surface_count() - 1
			out.surface_set_name(new_idx, am.surface_get_name(i))
			out.surface_set_material(new_idx, am.surface_get_material(i))

	return out


static func count_triangles(mesh: ArrayMesh) -> int:
	if mesh == null:
		return 0

	@warning_ignore("integer_division")
	return mesh.surface_get_array_index_len(0) / 3


static func flatten_mesh(mesh: Mesh) -> ArrayMesh:
	var src := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	var uvs := PackedVector2Array()
	if src[Mesh.ARRAY_TEX_UV] != null:
		uvs = src[Mesh.ARRAY_TEX_UV]
	var result := build_mesh(vertices, indices, true, uvs)
	result.surface_set_name(0, (mesh as ArrayMesh).surface_get_name(0))
	result.surface_set_material(0, mesh.surface_get_material(0))
	return result


static func simplify(src: ArrayMesh, max_triangles: float) -> ArrayMesh:
	if count_triangles(src) <= max_triangles:
		return src

	var arrays := src.surface_get_arrays(0)
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(25.0, 60.0, [])

	for lod in importer.get_surface_lod_count(0):
		var indices := importer.get_surface_lod_indices(0, lod)
		arrays[Mesh.ARRAY_INDEX] = indices
		if indices.size() / 3.0 <= max_triangles:
			break

	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _remove_unused_vertices(arrays))
	out.surface_set_name(0, src.surface_get_name(0))
	return out
