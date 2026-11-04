shader_type canvas_item;
// The mortar bed: dark between freshly laid stones, so they look loose, and pale grout wherever the sponge has wiped.
// state.r is how much grout an area has.

uniform sampler2D state : filter_linear;
uniform vec4 grout : source_color = vec4(0.84, 0.8, 0.72, 1.0);

void fragment() {
	vec4 bed = texture(TEXTURE, UV);
	float g = smoothstep(0.2, 0.8, texture(state, UV).r);
	vec3 bare = bed.rgb * 0.62;
	COLOR = vec4(mix(bare, grout.rgb * (0.95 + (bed.r - 0.6) * 1.2), g), 1.0);
}
