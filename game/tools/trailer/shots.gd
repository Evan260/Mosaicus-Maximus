extends Node
## The trailer's scripted shots: each starts a fresh workshop that is never saved, opens its screens and plays them with
## a drawn pointer that moves onto what it clicks and sets it off, so tools/trailer/make_trailer.py records it the same
## way every time. Started by main.gd.

const INK := Color(0.29, 0.18, 0.14)
## The doves' and the flower's sizes in tiles on her floor, which together earn all five stars.
const DOVE_SIZE := 13.0
const DOVE_FLOWER := 15.0
const CREAM := Color(0.99, 0.95, 0.86)

var shot := ""
var _pointer: Sprite2D
var _ring: Sprite2D
var _scale := 4.0
var _job := {}


func _ready() -> void:
	shot = Dev.get_arg("trailer-shot")
	Saves.enabled = false
	Library.enabled = false
	Audio.music_on = false
	Tips.process_mode = Node.PROCESS_MODE_DISABLED
	# A shot that opens a later chapter at once would otherwise earn its achievement on screen.
	Awards.process_mode = Node.PROCESS_MODE_DISABLED
	# The shots were framed for an interface as large as the pictures, the largest whole scale that fits.
	var frame := get_viewport().get_visible_rect().size
	Nav.ui_scale_override = maxi(1, int(minf(frame.x / Nav.BASE.x, frame.y / Nav.BASE.y)))
	Nav.refit()
	_scale = float(Nav.scale_factor())
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_pointer = Sprite2D.new()
	_pointer.texture = _arrow()
	_pointer.centered = false
	_pointer.scale = Vector2.ONE * _scale
	_pointer.visible = false
	layer.add_child(_pointer)
	_ring = Sprite2D.new()
	_ring.texture = _ring_texture()
	_ring.modulate.a = 0.0
	layer.add_child(_ring)
	# The real mouse plays no part: wherever it rests would light up what it is over.
	get_tree().root.set_disable_input(true)
	_new_workshop()
	call("_shot_" + shot)


## A new workshop on its first morning, its guide notes and letters already read. For the first job's shots it is
## already in its second chapter, so Livia the bride-to-be is first on the board.
func _new_workshop() -> void:
	Game.new_game("Marcus")
	Game.state["story_seen"].append("intro")
	Game.state["guide_off"] = true
	if shot in ["client", "design", "floor"] or shot.begins_with("react_"):
		Story.unlock(Game.state, 2)
	# The same seed every time, so every shot shows the same board and the same clients.
	Game.state["seed"] = 72
	Story.morning(Game.state)
	Game.state["pending_events"] = []
	var board: Array = Game.state["board"]
	var hers := board.filter(func(j: Dictionary) -> bool: return str(j.get("client", "")) == "livia")
	if hers.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 72
		hers = [JobFactory._named("livia", Game.state, rng)]
		board.pop_back()
	board.erase(hers[0])
	board.push_front(hers[0])
	_job = hers[0]


## Her job as agreed: the asking price shaken on, and her bedroom floor on the table with its border chosen.
func _agreed_job() -> Dictionary:
	var job := _job.duplicate(true)
	job["asked"] = job["budget"]
	job["expected"] = 0.5
	var start := FloorDesign.for_room(job["room"])
	_frame(start)
	job["design"] = start.to_dict()
	Game.state["active_job"] = job
	return job


## Two doves facing each other across a flower in the middle of her bedroom, the way she asked for them.
func _first_floor() -> FloorDesign:
	var design := FloorDesign.for_room(_job["room"])
	_frame(design)
	design.add("flower", design.w * 0.5, design.h * 0.5, DOVE_FLOWER)
	design.add("dove", snappedf(design.w * 0.2, 0.5), design.h * 0.5, DOVE_SIZE, 0, true)
	design.add("dove", snappedf(design.w * 0.8, 0.5), design.h * 0.5, DOVE_SIZE)
	_no_black(design)
	return design


## A plain band in the green marble she loves.
func _frame(design: FloorDesign) -> void:
	design.set_border("plain")
	design.border["stones"] = ["white_marble", "green_marble", "green_marble", "green_marble"]


