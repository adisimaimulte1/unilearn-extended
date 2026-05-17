shader_type canvas_item;
render_mode unshaded;

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color_a : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.008, 0.018, 0.055, 1.0);
uniform vec4 color_c : source_color = vec4(0.025, 0.045, 0.11, 1.0);

void fragment() {
	vec2 uv = UV;

	float vertical = smoothstep(0.18, 1.0, uv.y);

	float radial = 1.0 - distance(uv, vec2(0.5, 0.42));
	radial = smoothstep(0.28, 1.0, radial);

	vec3 base = mix(color_a.rgb, color_b.rgb, vertical);
	vec3 glow = mix(base, color_c.rgb, radial * 0.20);

	COLOR = vec4(glow, reveal);
}