# Copyright © 2026 CosmonautFrog - MIT License

@tool
extends EditorScenePostImport
## glTF loses custom_aabb, without it the LODs don't swap at the same distance.


func _post_import(scene: Node) -> Object:
	var meshes := scene.get_children().filter(
		func(child: Node) -> bool:
			return child is MeshInstance3D
	)

	var collisions := scene.get_children().filter(
		func(child: Node) -> bool:
			return child is StaticBody3D
	)

	var bounds := AABB()
	for mesh: MeshInstance3D in meshes:
		bounds = bounds.merge(mesh.mesh.get_aabb())

	if scene.has_node("Impostor_LOD3"):
		var r := maxf(
			maxf(-bounds.position.x, bounds.end.x),
			maxf(-bounds.position.z, bounds.end.z)
		)
		bounds = AABB(
			Vector3(-r, bounds.position.y, -r),
			Vector3(2.0 * r, bounds.size.y, 2.0 * r)
		)

	for mesh: MeshInstance3D in meshes:
		mesh.custom_aabb = bounds
		mesh.add_to_group(&"cosmo_tree_mesh", true)

	for col: StaticBody3D in collisions:
		col.add_to_group(&"cosmo_tree_collision", true)

	scene.add_to_group(&"cosmo_tree", true)

	return scene
