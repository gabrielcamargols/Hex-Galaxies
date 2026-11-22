# Copyright © 2026 CosmonautFrog - MIT License

@tool
extends RefCounted

const MeshUtils := preload("./mesh_utils.gd")
const Settings := preload("./settings.gd")
const TreeBuilder := preload("./tree_builder.gd")

const CAPTURE_SHADER := preload("../shaders/impostor_capture.gdshader")
const STATIC_SHADER := preload("../shaders/impostor_static.gdshader")
const OCTAHEDRAL_SHADER := preload("../shaders/impostor_octahedral.gdshader")

enum Type {
	NONE,
	STATIC,
	OCTAHEDRAL,
}

enum Output {
	ALBEDO,
	NORMAL,
	MASK,
}

const NODE_NAME: String = "Impostor_LOD3"
const PADDING_PX: int = 2
const PIXEL_ALIGNMENT: int = 4
const ALPHA_THRESHOLD: float = 0.5
const FLAT_NORMAL := Color(0.5, 0.5, 1.0, 0.0)
const OCTAHEDRAL_NORMAL_SIGN := Vector3(-1.0, 1.0, 1.0)


static func _create_capture_material(source: Material, is_foliage: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CAPTURE_SHADER
	mat.set_shader_parameter("albedo_texture", MeshUtils.get_albedo_texture(source))
	mat.set_shader_parameter("is_foliage", is_foliage)

	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		mat.set_shader_parameter("albedo", base.albedo_color)
		mat.set_shader_parameter("uv_scale", base.uv1_scale)
		mat.set_shader_parameter("uv_offset", base.uv1_offset)
		mat.set_shader_parameter("triplanar", base.uv1_triplanar)
		mat.set_shader_parameter("triplanar_sharpness", base.uv1_triplanar_sharpness)
		if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			mat.set_shader_parameter("alpha_scissor_threshold", base.alpha_scissor_threshold)
	elif source is ShaderMaterial:
		var shader_mat := source as ShaderMaterial
		mat.set_shader_parameter("albedo", _get_shader_param(shader_mat, &"albedo", Color.WHITE))
		mat.set_shader_parameter(
			"alpha_scissor_threshold", _get_shader_param(shader_mat, &"alpha_scissor_threshold", 0.5)
		)
		mat.set_shader_parameter("ao_strength", _get_shader_param(shader_mat, &"ao_light_affect", 0.0))

	return mat


static func _get_shader_param(
	material: ShaderMaterial, param: StringName, fallback: Variant,
) -> Variant:
	var value: Variant = material.get_shader_parameter(param)
	if value == null:
		value = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), param)
	return fallback if value == null else value


static func _average_color(image: Image) -> Color:
	var small := image.duplicate() as Image
	small.generate_mipmaps()
	var c := small.get_data().slice(-4)
	return Color(c[0], c[1], c[2], 0.0) / maxf(c[3], 1.0)


static func _fill_transparent(image: Image, color: Color) -> Image:
	var out := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(color)
	out.blit_rect_mask(image, image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	out.fix_alpha_edges()
	return out


static func _write_alpha(image: Image, mask: Image) -> void:
	var data := image.get_data()
	var src := mask.get_data()
	for i in range(3, data.size(), 4):
		data[i] = src[i - 3] if src[i] > 0 else 255

	image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, data)


static func _preserve_coverage(image: Image) -> void:
	var data := image.get_data()
	var cutoff := roundi(ALPHA_THRESHOLD * 255.0)
	var target: float = 0.0
	var mm_count := image.get_mipmap_count()

	for level in image.get_mipmap_count() + 1:
		var start := image.get_mipmap_offset(level)
		var end := image.get_mipmap_offset(level + 1) if level < mm_count else data.size()
		var count := (end - start) / 4.0
		var histogram := PackedInt32Array()
		histogram.resize(256)
		for i in range(start + 3, end, 4):
			histogram[data[i]] += 1

		if level == 0:
			for value in range(cutoff, 256):
				target += histogram[value] / count
			continue

		var alpha: int = 255
		var covered := histogram[alpha]
		while alpha > 1 and covered < target * count:
			alpha -= 1
			covered += histogram[alpha]

		var scale := float(cutoff) / alpha
		for i in range(start + 3, end, 4):
			data[i] = mini(roundi(data[i] * scale), 255)

	var w := image.get_width()
	var h := image.get_height()
	image.set_data(w, h, true, Image.FORMAT_RGBA8, data)