## She will have no black stone, so the doves' dark eyes and edges are laid in brown, and the rest in stone the
## workshop has.
func _no_black(design: FloorDesign) -> void:
	for p in design.placements:
		for k in p["stones"]:
			p["stones"][k] = "brown_stone" if p["stones"][k] == "black_stone" else Stones.nearest(p["stones"][k], Game.state["unlocked_stones"])
		if str(p.get("outline", "")) != "":
			p["outline"] = "brown_stone"


# Shots -------------------------------------------------------------------

## The workshop as the uncle left it, at first light, the dog still asleep in its basket.
func _shot_dawn() -> void:
	Game.state["hour"] = 6.3
	Dev.args["hour"] = "6.3"
	Nav.go("workshop")


## The first client: the job board is opened, Livia is chosen, and the price is agreed with a handshake.
func _shot_client() -> void:
	Dev.args["hour"] = "8.5"
	Nav.go("workshop")
	await _wait(1.2)
	var workshop: Node = Nav.current
	_pointer.position = Vector2(1700, 980)
	_pointer.visible = true
	await _click_spot(workshop._layers["board"])
	await _wait(1.3)
	await _press(_button_near(Nav.ui, "See her", str(_job.get("client_name", ""))))
	await _wait(1.6)
	var visit: Node = Nav.current
	var slider: HSlider = visit._price
	await _slide(slider, minf(slider.max_value, slider.value + (slider.max_value - slider.min_value) * 0.05))
	await _wait(0.6)
	await _press(visit._shake)


## The first design: a dove dragged onto her bedroom, made smaller and paired with a mirror image that faces it, then a
## flower dragged in between them.
func _shot_design() -> void:
	Nav.go("design_table", {"job": _agreed_job()})
	await _wait(1.2)
	var table: Node = Nav.current
	_pointer.position = Vector2(1500, 900)
	_pointer.visible = true
	await _press(table._tab_buttons["pictures"])
	await _wait(0.4)
	await _drag_motif(table, "dove", Vector2(0.8, 0.5))
	_tidy(table)
	await _shrink_to(table, DOVE_SIZE)
	await _wait(0.3)
	await _press(_button_near(Nav.ui, "Pair", ""))
	_tidy(table)
	await _wait(0.6)
	await _press(table._tab_buttons["patterns"])
	await _wait(0.4)
	await _drag_motif(table, "flower", Vector2(0.5, 0.5))
	_tidy(table)
	await _shrink_to(table, DOVE_FLOWER)
	await _wait(0.8)
	_pointer.visible = false


## Keeps the table's design in the stones she allows, and draws it again.
func _tidy(table: Node) -> void:
	_no_black(table.design)
	table._dirty = true
	table._cost_dirty = true
	table._refresh_chips()


## Turns the scroll wheel over the picked motif until it is the size wanted, a step at a time.
func _shrink_to(table: Node, size: float) -> void:
	var p: Dictionary = table.design.placements[table.selected]
	for k in 12:
		var now := float(p["size"])
		if absf(now - size) < 0.5:
			return
		table._resize(-1 if now > size else 1)
		table._plan.selection = table._rect_of(p)
		await _wait(0.12)


