shader_type canvas_item;

uniform vec3 paper_light : source_color = vec3(0.102, 0.129, 0.118);
uniform vec3 paper_shade : source_color = vec3(0.071, 0.094, 0.086);
uniform vec3 ink : source_color = vec3(0.835, 0.878, 0.839);
uniform vec3 flashlight : source_color = vec3(0.72, 0.52, 0.28);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float grid_line(vec2 p, float step) {
	vec2 g = abs(fract(p / step) - 0.5);
	float d = min(g.x, g.y) * step;
	return 1.0 - smoothstep(0.35, 1.15, d);
}

float blob(vec2 uv, vec2 center, vec2 scale, float radius) {
	float d = length((uv - center) * scale);
	return smoothstep(radius, radius * 0.35, d);
}

void fragment() {
	vec2 p = FRAGCOORD.xy;
	vec2 uv = UV;

	float grain = vnoise(p * 0.35);
	float fiber = vnoise(vec2(p.x * 0.02, p.y * 0.55));
	float wave = sin(p.y * 0.028 + sin(p.x * 0.007) * 2.6);
	float damp = smoothstep(-0.15, 0.9, wave);

	vec3 col = mix(paper_shade, paper_light, 0.4 + 0.35 * damp);
	col *= 0.96 + 0.05 * grain;
	col = mix(col, col * vec3(0.93, 0.95, 0.9), fiber * 0.22);
	col = mix(col, col * vec3(0.9, 0.91, 0.84), damp * 0.08);

	float stain = blob(uv, vec2(0.14, 0.88), vec2(1.1, 1.45), 0.18);
	stain += blob(uv, vec2(0.8, 0.16), vec2(1.35, 1.05), 0.12) * 0.65;
	col = mix(col, col * vec3(0.84, 0.8, 0.68), clamp(stain, 0.0, 1.0) * 0.28);

	float print = blob(uv, vec2(0.24, 0.46), vec2(2.2, 1.15), 0.1);
	print += blob(uv, vec2(0.82, 0.6), vec2(2.0, 1.2), 0.09) * 0.7;
	col = mix(col, col * vec3(0.88, 0.9, 0.84), print * 0.16);

	float dent = vnoise(p * 0.08);
	col *= 1.0 - smoothstep(0.72, 0.95, dent) * 0.04;

	float minor = grid_line(p, 22.0);
	float major = grid_line(p, 88.0);
	float grid = max(minor * 0.5, major * 0.85);
	col = mix(col, ink, grid * 0.14);

	vec2 q = uv * 2.0 - 1.0;
	float vig = smoothstep(0.22, 1.15, length(q * vec2(0.72, 1.05)));
	col = mix(col, col * flashlight, vig * 0.5);
	col *= mix(1.0, 0.76, vig);

	COLOR = vec4(col, 1.0);
}
