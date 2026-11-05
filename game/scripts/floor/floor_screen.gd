extends Node
## The floor at the client's house: pick a stone and sweep it into the places it goes, then one wipe grouts and polishes.
## Opened with {design: FloorDesign, job: Dictionary}, or with nothing to lay the test floor.

const TEST_DESIGN := "res://designs/test_floor.png"
const TILE_PX := Composer.TILE_PX
const ZOOM_MIN := 0.2
const ZOOM_MAX := 6.0

var floor_view: FloorView
var cam: Camera2D
var cursor: Node2D
var brush_tiles := 4.0
## How far past its one gap the mending brush reaches, kept apart from the laying brush so mending starts precise.
var mend_tiles := 0.0
## The stone the brush lays, from the tray.
var stone := -1
## The tool picked from the tray for digging, mending, grouting or polishing: trowel, stone, lift, sponge or cloth.
var tool := ""
var job := {}
var design: FloorDesign

var _hud: FloorHud
var _brushing := false
var _last := Vector2.ZERO
var _panning := false
var _demo := {}
var _demo_prev := Vector2.INF
var _time := 0.0
var _started_msec := 0
var _task := -1
var _layout: MosaicLayout
## The area of picture panels set into this floor, which come already laid.
var _made := PackedByteArray()
var _loading: LoadingCard
var _paused: PanelContainer


func enter(args: Dictionary) -> void:
	job = args.get("job", {})
	design = args.get("design", null)
	if design == null and job.has("design"):
		design = FloorDesign.from_dict(job["design"])
	if "big_brush" in Game.state["upgrades"]:
		brush_tiles = 5.0
	if design == null and Dev.has("sample"):
		design = Samples.make(Dev.get_arg("sample"))
		if Dev.has("panels"):
			design.placements[0]["panel"] = "test"
	_loading = LoadingCard.new()
	Nav.ui.add_child(_loading)
	_loading.show_text("Marking out the floor")
	var d := design
	var layout := MosaicLayout.new()
	_layout = layout
	_task = WorkerThreadPool.add_task(func() -> void:
		if d:
			Composer.lay_out(d, layout)
			_made = Composer.panel_mask(d, TILE_PX)
		else:
			layout.build((load(TEST_DESIGN) as Texture2D).get_image(), TILE_PX))


