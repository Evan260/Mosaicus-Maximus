extends Node
## The workshop, the hub between jobs: the street door, the job board, the design table, the stone shelves,
## the workbench, the library and the dog. A bar along the top shows money, reputation and the day.

const ART := "res://assets/art/workshop/"
## Pieces of furniture, back to front: the picture, what the mouse says over it, and what clicking it does.
## Upgrades only appear once bought.
const PIECES := [
	["board", "The job board", "job_board"],
	["scrolls", "Your library", "library"],
	["shelves", "Stone shelves: buy stone", "merchant"],
	["bench", "Workbench: picture panels and upgrades", "bench"],
	["plants", "", "plants"],
	["amphorae", "", "amphorae"],
	["lamps", "", "lamps"],
	["bed", "", ""],
	["table", "The design table", "table"],
]
const UPGRADE_PIECES := ["plants", "amphorae", "lamps"]
const DOOR := Rect2(4, 30, 88, 196)
const BASKET := Vector2(326, 239)
## Where the lamps' flames are, and how far their light reaches into the room, once lamps are bought.
const FLAMES := [[Vector2(108, 126), 175.0], [Vector2(324, 56), 145.0]]

var _root: Control
## The room and everything painted in it, on the picture layer.
var _pictures: Control
var _scene: Control
var _bar: PanelContainer
var _coins: Label
var _rep: Button
var _day: Label
var _jobs: Label
var _tip: PanelContainer
var _tip_label: Label
var _popup: Control
var _panel: Control
var _dog: DogView
var _layers := {}
var _sky: SkyView
var _sunlit: Array[ShaderMaterial] = []
var _glows: Array = []
## The lamps' flames and the glow painted round them, shown only while the lamps are lit.
var _flames: TextureRect
## Where the room's picture lies, measured from the painting's corner: it reaches past it on every side.
var _room_rect := Rect2()
var _edges: EdgeFade
var _end_day: Button
var _t := 0.0
var _leaving := false
var _sold_at := -1000
var _list_scroll: ScrollContainer
## The day and part of the day the top bar shows, so its text is only made again when they change.
var _day_key := ""


func enter(_args: Dictionary) -> void:
	Story.morning(Game.state)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Nav.ui.add_child(_root)
	_pictures = Control.new()
	_pictures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Nav.pictures.add_child(_pictures)
	_scene = Control.new()
	_scene.custom_minimum_size = Nav.BASE
	_scene.size = Nav.BASE
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky = SkyView.new()
	_sky.size = Nav.BASE
	_pictures.add_child(_sky)
	_pictures.add_child(_scene)
	if Dev.get_arg("panel") == "upgrades" or Dev.has("furnished"):
		Game.state["upgrades"].append_array(UPGRADE_PIECES)
	if Dev.has("hour"):
		Game.state["hour"] = Dev.num("hour", 8.0)
	_room()
	_edges = EdgeFade.make()
	_pictures.add_child(_edges)
	_build_bar()
	_tip = Ui.panel(_root, "TipPanel")
	_tip_label = Ui.label(_tip, "", "LightLabel")
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.child_entered_tree.connect(_adopt_panel)
	Nav.resized.connect(_layout)
	_layout()
	Game.changed.connect(_refresh)
	_refresh()
	if not "intro" in Game.state["story_seen"]:
		Game.state["story_seen"].append("intro")
		var ch := Data.chapter(1)
		_queue_event({"kind": "chapter", "n": 1, "title": ch.get("title", ""), "text": ch.get("text", "")})
	# A demo workshop opened in the full game, or one past the demo's end, opens the chapters its reputation has reached.
	for e in Story.check_chapters(Game.state):
		_queue_event(e)
	if Dev.has("panel") or Dev.has("no-hud"):
		Game.state["pending_events"].clear()
	_bar.visible = not Dev.has("no-hud")
	_show_next_event()
	match Dev.get_arg("panel"):
		"settings":
			open_settings()
		"dog":
			_show_panel(DogPanel.open(_root))
		"upgrades":
			Game.state["upgrades"] = ["big_brush"]
			_open_upgrades()
		"merchant":
			var n := int(Dev.num("chapter", 3))
			Story.unlock(Game.state, n)
			var ahead := Stones.LIST.filter(func(st: Dictionary) -> bool: return int(st["tier"]) == n + 1)
			Game.state["ship"] = {"day": Game.state["day"], "stone": ahead[0]["id"] if not ahead.is_empty() else "gold", "port": "Alexandria", "bargain": ahead.is_empty()}
			_open_merchant()
		"bench":
			Game.state["panels"] = [{"id": "p1", "motif": "dolphin", "stones": {}, "stars": 4, "size": 14}, {"id": "p2", "motif": "dove", "stones": {}, "stars": 5, "size": 12}]
			if Dev.has("busy"):
				var d := FloorDesign.for_room("panel")
				d.add("dolphin", 10, 10, 14)["panel"] = "p1"
				Game.state["active_job"] = {"kind": "panel", "room": "panel", "design": d.to_dict(), "stone_paid": true, "stone_taken": {"limestone": 300}}
			_open_bench()
		"chapters":
			_show_panel(ChaptersPanel.open(_root))
		"achievements":
			var book := ChaptersPanel.open(_root)
			book.show_awards()
			_show_panel(book)
		"letters":
			var book := ChaptersPanel.open(_root)
			book.show_letters()
			_show_panel(book)
		"demo-end":
			_queue_event({"kind": "demo_end"})
			_show_next_event()
		"letter":
			Story.unlock(Game.state, 2)
			Game.state["reputation"] = 40
			_queue_event({"kind": "chapter", "n": 2, "title": Data.chapter(2)["title"], "text": Data.chapter(2)["text"]})
			_show_next_event()


