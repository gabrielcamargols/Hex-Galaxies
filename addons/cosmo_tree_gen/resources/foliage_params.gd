# Copyright © 2026 CosmonautFrog - MIT License

@tool
class_name CosmoFoliageParams
extends Resource
## Foliage of a [CosmoTreeGen]: icospheres or leaf cards on the branches of the last level.

const MeshUtils := preload("../core/mesh_utils.gd")

enum Type {
	## No foliage.
	NONE,
	## One noisy icosphere at the tip of each branch of the last level, and at the top of each trunk.
	## Needs a material with UV1 Triplanar.
	ICOSPHERES,
	## Textured cards along the branches of the last level.
	LEAVES,
}

## Foliage type.
@export var type: Type = Type.ICOSPHERES:
	set(value):
		type = value
		notify_property_list_changed()
		emit_changed()

#region ICOSPHERES
## How much the branch length scales the icospheres. [br][br]
## 0 gives them all [member icosphere_radius], 1 scales it by the branch length relative to the trunk.
@export_range(0.0, 1.0) var icosphere_length_influence: float = 0.4:
	set(value):
		icosphere_length_influence = value
		emit_changed()
## Radius of the icospheres, in meters, before [member icosphere_length_influence].
@export_range(0.1, 5.0, 0.01, "suffix:m", "or_greater") var icosphere_radius: float = 1.0:
	set(value):
		icosphere_radius = value
		emit_changed()
## Detail of the icospheres, each level has 4 times the triangles: 20, 80, 320, 1280 and 5120 per icosphere.
@export_range(0, 4, 1, "or_greater") var icosphere_subdivisions: int = 1:
	set(value):
		icosphere_subdivisions = value
		emit_changed()
## How much the noise deforms the icospheres, as a fraction of their radius. 0 keeps them round.
@export_range(0.0, 0.6, 0.01, "or_greater") var icosphere_amplitude: float = 0.4:
	set(value):
		icosphere_amplitude = value
		emit_changed()
## Frequency of the deformation noise. Higher values make more and smaller bumps.
@export_range(0.1, 10.0, 0.1, "or_greater") var icosphere_frequency: float = 1.5:
	set(value):
		icosphere_frequency = value
		emit_changed()
#endregion


#region LEAVES
## Leaves per branch, spread from [member leaf_start] to the tip. [br][br]
## With [member leaf_double], each leaf is 2 cards.
@export_range(1, 50, 1, "or_greater") var leaf_count: int = 12:
	set(value):
		leaf_count = value
		emit_changed()
## Adds one more leaf at the tip of each branch, pointing along it.
@export var leaf_tip: bool = false:
	set(value):
		leaf_tip = value
		emit_changed()
## Height of the leaf cards, in meters, before [member leaf_size_variance], [member leaf_size_curve]
## and [member leaf_length_influence].
@export_range(0.05, 3.0, 0.01, "suffix:m", "or_greater") var leaf_size: float = 0.6:
	set(value):
		leaf_size = value
		emit_changed()
## Width / height of the leaf cards, their height is [member leaf_size]. [br][br]
## 0 takes it from the albedo texture of the foliage material, or square if it has none.
@export_range(0.0, 4.0, 0.01, "or_greater") var leaf_aspect: float = 0.0:
	set(value):
		leaf_aspect = value
		emit_changed()
## Multiplies [member leaf_size] by the curve value where each leaf grows on the branch (0 base, 1 tip).
## Leaves where it's 0 are skipped.
@export var leaf_size_curve: Curve:
	set(value):
		if leaf_size_curve != null:
			leaf_size_curve.changed.disconnect(emit_changed)
		leaf_size_curve = value
		if leaf_size_curve != null:
			leaf_size_curve.changed.connect(emit_changed)
		emit_changed()
## How much the branch length scales the leaves. [br][br]
## 0 gives them all the same size, 1 scales them by the branch length relative to the longest branch.
@export_range(0.0, 1.0) var leaf_length_influence: float = 0.0:
	set(value):
		leaf_length_influence = value
		emit_changed()
## Random size variation of each leaf, 0.3 is +-30%.
@export_range(0.0, 0.9) var leaf_size_variance: float = 0.3:
	set(value):
		leaf_size_variance = value
		emit_changed()
## Where the leaves start along the branch, 0 is its base and 1 its tip.
@export_range(0.0, 1.0) var leaf_start: float = 0.3:
	set(value):
		leaf_start = value
		emit_changed()
## Offset applied to each leaf's position relative to its attachment point.
@export var leaf_position_offset: Vector3 = Vector3.ZERO:
	set(value):
		leaf_position_offset = value
		emit_changed()
## Angle between the leaf cards and the branch, in degrees. 0 points them along the branch, 90 perpendicular.
@export_range(0.0, 90.0, 0.05, "degrees") var leaf_angle: float = 40.0:
	set(value):
		leaf_angle = value
		emit_changed()
## How strong leaves are tilted toward the down direction.
## 0 keeps the generated orientation, 1 points them full down.
@export_range(0.0, 1.0) var leaf_gravity: float = 0.0:
	set(value):
		leaf_gravity = value
		emit_changed()
## Adds a second card to each leaf, crossed at 90°, so they don't look flat from the side.
## Doubles the foliage triangles.
@export var leaf_double: bool = true:
	set(value):
		leaf_double = value
		emit_changed()
## Blends the card normals towards a rounded shape around the whole canopy, so it's lit as one volume.
## 0 keeps the flat card normals.
@export_range(0.0, 1.0) var leaf_canopy_normals: float = 0.8:
	set(value):
		leaf_canopy_normals = value
		emit_changed()
## Brightness of the leaves in the center of the canopy, it fades to 1 towards the edges. 1 disables it. [br][br]
## Stored in the vertex color, the included leaves shader uses it as AO.
@export_range(0.0, 1.0) var leaf_inner_ao: float = 0.35:
	set(value):
		leaf_inner_ao = value
		emit_changed()
#endregion


func _validate_property(property: Dictionary) -> void:
	var prop_name: String = property.name
	var is_leaf := prop_name.begins_with("leaf_")
	var is_icosphere := prop_name.begins_with("icosphere_")
	if (
		(is_leaf and type != Type.LEAVES)
		or (is_icosphere and type != Type.ICOSPHERES)
	):
		property.usage = PROPERTY_USAGE_NO_EDITOR


func get_leaf_aspect(material: Material) -> float:
	if leaf_aspect > 0.0:
		return leaf_aspect

	var texture := MeshUtils.get_albedo_texture(material)
	if texture == null or texture.get_height() == 0:
		return 1.0

	return float(texture.get_width()) / texture.get_height()