## The first floor laid close up, a stone at a time: white is picked in the tray and swept over the dove, where it
## glows, then red over the flower. The rest is poured in, grouted and polished, then shown in her bedroom.
func _shot_floor() -> void:
	var design := _first_floor()
	var job := _agreed_job()
	job["design"] = design.to_dict()
	job["stone_paid"] = true
	job["stone_taken"] = Composer.stone_counts(design).duplicate()
	# The recording's own sweep never starts; the shot moves the brush itself, and the floor finishes on its own.
	Dev.args.merge({"demo": "", "demo-start": "99999", "fill-at": "8.0", "fill-seconds": "2.6", "finish-demo": "", "finish-seconds": "3.0"}, true)
	Nav.go("floor", {"design": design, "job": job})
	while Nav.current_name != "floor" or Nav.current == null or Nav.current.cursor == null:
		await get_tree().process_frame
	var screen: Node = Nav.current
	var view: FloorView = screen.floor_view
	var cam: Camera2D = screen.cam
	var fit := cam.zoom
	var tw := view.tile_world()
	var dove := _tiles_rect(design.placements[2])
	var flower := _tiles_rect(design.placements[0])
	# The tall frame of a short is filled by the dove alone, then turns to the flower; the wide one shows both.
	if _tall():
		cam.zoom = Vector2.ONE * get_viewport().get_visible_rect().size.x / (dove.size.x * 1.25 * tw)
		cam.position = dove.get_center() * tw
	else:
		cam.zoom = fit * 1.55
		cam.position = Vector2(design.w * 0.66, design.h * 0.5) * tw
	screen.cursor.visible = false
	_pointer.position = (get_viewport().get_visible_rect().size * Vector2(0.62, 0.96)).round()
	await _wait(0.6)
	await _lay_stone(screen, "white_marble", dove.grow(1.0), 2.4)
	if _tall():
		var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		turn.tween_property(cam, "position", flower.get_center() * tw, 0.7)
	await _lay_stone(screen, "red_marble", flower.grow(1.0), 2.0)
	await _wait(0.5)
	var back := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(cam, "zoom", fit, 1.6)
	back.parallel().tween_property(cam, "position", view.size_world() * 0.5, 1.6)
	while view.phase == FloorView.Phase.LAY:
		await get_tree().process_frame
	# The sponge and cloth sweep the floor for a few seconds; the last specks a sweep misses are finished off.
	await _wait(3.4)
	view._finish_channel(0)
	await _wait(0.5)
	view._finish_channel(1)


## Where a motif lies on the floor, in tiles.
func _tiles_rect(p: Dictionary) -> Rect2:
	var t := MotifLibrary.tiles(str(p["motif"]), float(p["size"]))
	return Rect2(Vector2(float(p["x"]), float(p["y"])) - t * 0.5, t)


## Picks a stone in the tray, as a player would, then sweeps the brush row by row over the places it glows in, inside
## an area of the floor given in tiles.
func _lay_stone(screen: Node, stone_id: String, area: Rect2, seconds: float) -> void:
	var st := Stones.index(stone_id)
	_pointer.visible = true
	await _press_with(screen._hud._buttons[st], func() -> void: screen.select_stone(st))
	await _wait(0.3)
	_pointer.visible = false
	var view: FloorView = screen.floor_view
	var tw := view.tile_world()
	var path := _sweep(view, st, Rect2(area.position * tw, area.size * tw), screen.brush_radius())
	if path.size() >= 2:
		await _drag_brush(screen, [path], seconds)


## Moves the brush through each line in turn at a steady pace, as a hand would, lifting it between lines.
func _drag_brush(screen: Node, lines: Array, seconds: float) -> void:
	var length := 0.0
	for n in lines.size():
		var line: PackedVector2Array = lines[n]
		if n > 0:
			length += (lines[n - 1][-1] as Vector2).distance_to(line[0])
		for k in range(1, line.size()):
			length += line[k - 1].distance_to(line[k])
	if length <= 0.0:
		return
	# Each frame the brush covers the same distance, working along a line or, lifted, moving on to the next one.
	var pace := length / (seconds * 30.0)
	screen.cursor.visible = true
	var at: Vector2 = lines[0][0]
	screen._demo_prev = at
	for line in lines:
		var points := PackedVector2Array([line[0]])
		points.append_array(line)
		var leg := 1
		while leg < points.size():
			await get_tree().process_frame
			var step := pace
			while step > 0.0 and leg < points.size():
				var target: Vector2 = points[leg]
				var dist := at.distance_to(target)
				var next := target
				if dist <= step:
					step -= dist
				else:
					next = at.move_toward(target, step)
					step = 0.0
				# The first leg only carries the lifted brush to where the line begins.
				if leg > 1:
					screen._stroke(at, next)
				at = next
				if next == target:
					leg += 1
			screen._demo_prev = at
	screen.cursor.visible = false
	screen._demo_prev = Vector2.INF


