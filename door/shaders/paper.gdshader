shader_type canvas_item;

uniform vec3 paper_light : source_color = vec3(0.851, 0.867, 0.824);
uniform vec3 paper_shade : source_color = vec3(0.812, 0.835, 0.784);
uniform vec3 ink : source_color = vec3(0.122, 0.290, 0.259);
uniform vec3 flashlight : source_color = vec3(0.72, 0.52, 0.28);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
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

	float grain = hash21(floor(p * 0.85));
	float fiber = hash21(vec2(floor(p.y * 2.4), floor(p.x * 0.15)));
	fiber = smoothstep(0.62, 0.96, fiber);
	float wave = sin(p.y * 0.028 + sin(p.x * 0.007) * 2.6);
	float damp = smoothstep(-0.2, 0.85, wave);

	vec3 col = mix(paper_shade, paper_light, 0.35 + 0.4 * damp);
	col *= 0.94 + 0.08 * grain;
	col = mix(col, col * vec3(0.9, 0.93, 0.86), fiber * 0.35);
	col = mix(col, col * vec3(0.86, 0.88, 0.78), damp * 0.12);

	float stain = blob(uv, vec2(0.12, 0.86), vec2(1.1, 1.5), 0.16);
	stain += blob(uv, vec2(0.78, 0.18), vec2(1.4, 1.0), 0.11) * 0.7;
	stain += blob(uv, vec2(0.62, 0.72), vec2(1.8, 2.2), 0.07) * 0.45;
	col = mix(col, col * vec3(0.78, 0.74, 0.58), clamp(stain, 0.0, 1.0) * 0.45);

	float print = blob(uv, vec2(0.22, 0.42), vec2(2.4, 1.1), 0.09);
	print += blob(uv, vec2(0.84, 0.58), vec2(2.2, 1.2), 0.08) * 0.8;
	float print_grain = hash21(floor(p * 0.35));
	col = mix(col, col * vec3(0.82, 0.84, 0.76), print * print_grain * 0.28);

	float dent = smoothstep(0.86, 0.98, hash21(floor(p / 17.0)));
	col *= 1.0 - dent * 0.07;

	float minor = grid_line(p, 22.0);
	float major = grid_line(p, 88.0);
	float grid = max(minor * 0.55, major);
	col = mix(col, ink, grid * 0.16);

	vec2 q = uv * 2.0 - 1.0;
	float vig = smoothstep(0.2, 1.15, length(q * vec2(0.72, 1.05)));
	col = mix(col, col * flashlight, vig * 0.55);
	col *= mix(1.0, 0.72, vig);

	COLOR = vec4(col, 1.0);
}
