# Copyright © 2026 CosmonautFrog - MIT License

@tool
extends RefCounted
## Builds a tree from CosmoTreeGen params, creates meshes and collision shapes.

enum Part {
	## Trunk and/or foliage in a single mesh, one surface/material each.
	COMBINED,
	TRUNK,
	FOLIAGE,
}

const Settings := preload("./settings.gd")
const Branch := preload("./branch.gd")
const FoliageGen := preload("./foliage_gen.gd")
const CollisionGen := preload("./collision_gen.gd")
const TrunkGen := preload("./trunk_gen.gd")
const BranchGen := preload("./branch_gen.gd")
const MeshUtils := preload("./mesh_utils.gd")

const TRUNK_SURFACE_NAME: String = "bark"
const FOLIAGE_SURFACE_NAME: String = "foliage"
const COLLISION_RADIAL_SEGMENTS: int = 6


## Grows all the branch levels, then meshes them along with the trunk.
## Fills `roots` with the trunk roots, they are not part of the returned branches.
static func _generate_branches(
	tree: CosmoTreeGen,
	trunks: Array[Branch],
	roots: Array[Branch],
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	trunk_radial: int,
	branch_radial: int,
) -> Array[Branch]:
	var branches: Array[Branch] = []
	var parents: Array[Branch] = trunks
	for level in tree.branch_levels:
		if level == null:
			continue
		var children: Array[Branch] = []
		for parent in parents:
			children.append_array(BranchGen.grow_branches(parent, level))
		branches.append_array(children)
		if children.is_empty():
			break
		parents = children

	# terminal branches are meshed inside the tube of the branch they continue
	var params := tree.trunk_params
	var uv_density := tree.get_uv_density()
	for trunk in trunks:
		_append_branch_tube(vertices, indices, uvs, trunk, trunk_radial, params, uv_density)
	for branch in branches:
		if not branch.is_terminal:
			_append_branch_tube(vertices, indices, uvs, branch, branch_radial, params, uv_density)

	# roots are not added to `branches`, so they get no foliage
	if params.roots != null:
		for trunk in trunks:
			for root in BranchGen.grow_branches(trunk, params.roots):
				roots.append(root)
				_append_branch_tube(vertices, indices, uvs, root, branch_radial, params, uv_density)

	return branches


## Meshes a branch and its terminal branches as one seamless tube.
static func _append_branch_tube(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	branch: Branch,
	radial: int,
	trunk_params: CosmoTrunkParams,
	uv_density: float,
) -> void:
	var first := vertices.size()
	var ringed: Branch = branch.with_base_rings()
	var points: PackedVector3Array = ringed.points
	var radii: PackedFloat32Array = ringed.radii

	if branch.sink_depth > 0.0:
		points.insert(0, branch.points[0] + Vector3.DOWN * branch.sink_depth)
		radii.insert(0, branch.radii[0])

	var terminal := branch.terminal
	while terminal != null:
		# Its first point is the tip it grows from
		points.append_array(terminal.points.slice(1))
		radii.append_array(terminal.radii.slice(1))
		terminal = terminal.terminal
	MeshUtils.append_tube(vertices, indices, points, radii, radial, true)
	if branch.base_rings > 0:
		TrunkGen.flare_base(vertices, first, branch, trunk_params)

	# after the flare so it doesn't stretch them, offset so the branches don't all start the same
	var rng := RandomNumberGenerator.new()
	rng.seed = branch.branch_seed
	var offset := Vector2(rng.randf(), rng.randf())
	MeshUtils.append_tube_uvs(uvs, vertices, first, points.size(), radial, uv_density, offset)


static func _create_lod(
	tree: CosmoTreeGen,
	trunk_mesh: ArrayMesh,
	foliage_mesh: ArrayMesh,
	ratio: float,
) -> Array[ArrayMesh]:
	var trunk_tris := MeshUtils.count_triangles(trunk_mesh)
	var foliage_tris := MeshUtils.count_triangles(foliage_mesh)
	var budget := (trunk_tris + foliage_tris) * ratio

	var trunk: ArrayMesh
	if trunk_mesh != null:
		trunk = MeshUtils.simplify(trunk_mesh, maxf(budget * tree.lod_trunk_share, budget - foliage_tris))

	var foliage: ArrayMesh
	if foliage_mesh != null:
		var remaining := budget - MeshUtils.count_triangles(trunk)
		if tree.foliage_params.type == CosmoFoliageParams.Type.LEAVES:
			foliage = FoliageGen.create_leaves_lod(tree.foliage_params, foliage_mesh, remaining / foliage_tris)
		else:
			foliage = MeshUtils.simplify(foliage_mesh, remaining)

	return [trunk, foliage]


