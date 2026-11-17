shader_type canvas_item;

uniform vec3 ink : source_color = vec3(0.122, 0.290, 0.259);
uniform vec3 marker : source_color = vec3(0.890, 0.757, 0.231);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float red = tex.r - max(tex.g, tex.b);
	float mark = smoothstep(0.06, 0.28, red);
	float drawn = 1.0 - smoothstep(0.48, 0.9, luma);
	float alpha = clamp(max(drawn, mark * 0.95), 0.0, 1.0);
	vec3 col = mix(ink, marker, mark);
	COLOR = vec4(col, alpha * tex.a);
}
