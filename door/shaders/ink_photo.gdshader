shader_type canvas_item;

uniform vec3 ink : source_color = vec3(0.835, 0.878, 0.839);
uniform vec3 marker : source_color = vec3(0.753, 0.271, 0.220);

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