func open_settings() -> void:
	_show_panel(SettingsPanel.open(_root, true))


func _layout() -> void:
	var s := Nav.ui_size()
	_root.size = s
	var view := Nav.picture_view()
	_edges.position = view.position
	_edges.fit(Rect2(_room_rect.position - view.position, _room_rect.size), view.size)
	_bar.position = Vector2(4, 3)
	_fit_bar()
	if is_instance_valid(_popup):
		_popup.reset_size()
		_popup.position = ((s - _popup.size) * 0.5).floor()
	if is_instance_valid(_panel):
		if is_instance_valid(_list_scroll) and _panel.is_ancestor_of(_list_scroll):
			_fit_list()
		_panel.reset_size()
		_panel.position = ((s - _panel.size) * 0.5).floor()


## The room painting, its furniture piece by piece, the dog in its basket, and what each piece does when clicked.
func _room() -> void:
	var rects: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "layers.json"))
	var r0: Array = rects["room"]
	_room_rect = Rect2(r0[0], r0[1], r0[2], r0[3])
	var back := TextureRect.new()
	back.texture = load(ART + "room.png")
	back.position = _room_rect.position
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(back)
	_follow_sun(back)
	var owned: Array = Game.state["upgrades"]
	var spots := []
	for piece in PIECES:
		var id: String = piece[0]
		if id in UPGRADE_PIECES and not id in owned:
			continue
		var r: Array = rects[id]
		var t := TextureRect.new()
		t.texture = load(ART + id + ".png")
		t.position = Vector2(r[0], r[1])
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scene.add_child(t)
		_layers[id] = t
		if id == "lamps":
			_flames = TextureRect.new()
			_flames.texture = load(ART + "lamps_flame.png")
			_flames.position = t.position
			_flames.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_scene.add_child(_flames)
		if piece[1] != "":
			spots.append([t, piece[1], piece[2], id])
	_dog = DogView.make(Game.state.get("dog", {}), 2)
	_scene.add_child(_dog)
	_dog.play("sleep")
	_dog.position = (BASKET - _dog.sleeping_centre()).floor()
	# The basket's front wall goes over the dog, so it lies inside the basket rather than on its rim.
	var basket_front := TextureRect.new()
	basket_front.texture = load(ART + "bed_front.png")
	basket_front.position = (_layers["bed"] as TextureRect).position
	basket_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(basket_front)
	_layers["bed_front"] = basket_front
	_dog.stood_up.connect(_hearts)
	var door := Hotspot.make(DOOR, "To the town")
	door.clicked.connect(func() -> void: _use("town"))
	_add_spot(door)
	for sp in spots:
		var t: TextureRect = sp[0]
		var shape := _shape(sp[3])
		var h := Hotspot.make(Rect2(t.position, t.texture.get_size()), sp[1], shape if shape else t.texture)
		h.light(t, shape)
		var what: String = sp[2]
		h.clicked.connect(func() -> void: _use(what))
		_add_spot(h)
	for id in _layers:
		_follow_sun(_layers[id])
	var bed: TextureRect = _layers["bed"]
	var pet := Hotspot.make(Rect2(bed.position, bed.texture.get_size()), tr("Pet %s") % tr(_dog_name()) if _dog_name() != "" else tr("Pet the dog"), _shape("bed"))
	pet.light(bed, _shape("bed"), false)
	pet.light(_dog, null, false)
	pet.light(_layers["bed_front"], null, false)
	_follow_sun(bed)
	_follow_sun(_layers["bed_front"])
	_follow_sun(_dog)
	pet.clicked.connect(func() -> void:
		_tip.visible = false
		_pet())
	_add_spot(pet)
	if "lamps" in owned:
		var light := Control.new()
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pictures.add_child(light)
		for f in FLAMES:
			var halo := LampGlow.make(f[0], 12.0, 0.45)
			light.add_child(halo)
			_glows.append(halo)