## Runs once the floor has been worked out on its worker thread: builds the floor, camera and interface.
func _ready_floor() -> void:
	var layout := _layout
	_loading.queue_free()
	floor_view = FloorView.new()
	var room := Data.room(str(job.get("room", design.room if design else "")))
	floor_view.door_visible = not (bool(room.get("wall", false)) or bool(room.get("bench", false)))
	Nav.world.add_child(floor_view)
	floor_view.setup(layout)
	if not _made.is_empty():
		floor_view.prelay(Composer.prelaid(layout, _made))
	floor_view.tiles_landed.connect(Audio.on_landed)
	floor_view.phase_changed.connect(_on_phase)
	if job.get("kind", "") == "restoration" or Dev.has("restore"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(job.get("id", "test"))
		floor_view.setup_restoration(Damage.holes(layout, rng, float(job.get("severity", Dev.num("restore", 0.25)))))
		if Dev.has("dig-done"):
			floor_view._finish_channel(2)
		if Dev.has("gaps-left"):
			for i in floor_view.missing.keys().slice(int(Dev.num("gaps-left", 5))):
				floor_view.repaired[i] = floor_view.layout.stone[i]
				floor_view._schedule(i, floor_view.now)
	cursor = Node2D.new()
	cursor.draw.connect(_draw_cursor)
	Nav.world.add_child(cursor)
	cam = Camera2D.new()
	Nav.world.add_child(cam)
	cam.make_current()
	_fit()
	if Dev.has("zoom"):
		cam.zoom = Vector2.ONE * Dev.num("zoom", 1.0)
	if Dev.has("center"):
		var c := Dev.get_arg("center").split(",")
		cam.position = Vector2(float(c[0]), float(c[1])) * floor_view.tile_world()
	if Dev.has("no-chalk"):
		floor_view.chalk_visible = false
	_demo = Dev.args.duplicate()
	_hud = FloorHud.new()
	_hud.setup(self)
	Nav.ui.add_child(_hud)
	_hud.visible = not Dev.has("no-hud")
	_started_msec = Time.get_ticks_msec()
	_time = 0.0
	if job.get("kind", "") == "restoration":
		Guide.note("dig", "This old floor is buried. Pick the trowel and scrape the dirt away, then fill each gap with a matching stone and press Done. Then grout and polish it.", "top_left")
	else:
		Guide.note("floor", "Now lay the floor, one stone at a time. Pick a stone in the tray below, then hold the left mouse button and sweep over the places that glow. Then wipe in the grout with the sponge and polish with the cloth.", "top_left")


func _process(delta: float) -> void:
	if floor_view == null:
		if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
			_ready_floor()
		return
	_time += delta
	cursor.queue_redraw()
	_run_demo()
	if _demo.has("fill-at") and _time >= float(_demo["fill-at"]) and _demo["fill-at"] != "done":
		_demo["fill-at"] = "done"
		floor_view.lay_rest(float(_demo.get("fill-seconds", "3.0")))


func _unhandled_input(event: InputEvent) -> void:
	if floor_view == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_brushing = mb.pressed
				if mb.pressed:
					_last = _to_world(mb.position)
					_stroke(_last, _last)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_panning = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom_at(mb.position, 1.15)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom_at(mb.position, 1.0 / 1.15)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			cam.position -= mm.relative / cam.zoom
		if _brushing:
			var p := _to_world(mm.position)
			_stroke(_last, p)
			_last = p
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE:
				_pause()
			KEY_C:
				floor_view.chalk_visible = not floor_view.chalk_visible
			KEY_BRACKETLEFT:
				grow_brush(-1.0)
			KEY_BRACKETRIGHT:
				grow_brush(1.0)
			KEY_TAB:
				select_stone(next_stone(stone))
			_:
				var n := (event as InputEventKey).keycode - KEY_1
				var order := floor_view.stones_used()
				if n >= 0 and n < mini(9, order.size()) and floor_view.phase == FloorView.Phase.LAY:
					select_stone(order[n])


## Leaving a floor half done keeps the job, and the stone already paid for, for later.
func _pause() -> void:
	if _paused:
		return
	_paused = Ui.panel(Nav.ui, "PagePanel")
	var col := Ui.vbox(_paused, 4)
	Ui.label(col, "Leave this floor?", "Heading")
	Ui.label(col, "The job stays on your table, and the stone you've paid for is kept. You'll start this floor again when you come back.", "", 200)
	var row := Ui.hbox(col, 4)
	Ui.button(row, "Keep working", func() -> void:
		_paused.queue_free()
		_paused = null, "brush", true)
	Ui.button(row, "Back to the workshop" if not job.get("free", false) else "Back to the title", func() -> void:
		if job.get("free", false):
			Nav.go("title")
		else:
			Saves.save()
			Nav.go("workshop"), "arrow_l")
	_paused.reset_size()
	_paused.position = ((Nav.ui_size() - _paused.size) * 0.5).floor()


func select_tool(name: String) -> void:
	tool = name
	if name == "lift":
		floor_view.repair_stone = -1
	Audio.ui("tab", -14.0)


func select_repair_stone(st: int) -> void:
	tool = "stone"
	floor_view.repair_stone = st
	Audio.ui("tab", -14.0)


## Chooses the stone to lay, and lights up where it goes.
func select_stone(st: int) -> void:
	if st == stone:
		return
	stone = st
	floor_view.guide(st if floor_view.phase == FloorView.Phase.LAY else -1)
	if st >= 0:
		Audio.ui("tab", -14.0)


## The next stone in the tray, after the one given, that still has tiles to lay; -1 when every tile is down. Tab uses it.
func next_stone(after: int) -> int:
	var order := floor_view.stones_used()
	var start := order.find(after) + 1
	for k in order.size():
		var st: int = order[(start + k) % order.size()]
		if floor_view.stone_unplaced(st) > 0:
			return st
	return -1


## Widens or narrows the brush of the phase the floor is in.
func grow_brush(step: float) -> void:
	if floor_view.phase == FloorView.Phase.REPAIR:
		mend_tiles = clampf(mend_tiles + step, 0.0, 6.0)
	else:
		brush_tiles = clampf(brush_tiles + step, 1.5, 10.0)


## The brush's reach: one tile when mending until it is widened, so each gap can be set just right; wider for wiping.
func brush_radius() -> float:
	if floor_view.phase == FloorView.Phase.REPAIR:
		return (0.6 + mend_tiles) * floor_view.tile_world()
	var wide := 1.0 if floor_view.phase == FloorView.Phase.LAY else 2.0
	return brush_tiles * wide * floor_view.tile_world()


## One movement of the brush: lays tiles, or wipes grout or polish once the tiles are down.
func _stroke(from: Vector2, to: Vector2) -> void:
	match floor_view.phase:
		FloorView.Phase.LAY:
			if stone < 0 and not _demo.has("demo"):
				_hud.nudge_tray()
				return
			floor_view.brush(from, to, brush_radius(), -1 if _demo.has("demo") else stone)
			if stone >= 0 and floor_view.stone_unplaced(stone) == 0:
				select_stone(-1)
		FloorView.Phase.REPAIR:
			if tool == "lift":
				floor_view.lift(from, to, brush_radius())
			elif tool == "stone" and floor_view.repair_stone >= 0:
				floor_view.repair(from, to, brush_radius())
			else:
				_hud.nudge_tray()
		FloorView.Phase.GROUT, FloorView.Phase.DIG:
			var ch := {"sponge": 0, "cloth": 1, "trowel": 2}.get(tool, -1) as int
			if (floor_view.phase == FloorView.Phase.DIG) != (ch == 2) or ch < 0:
				_hud.nudge_tray()
				return
			var gained := floor_view.paint(from, to, brush_radius(), ch)
			if gained > 0.0 or from.distance_to(to) > 2.0:
				Audio.swipe("sponge" if ch == 0 else "cloth", gained > 0.0)


func _to_world(screen: Vector2) -> Vector2:
	return cam.position + (screen - get_viewport().get_visible_rect().size * 0.5) / cam.zoom


func _zoom_at(screen: Vector2, factor: float) -> void:
	var before := _to_world(screen)
	cam.zoom = (cam.zoom * factor).clamp(Vector2.ONE * ZOOM_MIN, Vector2.ONE * ZOOM_MAX)
	cam.position = before - (screen - get_viewport().get_visible_rect().size * 0.5) / cam.zoom


var _gap_turn := -1


## Moves the view to the next gap still without a stone, close enough to see which stone it wants.
func find_gap() -> void:
	var left := floor_view.missing.keys().filter(func(i: int) -> bool: return not floor_view.repaired.has(i))
	if left.is_empty():
		return
	_gap_turn = (_gap_turn + 1) % left.size()
	var zoom := clampf(maxf(cam.zoom.x, _fit_zoom() * 2.5), ZOOM_MIN, ZOOM_MAX)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "position", floor_view.layout.pos[left[_gap_turn]] * FloorView.WORLD, 0.5)
	tw.parallel().tween_property(cam, "zoom", Vector2.ONE * zoom, 0.5)


