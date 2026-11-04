class_name Composer
## Turns a floor design into the colour map the layout reads: one colour per stone, magenta where nothing is laid.

## Tiles the layout makes for each tile-sized square of floor, measured on real floors, for costing before laying.
const TILES_PER_SQUARE := 1.07
## In a part map, motif parts start here: PART_MOTIF + 8 * placement + role, with role 7 for the outline.
const PART_MOTIF := 16
const PART_GROUND := 1
const PART_BORDER := 2
const MAX_PARTS := 29


static func compose(design: FloorDesign, px: int = 6) -> Image:
	var w := design.w * px
	var h := design.h * px
	var labels := PackedByteArray()
	labels.resize(w * h)
	labels.fill(Stones.index(design.ground))
	var inside := _shape(design, w, h, px)
	for i in w * h:
		if inside[i] == 0:
			labels[i] = Stones.NO_TILE
	BorderPainter.paint(labels, w, h, px, design.room_data(), design.border, inside)
	for p in design.placements:
		_stamp(labels, inside, w, h, px, p)
	return _to_image(labels, w, h)


## Which part of the design each pixel belongs to (the PART_ codes, NO_TILE outside), so a click can pick a part.
static func part_map(design: FloorDesign, px: int) -> PackedByteArray:
	var w := design.w * px
	var h := design.h * px
	var labels := PackedByteArray()
	labels.resize(w * h)
	labels.fill(PART_GROUND)
	var inside := _shape(design, w, h, px)
	for i in w * h:
		if inside[i] == 0:
			labels[i] = Stones.NO_TILE
	# The border painter writes stone numbers, so four stones whose numbers equal the border parts stand in.
	var border := design.border.duplicate(true)
	border["stones"] = range(4).map(func(k: int) -> String: return Stones.id_of(PART_BORDER + k))
	BorderPainter.paint(labels, w, h, px, design.room_data(), border, inside)
	for n in mini(design.placements.size(), MAX_PARTS):
		var codes := PackedByteArray()
		codes.resize(8)
		for r in 8:
			codes[r] = PART_MOTIF + n * 8 + r
		_stamp(labels, inside, w, h, px, design.placements[n], codes)
	return labels


## How many tiles of each stone the floor will need, keyed by stone id. Picture panels need four small tiles a square.
static func stone_counts(design: FloorDesign) -> Dictionary:
	var px := 3
	var img := compose(design, px)
	var fine := fine_mask(design, px)
	var data := img.get_data()
	var by_colour := Stones.lookup()
	var px_counts := {}
	for i in img.get_width() * img.get_height():
		var key := (data[i * 3] << 16) | (data[i * 3 + 1] << 8) | data[i * 3 + 2]
		var s: int = by_colour.get(key, 0)
		if s != Stones.NO_TILE:
			px_counts[s] = px_counts.get(s, 0) + (4 if not fine.is_empty() and fine[i] == 1 else 1)
	var out := {}
	for s in px_counts:
		out[Stones.id_of(s)] = int(round(px_counts[s] / float(px * px) * TILES_PER_SQUARE))
	return out


## 1 for every design pixel inside a picture panel, which the layout fills with half-size tiles. Empty if there are none.
static func fine_mask(design: FloorDesign, px: int) -> PackedByteArray:
	var out := PackedByteArray()
	var any := false
	for p in design.placements:
		any = any or bool(p.get("fine", false))
	if not any:
		return out
	var w := design.w * px
	var h := design.h * px
	out.resize(w * h)
	for p in design.placements:
		if not bool(p.get("fine", false)):
			continue
		var motif: String = p.get("motif", "")
		var t := MotifLibrary.tiles(motif, float(p.get("size", 10)))
		var rot := int(p.get("rot", 0))
		if rot % 2 == 1:
			t = Vector2(t.y, t.x)
		var size := Vector2i(maxi(1, int(t.x * px)), maxi(1, int(t.y * px)))
		var mask := MotifLibrary.mask(motif, size, rot, bool(p.get("flip", false)))
		var ox := int((float(p.get("x", 0)) - t.x * 0.5) * px)
		var oy := int((float(p.get("y", 0)) - t.y * 0.5) * px)
		for y in size.y:
			var gy := oy + y
			if gy < 0 or gy >= h:
				continue
			for x in size.x:
				var gx := ox + x
				if gx >= 0 and gx < w and mask[y * size.x + x] > 0:
					out[gy * w + gx] = 1
	return out


static func _shape(design: FloorDesign, w: int, h: int, px: int) -> PackedByteArray:
	var inside := PackedByteArray()
	inside.resize(w * h)
	inside.fill(1)
	if design.shape == "apse":
		var r := w * 0.5
		for y in int(ceil(r)):
			for x in w:
				if Vector2(x + 0.5 - r, y + 0.5 - r).length() > r:
					inside[y * w + x] = 0
	elif design.shape == "pool" and design.pool.size() == 4:
		var x0 := int(float(design.pool[0]) * w)
		var y0 := int(float(design.pool[1]) * h)
		var x1 := x0 + int(float(design.pool[2]) * w)
		var y1 := y0 + int(float(design.pool[3]) * h)
		for y in range(maxi(y0, 0), mini(y1, h)):
			for x in range(maxi(x0, 0), mini(x1, w)):
				inside[y * w + x] = 0
	return inside