func _process(delta: float) -> void:
	var hour := float(Game.state.get("hour", 8.0))
	var night := Daylight.night(hour)
	_sky.hour = hour
	_t += delta
	var lamps := []
	var lit := Daylight.lamps_lit(hour)
	if "lamps" in Game.state["upgrades"] and lit > 0.0:
		var flicker := 0.95 if Settings.reduced_motion else 0.92 + 0.05 * sin(_t * 9.0) + 0.03 * sin(_t * 23.0) + randf() * 0.02
		for f in FLAMES:
			lamps.append(Vector4(f[0].x, f[0].y, f[1], (0.08 + 0.95 * night) * flicker * lit))
	if _flames:
		_flames.modulate.a = lit
	var ambient := Daylight.light(hour)
	var lamp_array := PackedVector4Array(lamps)
	for m in _sunlit:
		m.set_shader_parameter("night", night)
		m.set_shader_parameter("ambient", ambient)
		m.set_shader_parameter("lamp_count", lamps.size())
		if not lamps.is_empty():
			m.set_shader_parameter("lamps", lamp_array)
	for g in _glows:
		g.night = night
		g.lit = lit
	var part := Daylight.part_of_day(hour)
	var day_key := "%d %s" % [int(Game.state["day"]), part]
	if day_key != _day_key:
		_day_key = day_key
		_day.text = tr("Day %d, %s") % [int(Game.state["day"]), Daylight.part_name(part)]
		_fit_bar()
	Ui.restyle(_end_day, "MainButton" if part in ["evening", "night"] else "")


## Lets a piece's painted sunlight fade at night with the room's, reading the room's sunlight map at its place.
func _follow_sun(t: TextureRect) -> void:
	var m := t.material as ShaderMaterial
	if m == null:
		m = ShaderMaterial.new()
		m.shader = load("res://shaders/room.gdshader")
		t.material = m
	m.set_shader_parameter("sun", load(ART + "room_sun.png"))
	m.set_shader_parameter("sun_origin", (t.position - _room_rect.position) / _room_rect.size)
	m.set_shader_parameter("sun_span", t.texture.get_size() / _room_rect.size)
	m.set_shader_parameter("room_size", _room_rect.size)
	m.set_shader_parameter("room_origin", _room_rect.position)
	_sunlit.append(m)


## A piece's hand-traced outline, which the glow and the pointer follow instead of the painted shadows round it.
func _shape(id: String) -> Texture2D:
	var path := ART + id + "_shape.png"
	return load(path) if ResourceLoader.exists(path) else null


