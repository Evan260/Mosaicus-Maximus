class_name SoftNoise
## Smooth random patches for the mortar's texture and the dirt over old floors, made here because the trimmed engine
## the game ships with leaves Godot's own noise out: coarse random grids scaled up smoothly, in two sizes.


## A value from about -1 to 1 for every pixel of a w by h area, in patches roughly `cell` pixels across.
static func field(w: int, h: int, cell: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	var weight := 1.0
	var total := 0.0
	for octave in 2:
		var size := cell / pow(2.0, octave)
		var gw := maxi(2, int(ceil(w / size)) + 1)
		var gh := maxi(2, int(ceil(h / size)) + 1)
		var grid := Image.create(gw, gh, false, Image.FORMAT_RF)
		for y in gh:
			for x in gw:
				grid.set_pixel(x, y, Color(rng.randf(), 0, 0))
		grid.resize(w, h, Image.INTERPOLATE_CUBIC)
		var values := grid.get_data().to_float32_array()
		for i in w * h:
			out[i] += (values[i] * 2.0 - 1.0) * weight
		total += weight
		weight *= 0.5
	for i in w * h:
		out[i] = out[i] / total * 0.9
	return out
