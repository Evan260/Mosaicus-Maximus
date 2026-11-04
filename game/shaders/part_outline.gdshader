shader_type canvas_item;
// Draws only the inner edge of a part on the plan, so the part being coloured shows without hiding its colour.

uniform vec4 colour : source_color = vec4(1.0, 0.84, 0.3, 1.0);
uniform float width = 1.0;
uniform float strength = 1.0;

void fragment() {
	float here = texture(TEXTURE, UV).a;
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float gap = 0.0;
	gap = max(gap, 1.0 - texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	gap = max(gap, 1.0 - texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	gap = max(gap, 1.0 - texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	gap = max(gap, 1.0 - texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	COLOR = vec4(colour.rgb, step(0.5, here) * step(0.5, gap) * colour.a * strength);
}