func _add_spot(h: Hotspot) -> void:
	_scene.add_child(h)
	h.hovered.connect(func(on: bool) -> void:
		if not on:
			_tip.visible = false
			return
		_tip_label.text = h.tip
		_tip.visible = true
		_tip.reset_size()
		var r := Nav.picture_rect_to_ui(Rect2(h.position, h.size))
		var above := Vector2(r.get_center().x - _tip.size.x * 0.5, r.position.y - _tip.size.y - 3)
		if above.y < _bar.get_rect().end.y + 2:
			above.y = r.end.y + 3
		_tip.position = above.clamp(Vector2(2, 2), Nav.ui_size() - _tip.size - Vector2(2, 2)).floor())


func _use(what: String) -> void:
	_tip.visible = false
	Audio.play("click")
	match what:
		"town":
			Nav.go("town_map")
		"job_board":
			Nav.go("job_board")
		"table":
			_open_table()
		"merchant":
			_open_merchant()
		"upgrades":
			_open_upgrades()
		"bench":
			_open_bench()
		"library":
			Nav.go("library", {"back": "workshop"})


func _dog_name() -> String:
	return str((Game.state.get("dog", {}) as Dictionary).get("name", ""))


func _build_bar() -> void:
	_bar = Ui.panel(_root, "TabletPanel")
	_bar.add_to_group(Backdrop.ABOVE)
	var row := Ui.hbox(_bar, 4)
	Ui.icon(row, "coin")
	_coins = Ui.label(row, "", "LightLabel")
	_rep = Ui.button(row, "", func() -> void: _show_panel(ChaptersPanel.open(_root)), "laurel")
	Ui.icon(row, "sun")
	_day = Ui.label(row, "", "LightLabel")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_jobs = Ui.label(row, "", "LightLabel")
	_end_day = Ui.button(row, "End the day", func() -> void: Nav.go("day_end"), "sun")
	Ui.icon_button(row, "gear", "Settings", open_settings)
	Ui.icon_button(row, "house", "Save and go back to the title", _save_and_quit)


## When big numbers or long words would push the top bar past the edge, the job count goes first, then the chapter
## button shortens, then the purse shows only its number, and last End the day shows only its sun.
func _fit_bar() -> void:
	var room := Nav.ui_size().x - 8
	var coins := int(Game.state["coins"])
	_jobs.visible = true
	_rep.text = _chapter_text(false)
	_coins.text = Ui.coins_text(coins)
	Ui.relabel(_end_day, tr("End the day"))
	Ui.tip_on(_end_day, "")
	if _bar.get_combined_minimum_size().x > room:
		_jobs.visible = false
	if _bar.get_combined_minimum_size().x > room:
		_rep.text = _chapter_text(true)
	if _bar.get_combined_minimum_size().x > room:
		_coins.text = str(coins)
	if _bar.get_combined_minimum_size().x > room:
		Ui.relabel(_end_day, "")
		Ui.tip_on(_end_day, "End the day")
	_bar.size = Vector2(room, 0)


func _chapter_text(short: bool) -> String:
	var st := Game.state
	var next := Data.chapter(int(st["chapter"]) + 1)
	return (tr("Ch %d  %d") if short else tr("Chapter %d  %d")) % [int(st["chapter"]), int(st["reputation"])] + ("" if next.is_empty() else "/%d" % int(next["reputation"]))


func _refresh() -> void:
	var st := Game.state
	Ui.tip_on(_coins, "Your purse. Money is counted in denarii, the Roman silver coin.")
	var ch := Data.chapter(int(st["chapter"]))
	var next := Data.chapter(int(st["chapter"]) + 1)
	var title := tr(str(ch.get("title", "")))
	if next.is_empty():
		Ui.tip_on(_rep, tr("Chapter %d: %s. Reputation %d. Click to see every chapter.") % [int(st["chapter"]), title, int(st["reputation"])])
	elif Game.in_full_game(int(next["n"])):
		Ui.tip_on(_rep, tr("Chapter %d: %s. Reputation %d of the %d that finishes the demo. Click to see every chapter.") % [int(st["chapter"]), title, int(st["reputation"]), int(next["reputation"])])
	else:
		Ui.tip_on(_rep, tr("Chapter %d: %s. Reputation %d of the %d that opens chapter %d. Click to see every chapter.") % [int(st["chapter"]), title, int(st["reputation"]), int(next["reputation"]), int(next["n"])])
	var left := Story.jobs_left(st)
	_jobs.text = tr("1 job left") if left == 1 else tr("%d jobs left") % left
	_fit_bar()


