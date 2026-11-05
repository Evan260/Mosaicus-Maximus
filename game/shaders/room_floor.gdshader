shader_type canvas_item;
// A finished floor laid into a client's room in perspective: each pixel finds its point on the flat floor picture.

uniform sampler2D floor_tex : filter_linear;
uniform vec3 row0;
uniform vec3 row1;
uniform vec3 row2;

varying vec2 local;
varying vec4 modulate;

void vertex() {
	local = VERTEX;
	modulate = COLOR;
}

void fragment() {
	vec3 p = vec3(local, 1.0);
	vec2 uv = vec2(dot(row0, p), dot(row1, p)) / dot(row2, p);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		discard;
	}
	vec4 c = texture(floor_tex, uv);
	// The back of the room and the foot of each wall are a little darker, as the room's own floor would be.
	float edge = min(min(uv.x, 1.0 - uv.x), uv.y);
	float light = mix(0.8, 1.0, uv.y) * (0.8 + 0.2 * smoothstep(0.0, 0.08, edge));
	COLOR = vec4(c.rgb * light * vec3(1.0, 0.97, 0.92), c.a) * modulate;
}
