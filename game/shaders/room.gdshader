shader_type canvas_item;
// The workshop's painted room and the pieces in it, lit by the hour and the lamps; painted sunlight fades at night.
// A piece reads the room's sunlight map, and its light, at its own place in the room.

#include "res://shaders/workshop_light.gdshaderinc"

uniform sampler2D sun : filter_nearest;
uniform float night = 0.0;
uniform vec2 sun_origin = vec2(0.0);
uniform vec2 sun_span = vec2(1.0);

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 room_uv = sun_origin + UV * sun_span;
	vec4 c = texture(TEXTURE, UV) * modulate;
	vec4 map = texture(sun, room_uv);
	c.rgb *= (1.0 - map.r * night * 0.4) * workshop_light(room_uv, map.g);
	COLOR = c;
}
