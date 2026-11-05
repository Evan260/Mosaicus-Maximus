class_name FloorView
extends Node2D
## One floor being laid: the mortar bed with its chalk sketch, every tile in two batches, and the timing of each drop.

signal tiles_landed(stones: PackedInt32Array)
signal patch_finished(stone: int)
signal floor_finished
signal phase_changed(phase: int)

enum Phase { LAY, GROUT, POLISH, DONE, DIG, REPAIR }

const WORLD := 4.0  # world pixels per design pixel
const QUAD := 1.8  # each tile's quad is this many tiles wide, to leave room for its shadow and dust
const DROP := 0.2
const SETTLE := 0.36
const ACTIVE_LIFE := 0.7
const ACTIVE_CAP := 4096
const RIPPLE := 0.11  # seconds between the brush's centre and the edge of its circle
const UNSET := 1.0e7
const WALL := 6.0  # wall thickness in tiles
const STATE_DIV := 2  # grout and polish are tracked at half the design's resolution, which the eye can't tell apart
## How much of the floor each wipe must cover before the last specks fill themselves in: grout, polish, dirt.
const FINISH_AT := [0.97, 0.97, 0.9]
const RING_GAPS_BELOW := 13  # the last few empty gaps get a gold ring, since one bare tile is easy to miss

var layout: MosaicLayout
var now := 0.0
var laid := 0
var chalk_visible := true:
	set(v):
		chalk_visible = v
		if _chalk:
			_chalk.visible = v

var _start := PackedFloat32Array()
var _shimmer := PackedFloat32Array()
var _packed := PackedFloat32Array()
var _xf: Array[Transform2D] = []
var _flying := PackedInt32Array()
var _patch_left := {}
var _patch_tiles := {}
var _landed_mm: MultiMesh
var _active_mm: MultiMesh
var _active_next := 0
var _materials: Array[ShaderMaterial] = []
var _chalk: Sprite2D
var _rings: Node2D
var _guide: ShaderMaterial
var _chalk_img: Image
var _chalk_fresh: Image
var _chalk_tex: ImageTexture
var _chalk_dirty := false
var _quad: ArrayMesh
var _done := false
var phase := Phase.LAY
var _state := PackedByteArray()  # three bytes a design pixel: how much grout, how much polish, how much dirt cleared
var _state_img: Image
var _state_tex: ImageTexture
var _state_dirty := false
var _covered := [0, 0, 0]
## 1 for each grout cell over the floor, so the corners beside an apse and an atrium's pool don't count towards a wipe.
var _floor_cells := PackedByteArray()
var _floor_total := 1
## For a restoration: the tiles missing from the old floor, the stone the player chose for each, and the stone in use.
var missing := {}
var repaired := {}
var repair_stone := -1
## Off when the floor is drawn into a painted room, which has walls of its own.
var walls_visible := true
## Off for a wall mosaic or a panel at the bench, which have no doorway.
var door_visible := true
var _finish_mats: Array[ShaderMaterial] = []
## Every tile in the order it was laid, for the time-lapse.
var order := PackedInt32Array()
var _stone_total := {}
var _stone_laid := {}
var _stone_placed := {}
var _rng := RandomNumberGenerator.new()


func setup(l: MosaicLayout) -> void:
	layout = l
	_rng.seed = 11
	_add_mortar()
	_quad = _quad_mesh()
	var n := layout.tile_count()
	_start.resize(n)
	_start.fill(UNSET)
	_shimmer.resize(n)
	_shimmer.fill(-100.0)
	_packed.resize(n)
	_xf.resize(n)
	_landed_mm = _make_batch(n, 0)
	_active_mm = _make_batch(ACTIVE_CAP, 1)
	_add_finish_layers()
	for i in n:
		_packed[i] = layout.stone[i] * 1000 + floorf(_rng.randf() * 999.0)
		var s := layout.size[i] * QUAD * WORLD
		_xf[i] = Transform2D(layout.angle[i], Vector2(s, s), 0.0, layout.pos[i] * WORLD)
		_landed_mm.set_instance_transform_2d(i, _xf[i])
		_landed_mm.set_instance_custom_data(i, Color(UNSET, _packed[i], -100.0, layout.angle[i]))
		_stone_total[layout.stone[i]] = _stone_total.get(layout.stone[i], 0) + 1
		var p := layout.patch[i]
		if not _patch_tiles.has(p):
			_patch_tiles[p] = []
		_patch_tiles[p].append(i)
	for j in ACTIVE_CAP:
		_active_mm.set_instance_transform_2d(j, Transform2D())
		_active_mm.set_instance_custom_data(j, Color(UNSET, 0.0, -100.0, 0.0))
	_reset_patches()
	if walls_visible:
		var walls := Node2D.new()
		walls.draw.connect(_draw_walls.bind(walls))
		add_child(walls)


