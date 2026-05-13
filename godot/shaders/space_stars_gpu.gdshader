shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 camera_position = vec2(0.0, 0.0);
uniform float camera_rotation = 0.0;
uniform float visual_zoom = 1.0;
uniform float star_size_zoom = 1.0;
uniform vec2 screen_center = vec2(0.0, 0.0);

uniform float star_reveal = 0.0;
uniform float zoom_out_brightness = 1.0;

uniform bool animation_enabled = false;
uniform float time_seconds = 0.0;

varying float final_alpha;

void vertex() {
	vec2 world_pos = INSTANCE_CUSTOM.xy;
	float parallax = INSTANCE_CUSTOM.z;
	float base_star_size = INSTANCE_CUSTOM.w;

	float base_alpha = COLOR.r;
	float drift = mix(-2.0, 2.0, COLOR.g);
	float pulse_speed = mix(0.75, 1.7, COLOR.b);
	float phase = COLOR.a * 6.28318530718;

	vec2 animated_world_pos = world_pos;

	if (animation_enabled) {
		animated_world_pos.x += sin(time_seconds + phase) * drift;
	}

	// Correct direction: same behavior as the old CPU version.
	vec2 local = (animated_world_pos - camera_position) * parallax;

	// Rotate the star field positions, but NOT the star quads themselves.
	// This gives navigation rotation without tilted/squashed stars.
	float c = cos(camera_rotation);
	float s = sin(camera_rotation);

	vec2 rotated = vec2(
		local.x * c - local.y * s,
		local.x * s + local.y * c
	);

	float star_size = base_star_size * star_size_zoom;
	vec2 quad_offset = (UV - vec2(0.5, 0.5)) * star_size;

	VERTEX = screen_center + rotated * visual_zoom + quad_offset;

	float pulse = 1.0;

	if (animation_enabled) {
		pulse = sin(time_seconds * pulse_speed + phase) * 0.16 + 0.84;
	}

	final_alpha = clamp(base_alpha * pulse * star_reveal * zoom_out_brightness, 0.0, 1.0);
}

void fragment() {
	COLOR = vec4(1.0, 1.0, 1.0, final_alpha);
}