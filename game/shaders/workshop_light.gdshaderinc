// The workshop's light, shared by every picture in the room: the hour's daylight, plus warm pools of light round
// each lit lamp, strongest at the flame and fading out over its reach.

uniform vec3 ambient : source_color = vec3(1.0);
uniform vec4 lamps[3];
uniform int lamp_count = 0;
uniform vec2 room_size = vec2(480.0, 272.0);
// Where the room's picture starts, measured from the painting's corner, which the lamps are placed from.
uniform vec2 room_origin = vec2(0.0);

vec3 workshop_light(vec2 room_uv, float outdoors) {
	vec2 at = room_origin + room_uv * room_size;
	vec3 lamp = vec3(0.0);
	for (int i = 0; i < lamp_count; i++) {
		float d = distance(at, lamps[i].xy) / lamps[i].z;
		lamp += vec3(1.0, 0.74, 0.46) * lamps[i].w * pow(clamp(1.0 - d, 0.0, 1.0), 1.25);
	}
	return min(ambient + lamp * (1.0 - outdoors), vec3(1.12));
}
