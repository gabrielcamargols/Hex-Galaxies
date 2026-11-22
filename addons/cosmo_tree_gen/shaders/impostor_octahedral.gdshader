/*
Octahedral impostor shader from godot-imposter by Zhang Juntao (Godot 4 port):
https://github.com/zhangjt93/godot-imposter
Based on Godot-Octahedral-Impostors by wojtekpil:
https://github.com/wojtekpil/Godot-Octahedral-Impostors
Modified and optimized for Cosmo Tree Gen, only using hemi octahedron.

MIT License

Copyright (c) 2023 Zhang Juntao
Copyright (c) 2020 wojtekpil, K. S. Ernest (iFire) Lee

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_disable;
uniform vec2 impostor_frames = vec2(12.0);
uniform float scale = 1.0;
uniform vec3 position_offset = vec3(0.0);
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;
uniform bool dither = false;
uniform vec3 backlight : source_color = vec3(0.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.2;

const float BAYER_4X4[16] = float[](
	0.0625, 0.5625, 0.1875, 0.6875,
	0.8125, 0.3125, 0.9375, 0.4375,
	0.25, 0.75, 0.125, 0.625,
	1.0, 0.5, 0.875, 0.375
);

varying vec2 uv_a;
varying vec2 uv_b;
varying vec2 uv_c;
varying flat vec2 frame_a;
varying flat vec2 frame_b;
varying flat vec2 frame_c;
varying flat vec3 normal_a;
varying flat vec3 normal_b;
varying flat vec3 normal_c;
varying flat vec3 weights;

vec2 hemi_octahedron_grid(vec3 direction) {
	direction.y = max(direction.y, 0.001);
	direction = normalize(direction);
	vec3 octahedron = direction / dot(direction, sign(direction));
	return vec2(octahedron.x + octahedron.z, octahedron.z - octahedron.x);
}

vec3 hemi_octahedron(vec2 coord) {
	vec3 direction = vec3(coord.x - coord.y, 0.0, -1.0 + coord.x + coord.y);
	direction.y = 1.0 - abs(direction.x) - abs(direction.z);
	return normalize(direction);
}

vec2 frame_uv(vec3 frame_direction, vec3 pivot_to_camera, vec3 vertex_to_camera) {
	vec3 up = abs(frame_direction.y) > 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	vec3 plane_x = normalize(cross(frame_direction, up));
	vec3 plane_y = normalize(cross(plane_x, frame_direction));
	float t = dot(frame_direction, pivot_to_camera) / dot(frame_direction, vertex_to_camera);
	vec3 offset = vertex_to_camera * t - pivot_to_camera;
	return vec2(dot(plane_x, offset), dot(plane_y, offset)) / (2.0 * scale) + 0.5;
}

void vertex() {
	vec2 frames_minus_one = impostor_frames - 1.0;
	vec3 camera = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz;
	vec3 pivot_to_camera = camera * 10.0;
	vec3 view_direction = normalize(camera);

	vec2 grid = clamp((hemi_octahedron_grid(view_direction) + 1.0) * 0.5, 0.0, 1.0) * frames_minus_one;
	vec2 grid_fract = fract(grid);
	frame_a = floor(grid);
	frame_b = clamp(
		frame_a + (grid_fract.x > grid_fract.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0)),
		vec2(0.0), frames_minus_one
	);
	frame_c = min(frame_a + 1.0, frames_minus_one);
	weights = vec3(
		min(1.0 - grid_fract.x, 1.0 - grid_fract.y),
		abs(grid_fract.x - grid_fract.y),
		min(grid_fract.x, grid_fract.y)
	);

	vec3 direction_a = hemi_octahedron(frame_a / frames_minus_one);
	vec3 direction_b = hemi_octahedron(frame_b / frames_minus_one);
	vec3 direction_c = hemi_octahedron(frame_c / frames_minus_one);
	normal_a = (MODELVIEW_MATRIX * vec4(direction_a, 0.0)).xyz;
	normal_b = (MODELVIEW_MATRIX * vec4(direction_b, 0.0)).xyz;
	normal_c = (MODELVIEW_MATRIX * vec4(direction_c, 0.0)).xyz;

	vec3 up = abs(view_direction.y) > 0.999 ? vec3(0.0, 0.0, -1.0) : vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, view_direction));
	vec3 down = normalize(cross(right, view_direction));
	vec2 corner = (UV * 2.0 - 1.0) * scale;
	vec3 offset = right * corner.x + down * corner.y;

	vec3 vertex_to_camera = pivot_to_camera - offset;
	uv_a = frame_uv(direction_a, pivot_to_camera, vertex_to_camera);
	uv_b = frame_uv(direction_b, pivot_to_camera, vertex_to_camera);
	uv_c = frame_uv(direction_c, pivot_to_camera, vertex_to_camera);

	VERTEX = offset + position_offset;
	NORMAL = view_direction;
	TANGENT = -right;
	BINORMAL = -down;
}

vec2 atlas_uv(vec2 uv, vec2 frame, vec2 frame_size) {
	return clamp(frame_size * (frame + clamp(uv, 0.0, 1.0)), 0.0, 1.0);
}

vec3 unpack_normal(vec4 tex, vec3 tangent, vec3 binormal, vec3 normal) {
	vec3 n = normalize(tex.xyz * 2.0 - 1.0);
	return normalize(tangent * n.x + binormal * n.y + normal * n.z);
}

void fragment() {
	vec2 frame_size = 1.0 / impostor_frames;
	vec2 atlas_a = atlas_uv(uv_a, frame_a, frame_size);
	vec2 atlas_b = atlas_uv(uv_b, frame_b, frame_size);
	vec2 atlas_c = atlas_uv(uv_c, frame_c, frame_size);

	vec4 color = texture(albedo_texture, atlas_a) * weights.x
		+ texture(albedo_texture, atlas_b) * weights.y
		+ texture(albedo_texture, atlas_c) * weights.z;
	vec4 tex_a = texture(normal_texture, atlas_a);
	vec4 tex_b = texture(normal_texture, atlas_b);
	vec4 tex_c = texture(normal_texture, atlas_c);
	vec3 normal = unpack_normal(tex_a, TANGENT, BINORMAL, normal_a) * weights.x
		+ unpack_normal(tex_b, TANGENT, BINORMAL, normal_b) * weights.y
		+ unpack_normal(tex_c, TANGENT, BINORMAL, normal_c) * weights.z;

	ALBEDO = color.rgb;
	NORMAL = normalize(normal);
	BACKLIGHT = backlight * (tex_a.a * weights.x + tex_b.a * weights.y + tex_c.a * weights.z);
	ROUGHNESS = roughness;
	SPECULAR = specular;

	if (dither) {
		int index = int(FRAGCOORD.x) % 4 + int(FRAGCOORD.y) % 4 * 4;
		if (color.a < BAYER_4X4[index] * alpha_scissor_threshold) {
			discard;
		}
	} else {
		ALPHA = color.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	}
}
