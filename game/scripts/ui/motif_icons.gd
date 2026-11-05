class_name MotifIcons
## Small pictures of motifs and stones for the pattern book and the stone tray, coloured in real stone.

const KEEP := 256
const KEEP_PARTS := 64

## Pictures by what they show, least recently used first, the oldest dropped past KEEP.
static var _cache := {}
## Part chips change with every stone picked, so they have a pool of their own and never push the book's pictures out.
static var _parts := {}


static func motif(id: String, size: int, stones: Dictionary = {}) -> ImageTexture:
	var key := "%s|%d|%s" % [id, size, JSON.stringify(stones)]
	if _cache.has(key):
		return _used(_cache, key)
	var t := MotifLibrary.tiles(id, 1.0)
	var dims := Vector2i(maxi(1, int(round(size * t.x))), maxi(1, int(round(size * t.y))))
	var mask := MotifLibrary.mask(id, dims, 0, false)
	var defaults: Dictionary = Data.motif(id).get("stones", {})
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var ox := (size - dims.x) / 2
	var oy := (size - dims.y) / 2
	var colours := {}
	for y in dims.y:
		for x in dims.x:
			var role := mask[y * dims.x + x]
			if role == 0:
				continue
			if not colours.has(role):
				var sid: String = stones.get(str(role), defaults.get(str(role), "black_stone"))
				colours[role] = Stones.LIST[Stones.index(sid)]["tile"]
			img.set_pixel(ox + x, oy + y, colours[role])
	var tex := ImageTexture.create_from_image(img)
	return _keep(_cache, key, tex)


## A motif with one part in its stone and the rest faded, for the chip that picks that part. Role 7 is the outline,
## drawn as a ring round the whole shape.
static func part(id: String, size: int, role: int, stones: Dictionary, outline: String = "") -> ImageTexture:
	var key := "%s|%d|%d|%s|%s" % [id, size, role, JSON.stringify(stones), outline]
	if _parts.has(key):
		return _used(_parts, key)
	var t := MotifLibrary.tiles(id, 1.0)
	var inner := size - 2
	var dims := Vector2i(maxi(1, int(round(inner * t.x))), maxi(1, int(round(inner * t.y))))
	var mask := MotifLibrary.mask(id, dims, 0, false)
	var defaults: Dictionary = Data.motif(id).get("stones", {})
	var faded := Color(0.42, 0.36, 0.3, 0.28)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var ox := (size - dims.x) / 2
	var oy := (size - dims.y) / 2
	var filled := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < dims.x and y < dims.y and mask[y * dims.x + x] > 0
	for y in range(-1, dims.y + 1):
		for x in range(-1, dims.x + 1):
			var r := mask[y * dims.x + x] if filled.call(x, y) else 0
			var c := Color(0, 0, 0, 0)
			if r > 0:
				c = Stones.LIST[Stones.index(stones.get(str(r), defaults.get(str(r), "black_stone")))]["tile"] if r == role else faded
			elif role == 7 and outline != "" and (filled.call(x + 1, y) or filled.call(x - 1, y) or filled.call(x, y + 1) or filled.call(x, y - 1)):
				c = Stones.LIST[Stones.index(outline)]["tile"]
			if c.a > 0.0 and ox + x >= 0 and oy + y >= 0 and ox + x < size and oy + y < size:
				img.set_pixel(ox + x, oy + y, c)
	var tex := ImageTexture.create_from_image(img)
	return _keep(_parts, key, tex, KEEP_PARTS)


## A floor part in its stone, the rest faded: the ground as a tiny plan of the floor, a border stripe as its corner.
static func floor_part(design: FloorDesign, key: String, size: int) -> ImageTexture:
	var d := design
	var px := 1
	var crop := Rect2i(0, 0, design.w, design.h)
	var code := Composer.PART_GROUND
	if key.begins_with("border"):
		d = FloorDesign.new()
		d.w = 24
		d.h = 24
		d.border = design.border.duplicate(true)
		d.border["margin"] = 0
		px = 2
		var band := int(d.border.get("width", 2)) + 4
		crop = Rect2i(0, 0, mini(24, band * 2) * px, mini(24, band * 2) * px)
		code = Composer.PART_BORDER + int(key.trim_prefix("border"))
	var parts := Composer.part_map(d, px)
	var img := Composer.compose(d, px)
	var w := d.w * px
	var out := Image.create(crop.size.x, crop.size.y, false, Image.FORMAT_RGBA8)
	var faded := Color(0.42, 0.36, 0.3, 0.28)
	for y in crop.size.y:
		for x in crop.size.x:
			var i := (crop.position.y + y) * w + crop.position.x + x
			var label := parts[i]
			if label == Stones.NO_TILE or (key.begins_with("border") and label == Composer.PART_GROUND):
				continue
			out.set_pixel(x, y, img.get_pixel(crop.position.x + x, crop.position.y + y) if label == code else faded)
	var k := float(size) / maxf(out.get_width(), out.get_height())
	out.resize(maxi(1, int(out.get_width() * k)), maxi(1, int(out.get_height() * k)), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(out)


static func swatch(stone_id: String, size: int = 10) -> ImageTexture:
	var key := "stone|%s|%d" % [stone_id, size]
	if _cache.has(key):
		return _used(_cache, key)
	var c: Color = Stones.LIST[Stones.index(stone_id)]["tile"]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(c)
	for i in size:
		img.set_pixel(i, 0, c.lightened(0.25))
		img.set_pixel(0, i, c.lightened(0.25))
		img.set_pixel(i, size - 1, c.darkened(0.3))
		img.set_pixel(size - 1, i, c.darkened(0.3))
	var tex := ImageTexture.create_from_image(img)
	return _keep(_cache, key, tex)


static func border(id: String, w: int = 40, h: int = 10) -> ImageTexture:
	var key := "border|%s|%d" % [id, w]
	if _cache.has(key):
		return _used(_cache, key)
	var d := FloorDesign.new()
	d.w = 40
	d.h = 18
	d.set_border(id)
	d.border["margin"] = 0
	var img := Composer.compose(d, 2)
	var crop := img.get_region(Rect2i(0, 0, w * 2, int(d.border["width"]) * 2 + 2))
	crop.resize(w, maxi(4, int(d.border["width"]) + 1), Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(crop)
	return _keep(_cache, key, tex)


## A cached picture, moved to the back of the queue so it is dropped last.
static func _used(cache: Dictionary, key: String) -> ImageTexture:
	var tex: ImageTexture = cache[key]
	cache.erase(key)
	cache[key] = tex
	return tex


static func _keep(cache: Dictionary, key: String, tex: ImageTexture, most: int = KEEP) -> ImageTexture:
	cache[key] = tex
	if cache.size() > most:
		cache.erase(cache.keys()[0])
	return tex