## A back-and-forth path through the rows of a stone's unlaid tiles inside an area of the floor, in world pixels.
func _sweep(view: FloorView, st: int, area: Rect2, radius: float) -> PackedVector2Array:
	var pts: Array[Vector2] = []
	for i in view.layout.tile_count():
		var p := view.layout.pos[i] * FloorView.WORLD
		if view.layout.stone[i] == st and view._start[i] >= FloorView.UNSET and area.has_point(p):
			pts.append(p)
	var path := PackedVector2Array()
	if pts.is_empty():
		return path
	var top := pts.map(func(p: Vector2) -> float: return p.y).min() as float
	var bottom := pts.map(func(p: Vector2) -> float: return p.y).max() as float
	var band := radius * 1.3
	var row := 0
	var y := top + band * 0.4
	while y <= bottom + band * 0.5:
		var xs := pts.filter(func(p: Vector2) -> bool: return absf(p.y - y) <= band * 0.6).map(func(p: Vector2) -> float: return p.x)
		if not xs.is_empty():
			var a := Vector2(float(xs.min()), y)
			var b := Vector2(float(xs.max()), y)
			path.append(b if row % 2 == 1 else a)
			path.append(a if row % 2 == 1 else b)
			row += 1
		y += band
	return path


## Bigger floors as the workshop's name spreads, each poured in tile by tile.
func _shot_sea() -> void:
	_pour("sea")


func _shot_villa() -> void:
	_pour("villa")


func _shot_apse() -> void:
	_pour("apse")


func _pour(sample: String) -> void:
	Dev.args.merge({"sample": sample, "no-hud": "", "fill-at": "0.5", "fill-seconds": "3.4"}, true)
	Nav.go("floor", {})
	await _hide_brush()


## Whether this is being recorded for a short, whose frame is taller than it is wide.
func _tall() -> bool:
	var size := get_viewport().get_visible_rect().size
	return size.y > size.x


## Brings the floor closer in a short's tall frame, which would otherwise show it as a thin band across the middle.
func _fill_tall(closer: float, lower := 0.0) -> void:
	while Nav.current_name != "floor" or Nav.current == null or Nav.current.cam == null:
		await get_tree().process_frame
	await get_tree().process_frame
	var screen: Node = Nav.current
	screen.cam.zoom *= closer
	# Lowered by a share of the frame's height, to keep the floor clear of the captions at the top.
	screen.cam.position = screen.floor_view.size_world() * 0.5 - Vector2(0, get_viewport().get_visible_rect().size.y * lower) / screen.cam.zoom


## With no hand on the brush, the floor screen's brush ring would follow wherever the real mouse rests.
func _hide_brush() -> void:
	while Nav.current_name != "floor" or Nav.current == null or Nav.current.cursor == null:
		await get_tree().process_frame
	Nav.current.cursor.visible = false


## A floor found under an old house: the trowel scrapes the dirt away, then the gaps are mended.
func _shot_dig() -> void:
	Dev.args.merge({"sample": "cave", "restore": "0.3", "finish-demo": "", "finish-seconds": "4.0"}, true)
	Nav.go("floor", {})
	if _tall():
		await _fill_tall(1.2, 0.07)


## The dog is woken with a pat, and stands up wagging.
func _shot_dog() -> void:
	Dev.args["hour"] = "11"
	Nav.go("workshop")
	await _wait(1.2)
	var workshop: Node = Nav.current
	_pointer.position = Vector2(1500, 1000)
	_pointer.visible = true
	await _click_spot(workshop._layers["bed"])
	await _wait(0.5)
	await _glide(_pointer.position + Vector2(140, 90), 0.6)


## The workshop grown and lamplit at night, its plants, wine jars and lamps bought with the floors it has laid.
func _shot_night() -> void:
	for id in ["plants", "amphorae", "lamps", "big_brush", "cutting_bench"]:
		if not id in Game.state["upgrades"]:
			Game.state["upgrades"].append(id)
	Dev.args["hour"] = "21.5"
	Nav.go("workshop")


