class_name Composer
## Turns a floor design into the colour map the layout reads: one colour per stone, magenta where nothing is laid.

## Design pixels to a tile on the floor screen.
const TILE_PX := 6
## Tiles the layout makes for each tile-sized square of floor, measured on real floors, for costing before laying.
const TILES_PER_SQUARE := 1.07
## In a part map, motif parts start here: PART_MOTIF + 8 * placement + role, with role 7 for the outline.
const PART_MOTIF := 16
const PART_GROUND := 1
const PART_BORDER := 2
const MAX_PARTS := 29
## In a part map, wherever a placement at MAX_PARTS or later shows, since it has no codes of its own.
const PART_COVERED := 15
const COUNTS_KEPT := 32

static var _counted := {}
static var _counted_lock := Mutex.new()


static func compose(design: FloorDesign, px: int = 6) -> Image:
	return _to_image(_labels(design, px), design.w * px, design.h * px)


## The design as a picture to look at, clear outside the room's shape, such as the corners beside an apse.
static func picture(design: FloorDesign, px: int = 6) -> Image:
	return _to_image(_labels(design, px), design.w * px, design.h * px, true)


static func _labels(design: FloorDesign, px: int) -> PackedByteArray:
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
	return labels


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
	var covered := PackedByteArray([PART_COVERED, PART_COVERED, PART_COVERED, PART_COVERED, PART_COVERED, PART_COVERED, PART_COVERED, PART_COVERED])
	for n in design.placements.size():
		var codes := covered
		if n < MAX_PARTS:
			codes = PackedByteArray()
			codes.resize(8)
			for r in 8:
				codes[r] = PART_MOTIF + n * 8 + r
		_stamp(labels, inside, w, h, px, design.placements[n], codes)
	return labels


## The floor screen's own tiles for a design, built into the layout given.
static func lay_out(design: FloorDesign, layout: MosaicLayout = MosaicLayout.new()) -> MosaicLayout:
	layout.build(compose(design, TILE_PX), TILE_PX, fine_mask(design, TILE_PX))
	return layout


## The tiles of a layout whose centres lie in a panel_mask, which come already laid.
static func prelaid(layout: MosaicLayout, made: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	if made.is_empty():
		return out
	for i in layout.tile_count():
		var at := Vector2i(layout.pos[i])
		if at.x >= 0 and at.y >= 0 and at.x < layout.w and at.y < layout.h and made[at.y * layout.w + at.x] == 1:
			out.append(i)
	return out


## How many tiles of each stone laying the floor takes, keyed by stone id, counted on the very tiles the floor screen lays.
static func stone_counts(design: FloorDesign) -> Dictionary:
	# Laying out a big floor takes seconds, so each count is kept, behind a lock so it can be counted on a worker thread.
	var key := JSON.stringify(design.to_dict(), "", true, true)
	_counted_lock.lock()
	var known: Variant = _counted.get(key)
	_counted_lock.unlock()
	if known != null:
		return (known as Dictionary).duplicate()
	var layout := lay_out(design)
	var made := PackedByteArray()
	made.resize(layout.tile_count())
	for i in prelaid(layout, panel_mask(design, TILE_PX)):
		made[i] = 1
	var out := {}
	for i in layout.tile_count():
		if made[i] == 0:
			var id := Stones.id_of(layout.stone[i])
			out[id] = int(out.get(id, 0)) + 1
	_counted_lock.lock()
	_counted[key] = out
	while _counted.size() > COUNTS_KEPT:
		_counted.erase(_counted.keys()[0])
	_counted_lock.unlock()
	return out.duplicate()


## A quick guess at stone_counts from each stone's area, to show in the moment before the exact count is ready.
static func stone_estimate(design: FloorDesign) -> Dictionary:
	var px := 3
	var img := compose(design, px)
	var fine := fine_mask(design, px)
	var made := panel_mask(design, px)
	var data := img.get_data()
	var by_colour := Stones.lookup()
	var px_counts := {}
	for i in img.get_width() * img.get_height():
		if not made.is_empty() and made[i] == 1:
			continue
		var key := (data[i * 3] << 16) | (data[i * 3 + 1] << 8) | data[i * 3 + 2]
		var s: int = by_colour.get(key, 0)
		if s != Stones.NO_TILE:
			px_counts[s] = px_counts.get(s, 0) + (4 if not fine.is_empty() and fine[i] == 1 else 1)
	var out := {}
	for s in px_counts:
		out[Stones.id_of(s)] = maxi(1, int(round(px_counts[s] / float(px * px) * TILES_PER_SQUARE)))
	return out


## 1 for every design pixel inside a picture panel, which the layout fills with half-size tiles. Empty if there are none.
static func fine_mask(design: FloorDesign, px: int) -> PackedByteArray:
	if not design.placements.any(func(p: Dictionary) -> bool: return bool(p.get("fine", false))):
		return PackedByteArray()
	return _top_mask(design, px, func(p: Dictionary) -> bool: return bool(p.get("fine", false)), false)


## 1 for every design pixel of a picture panel set into the floor, which is laid already. Empty if there are none.
static func panel_mask(design: FloorDesign, px: int) -> PackedByteArray:
	if not design.placements.any(func(p: Dictionary) -> bool: return str(p.get("panel", "")) != ""):
		return PackedByteArray()
	return _top_mask(design, px, func(p: Dictionary) -> bool: return str(p.get("panel", "")) != "", true)


## 1 where the placement on top is one that wanted picks, stamped in order as _labels paints; ring says if its outline counts.
static func _top_mask(design: FloorDesign, px: int, wanted: Callable, ring: bool) -> PackedByteArray:
	var w := design.w * px
	var h := design.h * px
	var out := PackedByteArray()
	out.resize(w * h)
	var inside := PackedByteArray()
	inside.resize(w * h)
	inside.fill(1)
	for p in design.placements:
		var on := 1 if wanted.call(p) else 0
		_stamp(out, inside, w, h, px, p, PackedByteArray([0, on, on, on, on, on, on, on if ring else 0]))
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


static func _to_image(labels: PackedByteArray, w: int, h: int, clear := false) -> Image:
	var n := 4 if clear else 3
	var table := PackedByteArray()
	table.resize(256 * n)
	for i in Stones.LIST.size():
		var c: Color = Stones.LIST[i]["map"]
		table[i * n] = c.r8
		table[i * n + 1] = c.g8
		table[i * n + 2] = c.b8
		if clear:
			table[i * n + 3] = 255
	if not clear:
		table[Stones.NO_TILE * n] = 255
		table[Stones.NO_TILE * n + 2] = 255
	var out := PackedByteArray()
	out.resize(w * h * n)
	for i in w * h:
		var s := labels[i] * n
		for k in n:
			out[i * n + k] = table[s + k]
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8 if clear else Image.FORMAT_RGB8, out)