static func build(tree: CosmoTreeGen) -> Result:
	var result := Result.new()
	if tree.trunk_params == null:
		push_warning("CosmoTreeGen: missing 'trunk_params'!")
		return result

	# Skeleton
	var trunk_radial: int = TrunkGen.BASE_RADIAL_SEGMENTS * tree.trunk_params.quality
	var branch_radial: int = maxi(3, trunk_radial - 2)

	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()

	var trunks: Array[Branch] = TrunkGen.generate_trunks(tree.noise_seed, tree.trunk_params)

	var roots: Array[Branch] = []
	var branches: Array[Branch] = _generate_branches(
		tree, trunks, roots, vertices, indices, uvs, trunk_radial, branch_radial
	)

	var tips: Array[Branch] = trunks.duplicate()
	if not branches.is_empty():
		var last_level: int = branches.back().level
		tips.append_array(branches.filter(
			func(b: Branch) -> bool:
				return b.level == last_level
		))

	var trunk_mesh: ArrayMesh
	if tree.create_trunk:
		trunk_mesh = MeshUtils.build_mesh(vertices, indices, false, uvs)
		trunk_mesh.surface_set_name(0, TRUNK_SURFACE_NAME)

	# Foliage
	var foliage_mesh: ArrayMesh
	var sphere_centers := PackedVector3Array()
	var sphere_radii := PackedFloat32Array()
	if tree.foliage_params != null and tree.create_foliage:
		# TODO: add different types of foliage, E.G.: dead trees, pines, etc...
		match tree.foliage_params.type:
			CosmoFoliageParams.Type.NONE: pass
			CosmoFoliageParams.Type.ICOSPHERES:
				foliage_mesh = FoliageGen.create_icospheres_mesh(tree, tips, sphere_centers, sphere_radii)
			CosmoFoliageParams.Type.LEAVES:
				foliage_mesh = FoliageGen.create_leaves_mesh(tree, tips, trunks.size(), sphere_centers, sphere_radii)

		if foliage_mesh != null:
			foliage_mesh.surface_set_name(0, FOLIAGE_SURFACE_NAME)

	# Collision
	if tree.collision_type != CosmoTreeGen.CollisionType.NONE:
		var collision_branches: Array[Branch] = trunks.duplicate()
		collision_branches.append_array(branches)
		collision_branches.append_array(roots)
		var max_height := tree.collision_max_height if tree.collision_max_height > 0.0 else INF
		var shapes := CollisionGen.create_branch_shapes(
			tree.collision_type, collision_branches, tree.collision_level, max_height, COLLISION_RADIAL_SEGMENTS,
			tree.trunk_params,
		)
		# already in local space
		for shape in shapes:
			result.collision.add(shape)

	if tree.foliage_collision_type != CosmoTreeGen.FoliageCollisionType.NONE and foliage_mesh != null:
		var shapes := CollisionGen.create_foliage_shapes(tree.foliage_collision_type, foliage_mesh, sphere_radii)
		for i in shapes.size():
			var origin := Vector3.ZERO
			if tree.foliage_collision_type == CosmoTreeGen.FoliageCollisionType.SPHERES:
				origin = sphere_centers[i]
			result.foliage_collision.add(shapes[i], Transform3D(Basis.IDENTITY, origin))

	# LODs
	var levels: Array[Array] = [[trunk_mesh, foliage_mesh]]
	if tree.generate_lod:
		var lod1_ratio: float = Settings.get_setting(Settings.LOD1_RATIO, 0.4)
		var lod2_ratio: float = Settings.get_setting(Settings.LOD2_RATIO, 0.15)
		levels.append(_create_lod(tree, trunk_mesh, foliage_mesh, lod1_ratio))
		levels.append(_create_lod(tree, trunk_mesh, foliage_mesh, lod2_ratio))

	# Flat shading
	if tree.flat_shading:
		for level: Array in levels:
			var trunk: Mesh = level[0]
			var foliage: Mesh = level[1]
			if trunk != null:
				level[0] = MeshUtils.flatten_mesh(trunk)
			if foliage != null and tree.foliage_params.type == CosmoFoliageParams.Type.ICOSPHERES:
				level[1] = MeshUtils.flatten_mesh(foliage)

	# Combine, every level gets a LOD even if empty, so the indices stay the LOD levels
	for level: Array in levels:
		var lod := LOD.new()
		if tree.combine_trunk_and_foliage:
			var parts: Array[ArrayMesh] = [level[0], level[1]]
			parts = parts.filter(func(x: ArrayMesh) -> bool: return x != null)
			if not parts.is_empty():
				lod.meshes[Part.COMBINED] = MeshUtils.combine_meshes(parts)
		else:
			if level[0] != null:
				lod.meshes[Part.TRUNK] = level[0]
			if level[1] != null:
				lod.meshes[Part.FOLIAGE] = level[1]
		result.lods.append(lod)

	# Bounds
	for lod in result.lods:
		for mesh: ArrayMesh in lod.meshes.values():
			result.bounds = result.bounds.merge(mesh.get_aabb())

	return result


class TreeCollision:   # renomeada: o Cyclops já tem uma classe global "Collision"
	var shapes: Array[Shape3D] = []
	## Transform per shape, local space.
	var transforms: Array[Transform3D] = []

	func add(shape: Shape3D, transform: Transform3D = Transform3D.IDENTITY) -> void:
		shapes.append(shape)
		transforms.append(transform)


class LOD:
	## Just the built parts, never null meshes.
	var meshes: Dictionary[Part, ArrayMesh]


class Result:
	## LOD0 first, its index is the LOD level. 1 LOD, or 3 with generate_lod.
	var lods: Array[LOD] = []
	## Bounds of all the LODs, used to swap them at the same distance.
	var bounds := AABB()
	## Trunks, roots and branches.
	var collision := TreeCollision.new()
	var foliage_collision := TreeCollision.new()
