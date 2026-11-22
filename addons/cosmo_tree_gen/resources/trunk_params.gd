# Copyright © 2026 CosmonautFrog - MIT License

@tool
class_name CosmoTrunkParams
extends Resource
## Shape of the trunks of a [CosmoTreeGen], and their roots.

## Mesh detail of the trunks, branches and roots. [br][br]
## Trunks get 6 × quality sides and 3 × quality height segments, branches and roots 2 sides less.
## Branch segments are set per level, in [member CosmoBranchLevel.segments].
@export_range(1, 6, 1, "or_greater") var quality: int = 1:
	set(value):
		quality = value
		emit_changed()
## Number of trunks, growing from the same base in a circle. Each one gets its own branches.
@export_range(1, 6, 1, "or_greater") var amount: int = 1:
	set(value):
		amount = value
		emit_changed()
## Distance between the trunk bases, relative to [member radius_bottom]. [br][br]
## 0 grows them all from the same point and 1 makes them touch. Only used with 2 or more trunks.
@export_range(0.0, 4.0, 0.01, "or_greater") var spread: float = 1.0:
	set(value):
		spread = value
		emit_changed()
## Height of the trunks, in meters. [br][br]
## Branch lengths are relative to their parent, so taller trunks also get longer branches.
@export_range(0.1, 25.0, 0.1, "suffix:m", "or_greater") var height: float = 4.5:
	set(value):
		height = value
		emit_changed()
## Radius at the base of the trunks, in meters, before the [member flare].
@export_range(0.0, 2.0, 0.01, "suffix:m", "or_greater") var radius_bottom: float = 0.35:
	set(value):
		radius_bottom = value
		emit_changed()
## Radius at the top of the trunks, in meters. It goes linearly from [member radius_bottom] to this.
@export_range(0.0, 0.5, 0.01, "suffix:m", "or_greater") var radius_top: float = 0.1:
	set(value):
		radius_top = value
		emit_changed()
## How far the top of the trunks moves sideways, in meters. It bends more towards the top. [br][br]
## The direction comes from the seed. Multiple trunks lean away from each other.
@export_range(0.0, 2.0, 0.01, "suffix:m", "or_greater") var lean: float = 0.6:
	set(value):
		lean = value
		emit_changed()
## Random sideways bending of the trunks, in meters. Strongest in the middle, the base and the top don't move.
@export_range(0.0, 2.0, 0.01, "suffix:m", "or_greater") var wobble: float = 0.15:
	set(value):
		wobble = value
		emit_changed()
## Widens the base of the trunks. [br][br]
## 1 doubles the radius at the ground, 0 disables it.
@export_range(0.0, 3.0, 0.01, "or_greater") var flare: float = 0.0:
	set(value):
		flare = value
		emit_changed()
## How high the flare reaches, as a fraction of [member height].
@export_range(0.01, 1.0, 0.01) var flare_height: float = 0.15:
	set(value):
		flare_height = value
		emit_changed()
## How uneven the flare is around the trunk. 0 keeps it round, 1 makes strong lobes.
@export_range(0.0, 1.0, 0.01) var flare_lobes: float = 0.6:
	set(value):
		flare_lobes = value
		emit_changed()
## Extends the trunks this many meters underground, so they don't float on slopes.
@export_range(0.0, 2.0, 0.01, "suffix:m", "or_greater") var sink_depth: float = 0.0:
	set(value):
		sink_depth = value
		emit_changed()
## Branch level that grows the roots from each trunk. Roots get no foliage. [br][br]
## Use a low [member CosmoBranchLevel.end], a high angle and a negative
## [member CosmoBranchLevel.up_force] so they spread near the ground, see the Ash preset.
@export var roots: CosmoBranchLevel:
	set(value):
		if roots != null:
			roots.changed.disconnect(emit_changed)
		roots = value
		if roots != null:
			roots.changed.connect(emit_changed)
		emit_changed()


func get_lean_vec(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle)) * lean


func get_base_offset(angle: float) -> Vector3:
	if amount < 2:
		return Vector3.ZERO
	return Vector3(cos(angle), 0.0, sin(angle)) * spread * radius_bottom / sin(PI / amount)
