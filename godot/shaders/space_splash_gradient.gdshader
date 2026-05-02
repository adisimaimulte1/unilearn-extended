shader_type canvas_item;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.45;

uniform vec4 color_a : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.018, 0.028, 0.095, 1.0);
uniform vec4 color_c : source_color = vec4(0.14, 0.07, 0.24, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;

	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p *= 2.05;
		amplitude *= 0.5;
	}

	return value;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.08;

	vec2 drift = vec2(
		sin(TIME * 0.05) * 0.25,
		cos(TIME * 0.04) * 0.18
	);

	float clouds_a = fbm(uv * 3.0 + drift + vec2(t, -t * 0.6));
	float clouds_b = fbm(uv * 7.0 - drift * 0.7 + vec2(-t * 0.8, t * 0.4));
	float clouds_c = fbm(uv * 13.0 + vec2(t * 0.35, t * 0.2));

	float clouds = clouds_a * 0.6 + clouds_b * 0.3 + clouds_c * 0.1;
	clouds = smoothstep(0.42, 0.82, clouds);

	float vertical = smoothstep(0.0, 1.0, uv.y);
	vec4 gradient = mix(color_a, color_b, vertical);

	vec3 nebula_color = mix(color_b.rgb, color_c.rgb, clouds);
	vec3 final_color = mix(gradient.rgb, nebula_color, clouds * wave_strength);

	COLOR = vec4(final_color, reveal);
}