static func _create_texture(image: Image) -> PortableCompressedTexture2D:
	var texture := PortableCompressedTexture2D.new()
	# without keep_compressed_buffer set,
	# PortableCompressedTexture2D would save without data
	texture.keep_compressed_buffer = true
	texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_BASIS_UNIVERSAL)
	return texture


static func _create_textures(albedo: Image, normal: Image, mask: Image) -> Array[PortableCompressedTexture2D]:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		normal.srgb_to_linear()
	normal = _fill_transparent(normal, FLAT_NORMAL)
	_write_alpha(normal, mask)
	normal.generate_mipmaps()

	albedo = _fill_transparent(albedo, _average_color(albedo))
	albedo.generate_mipmaps()
	_preserve_coverage(albedo)

	return [_create_texture(albedo), _create_texture(normal)]


static func _get_bounds(sources: Array[MeshInstance3D]) -> AABB:
	var bounds := AABB()
	for mi: MeshInstance3D in sources:
		bounds = bounds.merge(mi.get_aabb())
	return bounds


static func _add_sources(
	parent: Node, sources: Array[MeshInstance3D], normal_sign: Vector3,
) -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	for src: MeshInstance3D in sources:
		var mesh := src.mesh as ArrayMesh
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		for s in mesh.get_surface_count():
			var is_foliage := mesh.surface_get_name(s) == TreeBuilder.FOLIAGE_SURFACE_NAME
			var mat := _create_capture_material(src.get_active_material(s), is_foliage)
			mat.set_shader_parameter("normal_sign", normal_sign)
			mi.set_surface_override_material(s, mat)
			materials.append(mat)
		parent.add_child(mi)
	return materials


static func _create_viewport(
	size: Vector2i, camera_size: float, camera_far: float, camera_transform: Transform3D,
) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.far = camera_far
	camera.transform = camera_transform

	viewport.add_child(camera)
	return viewport


static func _capture(viewports: Array[SubViewport], materials: Array[ShaderMaterial]) -> Array[Array]:
	var root := (Engine.get_main_loop() as SceneTree).root
	for viewport in viewports:
		root.add_child(viewport)

	var images: Array[Array] = []
	for output: Output in Output.values():
		for mat in materials:
			mat.set_shader_parameter("output", output)
		for viewport in viewports:
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var pass_images: Array[Image] = []
		for viewport in viewports:
			pass_images.append(viewport.get_texture().get_image())
		images.append(pass_images)

	for viewport in viewports:
		viewport.queue_free()
	return images


static func _get_backlight(tree: CosmoTreeGen) -> Color:
	if tree.foliage_material is ShaderMaterial:
		return _get_shader_param(tree.foliage_material as ShaderMaterial, &"backlight", Color.BLACK)
	return Color.BLACK


static func _get_specular(tree: CosmoTreeGen) -> float:
	if tree.foliage_material is ShaderMaterial:
		return _get_shader_param(tree.foliage_material as ShaderMaterial, &"specular", 0.2)
	if tree.foliage_material is BaseMaterial3D:
		return (tree.foliage_material as BaseMaterial3D).metallic_specular
	return 0.5


static func _hemi_octahedron(coord: Vector2) -> Vector3:
	var x := coord.x - coord.y
	var z := coord.x + coord.y - 1.0
	return Vector3(x, 1.0 - absf(x) - absf(z), z).normalized()


