# Copyright © 2026 CosmonautFrog - MIT License

extends RefCounted
## Grows child branches out of a parent Branch.

const Branch := preload("./branch.gd")

## PI * (3 - sqrt(5)), ~137.5° - https://en.wikipedia.org/wiki/Golden_angle
const GOLDEN_ANGLE: float = 2.399963229728653


static func _grow_branch(
	level: CosmoBranchLevel,
	rng: RandomNumberGenerator,
	origin: Vector3,
	dir: Vector3,
	r0: float,
	step: float
) -> Branch:
	var branch := Branch.new()

	var is_broken: bool = rng.randf() < level.broken_chance
	branch.is_broken = is_broken

	var pos := origin
	var segment_count := maxi(level.segments, 1)
	var extent := rng.randf_range(0.33, 0.66) if is_broken else 1.0
	var length: float = maxf(step, 0.01) * extent
	var up_force: float = -absf(level.up_force) if is_broken else level.up_force

	for i in segment_count + 1:
		var progress := float(i) / segment_count * extent
		var radius := lerpf(r0, r0 * 0.2, progress)
		branch.add_point(pos, radius)
		var random := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		dir = (dir + (Vector3.UP * up_force + random * level.gnarl) / segment_count).normalized()
		pos += dir * length

	return branch


static func grow_branches(parent: Branch, level: CosmoBranchLevel) -> Array[Branch]:
	var branches: Array[Branch] = []
	if parent.is_broken:
		return branches

	var step := parent.get_length() * level.length / level.segments

	for k in level.count:
		var branch_seed := hash([parent.branch_seed, k])
		var rng := RandomNumberGenerator.new()
		rng.seed = branch_seed

		var t := lerpf(level.start, level.end, (k + rng.randf()) / level.count)
		var origin := parent.sample(t)
		var tangent := parent.tangent_at(t)
		var parent_radius := parent.radius_at(t)

		var helper := Vector3.RIGHT if absf(tangent.y) > 0.9 else Vector3.UP
		var azimuth := k * GOLDEN_ANGLE + rng.randf_range(-0.3, 0.3)
		var side := tangent.cross(helper).normalized().rotated(tangent, azimuth)
		var tilt := deg_to_rad(level.angle)
		var dir := tangent * cos(tilt) + side * sin(tilt)
		var r0 := parent_radius * minf(level.radius, 0.8)

		var branch_step := step
		if level.length_curve != null and level.length_curve.point_count > 0:
			branch_step *= level.length_curve.sample(t)
		if branch_step <= 0.0:
			continue

		var branch := _grow_branch(level, rng, origin, dir, r0, branch_step)
		branch.branch_seed = branch_seed
		branch.level = parent.level + 1
		branches.append(branch)

	# terminal branch, continues the parent from the tip, same direction and radius
	if level.terminal:
		var branch_seed := hash([parent.branch_seed, "terminal"])
		var rng := RandomNumberGenerator.new()
		rng.seed = branch_seed

		var terminal_step := step
		if level.length_curve != null and level.length_curve.point_count > 0:
			terminal_step *= level.length_curve.sample(1.0)

		var terminal := _grow_branch(
			level,
			rng,
			parent.tip(),
			parent.tangent_at(1.0),
			parent.radius_at(1.0),
			terminal_step
		)
		terminal.branch_seed = branch_seed
		terminal.level = parent.level + 1
		terminal.is_terminal = true
		parent.terminal = terminal
		branches.append(terminal)

	return branches
