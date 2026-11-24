shader_type canvas_item;

uniform float darkness : hint_range(0.0, 1.0) = 0.28;
uniform float blur_px : hint_range(0.0, 8.0) = 2.2;

void fragment() {
	vec2 px = vec2(blur_px) / vec2(textureSize(TEXTURE, 0));
	vec3 col = vec3(0.0);
	float weight = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			float w = 1.0 - 0.12 * float(abs(x) + abs(y));
			col += texture(TEXTURE, UV + px * vec2(float(x), float(y))).rgb * w;
			weight += w;
		}
	}
	col /= weight;
	vec2 q = UV * 2.0 - 1.0;
	float vig = smoothstep(0.15, 1.05, length(q * vec2(0.85, 1.05)));
	col *= mix(1.0, 0.2, vig);
	COLOR = vec4(col * darkness, 1.0);
}
