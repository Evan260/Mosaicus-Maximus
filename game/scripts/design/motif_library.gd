class_name MotifLibrary
## Motif pictures as masks of numbered colour areas ("roles") at any size, turn and mirror, smoothed as they grow.

static var _cache := {}
static var _lock := Mutex.new()
# Role colour bits (red 1, green 2, blue 4) mapped to role numbers.
const CODE_TO_ROLE := {1: 1, 2: 2, 4: 3, 3: 4, 5: 5, 6: 6}


static func source(id: String) -> Image:
	# Floors are composed on worker threads while the design table composes on the main one.
	_lock.lock()
	var known: Image = _cache.get(id)
	_lock.unlock()
	if known:
		return known
	var m := Data.motif(id)
	if m.is_empty() or not ResourceLoader.exists(m["file"]):
		return null
	var img := (load(m["file"]) as Texture2D).get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	_lock.lock()
	_cache[id] = img
	_lock.unlock()
	return img


## Loads every motif's picture on the main thread, since a picture loaded on a worker thread is left over at exit.
static func load_all() -> void:
	for id in Data.motif_order:
		source(id)


## The size in tiles a motif covers when its longest side is the given length, before turning.
static func tiles(id: String, longest: float) -> Vector2:
	var aspect := float(Data.motif(id).get("aspect", 1.0))
	return Vector2(longest, longest / aspect) if aspect >= 1.0 else Vector2(longest * aspect, longest)


## Roles at each pixel of a w by h area (0 is empty), with the picture turned clockwise rot times and mirrored if flip.
static func mask(id: String, size: Vector2i, rot: int, flip: bool) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(maxi(size.x, 0) * maxi(size.y, 0))
	var src := source(id)
	if src == null or size.x <= 0 or size.y <= 0:
		return out
	src = src.duplicate()
	if flip:
		src.flip_x()
	for k in posmod(rot, 4):
		src.rotate_90(CLOCKWISE)
	var sw := src.get_width()
	var sh := src.get_height()
	var data := src.get_data()
	var roles := {}
	var role_at := PackedByteArray()
	role_at.resize(sw * sh)
	for i in sw * sh:
		if data[i * 4 + 3] < 128:
			continue
		var code := int(data[i * 4] > 127) | (int(data[i * 4 + 1] > 127) << 1) | (int(data[i * 4 + 2] > 127) << 2)
		var role: int = CODE_TO_ROLE.get(code, 0)
		role_at[i] = role
		if role > 0:
			roles[role] = true
	var best := PackedByteArray()
	best.resize(size.x * size.y)
	for role in roles:
		var layer := PackedByteArray()
		layer.resize(sw * sh)
		for i in sw * sh:
			if role_at[i] == role:
				layer[i] = 255
		var m := Image.create_from_data(sw, sh, false, Image.FORMAT_L8, layer)
		m.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
		var d := m.get_data()
		for i in size.x * size.y:
			if d[i] > 127 and d[i] > best[i]:
				best[i] = d[i]
				out[i] = role
	return out


static func roles_of(id: String) -> Array:
	var out := []
	for k in Data.motif(id).get("stones", {}):
		out.append(int(k))
	out.sort()
	return out
