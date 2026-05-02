shader_type canvas_item;

uniform vec4 circle_color : source_color = vec4(1.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float d = length(centered);
	float alpha = smoothstep(0.5, 0.47, d);

	COLOR = vec4(circle_color.rgb, circle_color.a * alpha) * COLOR;
}