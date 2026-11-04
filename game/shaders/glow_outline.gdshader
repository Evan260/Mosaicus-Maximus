shader_type canvas_item;

#include "res://shaders/workshop_light.gdshaderinc"
// Lights a picture up when the mouse is over it: a little brighter, with a thin warm outline round its shape.
// Given a traced shape, the outline follows that, so shadows painted round a piece are left alone.

uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge : source_color = vec4(1.0, 0.86, 0.5, 1.0);
uniform bool use_shape = false;
uniform float outline = 1.0;
uniform sampler2D shape : filter_nearest;
// The room's sunlight map, read at this picture's place in the room, so painted sunlight fades at night.
uniform sampler2D sun : filter_nearest, hint_default_black;
uniform float night = 0.0;
uniform vec2 sun_origin = vec2(0.0);
uniform vec2 sun_span = vec2(1.0);

void fragment() {
	vec4 tint = COLOR;
	vec2 room_uv = sun_origin + UV * sun_span;
	vec4 map = texture(sun, room_uv);
	tint.rgb *= (1.0 - map.r * night * 0.4) * workshop_light(room_uv, map.g);
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float here = c.a;
	float near = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	if (use_shape) {
		here = texture(shape, UV).a;
		near = max(max(texture(shape, UV + vec2(px.x, 0.0)).a, texture(shape, UV - vec2(px.x, 0.0)).a),
			max(texture(shape, UV + vec2(0.0, px.y)).a, texture(shape, UV - vec2(0.0, px.y)).a));
	}
	if (here < 0.5) {
		float e = step(0.5, near) * glow * outline;
		COLOR = vec4(mix(c.rgb * tint.rgb, edge.rgb, e), max(c.a, e) * tint.a);
	} else {
		COLOR = vec4(mix(c.rgb, min(c.rgb * 1.18 + 0.03, vec3(1.0)), glow) * tint.rgb, c.a * tint.a);
	}
}
