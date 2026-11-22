# Copyright © 2026 CosmonautFrog - MIT License

extends RefCounted
## Builds collision shapes from the tree skeleton.

const Branch := preload("./branch.gd")
const MeshUtils := preload("./mesh_utils.gd")
const TrunkGen := preload("./trunk_gen.gd")


static func _convex(points: PackedVector3Array) -> ConvexPolygonShape3D:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape


## Cuts `branch` in place where it first rises above `max_y`. Returns true if it was cut.
static func _clip_height(branch: Branch, max_y: float) -> bool:
	for i in range(1, branch.points.size()):
		var a := branch.points[i - 1]
		var b := branch.points[i]
		if b.y <= max_y:
			continue

		var t := (max_y - a.y) / (b.y - a.y)
		var radius := lerpf(branch.radii[i - 1], branch.radii[i], t)
		branch.points.resize(i)
		branch.radii.resize(i)
		# a point right at the limit would make a zero length segment
		if a.y < max_y:
			branch.add_point(a.lerp(b, t), radius)
		return true

	return false


## `sphere_radii` is one radius per foliage cluster, only used by SPHERES.
static func create_foliage_shapes(
	type: CosmoTreeGen.FoliageCollisionType,
	foliage_mesh: ArrayMesh,
	sphere_radii: PackedFloat32Array,
) -> Array[Shape3D]:
	var shapes: Array[Shape3D] = []

	match type:
		CosmoTreeGen.FoliageCollisionType.HULL:
			shapes.append(foliage_mesh.create_convex_shape(true, true))
		CosmoTreeGen.FoliageCollisionType.SPHERES:
			for radius in sphere_radii:
				var sphere := SphereShape3D.new()
				sphere.radius = radius
				shapes.append(sphere)

	return shapes


static func create_branch_shapes(
	type: CosmoTreeGen.CollisionType,
	branches: Array[Branch],
	max_level: int,
	max_height: float,
	radial: int,
	trunk_params: CosmoTrunkParams,
) -> Array[Shape3D]:
	var shapes: Array[Shape3D] = []
	var faces := PackedVector3Array()

	for branch in branches:
		if branch.level > max_level:
			continue

		var part := branch
		while part != null:
			if part.points[0].y >= max_height:
				break

			var ringed: Branch = part.with_base_rings()
			var cut := _clip_height(ringed, max_height)
			var vertices := PackedVector3Array()
			var indices := PackedInt32Array()
			# a cut end gets a flat cap below instead of the cone poking above the limit
			MeshUtils.append_tube(
				vertices, indices, ringed.points, ringed.radii, radial,
				not cut and part.terminal == null,
			)

			if part.base_rings > 0 and type != CosmoTreeGen.CollisionType.SIMPLE_CONVEX:
				TrunkGen.flare_base(vertices, 0, part, trunk_params)

			if cut:
				# leaning rings tilt above the limit, flatten them onto it
				for i in vertices.size():
					vertices[i].y = minf(vertices[i].y, max_height)

				if type == CosmoTreeGen.CollisionType.TRIMESH:
					var last := (ringed.points.size() - 1) * (radial + 1)
					for j in radial:
						faces.append_array(PackedVector3Array([
							ringed.tip(), vertices[last + j], vertices[last + j + 1],
						]))

			match type:
				CosmoTreeGen.CollisionType.SIMPLE_CONVEX:
					shapes.append(_convex(vertices))
				CosmoTreeGen.CollisionType.MULTIPLE_CONVEX:
					# two consecutive rings make a frustum, which is already convex
					var ring := radial + 1
					for i in ringed.points.size() - 1:
						shapes.append(_convex(vertices.slice(i * ring, (i + 2) * ring)))
				CosmoTreeGen.CollisionType.TRIMESH:
					for i in indices:
						faces.push_back(vertices[i])

			part = null if cut else part.terminal

	if not faces.is_empty():
		var trimesh := ConcavePolygonShape3D.new()
		trimesh.set_faces(faces)
		shapes.append(trimesh)

	return shapes
