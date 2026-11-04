class_name Timelapse
## A looping GIF of a floor being laid, tile by tile in the order the player laid it, ending on the finished floor.

const FRAMES := 36


## Builds the GIF's bytes. Safe to run on a worker thread: it only reads the layout.
static func make(layout: MosaicLayout, order: PackedInt32Array, longest: int = 360) -> PackedByteArray:
	var k := minf(1.0, float(longest) / maxf(layout.w, layout.h))
	var w := maxi(16, int(layout.w * k))
	var h := maxi(16, int(layout.h * k))
	var palette := PackedColorArray([Color8(120, 110, 98)])
	for s in Stones.LIST:
		palette.append(s["tile"])
	palette.append(Color8(206, 196, 178))
	var grout := palette.size() - 1
	var frame := PackedByteArray()
	frame.resize(w * h)
	for y in h:
		for x in w:
			var i := int(y / k) * layout.w + int(x / k)
			frame[y * w + x] = grout if layout.labels[mini(i, layout.labels.size() - 1)] == Stones.NO_TILE else 0
	var seq := order.duplicate()
	if seq.is_empty():
		var all := range(layout.tile_count())
		all.sort_custom(func(a: int, b: int) -> bool: return layout.pos[a].x + layout.pos[a].y * 0.4 < layout.pos[b].x + layout.pos[b].y * 0.4)
		seq = PackedInt32Array(all)
	var placed := {}
	for i in seq:
		placed[i] = true
	for i in layout.tile_count():
		if not placed.has(i):
			_stamp(frame, w, h, k, layout, i)
	var gif := GifWriter.new()
	gif.begin(w, h, palette)
	gif.add_frame(frame, 50)
	var per := maxi(1, int(ceil(seq.size() / float(FRAMES))))
	var n := 0
	while n < seq.size():
		for j in range(n, mini(n + per, seq.size())):
			_stamp(frame, w, h, k, layout, seq[j])
		n += per
		gif.add_frame(frame, 8)
	for i in w * h:
		if frame[i] == 0:
			frame[i] = grout
	gif.add_frame(frame, 300)
	return gif.finish()


static func _stamp(frame: PackedByteArray, w: int, h: int, k: float, layout: MosaicLayout, i: int) -> void:
	var c := layout.pos[i] * k
	var half := layout.size[i] * k * 0.5
	var a := layout.angle[i]
	var ca := cos(a)
	var sa := sin(a)
	var r := int(ceil(half * 1.42))
	var idx := layout.stone[i] + 1
	for y in range(maxi(0, int(c.y) - r), mini(h, int(c.y) + r + 1)):
		for x in range(maxi(0, int(c.x) - r), mini(w, int(c.x) + r + 1)):
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			if absf(dx * ca + dy * sa) <= half and absf(-dx * sa + dy * ca) <= half:
				frame[y * w + x] = idx
