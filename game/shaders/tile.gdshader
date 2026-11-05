shader_type canvas_item;
// Draws every tile of a floor in one batch: the drop, bounce, glint, dust and shimmer all run here.
// Per tile: x = time it started falling, y = stone * 1000 + seed, z = time its shimmer starts, w = its angle.

uniform float now = 0.0;
// 0 draws tiles that have settled, 1 draws tiles still in the air, above the rest.
uniform int layer = 0;
uniform float drop_time = 0.2;
uniform float settle_time = 0.36;
uniform float active_life = 0.7;
uniform float texels = 6.0;
// rgb is the stone's colour, a is its material number divided by ten.
uniform vec4 palette[16];

varying vec2 local;
varying float t_rel;
varying float seed;
varying float stone_f;
varying float shimmer_t;
varying float ang;
varying vec4 modulate;

const float QUAD = 1.8;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

mat2 rot(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

void vertex() {
	local = VERTEX * QUAD;
	t_rel = now - INSTANCE_CUSTOM.x;
	stone_f = floor(INSTANCE_CUSTOM.y / 1000.0 + 0.001);
	seed = (INSTANCE_CUSTOM.y - stone_f * 1000.0) / 1000.0;
	shimmer_t = now - INSTANCE_CUSTOM.z;
	ang = INSTANCE_CUSTOM.w;
	modulate = COLOR;
}

void fragment() {
	if (t_rel < 0.0) {
		discard;
	}
	bool settled = t_rel >= settle_time;
	if (layer == 0 && !settled) {
		discard;
	}
	if (layer == 1 && t_rel >= active_life) {
		discard;
	}
	float p = clamp(t_rel / drop_time, 0.0, 1.0);
	float height = 1.0 - p * p;
	float sc = 1.0 + 0.38 * height;
	float after = t_rel - drop_time;
	if (after > 0.0 && after < 0.16) {
		float b = after / 0.16;
		sc = 1.0 - 0.08 * sin(b * 6.2832) * (1.0 - b);
	}
	float spin = (seed - 0.5) * 1.1 * height;
	vec2 shadow_screen = vec2(0.05, 0.08) + vec2(0.2, 0.28) * height;
	vec2 shadow_local = rot(-ang) * shadow_screen;

	vec2 q = rot(-spin) * local / sc;
	vec4 sides = 0.5 - 0.06 * vec4(h21(vec2(seed, 1.7)), h21(vec2(seed, 2.3)), h21(vec2(seed, 3.1)), h21(vec2(seed, 4.9)));
	bool in_body = q.x > -sides.x && q.x < sides.y && q.y > -sides.z && q.y < sides.w;
	float chip = h21(vec2(seed, 5.3));
	if (in_body && chip < 0.3) {
		vec2 flip = vec2(chip < 0.15 ? 1.0 : -1.0, mod(floor(chip * 40.0), 2.0) < 1.0 ? 1.0 : -1.0);
		vec2 cq = q * flip;
		if (cq.x + cq.y > 0.74) {
			in_body = false;
		}
	}

	vec4 col = vec4(0.0);
	if (in_body) {
		vec2 tq = floor((q + 0.5) * texels);
		vec4 pal = palette[int(stone_f)];
		int mat = int(pal.a * 10.0 + 0.5);
		float n = h21(tq + seed * 37.0);
		float tone = (h21(vec2(seed, 9.1)) - 0.5) * 0.12;
		vec3 c = pal.rgb * (1.0 + tone + (n - 0.5) * 0.08);
		vec2 qe = (tq + 0.5) / texels - 0.5;
		float edge = 0.5 - max(abs(qe.x), abs(qe.y));
		if (edge < 1.0 / texels) {
			vec2 nrm = abs(qe.x) > abs(qe.y) ? vec2(sign(qe.x), 0.0) : vec2(0.0, sign(qe.y));
			vec2 nw = rot(ang + spin) * nrm;
			float lit = dot(nw, normalize(vec2(-0.7, -1.0)));
			c *= 1.0 + 0.17 * lit;
		}
		if (mat == 3 && fract((tq.x * 0.7 + tq.y) * 0.31 + seed * 5.0) < 0.14) {
			c *= 0.9;
		}
		if (mat == 4) {
			if (tq.x == 1.0 && tq.y == 1.0) {
				c = mix(c, vec3(1.0), 0.55);
			}
			c *= 1.0 + 0.08 * sin(now * 1.3 + seed * 30.0);
		}
		if (mat == 5) {
			c += vec3(0.3, 0.26, 0.12) * step(0.93, h21(tq + floor(now * 2.5 + seed * 7.0)));
		}
		if (after > 0.0 && after < 0.14) {
			float g = 1.0 - after / 0.14;
			float side = clamp(0.5 - dot(rot(ang) * q, normalize(vec2(0.7, 1.0))), 0.0, 1.0);
			c = mix(c, vec3(1.0, 0.97, 0.88), 0.6 * g * side);
		}
		if (shimmer_t > 0.0 && shimmer_t < 0.45) {
			c += vec3(0.34, 0.3, 0.2) * sin(shimmer_t / 0.45 * 3.14159);
		}
		if (height > 0.0) {
			c *= 1.0 + 0.12 * height;
		}
		col = vec4(c, 1.0);
	} else {
		vec2 sq = (local - shadow_local) / sc;
		float sd = max(abs(sq.x), abs(sq.y));
		float shadow_a = (1.0 - smoothstep(0.44, 0.54 + 0.12 * height, sd)) * mix(0.4, 0.2, height);
		col = vec4(0.05, 0.03, 0.02, shadow_a);
		if (layer == 1 && after > 0.0 && after < 0.34) {
			float b = after / 0.34;
			float r = length(local);
			float ring = 0.55 + 0.38 * b;
			float a = atan(local.y, local.x);
			float puffs = step(0.4, h21(vec2(floor(a * 2.5 + seed * 20.0), seed)));
			float dust = (1.0 - smoothstep(0.0, 0.1, abs(r - ring))) * 0.38 * (1.0 - b) * puffs;
			col.rgb = mix(col.rgb, vec3(0.92, 0.87, 0.78), dust / max(col.a + dust, 0.001));
			col.a = max(col.a, dust);
		}
		if (col.a < 0.004) {
			discard;
		}
	}
	COLOR = col * modulate;
}