func _fit_zoom() -> float:
	var wall := FloorView.WALL * floor_view.tile_world()
	var area := floor_view.size_world() + Vector2.ONE * wall * 1.4
	var vp := get_viewport().get_visible_rect().size
	return minf(vp.x / area.x, (vp.y * 0.86) / area.y)


func _fit() -> void:
	cam.zoom = Vector2.ONE * _fit_zoom()
	cam.position = floor_view.size_world() * 0.5 + Vector2(0, 0.04 * floor_view.size_world().y)


func _on_phase(phase: int) -> void:
	tool = ""
	if phase != FloorView.Phase.LAY:
		floor_view.guide(-1)
	if phase != FloorView.Phase.DONE:
		return
	if Dev.has("zoom"):
		return
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.3)
	tw.tween_property(cam, "zoom", Vector2.ONE * _fit_zoom(), 1.6)
	tw.parallel().tween_property(cam, "position", floor_view.size_world() * 0.5, 1.6)
	if not job.is_empty():
		tw.tween_interval(1.4)
		var args := {"design": design, "job": job, "layout": floor_view.layout, "order": floor_view.order}
		if not floor_view.missing.is_empty():
			args["repair_score"] = floor_view.repair_score()
			args["stones"] = floor_view.repaired.duplicate()
		tw.tween_callback(func() -> void: Nav.go("reveal", args))