## The finished sea floor behind the logo at the end.
func _shot_endcard() -> void:
	Dev.args.merge({"sample": "sea", "no-hud": ""}, true)
	Nav.go("floor", {})
	await _hide_brush()
	Nav.current.floor_view.show_finished()
	if _tall():
		await _fill_tall(2.2)


# Shorts -------------------------------------------------------------------------

## The dog of each breed in its basket, woken with a pat; the shorts frame the basket close up.
func _shot_pet_hound() -> void:
	await _pet({"breed": "hound", "coat": "golden", "name": "Rufus"})


func _shot_pet_molossian() -> void:
	await _pet({"breed": "molossian", "coat": "natural", "name": "Brutus"})


func _shot_pet_sighthound() -> void:
	await _pet({"breed": "sighthound", "coat": "natural", "name": "Celer"})


func _shot_pet_lapdog() -> void:
	await _pet({"breed": "lapdog", "coat": "natural", "name": "Pupa"})


func _shot_pet_sheepdog() -> void:
	await _pet({"breed": "sheepdog", "coat": "natural", "name": "Lupus"})


func _pet(dog: Dictionary) -> void:
	Game.state["dog"] = dog
	Dev.args["hour"] = "11"
	Nav.go("workshop")
	await _screen_open("workshop")
	var workshop: Node = Nav.current
	var bed: Control = workshop._layers["bed"]
	# The room's painting is just tall enough for the frame, so it is centred up and down, and on the basket across.
	await _zoom_ui(7.0, Vector2(bed.get_global_rect().get_center().x, (workshop._scene as Control).get_global_rect().get_center().y))
	_pointer.position = (get_viewport().get_visible_rect().size * Vector2(0.85, 0.95)).round()
	await _wait(0.6)
	await _click_spot(bed)
	await _wait(0.4)
	await _glide(_pointer.position + Vector2(220, 160), 0.6)


## An old floor under a house, close on its picture: the trowel is picked and the dirt scraped from all round the
## picture first, the words CAVE CANEM coming up as a clue, and from the guard dog itself last.
func _shot_guess_dig() -> void:
	Dev.args.merge({"sample": "cave", "restore": "0.3", "demo": "", "demo-start": "99999"}, true)
	Nav.go("floor", {})
	await _hide_brush()
	var screen: Node = Nav.current
	var view: FloorView = screen.floor_view
	var dog: Dictionary = (screen.design.placements as Array).filter(func(p: Dictionary) -> bool: return p["motif"] == "dog")[0]
	var tw := view.tile_world()
	var r := _tiles_rect(dog)
	var cam: Camera2D = screen.cam
	var frame := get_viewport().get_visible_rect().size
	cam.zoom = Vector2.ONE * frame.x / (r.size.x * 1.35 * tw)
	cam.position = r.get_center() * tw
	_pointer.position = (frame * Vector2(0.7, 0.97)).round()
	await _wait(0.5)
	_pointer.visible = true
	await _press_with(screen._hud._buttons["trowel"], func() -> void: screen.select_tool("trowel"))
	await _wait(0.3)
	_pointer.visible = false
	# A small trowel, so all of it is on the floor and each pass clears a narrow band, the way a careful hand works.
	screen.brush_tiles = 2.0
	var radius: float = screen.brush_radius()
	var seen := Rect2(cam.position - frame / cam.zoom * 0.5, frame / cam.zoom).intersection(Rect2(Vector2.ZERO, view.size_world()))
	var hidden := Rect2(r.position * tw, r.size * tw).grow(radius * 0.4)
	# Back and forth, row by row, lifting the trowel over the picture so it stays buried until the end.
	var around: Array[PackedVector2Array] = []
	var left := seen.position.x + radius * 0.6
	var right := seen.end.x - radius * 0.6
	var y := seen.position.y + radius
	var row := 0
	while y < seen.end.y - radius:
		var parts: Array[PackedVector2Array] = []
		if y > hidden.position.y and y < hidden.end.y:
			parts = [PackedVector2Array([Vector2(left, y), Vector2(hidden.position.x, y)]), PackedVector2Array([Vector2(hidden.end.x, y), Vector2(right, y)])]
		else:
			parts = [PackedVector2Array([Vector2(left, y), Vector2(right, y)])]
		if row % 2 == 1:
			parts.reverse()
			for k in parts.size():
				var back := parts[k]
				back.reverse()
				parts[k] = back
		around.append_array(parts)
		row += 1
		y += radius * 1.2
	await _drag_brush(screen, around, 7.0)
	await _wait(0.6)
	var last: Array[PackedVector2Array] = []
	row = 0
	y = hidden.position.y + radius * 0.4
	while y < hidden.end.y:
		last.append(PackedVector2Array([Vector2(hidden.end.x if row % 2 else hidden.position.x, y), Vector2(hidden.position.x if row % 2 else hidden.end.x, y)]))
		row += 1
		y += radius * 1.2
	await _drag_brush(screen, last, 3.0)
	await _wait(0.8)
	view._finish_channel(2)


