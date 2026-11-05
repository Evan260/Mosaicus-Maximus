shader_type canvas_item;
// The soil and plaster over a buried floor. state.b is how much has been cleared, so this fades where the brush has been.

uniform vec2 size_px = vec2(600.0, 420.0);
uniform float now = 0.0;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float cleared = texture(TEXTURE, UV).b;
	vec2 p = UV * size_px;
	float n = noise(p * 0.08) * 0.6 + noise(p * 0.25) * 0.3 + h21(floor(p)) * 0.1;
	float edge = smoothstep(0.25, 0.75, cleared + (n - 0.5) * 0.5);
	vec3 soil = mix(vec3(0.42, 0.32, 0.22), vec3(0.56, 0.45, 0.32), n);
	vec3 plaster = vec3(0.82, 0.78, 0.7) * (0.9 + n * 0.15);
	vec3 c = mix(soil, plaster, step(0.62, noise(p * 0.04 + 7.0)));
	float crumb = step(0.86, h21(floor(p * 0.5)));
	c *= 1.0 - crumb * 0.15;
	COLOR = vec4(c, 1.0 - edge) * modulate;
}
