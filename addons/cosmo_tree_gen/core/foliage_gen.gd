# Copyright © 2026 CosmonautFrog - MIT License

extends RefCounted
## Foliage generator: textured quads along a branch and icospheres on tips.
## References:
## - https://tympanus.net/codrops/2025/01/27/fractals-to-forests-creating-realistic-3d-trees-with-three-js/
## Icosphere math's from:
## - https://blog.lslabs.dev/posts/generating_icosphere_with_code
## - https://schneide.blog/2016/07/15/generating-an-icosphere-in-c/

const Branch := preload("./branch.gd")
const BranchGen := preload("./branch_gen.gd")
const MeshUtils := preload("./mesh_utils.gd")

## (1 + sqrt(5)) / 2 - https://en.wikipedia.org/wiki/Golden_ratio
const GOLDEN_RATIO: float = 1.618033988749895

## 1 / golden ratio. Multiples of it spread evenly over [0, 1).
const GOLDEN_RATIO_CONJUGATE: float = 0.618033988749895


static func _append_icosphere(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	center: Vector3,
	noise_seed: int = 0,
	radius: float = 1.0,
	subdivisions: int = 0,
	amplitude: float = 0.0,
	frequency: float = 1.5,
) -> void:
	const T := GOLDEN_RATIO

	var sphere_vertices := PackedVector3Array([
		Vector3(-1, T, 0), Vector3(1, T, 0), Vector3(-1, -T, 0), Vector3(1, -T, 0),
		Vector3(0, -1, T), Vector3(0, 1, T), Vector3(0, -1, -T), Vector3(0, 1, -T),
		Vector3(T, 0, -1), Vector3(T, 0, 1), Vector3(-T, 0, -1), Vector3(-T, 0, 1),
	])
	for i in sphere_vertices.size():
		sphere_vertices[i] = sphere_vertices[i].normalized()

	var sphere_indices := PackedInt32Array([
		0, 5, 11, 0, 1, 5, 0, 7, 1, 0, 10, 7, 0, 11, 10,
		1, 9, 5, 5, 4, 11, 11, 2, 10, 10, 6, 7, 7, 8, 1,
		3, 4, 9, 3, 2, 4, 3, 6, 2, 3, 8, 6, 3, 9, 8,
		4, 5, 9, 2, 11, 4, 6, 10, 2, 8, 7, 6, 9, 1, 8,
	])

	sphere_indices = _subdivide(sphere_vertices, sphere_indices, subdivisions)
	_displace(sphere_vertices, noise_seed, amplitude, frequency)

	var base := vertices.size()
	for v in sphere_vertices:
		vertices.push_back(center + v * radius)
	for i in sphere_indices:
		indices.push_back(base + i)


static func _append_leaf(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	origin: Vector3,
	tangent: Vector3,
	azimuth: float,
	size: float,
	tilt: float,
	gravity: float,
	double: bool,
	aspect: float = 1.0,
) -> void:
	var helper := Vector3.RIGHT if absf(tangent.y) > 0.9 else Vector3.UP
	var side := tangent.cross(helper).normalized().rotated(tangent, azimuth)
	var dir := tangent * cos(tilt) + side * sin(tilt)
	var hang := Quaternion.IDENTITY.slerp(Quaternion(dir, Vector3.DOWN), gravity)
	var up := hang * dir * size
	var right := hang * tangent.cross(side).normalized() * size * aspect
	_append_quad(vertices, indices, uvs, origin, up, right)
	if double:
		var double_right := up.cross(right).normalized() * size * aspect
		_append_quad(vertices, indices, uvs, origin, up, double_right)