## The first floor a new workshop lays: one black and white rosette in an entrance hall, poured in and finished.
func _shot_first_pour() -> void:
	var d := FloorDesign.for_room("vestibule")
	d.set_border("plain")
	d.add("rosette", d.w * 0.5, d.h * 0.5, 14)
	await _pour_design(d, 3.0)


## A floor from late in the game: a villa dining room's, with its peacocks and coloured marble, poured in and finished.
func _shot_last_pour() -> void:
	await _pour_design(Samples.make("villa"), 4.0)


func _pour_design(design: FloorDesign, seconds: float) -> void:
	Dev.args.merge({"no-hud": "", "fill-at": "0.4", "fill-seconds": str(seconds)}, true)
	Nav.go("floor", {"design": design})
	await _hide_brush()
	await _wait(seconds + 1.0)
	Nav.current.floor_view.show_finished()


## The town's forum, its floor poured in from close on one corner while the view pulls back to show all of it.
func _shot_forum_pour() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	Dev.args.merge({"no-hud": "", "fill-at": "0.5", "fill-seconds": "6.5"}, true)
	Nav.go("floor", {"design": RandomDesign.make("forum", 4, rng)})
	await _hide_brush()
	var screen: Node = Nav.current
	var cam: Camera2D = screen.cam
	var fit := cam.zoom
	var world: Vector2 = screen.floor_view.size_world()
	cam.zoom = fit * 6.0
	cam.position = Vector2(world.x * 0.05, world.y * 0.16)
	# A floor this big takes a moment to set out, so the view pulls back only once its first tiles are landing.
	while screen.floor_view.laid == 0:
		await get_tree().process_frame
	await _wait(1.4)
	var out := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	out.tween_property(cam, "zoom", fit, 5.5)
	out.parallel().tween_property(cam, "position", world * 0.5, 5.5)


## A client's floor shown in their own room, close on the room; the short's caption carries their verdict.
func _shot_react_cornelia() -> void:
	var d := FloorDesign.for_room("vestibule")
	d.set_border("plain")
	d.add("dog", d.w * 0.5, d.h * 0.5, roundf(minf(d.w, d.h) * 0.6))
	_in_workshop_stones(d)
	await _react("cornelia", d)


func _shot_react_gaius() -> void:
	await _react("gaius", Samples.make("sea"))


func _shot_react_trimalchio() -> void:
	var d := FloorDesign.for_room("dining_room")
	d.set_border("dentil")
	d.add("loaves", d.w * 0.5, d.h * 0.5, roundf(minf(d.w, d.h) * 0.42))
	d.add("amphora", d.w * 0.22, d.h * 0.5, roundf(minf(d.w, d.h) * 0.4))
	d.add("amphora", d.w * 0.78, d.h * 0.5, roundf(minf(d.w, d.h) * 0.4), 0, true)
	await _react("trimalchio", d)


func _shot_react_livia() -> void:
	await _react("livia", _first_floor())