func size_world() -> Vector2:
	return Vector2(layout.w, layout.h) * WORLD


func tile_world() -> float:
	return layout.px * WORLD


## Lays every tile under a brush dragged between two points, rippling out from its centre; only one stone's if given.
func brush(from: Vector2, to: Vector2, radius: float, stone: int = -1) -> int:
	var a := from / WORLD
	var b := to / WORLD
	var r := radius / WORLD
	var steps := maxi(1, int(a.distance_to(b) / (r * 0.35)))
	var count := 0
	for k in steps + 1:
		var p := a.lerp(b, float(k) / steps)
		for i in layout.tiles_near(p, r):
			if _start[i] < UNSET or (stone >= 0 and layout.stone[i] != stone):
				continue
			var d := layout.pos[i].distance_to(p) / r
			_schedule(i, now + d * RIPPLE + _rng.randf() * 0.03)
			count += 1
	return count


## Lays everything left in one sweeping wave across the floor.
func lay_rest(seconds: float = 3.0) -> void:
	var span := layout.w + layout.h * 0.4
	for i in layout.tile_count():
		if _start[i] >= UNSET:
			var p := layout.pos[i]
			_schedule(i, now + (p.x + p.y * 0.4) / span * seconds + _rng.randf() * 0.05)


## Lays the floor again in its first order over the given time; tiles never in the order, like an apprentice's, come last.
func replay(sequence: PackedInt32Array, seconds: float) -> void:
	reset()
	if sequence.is_empty():
		lay_rest(seconds)
		return
	var seen := {}
	var once := PackedInt32Array()
	# A floor in the library can list a tile twice, and each tile must land only once for the count of laid tiles to hold.
	for i in sequence:
		if not seen.has(i):
			seen[i] = true
			once.append(i)
	var n := once.size()
	for k in n:
		_schedule(once[k], now + float(k) / maxf(1.0, n) * seconds)
	for i in layout.tile_count():
		if not seen.has(i):
			_schedule(i, now + seconds + _rng.randf() * 0.3)


## Runs a band of light across the whole floor, corner to corner, as it is shown off.
func shine(delay: float, seconds: float) -> void:
	_shimmer_tiles(range(layout.tile_count()), delay, seconds)


## Grouts and polishes the whole floor at once, as a time-lapse's last moment.
func wash(seconds: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_state.fill(int(v))
		_state_dirty = true, 0.0, 255.0, seconds)
	tw.tween_callback(func() -> void:
		_covered = [_floor_total, _floor_total, _floor_total]
		phase = Phase.DONE)


## The stones this floor uses, commonest first.
func stones_used() -> Array:
	var out := _stone_total.keys()
	out.sort_custom(func(a, b) -> bool: return _stone_total[a] > _stone_total[b])
	return out


## Tiles of a stone the brush hasn't reached yet, counting ones still falling as placed.
func stone_unplaced(stone: int) -> int:
	return int(_stone_total.get(stone, 0)) - int(_stone_placed.get(stone, 0))


func stone_left(stone: int) -> int:
	return int(_stone_total.get(stone, 0)) - int(_stone_laid.get(stone, 0))


func ground_left() -> int:
	var n := 0
	for st in _stone_total:
		if Stones.is_ground(st):
			n += stone_left(st)
	return n


## Turns the floor into an old one found under the dirt: every tile is down except the missing ones, all buried.
func setup_restoration(holes: PackedInt32Array) -> void:
	for i in holes:
		missing[i] = true
	for i in layout.tile_count():
		if missing.has(i):
			continue
		_start[i] = now - 30.0
		_landed_mm.set_instance_custom_data(i, Color(_start[i], _packed[i], -100.0, layout.angle[i]))
		laid += 1
	_bury()
	_chalk.visible = false
	phase = Phase.DIG
	var dirt := Sprite2D.new()
	dirt.texture = _state_tex
	dirt.centered = false
	dirt.scale = Vector2(WORLD, WORLD) * STATE_DIV
	dirt.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/dirt.gdshader")
	mat.set_shader_parameter("size_px", Vector2(layout.w, layout.h))
	dirt.material = mat
	add_child(dirt)
	move_child(dirt, get_child_count() - 2)
	_finish_mats.append(mat)
	_rings = Node2D.new()
	_rings.draw.connect(_draw_rings)
	add_child(_rings)
	phase_changed.emit(phase)