static func _bake_static(tree: CosmoTreeGen) -> QuadMesh:
	var sources := tree.get_meshes(0)
	var bounds := _get_bounds(sources)

	var resolution: int = Settings.get_setting(Settings.IMPOSTOR_STATIC_RESOLUTION, 512)
	var half_width := maxf(-bounds.position.x, bounds.end.x)
	var depth := maxf(-bounds.position.z, bounds.end.z)
	var texel := maxf(2.0 * half_width, bounds.size.y) / (resolution - 2 * PADDING_PX)

	var content_size := Vector2(2.0 * half_width, bounds.size.y)
	var content_pixels := content_size / texel
	var padding_pixels := Vector2.ONE * (2.0 * PADDING_PX)
	var required_pixels := content_pixels + padding_pixels
	var aligned_pixels := (required_pixels / PIXEL_ALIGNMENT).ceil() * PIXEL_ALIGNMENT
	var pixels := Vector2i(aligned_pixels)

	var size := Vector2(pixels) * texel
	var center := Vector3(0.0, bounds.get_center().y, 0.0)

	var camera_transform := Transform3D(Basis(), center + Vector3(0.0, 0.0, depth + 1.0))
	var viewport := _create_viewport(pixels, size.y, 2.0 * depth + 2.0, camera_transform)
	viewport.own_world_3d = true

	var materials := _add_sources(viewport, sources, Vector3.ONE)
	var images := await _capture([viewport], materials)
	var albedo: Image = images[Output.ALBEDO][0]
	var normal: Image = images[Output.NORMAL][0]
	var mask: Image = images[Output.MASK][0]
	var textures := _create_textures(albedo, normal, mask)

	var material := ShaderMaterial.new()
	material.shader = STATIC_SHADER
	material.set_shader_parameter("albedo_texture", textures[0])
	material.set_shader_parameter("normal_texture", textures[1])
	material.set_shader_parameter("backlight", _get_backlight(tree))
	material.set_shader_parameter("specular", _get_specular(tree))

	var quad := QuadMesh.new()
	quad.size = size
	quad.center_offset = center
	quad.material = material
	return quad


static func _bake_octahedral(tree: CosmoTreeGen) -> QuadMesh:
	var sources := tree.get_meshes(0)
	var center := Vector3(0.0, _get_bounds(sources).get_center().y, 0.0)
	var radius := 0.0
	for mi: MeshInstance3D in sources:
		for s in mi.mesh.get_surface_count():
			var vertices: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				radius = maxf(radius, vertex.distance_squared_to(center))
	radius = sqrt(radius)

	var frames: int = Settings.get_setting(Settings.IMPOSTOR_OCTAHEDRAL_FRAMES, 12)
	var resolution: int = Settings.get_setting(Settings.IMPOSTOR_OCTAHEDRAL_RESOLUTION, 1024)
	var frame_pixels := floori(float(resolution) / frames / PIXEL_ALIGNMENT) * PIXEL_ALIGNMENT
	var scale := radius * frame_pixels / (frame_pixels - 2 * PADDING_PX)

	var world := World3D.new()
	var viewports: Array[SubViewport] = []
	for y in frames:
		for x in frames:
			var direction := _hemi_octahedron(Vector2(x, y) / (frames - 1))
			var up := Vector3.BACK if absf(direction.y) > 0.999 else Vector3.UP
			var camera_transform := Transform3D(Basis.looking_at(-direction, up), center + direction * (scale + 1.0))
			var viewport := _create_viewport(Vector2i.ONE * frame_pixels, 2.0 * scale, 2.0 * scale + 2.0, camera_transform)
			viewport.world_3d = world
			viewports.append(viewport)

	var materials := _add_sources(viewports[0], sources, OCTAHEDRAL_NORMAL_SIGN)
	var images := await _capture(viewports, materials)

	var atlases: Array[Image] = []
	for pass_images: Array in images:
		var atlas := Image.create_empty(frames * frame_pixels, frames * frame_pixels, false, Image.FORMAT_RGBA8)
		for y in frames:
			for x in frames:
				var frame: Image = pass_images[y * frames + x]
				atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(x, y) * frame_pixels)
		atlases.append(atlas)
	var textures := _create_textures(atlases[Output.ALBEDO], atlases[Output.NORMAL], atlases[Output.MASK])

	var material := ShaderMaterial.new()
	material.shader = OCTAHEDRAL_SHADER
	material.set_shader_parameter("albedo_texture", textures[0])
	material.set_shader_parameter("normal_texture", textures[1])
	material.set_shader_parameter("impostor_frames", Vector2(frames, frames))
	material.set_shader_parameter("scale", scale)
	material.set_shader_parameter("position_offset", center)
	material.set_shader_parameter("backlight", _get_backlight(tree))
	material.set_shader_parameter("specular", _get_specular(tree))

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 2.0 * scale
	quad.center_offset = center
	quad.material = material
	return quad


static func bake(tree: CosmoTreeGen, type: Type) -> MeshInstance3D:
	var impostor := MeshInstance3D.new()
	impostor.name = NODE_NAME

	match type:
		Type.NONE: return null
		Type.STATIC: impostor.mesh = await _bake_static(tree)
		Type.OCTAHEDRAL: impostor.mesh = await _bake_octahedral(tree)

	return impostor
