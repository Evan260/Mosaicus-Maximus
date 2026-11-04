class_name MosaicLayout
extends RefCounted
## Turns a design map into tiles. Rows of tiles follow the outline of every shape, the way Roman craftsmen laid them,
## and plain ground switches to straight rows once it is a couple of rows away from any shape.

const HALO_ROWS := 2
const REACH := 0.54  # how far a tile's edge reaches from its centre, as a share of its width, for keeping tiles apart
const NONE := -1

var px := 6
var w := 0
var h := 0
var labels := PackedInt32Array()
var dist := PackedFloat32Array()
var patches := PackedInt32Array()
var patch_count := 0
## 1 for design pixels in a picture panel, laid in tiles half the usual width.
var fine := PackedByteArray()

var pos := PackedVector2Array()
var angle := PackedFloat32Array()
var size := PackedFloat32Array()
var stone := PackedInt32Array()
var patch := PackedInt32Array()

var _cols := 0
var _rows := 0
var _cells: Array = []
var _rng := RandomNumberGenerator.new()


func build(img: Image, tile_px: int, fine_mask: PackedByteArray = PackedByteArray()) -> bool:
	px = tile_px
	_rng.seed = 7
	fine = fine_mask
	var t0 := Time.get_ticks_msec()
	if not _read_labels(img):
		return false
	var t1 := Time.get_ticks_msec()
	_distance_to_edges()
	var t2 := Time.get_ticks_msec()
	_find_patches()
	_cols = int(ceil(float(w) / px)) + 1
	_rows = int(ceil(float(h) / px)) + 1
	_cells.clear()
	_cells.resize(_cols * _rows)
	for i in _cells.size():
		_cells[i] = []
	_lay_flowing_rows()
	var t3 := Time.get_ticks_msec()
	_lay_straight_rows()
	_fill_gaps()
	var t4 := Time.get_ticks_msec()
	print("layout: %d tiles | read %d ms, distances %d ms, rows %d ms, fill %d ms" % [pos.size(), t1 - t0, t2 - t1, t3 - t2, t4 - t3])
	return true


func tile_count() -> int:
	return pos.size()


