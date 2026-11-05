shader_type canvas_item;
// The dusty film grout leaves over the stones, smeared in sponge swirls, until the cloth polishes it away.
// state.r is grout, state.g is polish.

uniform vec2 size_px = vec2(600.0, 420.0);

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

float grain(vec2 p) {
	return fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 s = texture(TEXTURE, UV).rg;
	float film = smoothstep(0.15, 0.85, s.r) * (1.0 - smoothstep(0.15, 0.85, s.g));
	vec2 p = UV * size_px;
	float swirl = 0.5 + 0.5 * sin(length(fract(p / 9.0) - 0.5) * 18.0 + grain(p / 9.0) * 6.28);
	float speck = grain(p * 1.5);
	COLOR = vec4(vec3(0.86, 0.82, 0.74) * (0.96 + 0.08 * speck), film * (0.42 + 0.12 * swirl + 0.06 * speck)) * modulate;
}