func _react(id: String, design: FloorDesign) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 72
	var job := JobFactory._named(id, Game.state, rng)
	job["asked"] = job["budget"]
	job["expected"] = 0.5
	if id == "livia":
		_job = job
	Nav.go("reveal", {"design": design, "job": job})
	await _screen_open("reveal")
	for k in 120:
		if Nav.current._room != null:
			break
		await get_tree().process_frame
	var room: Control = Nav.current._room
	var painted := _painted_rect("res://assets/art/rooms/%s.png" % design.room)
	# The room's picture is painted right of its middle, leaving room for the client's card; the painted part is
	# centred across the frame and set low, under the caption.
	await _zoom_ui(3.0, room.get_global_rect().position + painted.get_center() - Vector2(0, 50))
	# The short's caption carries the client's words, so their card, half out of the frame, is put away.
	Nav.current._card.visible = false


## The motifs in the stones the workshop has, so a floor from the first chapter is laid as the player could lay it.
func _in_workshop_stones(design: FloorDesign) -> void:
	for p in design.placements:
		for k in p["stones"]:
			p["stones"][k] = Stones.nearest(p["stones"][k], Game.state["unlocked_stones"])


## The part of a room's picture that is painted, rather than the dark ground around the room, in its own pixels.
func _painted_rect(path: String) -> Rect2:
	var img: Image = load(path).get_image()
	var ground := img.get_pixel(2, 2)
	var found := Rect2()
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if absf(c.r - ground.r) + absf(c.g - ground.g) + absf(c.b - ground.b) > 0.16:
				found = Rect2(x, y, 1, 1) if found.size == Vector2.ZERO else found.expand(Vector2(x, y))
	return found


func _screen_open(name: String) -> void:
	while Nav.current_name != name or Nav.current == null:
		await get_tree().process_frame
	await get_tree().process_frame


## Shows the interface a whole number of times larger, with a point of it, in interface pixels, in the middle of the
## frame; the pointer grows with it.
func _zoom_ui(k: float, at: Vector2) -> void:
	await get_tree().process_frame
	var size := get_viewport().get_visible_rect().size
	var shift := (size * 0.5 - at * k).round()
	Nav.ui_layer.transform = Transform2D(0.0, Vector2(k, k), 0.0, shift)
	var p := float(Nav.picture_scale()) / Nav.scale_factor()
	Nav.pictures_layer.transform = Transform2D(0.0, Vector2(k * p, k * p), 0.0, shift + Nav.picture_origin() / Nav.scale_factor() * k)
	_scale = k
	_pointer.scale = Vector2.ONE * k


# The pointer ------------------------------------------------------------------

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## The middle of a control, in screen pixels.
func _centre(c: Control) -> Vector2:
	return (c.get_global_transform_with_canvas() * (c.size * 0.5)).round()


func _slider_point(s: HSlider, value: float) -> Vector2:
	var u := (value - s.min_value) / maxf(0.001, s.max_value - s.min_value)
	return (s.get_global_transform_with_canvas() * Vector2(u * s.size.x, s.size.y * 0.5)).round()


## The button with this text, taking the one in the same card as the given words when there are several.
func _button_near(root: Node, text: String, near: String) -> Button:
	var found: Button = null
	for b in root.find_children("*", "Button", true, false):
		if not (b is Button and (b as Button).text == text and b.is_visible_in_tree()):
			continue
		if near == "":
			return b
		var card: Node = b.get_parent()
		while card and not card is PanelContainer:
			card = card.get_parent()
		if card and card.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return near in l.text):
			return b
		if found == null:
			found = b
	return found


func _glide(to: Vector2, seconds := 0.5) -> void:
	var from := _pointer.position
	var tw := create_tween()
	tw.tween_method(func(u: float) -> void: _pointer.position = from.lerp(to, u * u * (3.0 - 2.0 * u)).round(), 0.0, 1.0, seconds)
	await tw.finished


## Moves the pointer onto a button and presses it, as a player would.
func _press(button: BaseButton) -> void:
	if button == null:
		return
	await _glide(_centre(button))
	await _wait(0.15)
	_tap()
	if button.toggle_mode:
		button.button_pressed = true
	button.pressed.emit()


## Moves the pointer onto a control and clicks it, running the given action.
func _press_with(c: Control, action: Callable) -> void:
	await _glide(_centre(c))
	await _wait(0.15)
	_tap()
	action.call()


