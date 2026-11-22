shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float alpha_scissor_threshold = 0.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform bool triplanar = false;
uniform float triplanar_sharpness = 1.0;
uniform float ao_strength = 0.0;
uniform bool is_foliage = false;
uniform vec3 normal_sign = vec3(1.0);
uniform int output = 0;

varying vec3 local_position;
varying vec3 local_normal;

vec4 sample_uv(vec2 uv) {
	vec2 tex_size = vec2(textureSize(albedo_texture, 0));
	vec2 texel = uv * tex_size;
	float mip = 0.5 * log2(max(dot(dFdx(texel), dFdx(texel)), dot(dFdy(texel), dFdy(texel))));
	return textureLod(albedo_texture, uv, clamp(mip, 0.0, log2(min(tex_size.x, tex_size.y)) - 3.0));
}

vec4 sample_triplanar() {
	vec3 w = pow(abs(local_normal), vec3(triplanar_sharpness));
	w /= dot(w, vec3(1.0));
	vec3 p = (local_position * uv_scale + uv_offset) * vec3(1.0, -1.0, 1.0);
	return texture(albedo_texture, p.xy) * w.z
		+ texture(albedo_texture, p.xz) * w.y
		+ texture(albedo_texture, p.zy * vec2(-1.0, 1.0)) * w.x;
}

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec4 tex = triplanar ? sample_triplanar() : sample_uv(UV * uv_scale.xy + uv_offset.xy);
	if (albedo.a * tex.a < alpha_scissor_threshold) {
		discard;
	}
	if (output == 2) {
		ALBEDO = vec3(is_foliage ? 1.0 : 0.0);
	} else if (output == 1) {
		ALBEDO = normalize(FRONT_FACING ? NORMAL : -NORMAL) * normal_sign * 0.5 + 0.5;
	} else {
		ALBEDO = albedo.rgb * tex.rgb * mix(1.0, COLOR.r, ao_strength);
	}
}