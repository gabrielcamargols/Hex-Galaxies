# Copyright © 2026 CosmonautFrog - MIT License

extends RefCounted
## A polyline definition, a radius per point.

const Branch := preload("./branch.gd")

var branch_seed: int = 0
var points := PackedVector3Array()
var radii := PackedFloat32Array()
var level: int = 0

## Branch grown from this terminal branch's tip
var terminal: Branch = null
var is_terminal: bool = false
var is_broken: bool = false

var base_rings: int = 0
var sink_depth: float = 0.0


func _segment_at(t: float) -> int:
	return mini(int(_index_at(t)), points.size() - 2)


func _index_at(t: float) -> float:
	return clampf(t, 0.0, 1.0) * (points.size() - 1)


func add_point(point: Vector3, radius: float) -> void:
	points.push_back(point)
	radii.push_back(radius)


func sample(t: float) -> Vector3:
	var i := _segment_at(t)
	return points[i].lerp(points[i + 1], _index_at(t) - i)


func radius_at(t: float) -> float:
	var i := _segment_at(t)
	return lerpf(radii[i], radii[i + 1], _index_at(t) - i)


func tangent_at(t: float) -> Vector3:
	var i := _segment_at(t)
	return (points[i + 1] - points[i]).normalized()


func get_length() -> float:
	var total: float = 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total


func tip() -> Vector3:
	return points[points.size() - 1]


func with_base_rings() -> Branch:
	var out := Branch.new()
	out.points = points.duplicate()
	out.radii = radii.duplicate()

	# bunched towards the ground, where the flare changes the most
	for k in base_rings:
		var s := pow(float(k + 1) / (base_rings + 1), 2.0)
		out.points.insert(k + 1, points[0].lerp(points[1], s))
		out.radii.insert(k + 1, lerpf(radii[0], radii[1], s))

	return out