## Moves onto a piece of the workshop, which lights up as it does under the mouse, and clicks it.
func _click_spot(piece: Control) -> void:
	var at := _centre(piece)
	var spot := _spot_at(at)
	await _glide(at, 0.6)
	if spot:
		spot._fade(1.0)
	await _wait(0.35)
	_tap()
	if spot:
		spot.clicked.emit()


## The workshop's clickable piece under a point on screen, the one drawn last when they overlap; the screens draw on Nav.ui.
func _spot_at(at: Vector2) -> Hotspot:
	var found: Hotspot = null
	for h in Nav.ui.find_children("*", "Control", true, false):
		if h is Hotspot and (h as Hotspot)._has_point(h.get_global_transform_with_canvas().affine_inverse() * at):
			found = h
	return found


## Takes hold of the slider's knob and slides it to a new price.
func _slide(slider: HSlider, value: float) -> void:
	await _glide(_slider_point(slider, slider.value))
	await _wait(0.15)
	_tap()
	var from := slider.value
	var tw := create_tween()
	tw.tween_method(func(u: float) -> void:
		slider.value = lerpf(from, value, u)
		_pointer.position = _slider_point(slider, slider.value), 0.0, 1.0, 0.8)
	await tw.finished


## Picks a motif up from the book and carries it onto the floor plan, at a share of its width and height.
func _drag_motif(table: Node, motif_id: String, where: Vector2) -> void:
	var ids: Array = Data.motif_order.filter(func(id: String) -> bool: return (Data.motif(id).get("kind", "") == "picture") == (table.tab == "pictures"))
	var slot: Control = table._book_grid.get_child(ids.find(motif_id))
	await _glide(_centre(slot))
	await _wait(0.15)
	_tap()
	var holder := Control.new()
	holder.scale = Vector2.ONE * _scale
	_pointer.get_parent().add_child(holder)
	_pointer.get_parent().move_child(holder, 0)
	holder.add_child(table._drag_preview(motif_id))
	var plan: PlanView = table._plan
	var r := plan.plan_rect()
	var target: Vector2 = (plan.get_global_transform_with_canvas() * (r.position + r.size * where)).round()
	var from := _pointer.position
	var tw := create_tween()
	tw.tween_method(func(u: float) -> void:
		_pointer.position = from.lerp(target, u * u * (3.0 - 2.0 * u)).round()
		holder.position = _pointer.position, 0.0, 1.0, 1.0)
	await tw.finished
	holder.queue_free()
	table._add_motif(motif_id, Vector2(table.design.w, table.design.h) * where)


## The pointer dips a pixel and a small ring spreads from its tip, so a click reads on screen.
func _tap() -> void:
	_ring.position = _pointer.position
	_ring.scale = Vector2.ONE * _scale * 0.5
	_ring.modulate.a = 1.0
	var t := create_tween().set_parallel()
	t.tween_property(_ring, "scale", Vector2.ONE * _scale * 1.2, 0.3)
	t.tween_property(_ring, "modulate:a", 0.0, 0.3)


## The familiar arrow pointer, drawn in the interface's ink and parchment.
static func _arrow() -> Texture2D:
	var rows := [
		"X.........",
		"XX........",
		"XoX.......",
		"XooX......",
		"XoooX.....",
		"XooooX....",
		"XoooooX...",
		"XooooooX..",
		"XoooooooX.",
		"XooooooooX",
		"XoooooXXXX",
		"XooXooX...",
		"XoX.XooX..",
		"XX..XooX..",
		"X....XooX.",
		".....XooX.",
		"......XX..",
	]
	var img := Image.create(10, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 10:
			var c: String = rows[y][x]
			if c == "X":
				img.set_pixel(x, y, INK)
			elif c == "o":
				img.set_pixel(x, y, CREAM)
	return ImageTexture.create_from_image(img)


static func _ring_texture() -> Texture2D:
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	for y in 11:
		for x in 11:
			var d := Vector2(x - 5, y - 5).length()
			if d > 3.6 and d < 4.8:
				img.set_pixel(x, y, Color(CREAM, 0.9))
	return ImageTexture.create_from_image(img)


