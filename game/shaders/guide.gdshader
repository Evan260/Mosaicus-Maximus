shader_type canvas_item;
// Shows where the stone being laid goes: its areas glow faintly in its colour, under the tiles.

uniform float chosen = -1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float now = 0.0;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	float label = texture(TEXTURE, UV).r * 255.0;
	float on = 1.0 - step(0.5, abs(label - chosen));
	COLOR = vec4(tint.rgb, on * (0.34 + 0.1 * sin(now * 3.0))) * modulate;
}
