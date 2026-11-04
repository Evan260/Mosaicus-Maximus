class_name BorderPainter
## Borders around a room's edge. Each kind is a pattern of numbered colour areas along a band a few tiles wide:
## role 0 is the band's background, and roles 1 to 3 are the pattern's stones.


## Paints the border into a room's stone labels, at px design pixels to a tile. inside marks pixels within the room.
static func paint(labels: PackedByteArray, w: int, h: int, px: int, room: Dictionary, border: Dictionary, inside: PackedByteArray) -> void:
	var kind: String = border.get("id", "")
	var width := float(border.get("width", 0))
	if kind == "" or width < 1.0:
		return
	var margin := float(border.get("margin", 1))
	var stones: Array = border.get("stones", [])
	var ids := PackedByteArray()
	for k in 4:
		ids.append(Stones.index(stones[k]) if k < stones.size() else Stones.index("white_marble"))
	var tw := float(w) / px
	var th := float(h) / px
	var apse := str(room.get("shape", "rect")) == "apse"
	var apse_r := tw * 0.5
	for y in h:
		var ty := (y + 0.5) / px
		for x in w:
			var i := y * w + x
			if inside[i] == 0:
				continue
			var tx := (x + 0.5) / px
			var along := 0.0
			var depth := 0.0
			var corner := false
			if apse and ty < apse_r:
				var r := Vector2(tx - apse_r, ty - apse_r).length()
				depth = apse_r - r - margin
				along = (atan2(ty - apse_r, tx - apse_r) + PI) * apse_r
			else:
				var dx := minf(tx, tw - tx) - margin
				var dy_top := (ty - margin) if not apse else 1.0e9
				var dy := minf(dy_top, th - ty - margin)
				depth = minf(dx, dy)
				along = tx if dy <= dx else ty
				corner = dx < width and dy < width and dx >= 0.0 and dy >= 0.0
			if depth < 0.0 or depth >= width:
				continue
			var role := _corner_role(minf(tx, tw - tx) - margin, minf(ty, th - ty) - margin, width) if corner else _role(kind, along, depth, width)
			labels[i] = ids[role]


static func _corner_role(u: float, v: float, width: float) -> int:
	var c := width * 0.5
	var m := maxf(absf(u - c), absf(v - c))
	if m >= c - 1.0:
		return 1
	if m < 1.0:
		return 2
	return 0


static func _role(kind: String, s: float, d: float, bw: float) -> int:
	match kind:
		"plain":
			return 1
		"double":
			return 1 if d < 1.0 or d >= bw - 1.0 else 0
		"key":
			var p := bw + 1.0
			var half := floorf(p * 0.5)
			var m := fposmod(s, p)
			if d < 1.0 or d >= bw - 1.0:
				return 0
			if d < 2.0 and m < half + 1.0:
				return 1
			if d >= bw - 2.0 and (m >= half or m < 1.0):
				return 1
			if m < 1.0 or (m >= half and m < half + 1.0):
				return 1
			return 0
		"wave":
			var phase := fposmod(s / (bw * 1.6), 1.0)
			var crest := pow(phase / 0.72, 1.6) if phase < 0.72 else 1.0 - (phase - 0.72) / 0.28
			if d < 0.9:
				return 2
			return 1 if d < 0.9 + crest * (bw - 1.8) else 0
		"braid":
			var p := bw * 2.2
			var t := bw * 0.17
			var mid := bw * 0.5
			var amp := bw * 0.5 - t - 0.6
			var under := int(floorf(s / (p * 0.5))) % 2
			for k in [under, 1 - under]:
				var yk := mid + amp * sin(TAU * s / p + k * PI)
				var off := absf(d - yk)
				if off < t:
					return 1 + k
				if off < t + 0.7:
					return 3
			return 0
		"chequer":
			var cell := maxf(1.0, bw * 0.5)
			return 1 if (int(floorf(s / cell)) + int(floorf(d / cell))) % 2 == 0 else 0
		"triangles":
			var tooth := absf(fposmod(s / bw, 1.0) * 2.0 - 1.0)
			return 1 if d < bw * (1.0 - tooth) else 0
		"dentil":
			if d < 0.9 or d >= bw - 0.9:
				return 2
			return 1 if fposmod(s, 2.0) < 1.0 else 0
		"ivy":
			var p := bw * 2.6
			var stem_y := bw * 0.5 + (bw * 0.5 - 1.6) * sin(TAU * s / p)
			if absf(d - stem_y) < 0.6:
				return 2
			var phase := fposmod(s / p, 1.0)
			for leaf in [[0.25, -1.0], [0.75, 1.0]]:
				var cx: float = (floorf(s / p) + leaf[0]) * p
				var cy: float = bw * 0.5 + leaf[1] * (bw * 0.5 - 1.2)
				var q := Vector2((s - cx) / (bw * 0.36), (d - cy) / (bw * 0.3))
				if q.length() < 1.0 - 0.35 * absf(q.x):
					return 1
			return 0
	return 0