## Tiles whose centres lie within radius of a point, in design pixels.
func tiles_near(p: Vector2, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c0 := Vector2i(int((p.x - radius) / px), int((p.y - radius) / px))
	var c1 := Vector2i(int((p.x + radius) / px), int((p.y + radius) / px))
	var r2 := radius * radius
	for cy in range(maxi(c0.y, 0), mini(c1.y, _rows - 1) + 1):
		for cx in range(maxi(c0.x, 0), mini(c1.x, _cols - 1) + 1):
			for i in _cells[cy * _cols + cx]:
				if pos[i].distance_squared_to(p) <= r2:
					out.append(i)
	return out


func _read_labels(img: Image) -> bool:
	var im := img.duplicate() as Image
	im.convert(Image.FORMAT_RGB8)
	w = im.get_width()
	h = im.get_height()
	var data := im.get_data()
	var by_colour := Stones.lookup()
	labels.resize(w * h)
	var unknown := 0
	for i in w * h:
		var key := (data[i * 3] << 16) | (data[i * 3 + 1] << 8) | data[i * 3 + 2]
		var s: int = by_colour.get(key, 0)
		if not by_colour.has(key):
			unknown += 1
		labels[i] = s
	if unknown > 0:
		push_warning("design map has %d pixels in colours that are not stones; they became limestone" % unknown)
	return true


## Exact distance from every pixel to the nearest pixel that touches a different stone or the floor's edge.
func _distance_to_edges() -> void:
	var big := 1.0e20
	var f := PackedFloat32Array()
	f.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			var s := labels[i]
			var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1
			if not edge:
				edge = labels[i - 1] != s or labels[i + 1] != s or labels[i - w] != s or labels[i + w] != s
			f[i] = 0.0 if edge else big
	var n := maxi(w, h)
	var line := PackedFloat32Array()
	line.resize(n)
	var out := PackedFloat32Array()
	out.resize(n)
	var v := PackedInt32Array()
	v.resize(n)
	var z := PackedFloat32Array()
	z.resize(n + 1)
	for x in w:
		for y in h:
			line[y] = f[y * w + x]
		_edt_line(line, h, out, v, z)
		for y in h:
			f[y * w + x] = out[y]
	for y in h:
		for x in w:
			line[x] = f[y * w + x]
		_edt_line(line, w, out, v, z)
		for x in w:
			f[y * w + x] = out[x]
	dist.resize(w * h)
	for i in w * h:
		dist[i] = sqrt(f[i])


## One pass of Felzenszwalb and Huttenlocher's distance transform, along a single row or column.
func _edt_line(f: PackedFloat32Array, n: int, d: PackedFloat32Array, v: PackedInt32Array, z: PackedFloat32Array) -> void:
	var k := 0
	v[0] = 0
	z[0] = -1.0e30
	z[1] = 1.0e30
	for q in range(1, n):
		var fq := f[q] + q * q
		var s := (fq - (f[v[k]] + v[k] * v[k])) / (2.0 * q - 2.0 * v[k])
		while s <= z[k]:
			k -= 1
			s = (fq - (f[v[k]] + v[k] * v[k])) / (2.0 * q - 2.0 * v[k])
		k += 1
		v[k] = q
		z[k] = s
		z[k + 1] = 1.0e30
	k = 0
	for q in n:
		while z[k + 1] < q:
			k += 1
		var dq := q - v[k]
		d[q] = dq * dq + f[v[k]]


func _find_patches() -> void:
	patches.resize(w * h)
	patches.fill(NONE)
	patch_count = 0
	var stack := PackedInt32Array()
	for start in w * h:
		if patches[start] != NONE:
			continue
		var s := labels[start]
		patches[start] = patch_count
		stack.append(start)
		while stack.size() > 0:
			var i := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var x := i % w
			var y := i / w
			if x > 0 and patches[i - 1] == NONE and labels[i - 1] == s:
				patches[i - 1] = patch_count
				stack.append(i - 1)
			if x < w - 1 and patches[i + 1] == NONE and labels[i + 1] == s:
				patches[i + 1] = patch_count
				stack.append(i + 1)
			if y > 0 and patches[i - w] == NONE and labels[i - w] == s:
				patches[i - w] = patch_count
				stack.append(i - w)
			if y < h - 1 and patches[i + w] == NONE and labels[i + w] == s:
				patches[i + w] = patch_count
				stack.append(i + w)
		patch_count += 1


func _pitch(i: int) -> float:
	return px * 0.5 if not fine.is_empty() and fine[i] == 1 else float(px)


func _row_of(i: int) -> int:
	return int(floor((dist[i] + 0.5) / _pitch(i)))


## Walks along the centre line of each row and drops a tile every tile-width.
func _lay_flowing_rows() -> void:
	var key := PackedInt32Array()
	key.resize(w * h)
	for i in w * h:
		if labels[i] == Stones.NO_TILE:
			continue
		var k := _row_of(i)
		var pitch := _pitch(i)
		var centre := (k + 0.5) * pitch - 0.5
		if absf(dist[i] - centre) > 0.65:
			continue
		var is_fine := 1 if pitch < px else 0
		if Stones.is_ground(labels[i]) and k >= HALO_ROWS and is_fine == 0:
			continue
		key[i] = ((labels[i] * 256 + k) * 2 + is_fine) + 1
	var visited := PackedByteArray()
	visited.resize(w * h)
	var ring1: Array[Vector2i] = []
	var ring2: Array[Vector2i] = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if dx == 0 and dy == 0:
				continue
			if maxi(absi(dx), absi(dy)) == 1:
				ring1.append(Vector2i(dx, dy))
			else:
				ring2.append(Vector2i(dx, dy))
	for start in w * h:
		if key[start] == 0 or visited[start] == 1:
			continue
		var k0 := key[start]
		var cur := start
		var heading := Vector2.ZERO
		var pitch := _pitch(start)
		var travelled := pitch
		while true:
			visited[cur] = 1
			var cx := cur % w
			var cy := cur / w
			if travelled >= pitch:
				if _try_place(Vector2(cx + 0.5, cy + 0.5), _gradient_angle(cx, cy), pitch * (0.84 + _rng.randf() * 0.06), labels[cur]):
					travelled = 0.0
			var nxt := _pick_next(cx, cy, k0, key, visited, heading, ring1)
			if nxt < 0:
				nxt = _pick_next(cx, cy, k0, key, visited, heading, ring2)
			for o in ring1:
				var nx := cx + o.x
				var ny := cy + o.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h:
					var j := ny * w + nx
					if j != nxt and key[j] == k0:
						visited[j] = 1
			if nxt < 0:
				break
			var step := Vector2(nxt % w - cx, nxt / w - cy)
			travelled += step.length()
			heading = step.normalized()
			cur = nxt


func _pick_next(cx: int, cy: int, k0: int, key: PackedInt32Array, visited: PackedByteArray, heading: Vector2, ring: Array[Vector2i]) -> int:
	var best := -1
	var best_score := -10.0
	for o in ring:
		var nx := cx + o.x
		var ny := cy + o.y
		if nx < 0 or ny < 0 or nx >= w or ny >= h:
			continue
		var j := ny * w + nx
		if key[j] != k0 or visited[j] == 1:
			continue
		var score := Vector2(o).normalized().dot(heading) if heading != Vector2.ZERO else 0.0
		if score > best_score:
			best_score = score
			best = j
	return best


func _gradient_angle(x: int, y: int) -> float:
	var xl := maxi(x - 1, 0)
	var xr := mini(x + 1, w - 1)
	var yu := maxi(y - 1, 0)
	var yd := mini(y + 1, h - 1)
	var gx := dist[y * w + xr] - dist[y * w + xl]
	var gy := dist[yd * w + x] - dist[yu * w + x]
	if absf(gx) + absf(gy) < 0.0001:
		return 0.0
	return atan2(gy, gx)


## Straight rows for the open ground, the way Roman floors filled plain space.
func _lay_straight_rows() -> void:
	for ty in range(h / px):
		for tx in range(w / px):
			var p := Vector2((tx + 0.5) * px, (ty + 0.5) * px)
			var i := int(p.y) * w + int(p.x)
			if not Stones.is_ground(labels[i]) or dist[i] < HALO_ROWS * px:
				continue
			var wobble := Vector2(_rng.randf() - 0.5, _rng.randf() - 0.5) * px * 0.08
			_try_place(p + wobble, (_rng.randf() - 0.5) * 0.08, px * (0.84 + _rng.randf() * 0.06), labels[i])


## Fits a smaller tile into any space left between the rows, so no bare mortar shows through.
func _fill_gaps() -> void:
	for pass_i in 2:
		var need := 0.8 if pass_i == 0 else 0.64
		for y in range(1, h - 1, 2):
			for x in range(1, w - 1, 2):
				if labels[y * w + x] == Stones.NO_TILE:
					continue
				var p := Vector2(x + 0.5, y + 0.5)
				var nearest := _nearest_tile(p)
				if nearest[1] < need * _pitch(y * w + x):
					continue
				var pitch := _pitch(y * w + x)
				var s := minf(0.9 * pitch, _free_reach(p) / REACH)
				if s < 0.42 * pitch or (pitch < px and nearest[1] < need * pitch):
					continue
				var a: float = angle[nearest[0]] if nearest[0] >= 0 else _gradient_angle(x, y)
				_add_tile(p, a, s, labels[y * w + x])


func _nearest_tile(p: Vector2) -> Array:
	var best := -1
	var best_d := 1.0e9
	var cx := int(p.x / px)
	var cy := int(p.y / px)
	for yy in range(maxi(cy - 1, 0), mini(cy + 1, _rows - 1) + 1):
		for xx in range(maxi(cx - 1, 0), mini(cx + 1, _cols - 1) + 1):
			for i in _cells[yy * _cols + xx]:
				var d := pos[i].distance_to(p)
				if d < best_d:
					best_d = d
					best = i
	return [best, best_d]


## How far a new tile's edge could reach from this point before it would touch a neighbour.
func _free_reach(p: Vector2) -> float:
	var free := 1.0e9
	var cx := int(p.x / px)
	var cy := int(p.y / px)
	for yy in range(maxi(cy - 1, 0), mini(cy + 1, _rows - 1) + 1):
		for xx in range(maxi(cx - 1, 0), mini(cx + 1, _cols - 1) + 1):
			for i in _cells[yy * _cols + xx]:
				free = minf(free, pos[i].distance_to(p) - REACH * size[i])
	return free


func _try_place(p: Vector2, a: float, s: float, st: int) -> bool:
	if _free_reach(p) < REACH * s * 0.97:
		return false
	_add_tile(p, a, s, st)
	return true


func _add_tile(p: Vector2, a: float, s: float, st: int) -> void:
	var idx := pos.size()
	pos.append(p)
	angle.append(a)
	size.append(s)
	stone.append(st)
	var pix := clampi(int(p.y), 0, h - 1) * w + clampi(int(p.x), 0, w - 1)
	patch.append(patches[pix])
	_cells[int(p.y / px) * _cols + int(p.x / px)].append(idx)