static func _append_leaves(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	branch: Branch,
	params: CosmoFoliageParams,
	length_influence: float = 1.0,
	aspect: float = 1.0,
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([branch.branch_seed, "ayylmao"])
	var tilt := deg_to_rad(params.leaf_angle)

	for k in params.leaf_count:
		var t := lerpf(params.leaf_start, 1.0, (k + rng.randf()) / params.leaf_count)
		var origin := branch.sample(t) + params.leaf_position_offset
		var tangent := branch.tangent_at(t)
		var azimuth := k * BranchGen.GOLDEN_ANGLE + rng.randf_range(-0.3, 0.3)
		var size := _get_leaf_size_at(rng, params, t, length_influence)

		if size <= 0.0 or branch.is_broken:
			continue

		_append_leaf(
			vertices, indices, uvs,
			origin, tangent, azimuth, size, tilt,
			params.leaf_gravity, params.leaf_double, aspect,
		)

	# terminal leaf, after the loop so it doesn't reshuffle the other leaves
	if params.leaf_tip:
		var leaf_tip_tilt: float = 0.0  # TODO: set this as a foliage param maybe
		var size := _get_leaf_size_at(rng, params, 1.0, length_influence)
		var azimuth := rng.randf() * TAU - PI / 2.0
		var origin := branch.tip() + params.leaf_position_offset
		var tangent := branch.tangent_at(1.0)

		if size <= 0.0 or branch.is_broken:
			return

		_append_leaf(
			vertices, indices, uvs,
			origin, tangent, azimuth, size, leaf_tip_tilt,
			params.leaf_gravity, params.leaf_double, aspect,
		)


static func _append_quad(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	base: Vector3,
	up: Vector3,
	right: Vector3,
) -> void:
	var first := vertices.size()
	var half := right * 0.5
	vertices.append_array(PackedVector3Array([base - half, base + half, base + half + up, base - half + up]))
	uvs.append_array(PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]))
	indices.append_array(PackedInt32Array([first, first + 3, first + 2, first, first + 2, first + 1]))


static func _canopy_direction(p: Vector3, radii: Vector3) -> Vector3:
	var outward := (p / radii).normalized()
	return Vector3.UP.lerp(outward, smoothstep(0.0, 0.5, p.length())).normalized()


## Blends the card normals towards an ellipsoid around all the leaves, so
## is lit as one rounded volume (like EZ-Tree "rounded normals", but for the whole thing).
## Also fakes AO in the vertex color, darker int the center.
static func _canopy_shading(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	params: CosmoFoliageParams,
) -> void:
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for v in vertices:
		bounds = bounds.expand(v)
	var center := bounds.get_center()
	var radii := (bounds.size * 0.5).max(Vector3.ONE * 0.01)

	normals.resize(vertices.size())
	colors.resize(vertices.size())
	# 4 vertices per card, see _append_quad
	for q in range(0, vertices.size(), 4):
		var card := (vertices[q + 1] - vertices[q]).cross(vertices[q + 3] - vertices[q]).normalized()
		var mid := (vertices[q] + vertices[q + 2]) * 0.5
		if card.dot(_canopy_direction((mid - center) / radii, radii)) < 0.0:
			card = -card
		for k in 4:
			var p := (vertices[q + k] - center) / radii
			normals[q + k] = card.lerp(_canopy_direction(p, radii), params.leaf_canopy_normals).normalized()
			var ao := lerpf(params.leaf_inner_ao, 1.0, minf(p.length(), 1.0))
			colors[q + k] = Color(ao, ao, ao)


static func _displace(
	vertices: PackedVector3Array,
	noise_seed: int,
	amplitude: float,
	frequency: float,
) -> void:
	if is_zero_approx(amplitude):
		return

	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency

	for i in vertices.size():
		var dir := vertices[i]
		vertices[i] = dir * (1.0 + amplitude * noise.get_noise_3dv(dir))


static func _get_leaf_size_at(
	rng: RandomNumberGenerator,
	params: CosmoFoliageParams,
	t: float,
	length_influence: float,
) -> float:
	var size := params.leaf_size * length_influence * (1.0 + rng.randf_range(-1.0, 1.0) * params.leaf_size_variance)
	if params.leaf_size_curve != null and params.leaf_size_curve.point_count > 0:
		size *= params.leaf_size_curve.sample(t)
	return size


static func _subdivide(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	levels: int,
) -> PackedInt32Array:
	var mid := PackedInt32Array([0, 0, 0])  # ab, bc, ca

	for level in levels:
		var cache := {}
		var new_indices := PackedInt32Array()
		new_indices.resize(indices.size() * 4)
		var n := 0

		for t in range(0, indices.size(), 3):
			for e in 3:
				var p := indices[t + e]
				var q := indices[t + (e + 1) % 3]
				var key := (mini(p, q) << 32) | maxi(p, q)
				var m: int = cache.get(key, -1)
				if m == -1:
					m = vertices.size()
					vertices.push_back((vertices[p] + vertices[q]).normalized())
					cache[key] = m
				mid[e] = m

			var a := indices[t]
			var b := indices[t + 1]
			var c := indices[t + 2]
			var ab := mid[0]
			var bc := mid[1]
			var ca := mid[2]

			new_indices[n] = a
			new_indices[n + 1] = ab
			new_indices[n + 2] = ca
			new_indices[n + 3] = b
			new_indices[n + 4] = bc
			new_indices[n + 5] = ab
			new_indices[n + 6] = c
			new_indices[n + 7] = ca
			new_indices[n + 8] = bc
			new_indices[n + 9] = ab
			new_indices[n + 10] = bc
			new_indices[n + 11] = ca
			n += 12

		indices = new_indices

	return indices


