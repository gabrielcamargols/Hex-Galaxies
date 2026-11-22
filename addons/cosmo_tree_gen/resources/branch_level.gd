# Copyright © 2026 CosmonautFrog - MIT License

@tool
class_name CosmoBranchLevel
extends Resource
## A level of branches of a [CosmoTreeGen], grown from every branch of the previous level,
## or from the trunks for the first one.

## Branches grown from each parent branch, spread around it between [member start] and [member end].
@export_range(0, 60, 1, "or_greater") var count: int = 6:
	set(value):
		count = value
		emit_changed()
## Grows one more branch from the tip of each parent, with its direction and radius,
## meshed as a single tube with it. [br][br]
## Use it to continue the trunk or the branches past the child branches. It isn't counted in [member count].
@export var terminal: bool = false:
	set(value):
		terminal = value
		emit_changed()
## Where the branches start along the parent, 0 is its base and 1 its tip.
@export_range(0.0, 1.0) var start: float = 0.4:
	set(value):
		start = value
		emit_changed()
## Where the branches end along the parent, 0 is its base and 1 its tip.
@export_range(0.0, 1.0) var end: float = 0.9:
	set(value):
		end = value
		emit_changed()
## Angle between the branches and their parent, in degrees. 0 grows them along the parent, 90 perpendicular.
@export_range(0.0, 90.0, 0.5, "or_greater") var angle: float = 50.0:
	set(value):
		angle = value
		emit_changed()
## Length of the branches, as a fraction of their parent's length.
@export_range(0.05, 1.0) var length: float = 0.4:
	set(value):
		length = value
		emit_changed()
## Multiplies [member length] by the curve value where each branch grows on the parent (0 base, 1 tip). [br][br]
## For example, a curve going down makes a conical, pine-like shape. Branches where it's 0 aren't grown.
@export var length_curve: Curve:
	set(value):
		if length_curve != null:
			length_curve.changed.disconnect(emit_changed)
		length_curve = value
		if length_curve != null:
			length_curve.changed.connect(emit_changed)
		emit_changed()
## Radius of the branches at their base, as a fraction of the parent radius where they grow. [br][br]
## Branches taper to 20% of it at the tip. Terminal branches keep the parent radius instead.
@export_range(0.05, 0.8, 0.05) var radius: float = 0.6:
	set(value):
		radius = value
		emit_changed()
## Segments per branch. More segments make smoother bends with [member gnarl] and [member up_force]. [br][br]
## With Multiple Convex collision, each segment is a collision shape.
@export_range(1, 8) var segments: int = 3:
	set(value):
		segments = value
		emit_changed()
## Random bending of the branches. 0 keeps them straight.
@export_range(0.0, 2.0, 0.01, "or_greater") var gnarl: float = 0.3:
	set(value):
		gnarl = value
		emit_changed()
## Bends the branches up when positive, or down when negative, like a willow. [br][br]
## Broken branches always bend down. See [member broken_chance].
@export_range(-4.0, 4.0, 0.01, "or_greater", "or_less") var up_force: float = 0.5:
	set(value):
		up_force = value
		emit_changed()
## Chance for each branch to be broken: shorter, bent down, and without child branches or foliage.
@export_range(0.0, 1.0) var broken_chance: float = 0.0:
	set(value):
		broken_chance = value
		emit_changed()
