shader_type canvas_item;
render_mode blend_add;
// Slow bands of light drifting across polished stone.

uniform float now = 0.0;
uniform vec2 size_px = vec2(600.0, 420.0);

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	float g = smoothstep(0.3, 0.9, texture(TEXTURE, UV).g);
	vec2 p = UV * size_px;
	float band = pow(max(0.0, sin((p.x * 0.7 + p.y) * 0.025 - now * 0.9)), 18.0);
	COLOR = vec4(vec3(1.0, 0.96, 0.86) * (band * 0.12 + 0.02) * g, 1.0) * modulate;
}