## Fills `sphere_centers` and `sphere_radii` with one sphere per icosphere.
static func create_icospheres_mesh(
	tree: CosmoTreeGen,
	branches: Array[Branch],
	sphere_centers: PackedVector3Array,
	sphere_radii: PackedFloat32Array,
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var trunk := branches[0]
	for branch in branches:
		if branch.is_broken:
			continue

		var length_ratio := branch.get_length() / trunk.get_length()
		var length_influence := lerpf(1.0, length_ratio, tree.foliage_params.icosphere_length_influence)
		var radius := tree.foliage_params.icosphere_radius * length_influence
		_append_icosphere(
			vertices,
			indices,
			branch.tip(),
			branch.branch_seed,
			radius,
			tree.foliage_params.icosphere_subdivisions,
			tree.foliage_params.icosphere_amplitude,
			tree.foliage_params.icosphere_frequency,
		)
		# the noise displaces it +-amplitude, so the base radius is the average fit
		sphere_centers.append(branch.tip())
		sphere_radii.append(radius)

	return MeshUtils.build_mesh(vertices, indices, false)


static func create_leaves_lod(params: CosmoFoliageParams, src: ArrayMesh, keep: float) -> ArrayMesh:
	var arrays := src.surface_get_arrays(0)
	var src_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var src_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]

	# 4 vertices per card, see _append_quad
	var cards_per_leaf: int = 2 if params.leaf_double else 1
	@warning_ignore("integer_division")
	var leaves: int = src_vertices.size() / 4 / cards_per_leaf
	var kept := clampf(keep, 1.0 / leaves, 1.0)
	var card_scale := sqrt(1.0 / kept)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for leaf in leaves:
		if fposmod(leaf * GOLDEN_RATIO_CONJUGATE, 1.0) >= kept:
			continue

		for card in cards_per_leaf:
			var q := (leaf * cards_per_leaf + card) * 4
			var center := (src_vertices[q] + src_vertices[q + 2]) * 0.5
			var first := vertices.size()
			for k in 4:
				vertices.push_back(center + (src_vertices[q + k] - center) * card_scale)
				normals.push_back(src_normals[q + k])
				colors.push_back(src_colors[q + k])
				uvs.push_back(src_uvs[q + k])
			indices.append_array(
				PackedInt32Array([first, first + 3, first + 2, first, first + 2, first + 1])
			)

	var out_arrays := []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX] = vertices
	out_arrays[Mesh.ARRAY_NORMAL] = normals
	out_arrays[Mesh.ARRAY_COLOR] = colors
	out_arrays[Mesh.ARRAY_TEX_UV] = uvs
	out_arrays[Mesh.ARRAY_INDEX] = indices

	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)
	out.surface_set_name(0, src.surface_get_name(0))
	return out


## Fills `sphere_centers` and `sphere_radii` with one sphere per tip leaf cluster.
static func create_leaves_mesh(
	tree: CosmoTreeGen,
	tips: Array[Branch],
	trunk_count: int,
	sphere_centers: PackedVector3Array,
	sphere_radii: PackedFloat32Array,
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()

	# tips starts with the trunks, they only get leaves when there are no branches
	var first := trunk_count if tips.size() > trunk_count else 0
	var aspect: float = tree.foliage_params.get_leaf_aspect(tree.foliage_material)
	var longest := 0.0
	for i in range(first, tips.size()):
		longest = maxf(longest, tips[i].get_length())
	for i in range(first, tips.size()):
		var length_ratio := tips[i].get_length() / longest
		var length_influence := lerpf(1.0, length_ratio, tree.foliage_params.leaf_length_influence)
		var tip_first := vertices.size()
		_append_leaves(vertices, indices, uvs, tips[i], tree.foliage_params, length_influence, aspect)

		# broken tips get no leaves
		if vertices.size() == tip_first:
			continue
		var bounds := AABB(vertices[tip_first], Vector3.ZERO)
		for k in range(tip_first, vertices.size()):
			bounds = bounds.expand(vertices[k])
		sphere_centers.append(bounds.get_center())
		# average of the half extents, the corners of the box are mostly empty
		sphere_radii.append((bounds.size.x + bounds.size.y + bounds.size.z) / 6.0)

	if vertices.is_empty():
		return null

	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	_canopy_shading(vertices, normals, colors, tree.foliage_params)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