## Dirt over an old floor, thick in places and worn thin in others, so parts of the picture already show.
func _bury() -> void:
	var sw := _state_w()
	var sh := _state_h()
	var noise := SoftNoise.field(sw, sh, 14.0, _rng)
	_covered[2] = 0
	for y in sh:
		for x in sw:
			var clear := clampf((noise[y * sw + x] - 0.06) * 3.2, 0.0, 1.0)
			_state[(y * sw + x) * 3 + 2] = int(clear * 255.0)
			if clear >= 0.5 and _floor_cells[y * sw + x] == 1:
				_covered[2] += 1
	_state_dirty = true


## Fills the gap nearest the brush with the chosen stone, one tile at a time along the stroke. Returns how many.
func repair(from: Vector2, to: Vector2, radius: float) -> int:
	if phase != Phase.REPAIR or repair_stone < 0:
		return 0
	var count := 0
	for p in _stroke_points(from, to, radius):
		for i in _under(p, radius, func(t: int) -> bool: return missing.has(t) and not repaired.has(t)):
			repaired[i] = repair_stone
			_packed[i] = repair_stone * 1000 + fmod(_packed[i], 1000.0)
			_schedule(i, now + _rng.randf() * 0.02)
			count += 1
	return count


## Lifts out the mended tile nearest the brush, so a wrong stone can be replaced. Returns how many it lifted.
func lift(from: Vector2, to: Vector2, radius: float) -> int:
	if phase != Phase.REPAIR:
		return 0
	var count := 0
	for p in _stroke_points(from, to, radius):
		for i in _under(p, radius, func(t: int) -> bool: return repaired.has(t) and now >= _start[t] + DROP):
			repaired.erase(i)
			_stone_laid[layout.stone[i]] = int(_stone_laid.get(layout.stone[i], 0)) - 1
			laid -= 1
			var at := order.rfind(i)
			if at >= 0:
				order.remove_at(at)
			_start[i] = UNSET
			_landed_mm.set_instance_custom_data(i, Color(UNSET, _packed[i], -100.0, layout.angle[i]))
			count += 1
	return count


## The tiles a mending brush reaches at one point: only the nearest while it is one tile wide, so a click never sets two.
func _under(p: Vector2, radius: float, wanted: Callable) -> Array:
	if radius <= tile_world():
		var i := _nearest(p, radius / WORLD, wanted)
		return [] if i < 0 else [i]
	return Array(layout.tiles_near(p, radius / WORLD)).filter(wanted)


## Fills every gap with the stone it had, for recordings made without a hand on the mouse.
func mend_all() -> void:
	for i in missing:
		if not repaired.has(i):
			repaired[i] = layout.stone[i]
			_schedule(i, now + _rng.randf() * 0.5)


## Puts tiles down at once, already laid, as a picture panel made earlier at the bench comes.
func prelay(tiles: PackedInt32Array) -> void:
	for i in tiles:
		if _start[i] != UNSET:
			continue
		_start[i] = now - 30.0
		_landed_mm.set_instance_custom_data(i, Color(_start[i], _packed[i], -100.0, layout.angle[i]))
		laid += 1
		order.append(i)
		_stone_placed[layout.stone[i]] = _stone_placed.get(layout.stone[i], 0) + 1
		_stone_laid[layout.stone[i]] = _stone_laid.get(layout.stone[i], 0) + 1
		_patch_left[layout.patch[i]] -= 1
		_rub_chalk(layout.pos[i], layout.size[i] * 0.75)


## How many gaps of an old floor are still without a stone.
func gaps_left() -> int:
	return missing.size() - repaired.size()


func _draw_rings() -> void:
	if phase != Phase.REPAIR or gaps_left() >= RING_GAPS_BELOW:
		return
	var glow := Color(1.0, 0.84, 0.36, 0.55 + 0.35 * sin(now * 4.0))
	for i in missing:
		if not repaired.has(i):
			_rings.draw_arc(layout.pos[i] * WORLD, layout.size[i] * WORLD * 2.2, 0.0, TAU, 24, glow, maxf(3.0, tile_world() * 0.3))