func _open_table() -> void:
	var job: Dictionary = Game.state["active_job"]
	if job.is_empty():
		_close_panel()
		_panel = Ui.panel(_root, "PagePanel")
		var col := Ui.vbox(_panel, 4)
		Ui.window_head(col, _panel, "Nothing on the table yet", _close_panel)
		Ui.label(col, "Take a job from the job board, and its floor plan will be waiting here." if Story.jobs_left(Game.state) > 0 else "That's today's work done. End the day, and new notices go up on the board in the morning.", "", 220)
		if Story.can_make_panel(Game.state):
			Ui.label(col, "Or lay a small picture panel at the workbench, under the window.", "MutedLabel", 220)
		var row := Ui.hbox(col, 4)
		row.alignment = BoxContainer.ALIGNMENT_END
		if Story.can_make_panel(Game.state):
			Ui.button(row, "To the workbench", _open_bench, "hammer")
		if Story.jobs_left(Game.state) > 0:
			Ui.button(row, "To the job board", func() -> void: Nav.go("job_board"), "arrow_r", true)
		else:
			Ui.button(row, "End the day", func() -> void: Nav.go("day_end"), "sun", true)
		_layout.call_deferred()
		return
	if job.get("kind", "") == "restoration" or job.has("progress"):
		Nav.go("floor", {"job": job})
	else:
		Nav.go("design_table", {"job": job})


func _pet() -> void:
	Game.bump("pets")
	if _dog.is_up():
		_hearts()
	else:
		Audio.play("rustle", -12.0)
	_dog.pet()


func _hearts() -> void:
	Audio.play("dog", -8.0)
	if Settings.reduced_motion:
		return
	var top := _dog.position + Rect2(_dog.texture.get_image().get_used_rect()).position + Vector2(_dog.texture.get_size().x * 0.4, -4)
	for i in 3:
		var heart := Label.new()
		heart.text = "♥"
		heart.add_theme_color_override("font_color", Color8(210, 70, 70))
		heart.position = top + Vector2(-8 + i * 7, 0)
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scene.add_child(heart)
		var tw := heart.create_tween()
		tw.tween_interval(i * 0.12)
		tw.tween_property(heart, "position:y", heart.position.y - 18 - i * 4, 0.9)
		tw.parallel().tween_property(heart, "modulate:a", 0.0, 0.9)
		tw.tween_callback(heart.queue_free)


func _flash(text: String) -> void:
	_tip_label.text = text
	_tip.visible = true
	_tip.reset_size()
	_tip.position = ((Nav.ui_size() - _tip.size) * 0.5).floor()
	Audio.play("nope", -8.0)


func _save_and_quit() -> void:
	Saves.save()
	Nav.go("title")


func _queue_event(e: Dictionary) -> void:
	if not Game.state.has("pending_events"):
		Game.state["pending_events"] = []
	Game.state["pending_events"].push_front(e)


## Shows the next letter waiting, a new chapter or a client's news, which stays waiting in the save until Carry on.
func _show_next_event() -> void:
	var pending: Array = Game.state.get("pending_events", [])
	if is_instance_valid(_popup):
		return
	if pending.is_empty():
		_guide.call_deferred()
		return
	var e: Dictionary = pending[0]
	if e.get("kind", "") == "demo_end":
		_show_demo_end(e)
		return
	_popup = Ui.panel(_root, "PagePanel")
	var popup := _popup
	var sides := Ui.hbox(_popup, 10)
	var col := Ui.vbox(sides, 5)
	var news: bool = e.get("kind", "") == "chapter" and int(e.get("n", 1)) > 1
	var body := Ui.text(e.get("text", ""))
	var width := Ui.wrap_width(body, 200.0 if news else 240.0, 7, floorf((Nav.ui_size().x - 40.0) * (0.5 if news else 1.0)))
	if e.get("kind", "") == "chapter":
		Ui.label(col, tr("Chapter %d") % int(e.get("n", 1)), "MutedLabel").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var t := Ui.label(col, Ui.text(e.get("title", "")), "Heading", width)
		t.add_theme_font_size_override("font_size", UiTheme.heading_size(true))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		Ui.label(col, Ui.text(e.get("title", Data.client(e.get("client", "")).get("name", "News"))), "Heading", width)
	Ui.label(col, body, "", width)
	if e.get("kind", "") == "chapter":
		_chapter_news(sides, col, int(e.get("n", 1)), width)
	var carry_on := func() -> void:
		if _popup != popup:
			return
		Story.keep_letter(Game.state, e)
		pending.erase(e)
		_popup.queue_free()
		_popup = null
		_show_next_event()
	var ok := Ui.button(col, "Carry on", carry_on, "tick", true)
	# A letter closed by a stray click is never seen again, so only Carry on and Escape close it.
	Ui.closes_with(_popup, carry_on, false)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Audio.play("page_turn", -6.0)
	_layout.call_deferred()


