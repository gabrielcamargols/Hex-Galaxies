# Copyright © 2026 CosmonautFrog - MIT License

extends RefCounted
## Trunk generator
## References:
## - EZ-Tree author: https://tympanus.net/codrops/2025/01/27/fractals-to-forests-creating-realistic-3d-trees-with-three-js/
## - Coding Train / Dan Shiffman: https://www.youtube.com/watch?v=MwLyeEWnMCY
## - https://algorithmicbotany.org/
## - https://en.wikipedia.org/wiki/L-system

const Branch := preload("./branch.gd")

const BASE_RADIAL_SEGMENTS: int = 6
const BASE_HEIGHT_SEGMENTS: int = 3
const FLARE_RINGS: int = 4


static func generate_trunks(noise_seed: int, params: CosmoTrunkParams) -> Array[Branch]:
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	var start_angle := rng.randf() * TAU

	var quality := maxi(params.quality, 1)
	var rings := BASE_HEIGHT_SEGMENTS * quality

	var noise := FastNoiseLite.new()
	noise.frequency = 0.5

	var trunks: Array[Branch] = []

	for k in params.amount:
		var trunk := Branch.new()
		trunk.branch_seed = noise_seed + k
		noise.seed = trunk.branch_seed
		var jitter := rng.randf_range(-0.25, 0.25) if k > 0 else 0.0
		var angle := start_angle + TAU * (k + jitter) / params.amount
		var base := params.get_base_offset(angle)
		var lean_vec := params.get_lean_vec(angle)

		for i in rings + 1:
			var t := float(i) / rings
			var center := base + Vector3(lean_vec.x * t * t, params.height * t, lean_vec.z * t * t)
			var w := params.wobble * sin(PI * t)
			center.x += w * noise.get_noise_1d(t * params.height)
			center.z += w * noise.get_noise_1d(t * params.height + 100.0)
			trunk.add_point(center, lerpf(params.radius_bottom, params.radius_top, t))

		trunk.base_rings = FLARE_RINGS if params.flare > 0.0 else 0
		trunk.sink_depth = params.sink_depth
		trunks.append(trunk)

	return trunks


static func flare_base(
	vertices: PackedVector3Array,
	first: int,
	trunk: Branch,
	params: CosmoTrunkParams,
) -> void:
	if params.flare <= 0.0:
		return

	var noise := FastNoiseLite.new()
	noise.seed = trunk.branch_seed
	noise.frequency = 1.0
	var reach := params.height * params.flare_height
	var center := trunk.points[0]

	for i in range(first, vertices.size()):
		var s := minf(1.0 - vertices[i].y / reach, 1.0)
		if s <= 0.0:
			continue

		var offset := Vector2(vertices[i].x - center.x, vertices[i].z - center.z)
		# sampled on a unit circle so it wraps around the trunk without a seam
		var lobe := noise.get_noise_2dv(offset.normalized())
		var grow := 1.0 + params.flare * s * s * s * (1.0 + 2.0 * params.flare_lobes * lobe)
		vertices[i].x = center.x + offset.x * grow
		vertices[i].z = center.z + offset.y * grow