## Whether every gap has a stone in it, so the mending can be called done.
func repairs_done() -> bool:
	return phase == Phase.REPAIR and repaired.size() >= missing.size() and _flying.is_empty()


func finish_repairs() -> void:
	if repairs_done():
		phase = Phase.GROUT
		phase_changed.emit(phase)


## Gives some tiles different stones, as the player mended them, for showing a restored floor as it really ended up.
func apply_stones(stones: Dictionary) -> void:
	for k in stones:
		var i := int(k)
		if i < 0 or i >= layout.tile_count():
			continue
		_packed[i] = int(stones[k]) * 1000 + fmod(_packed[i], 1000.0)
		_landed_mm.set_instance_custom_data(i, Color(_start[i], _packed[i], -100.0, layout.angle[i]))


func _stroke_points(from: Vector2, to: Vector2, radius: float) -> Array:
	var a := from / WORLD
	var b := to / WORLD
	var steps := maxi(1, int(a.distance_to(b) / maxf(radius / WORLD * 0.5, 0.5)))
	var out := []
	for k in steps + 1:
		out.append(a.lerp(b, float(k) / steps))
	return out


func _nearest(p: Vector2, r: float, wanted: Callable) -> int:
	var best := -1
	var best_d := INF
	for i in layout.tiles_near(p, r):
		var d := layout.pos[i].distance_to(p)
		if d < best_d and wanted.call(i):
			best = i
			best_d = d
	return best


## How closely the stones chosen for the gaps match the ones the old floor had, from 0 to 1.
func repair_score() -> float:
	if missing.is_empty():
		return 1.0
	var total := 0.0
	for i in missing:
		if repaired.has(i):
			total += 1.0 - minf(1.0, Stones.difference(Stones.id_of(layout.stone[i]), Stones.id_of(repaired[i])) * 2.5)
	return total / missing.size()


## Shows the floor finished, grouted and polished, as it looks in the client's house.
func show_finished() -> void:
	for i in layout.tile_count():
		_start[i] = now - 30.0
		_landed_mm.set_instance_custom_data(i, Color(_start[i], _packed[i], -100.0, layout.angle[i]))
	laid = layout.tile_count()
	_done = true
	_state.fill(255)
	_covered = [_floor_total, _floor_total, _floor_total]
	_state_dirty = true
	_chalk.visible = false
	phase = Phase.DONE


func reset() -> void:
	for i in layout.tile_count():
		_start[i] = UNSET
		_shimmer[i] = -100.0
		_landed_mm.set_instance_custom_data(i, Color(UNSET, _packed[i], -100.0, layout.angle[i]))
	for j in ACTIVE_CAP:
		_active_mm.set_instance_custom_data(j, Color(UNSET, 0.0, -100.0, 0.0))
	_flying.clear()
	_stone_laid.clear()
	_stone_placed.clear()
	_state.fill(0)
	_covered = [0, 0, 0]
	_state_dirty = true
	phase = Phase.LAY
	phase_changed.emit(phase)
	_chalk_img.copy_from(_chalk_fresh)
	_chalk_tex.update(_chalk_img)
	laid = 0
	_done = false
	_reset_patches()


func _process(delta: float) -> void:
	now += delta
	for m in _materials:
		m.set_shader_parameter("now", now)
	for m in _finish_mats:
		m.set_shader_parameter("now", now)
	if _rings and phase == Phase.REPAIR:
		_rings.queue_redraw()
	if _state_dirty:
		_state_dirty = false
		_state_img.set_data(_state_w(), _state_h(), false, Image.FORMAT_RGB8, _state)
		_state_tex.update(_state_img)
	var still := PackedInt32Array()
	var batch := PackedInt32Array()
	for i in _flying:
		if now >= _start[i] + DROP:
			batch.append(layout.stone[i])
			_landed(i)
		else:
			still.append(i)
	_flying = still
	if _chalk_dirty:
		_chalk_dirty = false
		_chalk_tex.update(_chalk_img)
	if not batch.is_empty():
		tiles_landed.emit(batch)