## The demo's end card, which is not kept with the letters, since it is about the game rather than the town.
func _show_demo_end(e: Dictionary) -> void:
	var card: Array[Control] = []
	var carry_on := func() -> void:
		if card.is_empty() or _popup != card[0]:
			return
		(Game.state["pending_events"] as Array).erase(e)
		_popup.queue_free()
		_popup = null
		_show_next_event()
	_popup = DemoEnd.open(_root, carry_on)
	card.append(_popup)
	_layout.call_deferred()


## The guide's note for the workshop: find a client, carry on with the job on the table, and after the first floor, end the day.
func _guide() -> void:
	var floors := (Game.state["floors"] as Array).size()
	var busy := not (Game.state["active_job"] as Dictionary).is_empty()
	if floors == 0 and not busy:
		Guide.note("workshop", "Welcome to your uncle's workshop. Money is counted in denarii, the Roman silver coin, and your purse is at the top left. First, find a client: click the job board on the wall by the door.",
			"bottom_right", _layers["board"])
	elif floors == 0 and str(Game.state["active_job"].get("kind", "")) != "panel":
		Guide.note("resume", "Your job is waiting on the design table at the front of the room. Click the table to carry on.",
			"bottom_right", _layers["table"])
	elif floors == 1 and not busy:
		Guide.note("first_floor", "Well done: your first floor! You can take one job a day. When you have finished for the day, click End the day at the top. New notices go up every morning.",
			"bottom_left", _end_day)


## Beside a chapter's letter, what it adds to the workshop, and under it how far off the next one is.
func _chapter_news(sides: HBoxContainer, col: VBoxContainer, n: int, width: float) -> void:
	if n > 1:
		var list := Ui.vbox(sides, 2)
		Ui.label(list, "New in the workshop:", "Heading")
		for line in Story.chapter_unlocks(n):
			var r := Ui.hbox(list, 3)
			Ui.icon(r, "tick_small").size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			Ui.label(r, line, "", 220)
	var next := Story.next_chapter_line(Game.state)
	if next != "":
		var lines := ["Finish floors to earn reputation, and better floors earn more."] if n == 1 else []
		lines += [tr("%s.") % next, "The Chapter button at the top shows what each chapter brings."]
		Ui.label(col, Ui.text(lines), "MutedLabel", width)


func _close_panel() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null


## Makes a panel the one open in the workshop, closing any other, so it is centred on every resize.
func _show_panel(p: Control) -> void:
	if p == _panel:
		return
	_close_panel()
	_panel = p
	_layout.call_deferred()


## The settings panel opens the dog and achievements panels itself, so they are caught as they join the room.
func _adopt_panel(node: Node) -> void:
	if node is SettingsPanel or node is DogPanel or node is ChaptersPanel:
		_show_panel(node as Control)