func _draw_cursor() -> void:
	var p := _demo_prev if _demo.has("demo") and _demo_prev != Vector2.INF else _to_world(get_viewport().get_mouse_position())
	var tint := Color(1.0, 0.96, 0.85, 0.55)
	if floor_view.phase == FloorView.Phase.LAY and stone >= 0:
		tint = Color(Stones.LIST[stone]["tile"], 0.9)
	elif floor_view.phase == FloorView.Phase.REPAIR and floor_view.repair_stone >= 0:
		tint = Color(Stones.LIST[floor_view.repair_stone]["tile"], 0.95)
	elif floor_view.phase == FloorView.Phase.GROUT:
		tint = Color(0.75, 0.85, 1.0, 0.6)
	elif floor_view.phase == FloorView.Phase.DIG:
		tint = Color(0.85, 0.7, 0.5, 0.6)
	elif floor_view.phase == FloorView.Phase.POLISH:
		tint = Color(1.0, 0.9, 0.6, 0.6)
	cursor.draw_arc(p, brush_radius(), 0.0, TAU, 64, tint, 2.0 / cam.zoom.x)


## A scripted sweep back and forth across the floor, for recording the laying without a hand on the mouse.
## With --finish-demo it then wipes the grout and polishes, a few seconds each.
func _run_demo() -> void:
	if _demo.has("finish-demo") and floor_view.phase == FloorView.Phase.REPAIR:
		floor_view.mend_all()
		if floor_view.repairs_done():
			floor_view.finish_repairs()
		return
	if _demo.has("finish-demo"):
		if floor_view.phase == FloorView.Phase.DIG:
			tool = "trowel"
		elif floor_view.phase == FloorView.Phase.GROUT:
			tool = "sponge" if floor_view.coverage() < 0.5 else "cloth"
	if _demo.has("finish-demo") and floor_view.phase in [FloorView.Phase.GROUT, FloorView.Phase.DIG]:
		if not _demo.has("demo"):
			_demo["demo"] = ""
		if _demo.get("_phase_seen", -1) != floor_view.phase:
			_demo["_phase_seen"] = floor_view.phase
			_demo["demo-start"] = str(_time + 0.6)
			_demo["demo-seconds"] = _demo.get("finish-seconds", "4.0")
			_demo["demo-passes"] = "10"
			_demo_prev = Vector2.INF
	if not _demo.has("demo"):
		return
	var start := float(_demo.get("demo-start", "0.6"))
	var length := float(_demo.get("demo-seconds", "8.0"))
	var u := (_time - start) / length
	if u < 0.0 or u > 1.0:
		if u > 1.0 and _demo_prev != Vector2.INF:
			_demo_prev = Vector2.INF
		return
	var area := Rect2(Vector2(0.06, 0.1) * floor_view.size_world(), Vector2(0.88, 0.8) * floor_view.size_world())
	if floor_view.phase != FloorView.Phase.LAY:
		area = Rect2(Vector2.ZERO, floor_view.size_world())
	elif _demo.has("demo-rect"):
		var r: PackedStringArray = str(_demo["demo-rect"]).split(",")
		var tw := floor_view.tile_world()
		area = Rect2(float(r[0]) * tw, float(r[1]) * tw, (float(r[2]) - float(r[0])) * tw, (float(r[3]) - float(r[1])) * tw)
	var passes := float(_demo.get("demo-passes", "5"))
	var lane := fmod(u * passes, 1.0)
	var row := floorf(u * passes)
	var x := lane if int(row) % 2 == 0 else 1.0 - lane
	var p := area.position + Vector2(x * area.size.x, ((row + lane * 0.3) / passes + 0.5 / passes) * area.size.y)
	if _demo_prev == Vector2.INF:
		_demo_prev = p
	_stroke(_demo_prev, p)
	_demo_prev = p