func _schedule(i: int, t: float) -> void:
	_start[i] = t
	_stone_placed[layout.stone[i]] = _stone_placed.get(layout.stone[i], 0) + 1
	var cd := Color(t, _packed[i], _shimmer[i], layout.angle[i])
	_landed_mm.set_instance_custom_data(i, cd)
	_active_mm.set_instance_transform_2d(_active_next, _xf[i])
	_active_mm.set_instance_custom_data(_active_next, cd)
	_active_next = (_active_next + 1) % ACTIVE_CAP
	_flying.append(i)


func _landed(i: int) -> void:
	laid += 1
	order.append(i)
	_stone_laid[layout.stone[i]] = _stone_laid.get(layout.stone[i], 0) + 1
	_rub_chalk(layout.pos[i], layout.size[i] * 0.75)
	var p := layout.patch[i]
	_patch_left[p] -= 1
	if _patch_left[p] == 0 and not Stones.is_ground(layout.stone[i]):
		_shimmer_tiles(_patch_tiles[p], 0.05, 0.45)
		patch_finished.emit(layout.stone[i])
	if phase == Phase.REPAIR:
		return
	if laid == layout.tile_count() and not _done and phase == Phase.LAY:
		_done = true
		var centre := Vector2(layout.w, layout.h) * 0.5
		var far := centre.length()
		for t in layout.tile_count():
			_set_shimmer(t, now + 0.35 + layout.pos[t].distance_to(centre) / far * 1.2)
		floor_finished.emit()
		phase = Phase.GROUT
		phase_changed.emit(phase)


## Runs a band of light across a group of tiles, from one corner of the group to the other.
func _shimmer_tiles(tiles: Array, delay: float, sweep: float) -> void:
	var lo := INF
	var hi := -INF
	for t in tiles:
		var k := layout.pos[t].x + layout.pos[t].y * 0.5
		lo = minf(lo, k)
		hi = maxf(hi, k)
	var span := maxf(hi - lo, 1.0)
	for t in tiles:
		var k := layout.pos[t].x + layout.pos[t].y * 0.5
		_set_shimmer(t, now + delay + (k - lo) / span * sweep)


func _set_shimmer(t: int, at: float) -> void:
	_shimmer[t] = at
	_landed_mm.set_instance_custom_data(t, Color(_start[t], _packed[t], at, layout.angle[t]))


func _reset_patches() -> void:
	_patch_left.clear()
	for p in _patch_tiles:
		_patch_left[p] = _patch_tiles[p].size()