func _open_merchant() -> void:
	_close_panel()
	_panel = Ui.panel(_root, "PagePanel")
	var col := Ui.vbox(_panel, 3)
	Ui.window_head(col, _panel, "The stone merchant", _close_panel)
	var labels := [Ui.label(col, "Prices are for a sack of 100 tiles, and a floor is laid only from stone in stock.", "MutedLabel", 300)]
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_list_scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 1)
	_list_scroll.add_child(grid)
	for id in Game.state["unlocked_stones"]:
		var cell := Ui.hbox(grid, 4)
		Ui.texture(cell, MotifIcons.swatch(id, 10))
		labels.append(Ui.label(cell, Stones.title(id), "", 74))
		var have := Ui.label(cell, tr("%d in stock") % Game.stock(id), "MutedLabel", 56)
		var sid: String = id
		var price := Game.sack_price(sid)
		var buy := Ui.button(cell, Ui.coins_text(price), func() -> void:
			if Game.buy_sack(sid):
				Audio.play("coins")
				have.text = tr("%d in stock") % Game.stock(sid)
			else:
				Audio.play("nope"), "sack")
		# Left-aligned, so the button keeps no room for its icon on the right and two columns fit a narrow interface.
		buy.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var cargo := Story.ship_stone(Game.state)
	if cargo != "":
		var ship := Ui.panel(col, "CardPanel")
		var row := Ui.hbox(ship, 6)
		Ui.texture(row, MotifIcons.swatch(cargo, 12))
		var text := Ui.vbox(row, 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		labels.append(Ui.label(text, Story.ship_offer(Game.state), "", 270))
		Ui.button(row, tr("Buy a sack: %s") % Ui.coins_text(Game.ship_sack_price()), func() -> void:
			if Game.buy_from_ship():
				Audio.play("coins")
				Saves.save()
				_open_merchant()
			else:
				Audio.play("nope"), "sack", true)
	# Deferred until the buttons have centred their text, which widens them.
	Ui.narrow_to_fit.call_deferred(_panel, labels, Nav.ui_size().x - 8.0)
	_layout.call_deferred()


## A list two to a row, the stones or the upgrades: when the rows don't all fit, they scroll so the card does.
func _fit_list() -> void:
	var grid := _list_scroll.get_child(0) as GridContainer
	_list_scroll.custom_minimum_size.y = 0.0
	var spare := Nav.ui_size().y - 8.0 - _panel.get_combined_minimum_size().y
	var full := grid.get_combined_minimum_size().y
	var gap := float(grid.get_theme_constant("v_separation"))
	var row := (full + gap) / maxf(ceilf(grid.get_child_count() / float(grid.columns)), 1.0)
	_list_scroll.custom_minimum_size.y = minf(full, maxf(floorf((spare + gap) / row), 1.0) * row - gap)


## The workbench: a picture panel to lay today, the panels made so far for collectors to buy, and the upgrades.
func _open_bench() -> void:
	_close_panel()
	_panel = Ui.panel(_root, "PagePanel")
	var col := Ui.vbox(_panel, 4)
	Ui.window_head(col, _panel, "The workbench", _close_panel)
	Ui.label(col, "Lay a small picture panel here, one a day. A collector will buy it, or you can set it into a client's floor, where it comes laid already and the client pays extra.", "MutedLabel", 270)
	var busy: Dictionary = Game.state["active_job"]
	if busy.get("kind", "") == "panel":
		var row := Ui.hbox(col, 4)
		Ui.label(row, "A panel is on the bench.").size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Ui.button(row, "Give it up", _give_up_panel, "cross")
		Ui.button(row, "Carry on", func() -> void: Nav.go("floor" if busy.get("stone_paid", false) else "design_table", {"job": busy}), "arrow_r", true)
	var lay := Ui.button(col, "Lay a picture panel", _start_panel, "brush", true)
	lay.visible = busy.get("kind", "") != "panel"
	if not Story.can_make_panel(Game.state):
		lay.disabled = true
		Ui.tip_on(lay, "Finish the job on your table first." if not (Game.state["active_job"] as Dictionary).is_empty() else "One panel a day. The bench is free again tomorrow.")
	var panels: Array = Game.state.get("panels", [])
	if not panels.is_empty():
		Ui.label(col, "Your panels", "Heading")
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(270, minf(panels.size(), 4) * 26)
		col.add_child(scroll)
		var list := Ui.vbox(scroll, 2)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for panel in panels:
			var row := Ui.hbox(list, 4)
			Ui.texture(row, MotifIcons.motif(panel["motif"], 18, panel.get("stones", {})))
			var stars := int(panel.get("stars", 0))
			var name := Ui.label(row, (tr("%s, 1 star") % Data.motif_title(panel["motif"])) if stars == 1 else tr("%s, %d stars") % [Data.motif_title(panel["motif"]), stars], "", 150)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var value := Story.panel_value(Game.state, int(panel.get("stars", 0)))
			var sold: Dictionary = panel
			var sell := Ui.button(row, tr("Sell: %s") % Ui.coins_text(value), func() -> void: _sell_panel(sold, value), "coin")
			var set_in := (FloorDesign.from_dict(busy.get("design", {})).placements if busy.has("design") else []).any(func(p: Dictionary) -> bool: return str(p.get("panel", "")) == str(panel["id"]))
			if set_in:
				sell.disabled = true
				Ui.tip_on(sell, "It's set into the floor on your table.")
	Ui.button(col, "Improve the workshop", _open_upgrades, "hammer")
	_layout.call_deferred()


func _start_panel() -> void:
	var job := {"kind": "panel", "room": "panel", "client": "", "client_name": "Your picture panel", "portrait": "", "brief": {},
		"budget": 0, "arc_step": -1, "taste": [], "id": "panel_%d" % int(Game.state["day"])}
	Game.state["active_job"] = job
	Nav.go("design_table", {"job": job})


## Throws away the panel being made, with the stone it took put back in stock.
func _give_up_panel() -> void:
	var busy: Dictionary = Game.state["active_job"]
	for id in busy.get("stone_taken", {}):
		Game.add_stock(id, int(busy["stone_taken"][id]))
	Game.state["active_job"] = {}
	Saves.save()
	Audio.play("rustle", -8.0)
	_open_bench()


func _sell_panel(panel: Dictionary, value: int) -> void:
	# The bench is rebuilt at once, so a double-click would land on the next panel's Sell button.
	if Time.get_ticks_msec() - _sold_at < 400:
		return
	_sold_at = Time.get_ticks_msec()
	Game.state["panels"] = (Game.state["panels"] as Array).filter(func(p: Dictionary) -> bool: return p["id"] != panel["id"])
	Game.earn(value, "Picture panel")
	Game.bump("panels_sold")
	Audio.play("coins")
	Saves.save()
	_open_bench()


func _open_upgrades() -> void:
	_close_panel()
	_panel = Ui.panel(_root, "PagePanel")
	var col := Ui.vbox(_panel, 3)
	Ui.window_head(col, _panel, "Improve the workshop", _close_panel)
	# Two to a row, scrolling only when a long language needs more lines than the screen has.
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_list_scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 3)
	_list_scroll.add_child(grid)
	var labels := []
	for id in Data.upgrade_order:
		var u: Dictionary = Data.upgrades[id]
		if int(u.get("chapter", 1)) > int(Game.state["chapter"]):
			continue
		var owned := (Game.state["upgrades"] as Array).count(id)
		var limit := int(u.get("repeat", 1))
		if id == "apprentice":
			owned = int(Game.state["apprentices"])
		var card := Ui.panel(grid, "CardPanel")
		var row := Ui.hbox(card, 4)
		var text := Ui.vbox(row, 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		labels.append(Ui.label(text, tr(str(u["name"])) + (tr("  (%d of %d)") % [owned, limit] if limit > 1 else ""), "", 172))
		labels.append(Ui.label(text, tr(str(u.get("text", ""))), "MutedLabel", 172))
		var uid: String = id
		var cost := int(u.get("cost", 0))
		var b := Ui.button(row, "Owned" if owned >= limit else Ui.coins_text(cost), func() -> void: _buy(uid, cost))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = owned >= limit or cost > Game.coins()
	# Deferred until the buttons have centred their text, which widens them.
	Ui.narrow_to_fit.call_deferred(_panel, labels, Nav.ui_size().x - 8.0)
	_layout.call_deferred()


func _buy(id: String, cost: int) -> void:
	if _leaving:
		return
	if not Game.spend(cost, Data.upgrades[id]["name"]):
		Audio.play("nope")
		return
	if id == "apprentice":
		Game.state["apprentices"] = int(Game.state["apprentices"]) + 1
	else:
		Game.state["upgrades"].append(id)
	Audio.play("coins")
	Saves.save()
	_leaving = true
	Nav.go("workshop")