## Draws one motif into the labels; with codes, roles are written as codes[role] and the outline as codes[7].
static func _stamp(labels: PackedByteArray, inside: PackedByteArray, w: int, h: int, px: int, p: Dictionary, codes := PackedByteArray()) -> void:
	var motif: String = p.get("motif", "")
	var t := MotifLibrary.tiles(motif, float(p.get("size", 10)))
	var rot := int(p.get("rot", 0))
	if rot % 2 == 1:
		t = Vector2(t.y, t.x)
	var size := Vector2i(maxi(1, int(t.x * px)), maxi(1, int(t.y * px)))
	var mask := MotifLibrary.mask(motif, size, rot, bool(p.get("flip", false)))
	var ox := int((float(p.get("x", 0)) - t.x * 0.5) * px)
	var oy := int((float(p.get("y", 0)) - t.y * 0.5) * px)
	var defaults: Dictionary = Data.motif(motif).get("stones", {})
	var chosen: Dictionary = p.get("stones", {})
	var role_stone := PackedByteArray()
	role_stone.resize(8)
	for role in range(1, 8):
		var id: String = chosen.get(str(role), defaults.get(str(role), "black_stone"))
		role_stone[role] = codes[role] if not codes.is_empty() else Stones.index(id)
	var outline: String = p.get("outline", "")
	if outline != "":
		var ring := _ring(mask, size, px)
		var o_idx := codes[7] if not codes.is_empty() else Stones.index(outline)
		var pad := px
		for y in size.y + 2 * pad:
			var gy := oy - pad + y
			if gy < 0 or gy >= h:
				continue
			for x in size.x + 2 * pad:
				var gx := ox - pad + x
				if gx < 0 or gx >= w or ring[y * (size.x + 2 * pad) + x] == 0:
					continue
				var gi := gy * w + gx
				if inside[gi] == 1:
					labels[gi] = o_idx
	for y in size.y:
		var gy := oy + y
		if gy < 0 or gy >= h:
			continue
		for x in size.x:
			var gx := ox + x
			if gx < 0 or gx >= w:
				continue
			var role := mask[y * size.x + x]
			if role == 0:
				continue
			var gi := gy * w + gx
			if inside[gi] == 1:
				labels[gi] = role_stone[role]


## A one-tile band around the outside of a motif's shape, in a grid padded by one tile on every side.
static func _ring(mask: PackedByteArray, size: Vector2i, px: int) -> PackedByteArray:
	var pw := size.x + 2 * px
	var ph := size.y + 2 * px
	var solid := PackedByteArray()
	solid.resize(pw * ph)
	for y in size.y:
		for x in size.x:
			if mask[y * size.x + x] > 0:
				solid[(y + px) * pw + x + px] = 1
	var wide := PackedByteArray()
	wide.resize(pw * ph)
	for y in ph:
		var run := -1000
		for x in pw:
			if solid[y * pw + x] == 1:
				run = x
			if x - run <= px:
				wide[y * pw + x] = 1
		run = 100000
		for x in range(pw - 1, -1, -1):
			if solid[y * pw + x] == 1:
				run = x
			if run - x <= px:
				wide[y * pw + x] = 1
	var ring := PackedByteArray()
	ring.resize(pw * ph)
	for x in pw:
		var run := -1000
		for y in ph:
			if wide[y * pw + x] == 1:
				run = y
			if y - run <= px:
				ring[y * pw + x] = 1
		run = 100000
		for y in range(ph - 1, -1, -1):
			if wide[y * pw + x] == 1:
				run = y
			if run - y <= px:
				ring[y * pw + x] = 1
	for i in pw * ph:
		if solid[i] == 1:
			ring[i] = 0
	return ring


static func _to_image(labels: PackedByteArray, w: int, h: int) -> Image:
	var table := PackedByteArray()
	table.resize(256 * 3)
	for i in Stones.LIST.size():
		var c: Color = Stones.LIST[i]["map"]
		table[i * 3] = c.r8
		table[i * 3 + 1] = c.g8
		table[i * 3 + 2] = c.b8
	table[Stones.NO_TILE * 3] = 255
	table[Stones.NO_TILE * 3 + 2] = 255
	var rgb := PackedByteArray()
	rgb.resize(w * h * 3)
	for i in w * h:
		var s := labels[i] * 3
		rgb[i * 3] = table[s]
		rgb[i * 3 + 1] = table[s + 1]
		rgb[i * 3 + 2] = table[s + 2]
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, rgb)