func _make_batch(count: int, layer_id: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = _quad
	mm.instance_count = count
	var node := MultiMeshInstance2D.new()
	node.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/tile.gdshader")
	mat.set_shader_parameter("layer", layer_id)
	mat.set_shader_parameter("palette", _palette())
	mat.set_shader_parameter("drop_time", DROP)
	mat.set_shader_parameter("settle_time", SETTLE)
	mat.set_shader_parameter("active_life", ACTIVE_LIFE)
	node.material = mat
	add_child(node)
	_materials.append(mat)
	return mm


func _palette() -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(16)
	for i in Stones.LIST.size():
		var c: Color = Stones.LIST[i]["tile"]
		out[i] = Color(c.r, c.g, c.b, Stones.LIST[i]["material"] / 10.0)
	return out


func _quad_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([
		Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5),
		Vector2(-0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## The bare mortar bed, with the design sketched on it in red chalk the way Roman craftsmen marked out a floor.
func _add_mortar() -> void:
	var w := layout.w
	var h := layout.h
	var bed := Image.create(w, h, false, Image.FORMAT_RGB8)
	var chalk := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := SoftNoise.field(w, h, 12.0, _rng)
	for y in h:
		for x in w:
			var n := noise[y * w + x] * 0.05 + (_rng.randf() - 0.5) * 0.05
			var i := y * w + x
			var s := layout.labels[i]
			if s == Stones.NO_TILE:
				bed.set_pixel(x, y, Color(0.8 + n * 0.4, 0.74 + n * 0.4, 0.63 + n * 0.4))
				continue
			bed.set_pixel(x, y, Color(0.6 + n, 0.565 + n, 0.51 + n))
			if (x < w - 1 and layout.labels[i + 1] != s) or (y < h - 1 and layout.labels[i + w] != s):
				chalk.set_pixel(x, y, Color(0.7, 0.3, 0.22, 0.5))
	_state.resize(_state_w() * _state_h() * 3)
	for i in _state_w() * _state_h():
		_state[i * 3 + 2] = 255
	_floor_cells.resize(_state_w() * _state_h())
	_floor_cells.fill(0)
	for i in w * h:
		if layout.labels[i] != Stones.NO_TILE:
			_floor_cells[(i / w) / STATE_DIV * _state_w() + (i % w) / STATE_DIV] = 1
	_floor_total = maxi(1, _floor_cells.count(1))
	_state_img = Image.create_from_data(_state_w(), _state_h(), false, Image.FORMAT_RGB8, _state)
	_state_tex = ImageTexture.create_from_image(_state_img)
	var bed_sprite := Sprite2D.new()
	var mortar := ShaderMaterial.new()
	mortar.shader = load("res://shaders/mortar.gdshader")
	mortar.set_shader_parameter("state", _state_tex)
	bed_sprite.material = mortar
	bed_sprite.texture = ImageTexture.create_from_image(bed)
	bed_sprite.centered = false
	bed_sprite.scale = Vector2(WORLD, WORLD)
	add_child(bed_sprite)
	_chalk_img = chalk
	_chalk_fresh = chalk.duplicate()
	_chalk_tex = ImageTexture.create_from_image(chalk)
	_chalk = Sprite2D.new()
	_chalk.texture = _chalk_tex
	_chalk.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_chalk.centered = false
	_chalk.scale = Vector2(WORLD, WORLD)
	add_child(_chalk)
	var labels := PackedByteArray()
	labels.resize(w * h)
	for i in w * h:
		labels[i] = layout.labels[i]
	var guide := Sprite2D.new()
	guide.texture = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_R8, labels))
	guide.centered = false
	guide.scale = Vector2(WORLD, WORLD)
	_guide = ShaderMaterial.new()
	_guide.shader = load("res://shaders/guide.gdshader")
	guide.material = _guide
	_finish_mats.append(_guide)
	add_child(guide)


## Lights up the places a stone goes, or nothing with -1.
func guide(stone: int) -> void:
	_guide.set_shader_parameter("chosen", float(stone))
	if stone >= 0:
		_guide.set_shader_parameter("tint", Stones.LIST[stone]["tile"])


## Wipes along a stroke: the sponge grouts (0), the cloth polishes grouted floor (1), or dirt clears (2). Returns 0 to 1.
func paint(from: Vector2, to: Vector2, radius: float, ch: int = 0) -> float:
	if phase == Phase.DIG:
		ch = 2
	elif phase != Phase.GROUT or ch > 1:
		return 0.0
	var sw := _state_w()
	var sh := _state_h()
	var a := from / (WORLD * STATE_DIV)
	var b := to / (WORLD * STATE_DIV)
	var r := radius / (WORLD * STATE_DIV)
	var before: int = _covered[ch]
	var steps := maxi(1, int(a.distance_to(b) / (r * 0.3)))
	for k in steps + 1:
		var c := a.lerp(b, float(k) / steps)
		for y in range(maxi(int(c.y - r), 0), mini(int(c.y + r), sh - 1) + 1):
			for x in range(maxi(int(c.x - r), 0), mini(int(c.x + r), sw - 1) + 1):
				var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / r
				if d >= 1.0:
					continue
				var v := int(clampf((1.0 - d) * 2.2, 0.0, 1.0) * 255.0)
				var i := (y * sw + x) * 3 + ch
				if ch == 1:
					v = mini(v, _state[(y * sw + x) * 3])
				var old := _state[i]
				if v > old:
					_state[i] = v
					if old < 128 and v >= 128 and _floor_cells[y * sw + x] == 1:
						_covered[ch] += 1
	_state_dirty = true
	var total := float(_floor_total)
	if _covered[ch] / total >= FINISH_AT[ch]:
		_finish_channel(ch)
	return (_covered[ch] - before) / total


## How far the job in hand has come, from 0 to 1, for the bar at the top of the screen.
func progress() -> float:
	var total := float(_floor_total)
	match phase:
		Phase.LAY:
			return float(laid) / maxf(1.0, layout.tile_count())
		Phase.DIG:
			return minf(1.0, _covered[2] / total / FINISH_AT[2])
		Phase.REPAIR:
			return float(repaired.size()) / maxf(1.0, missing.size())
		Phase.GROUT:
			return (minf(1.0, _covered[0] / total / FINISH_AT[0]) + minf(1.0, _covered[1] / total / FINISH_AT[1])) * 0.5
	return 1.0


func coverage() -> float:
	var total := float(_floor_total)
	if phase == Phase.GROUT:
		return (_covered[0] + _covered[1]) * 0.5 / total
	if phase == Phase.POLISH:
		return _covered[1] / total
	if phase == Phase.DIG:
		return _covered[2] / total
	if phase == Phase.REPAIR:
		return float(repaired.size()) / maxf(1.0, missing.size())
	return 1.0 if phase == Phase.DONE else 0.0


func _state_w() -> int:
	return int(ceil(float(layout.w) / STATE_DIV))


func _state_h() -> int:
	return int(ceil(float(layout.h) / STATE_DIV))


## The last few specks are filled in by themselves, so nobody has to hunt for them.
func _finish_channel(ch: int) -> void:
	if phase == Phase.DONE:
		return
	var all := _state_w() * _state_h()
	for i in all:
		_state[i * 3 + ch] = 255
	_covered[ch] = _floor_total
	_state_dirty = true
	if ch == 2:
		phase = Phase.REPAIR if not missing.is_empty() else Phase.GROUT
		phase_changed.emit(phase)
		return
	if _covered[0] < _floor_total or _covered[1] < _floor_total:
		return
	phase = Phase.DONE
	if phase == Phase.DONE:
		_shimmer_tiles(range(layout.tile_count()), 0.1, 1.2)
	phase_changed.emit(phase)


func _add_finish_layers() -> void:
	for path in ["res://shaders/film.gdshader", "res://shaders/sheen.gdshader"]:
		var s := Sprite2D.new()
		s.texture = _state_tex
		s.centered = false
		s.scale = Vector2(WORLD, WORLD) * STATE_DIV
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var mat := ShaderMaterial.new()
		mat.shader = load(path)
		mat.set_shader_parameter("size_px", Vector2(layout.w, layout.h))
		s.material = mat
		_finish_mats.append(mat)
		add_child(s)


## A laid tile covers the chalk beneath it, so its outline doesn't show through the gaps.
func _rub_chalk(p: Vector2, r: float) -> void:
	var x0 := maxi(int(p.x - r), 0)
	var x1 := mini(int(p.x + r), layout.w - 1)
	var y0 := maxi(int(p.y - r), 0)
	var y1 := mini(int(p.y + r), layout.h - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_chalk_img.set_pixel(x, y, Color(0, 0, 0, 0))
	_chalk_dirty = true


func _draw_walls(c: Node2D) -> void:
	var fw := layout.w * WORLD
	var fh := layout.h * WORLD
	var t := WALL * tile_world()
	var plaster := Color8(204, 188, 160)
	var face := Color8(150, 128, 104)
	c.draw_rect(Rect2(-t, -t, fw + 2 * t, t), plaster)
	c.draw_rect(Rect2(-t, 0, t, fh), plaster)
	c.draw_rect(Rect2(fw, 0, t, fh), plaster)
	var door := 16 * tile_world() if door_visible else 0.0
	var door_x := (fw - door) * 0.5
	c.draw_rect(Rect2(-t, fh, door_x + t, t), plaster)
	c.draw_rect(Rect2(door_x + door, fh, fw - door_x - door + t, t), plaster)
	# The doorway: a marble threshold the wall's full depth, a groove where the door closes, and a post each side.
	c.draw_rect(Rect2(door_x, fh, door, t), Color8(198, 190, 176))
	c.draw_rect(Rect2(door_x, fh + t * 0.42, door, t * 0.12), Color8(150, 142, 130))
	c.draw_rect(Rect2(door_x - t * 0.3, fh, t * 0.3, t), face)
	c.draw_rect(Rect2(door_x + door, fh, t * 0.3, t), face)
	c.draw_rect(Rect2(-t, -t, fw + 2 * t, 6), Color8(228, 214, 190))
	var lip := 10.0
	c.draw_rect(Rect2(0, -lip, fw, lip), face)
	c.draw_rect(Rect2(-lip, 0, lip, fh), face)
	c.draw_rect(Rect2(fw, 0, lip * 0.6, fh), face.lightened(0.15))
	for k in 10:
		var a := 0.22 * (1.0 - k / 10.0)
		c.draw_rect(Rect2(0, k * 5.0, fw, 5.0), Color(0.05, 0.03, 0.02, a))
		c.draw_rect(Rect2(k * 5.0, 0, 5.0, fh), Color(0.05, 0.03, 0.02, a))
