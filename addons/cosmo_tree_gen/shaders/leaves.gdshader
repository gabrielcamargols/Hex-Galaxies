// Copyright © 2026 CosmonautFrog - MIT License

// Two sided leaf cards that keep the CosmoTreeGen canopy normals on both faces.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;
uniform vec3 backlight : source_color = vec3(0.45, 0.5, 0.25);
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.5;

uniform vec3 wind_direction = vec3(1.0, 0.0, 0.3);
uniform float wind_strength : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float wind_speed : hint_range(0.0, 10.0, 0.01) = 1.0;
uniform float wind_phase_scale : hint_range(0.0, 10.0, 0.01) = 2.0;

float wind_wave(float t, float phase) {
	return 0.5 * sin(t + phase) + 0.3 * sin(2.0 * t + 1.3 * phase) + 0.2 * sin(5.0 * t + 1.5 * phase);
}

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = dot(world_position, vec3(1.0, 0.7, 1.3)) * wind_phase_scale;
	float sway = (1.0 - UV.y) * wind_strength * wind_wave(TIME * wind_speed, phase);
	VERTEX += normalize(wind_direction * mat3(MODEL_MATRIX)) * sway;
}

void fragment() {
	vec2 tex_size = vec2(textureSize(albedo_texture, 0));
	vec2 texel = UV * tex_size;
	float mip = 0.5 * log2(max(dot(dFdx(texel), dFdx(texel)), dot(dFdy(texel), dFdy(texel))));
	vec4 tex = textureLod(albedo_texture, UV, clamp(mip, 0.0, log2(min(tex_size.x, tex_size.y)) - 3.0));

	ALBEDO = albedo.rgb * tex.rgb;
	ALPHA = albedo.a * tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	AO = COLOR.r;
	AO_LIGHT_AFFECT = ao_light_affect;
	BACKLIGHT = backlight;
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
