extends Node
## Command-line options for checking the game without a hand on the mouse: screenshots, bursts of frames, window size.
## --shot=PATH [--shot-at=SECONDS] saves one screenshot; --burst=PREFIX [--burst-start, --burst-gap, --burst-count]
## saves several; --quit closes the game after the last one; --window=WxH sets the window size.

var args := {}
var time := 0.0
var _shots: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("window"):
		var wh: PackedStringArray = args["window"].split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
	if args.has("shot"):
		_shots.append([float(args.get("shot-at", "1.0")), args["shot"]])
	if args.has("burst"):
		var start := float(args.get("burst-start", "1.0"))
		var gap := float(args.get("burst-gap", "0.05"))
		for k in int(args.get("burst-count", "8")):
			_shots.append([start + k * gap, "%s_%02d.png" % [args["burst"], k]])
	_shots.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	# --hover=X,Y and --click=X,Y (interface pixels, at --hover-at and --click-at seconds) point and click for screenshots.
	for what in ["hover", "click"]:
		if args.has(what):
			var xy: PackedStringArray = args[what].split(",")
			var at := Vector2(float(xy[0]), float(xy[1]))
			get_tree().create_timer(float(args.get(what + "-at", "1.5"))).timeout.connect(_point.bind(at, what == "click"))
	# --drag=X0,Y0,X1,Y1 presses at the first point and moves to the second, still holding, at --drag-at seconds.
	if args.has("drag"):
		var d: PackedStringArray = args["drag"].split(",")
		get_tree().create_timer(float(args.get("drag-at", "1.5"))).timeout.connect(_drag.bind(Vector2(float(d[0]), float(d[1])), Vector2(float(d[2]), float(d[3]))))
	# --resize-at=SECONDS changes the window's size once, as dragging or maximising it would.
	if args.has("resize-at"):
		get_tree().create_timer(float(args["resize-at"])).timeout.connect(func() -> void:
			DisplayServer.window_set_size(DisplayServer.window_get_size() + Vector2i(96, 54)))
	if args.has("icon"):
		_make_icon.call_deferred(args["icon"])
	if args.has("quit") and _shots.is_empty():
		get_tree().create_timer(float(args.get("quit-at", "3.0"))).timeout.connect(get_tree().quit)


func has(key: String) -> bool:
	return args.has(key)


func get_arg(key: String, fallback: String = "") -> String:
	return args.get(key, fallback)


func num(key: String, fallback: float) -> float:
	return float(args[key]) if args.has(key) and args[key] != "" else fallback


func _process(delta: float) -> void:
	time += delta
	while not _shots.is_empty() and time >= _shots[0][0]:
		_take_shot(_shots.pop_front()[1], _shots.is_empty())


func _take_shot(path: String, last: bool) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
	if last and args.has("quit"):
		get_tree().quit()


func _point(ui_at: Vector2, click: bool) -> void:
	var at := ui_at * Nav.scale_factor()
	get_viewport().warp_mouse(at)
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	Input.parse_input_event(m)
	if click:
		for pressed in [true, false]:
			var b := InputEventMouseButton.new()
			b.button_index = MOUSE_BUTTON_LEFT
			b.pressed = pressed
			b.position = at
			b.global_position = at
			Input.parse_input_event(b)


## A job of one kind for checking a screen alone: commission, copy, contest or restoration.
func test_job(kind: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	Game.state["day"] = 7
	match kind:
		"copy":
			return JobFactory.copy(Game.state, rng)
		"contest":
			return JobFactory.contest(Game.state, rng)
		"restoration":
			return JobFactory.restoration(Game.state, rng)
		"free":
			return {"free": true}
		"panel":
			return {"kind": "panel", "room": "panel", "client": "", "client_name": "Your picture panel", "portrait": "", "brief": {},
				"budget": 0, "arc_step": -1, "taste": [], "id": "panel_test"}
	var job := JobFactory.commission(Game.state, rng, {}, false)
	job["asked"] = job["budget"]
	job["expected"] = 0.5
	return job


func _drag(from: Vector2, to: Vector2) -> void:
	var k := Nav.scale_factor()
	_point(from, false)
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	b.position = from * k
	b.global_position = b.position
	Input.parse_input_event(b)
	for i in range(1, 13):
		await get_tree().process_frame
		var at := from.lerp(to, i / 12.0) * k
		get_viewport().warp_mouse(at)
		var m := InputEventMouseMotion.new()
		m.position = at
		m.global_position = at
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		m.relative = (to - from) * k / 12.0
		Input.parse_input_event(m)


## The game's icon: a small mosaic laid by the floor's own renderer, saved as a square picture, and then the game quits.
func _make_icon(path: String) -> void:
	var d := FloorDesign.for_room(get_arg("icon-room", "panel"))
	d.ground = get_arg("icon-ground", "white_marble")
	d.set_border(get_arg("icon-border", "plain"))
	d.border["stones"] = get_arg("icon-frame", "black_stone,black_stone,black_stone,black_stone").split(",")
	var p := d.add(get_arg("icon-motif", "flower"), d.w * 0.5, d.h * 0.5, num("icon-size", 15.0))
	if get_arg("icon-stones") == "own" and has("icon-allowed"):
		for k in p["stones"]:
			p["stones"][k] = Stones.nearest(p["stones"][k], Array(get_arg("icon-allowed").split(",")))
	elif get_arg("icon-stones") != "own":
		var colours := get_arg("icon-stones", "red_marble,ochre_marble,black_stone,red_marble").split(",")
		p["stones"] = {"1": colours[0], "2": colours[1], "3": colours[2], "4": colours[3]}
	var layout := MosaicLayout.new()
	layout.build(Composer.compose(d, 6), 6, Composer.fine_mask(d, 6))
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var floor_view := FloorView.new()
	floor_view.walls_visible = false
	vp.add_child(floor_view)
	floor_view.setup(layout)
	floor_view.chalk_visible = false
	floor_view.show_finished()
	var cam := Camera2D.new()
	var world := Vector2(layout.w, layout.h) * FloorView.WORLD
	cam.position = world * 0.5
	cam.zoom = Vector2.ONE * 512.0 / world.x
	vp.add_child(cam)
	cam.make_current()
	for i in 4:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	get_tree().quit()
