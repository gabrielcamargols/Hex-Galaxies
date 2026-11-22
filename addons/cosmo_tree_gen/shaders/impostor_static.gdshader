shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_disable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;
uniform vec3 backlight : source_color = vec3(0.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.2;

// copy of what Godot generates for BILLBOARD_FIXED_Y with keep scale
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), MAIN_CAM_INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(MAIN_CAM_INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 color = texture(albedo_texture, UV);
	vec4 normal_mask = texture(normal_texture, UV);
	vec3 n = normal_mask.rgb * 2.0 - 1.0;
	ALBEDO = color.rgb;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	NORMAL = normalize(TANGENT * n.x + BINORMAL * n.y + NORMAL * n.z);
	BACKLIGHT = backlight * normal_mask.a;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
