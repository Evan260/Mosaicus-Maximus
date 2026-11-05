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
var _room_mat: ShaderMaterial
var _sunlit: Array[ShaderMaterial] = []
var _glows: Array = []
## The lamps' flames and the glow painted round them, shown only while the lamps are lit.
var _flames: TextureRect
var _end_day: Button
var _t := 0.0


func enter(_args: Dictionary) -> void:
	Story.morning(Game.state)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Nav.ui.add_child(_root)
	_scene = Control.new()
	_scene.custom_minimum_size = Nav.BASE
	_scene.size = Nav.BASE
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky = SkyView.new()
	_sky.size = Nav.BASE
	_root.add_child(_sky)
	_root.add_child(_scene)
	if Dev.get_arg("panel") == "upgrades":
		Game.state["upgrades"].append_array(UPGRADE_PIECES)
	if Dev.has("hour"):
		Game.state["hour"] = Dev.num("hour", 8.0)
	if Dev.has("late"):
		Game.state.merge({"coins": 14250, "reputation": 174, "day": 140, "chapter": 3}, true)
	_room()
	_build_bar()
	_tip = Ui.panel(_root, "TipPanel")
	_tip_label = Ui.label(_tip, "", "LightLabel")
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Nav.resized.connect(_layout)
	_layout()
	Game.changed.connect(_refresh)
	_refresh()
	if not "intro" in Game.state["story_seen"]:
		Game.state["story_seen"].append("intro")
		var ch := Data.chapter(1)
		_queue_event({"kind": "chapter", "n": 1, "title": ch.get("title", ""), "text": ch.get("text", "")})
	if Dev.has("panel"):
		Game.state["pending_events"].clear()
	_show_next_event()
	match Dev.get_arg("panel"):
		"settings":
			SettingsPanel.open(_root, true)
		"dog":
			DogPanel.open(_root)
		"upgrades":
			Game.state["upgrades"] = ["big_brush"]
			_open_upgrades()
		"bench":
			Game.state["panels"] = [{"id": "p1", "motif": "dolphin", "stones": {}, "stars": 4, "size": 14}, {"id": "p2", "motif": "dove", "stones": {}, "stars": 5, "size": 12}]
			_open_bench()
		"chapters":
			_panel = ChaptersPanel.open(_root)
		"achievements":
			AchievementsPanel.open(_root)
		"letter":
			Story.unlock(Game.state, 2)
			Game.state["reputation"] = 40
			_queue_event({"kind": "chapter", "n": 2, "title": Data.chapter(2)["title"], "text": Data.chapter(2)["text"]})
			_show_next_event()
		"award":
			Game.state["name"] = "Dev"
			Game.state["floors"].append({"score": 0.9})


func _layout() -> void:
	var s := Nav.ui_size()
	_root.size = s
	_scene.position = ((s - Nav.BASE) * 0.5).floor()
	_sky.position = _scene.position
	for g in _glows:
		g.get_parent().position = _scene.position
	_bar.position = Vector2(4, 3)
	_fit_bar()
	if _popup:
		_popup.reset_size()
		_popup.position = ((s - _popup.size) * 0.5).floor()
	if _panel:
		_panel.reset_size()
		_panel.position = ((s - _panel.size) * 0.5).floor()


## The room painting, its furniture piece by piece, the dog in its basket, and what each piece does when clicked.
func _room() -> void:
	var back := TextureRect.new()
	back.texture = load(ART + "room.png")
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room_mat = ShaderMaterial.new()
	_room_mat.shader = load("res://shaders/room.gdshader")
	_room_mat.set_shader_parameter("sun", load(ART + "room_sun.png"))
	back.material = _room_mat
	_sunlit.append(_room_mat)
	_scene.add_child(back)
	var rects: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "layers.json"))
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
	var pet := Hotspot.make(Rect2(bed.position, bed.texture.get_size()), "Pet " + _dog_name(), _shape("bed"))
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
		_root.add_child(light)
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
		var flicker := 0.92 + 0.05 * sin(_t * 9.0) + 0.03 * sin(_t * 23.0) + randf() * 0.02
		for f in FLAMES:
			lamps.append(Vector4(f[0].x, f[0].y, f[1], (0.08 + 0.95 * night) * flicker * lit))
	if _flames:
		_flames.modulate.a = lit
	var ambient := Daylight.light(hour)
	for m in _sunlit:
		m.set_shader_parameter("night", night)
		m.set_shader_parameter("ambient", ambient)
		m.set_shader_parameter("lamp_count", lamps.size())
		if not lamps.is_empty():
			m.set_shader_parameter("lamps", PackedVector4Array(lamps))
	for g in _glows:
		g.night = night
		g.lit = lit
	var part := Daylight.part_of_day(hour)
	var day := "Day %d, %s" % [int(Game.state["day"]), part]
	if _day.text != day:
		_day.text = day
		_fit_bar()
	_end_day.theme_type_variation = "MainButton" if part in ["evening", "night"] else ""


## Lets a piece's painted sunlight fade at night with the room's, reading the room's sunlight map at its place.
func _follow_sun(t: TextureRect) -> void:
	var m := t.material as ShaderMaterial
	if m == null:
		m = ShaderMaterial.new()
		m.shader = load("res://shaders/room.gdshader")
		t.material = m
	var room := Vector2(480, 272)
	m.set_shader_parameter("sun", load(ART + "room_sun.png"))
	m.set_shader_parameter("sun_origin", t.position / room)
	m.set_shader_parameter("sun_span", t.texture.get_size() / room)
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
		var above := Vector2(h.position.x + h.size.x * 0.5 - _tip.size.x * 0.5, h.position.y - _tip.size.y - 3)
		if above.y < 46:
			above.y = h.position.y + h.size.y + 3
		_tip.position = (_scene.position + above).clamp(Vector2(2, 2), Nav.ui_size() - _tip.size - Vector2(2, 2)).floor())


func _use(what: String) -> void:
	_tip.visible = false
	Audio.ui("click")
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
	return str((Game.state.get("dog", {}) as Dictionary).get("name", "the dog"))


func _build_bar() -> void:
	_bar = Ui.panel(_root, "TabletPanel")
	var row := Ui.hbox(_bar, 4)
	Ui.icon(row, "coin")
	_coins = Ui.label(row, "", "LightLabel")
	_rep = Ui.button(row, "", func() -> void:
		_close_panel()
		_panel = ChaptersPanel.open(_root), "laurel")
	Ui.icon(row, "sun")
	_day = Ui.label(row, "", "LightLabel")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_jobs = Ui.label(row, "", "LightLabel")
	_end_day = Ui.button(row, "End the day", func() -> void: Nav.go("day_end"), "sun")
	Ui.icon_button(row, "gear", "Settings", func() -> void: SettingsPanel.open(_root, true))
	Ui.icon_button(row, "house", "Save and go back to the title", _save_and_quit)


## When big numbers would push the top bar past the edge, the job count goes first, then the chapter button shortens.
func _fit_bar() -> void:
	var room := Nav.ui_size().x - 8
	_jobs.visible = true
	_rep.text = _chapter_text(false)
	if _bar.get_combined_minimum_size().x > room:
		_jobs.visible = false
	if _bar.get_combined_minimum_size().x > room:
		_rep.text = _chapter_text(true)
	_bar.size = Vector2(room, 0)


func _chapter_text(short: bool) -> String:
	var st := Game.state
	var next := Data.chapter(int(st["chapter"]) + 1)
	return ("Ch %d  %d" if short else "Chapter %d  %d") % [int(st["chapter"]), int(st["reputation"])] + ("" if next.is_empty() else "/%d" % int(next["reputation"]))


func _refresh() -> void:
	var st := Game.state
	_coins.text = "%d d" % int(st["coins"])
	var ch := Data.chapter(int(st["chapter"]))
	var next := Data.chapter(int(st["chapter"]) + 1)
	Ui.tip_on(_rep, "Chapter %d: %s. Reputation %d" % [int(st["chapter"]), ch.get("title", ""), int(st["reputation"])] + ("" if next.is_empty() else " of the %d that opens chapter %d" % [int(next["reputation"]), int(next["n"])]) + ". Click to see every chapter.")
	var left := Story.jobs_left(st)
	_jobs.text = "%d job%s left" % [left, "" if left == 1 else "s"]
	_fit_bar()


func _open_table() -> void:
	var job: Dictionary = Game.state["active_job"]
	if job.is_empty():
		_close_panel()
		_panel = Ui.panel(_root, "PagePanel")
		var col := Ui.vbox(_panel, 4)
		Ui.label(col, "Nothing on the table yet", "Heading")
		Ui.label(col, "Take a job from the job board, and its floor plan will be waiting here." if Story.jobs_left(Game.state) > 0 else "That's today's work done. End the day, and new notices go up on the board in the morning.", "", 220)
		if Story.can_make_panel(Game.state):
			Ui.label(col, "Or lay a small picture panel at the workbench, under the window.", "MutedLabel", 220)
		var row := Ui.hbox(col, 4)
		row.alignment = BoxContainer.ALIGNMENT_END
		Ui.button(row, "Close", _close_panel, "cross")
		if Story.can_make_panel(Game.state):
			Ui.button(row, "To the workbench", _open_bench, "hammer")
		if Story.jobs_left(Game.state) > 0:
			Ui.button(row, "To the job board", func() -> void: Nav.go("job_board"), "arrow_r", true)
		else:
			Ui.button(row, "End the day", func() -> void: Nav.go("day_end"), "sun", true)
		_layout.call_deferred()
		return
	if job.get("kind", "") == "restoration":
		Nav.go("floor", {"job": job})
	else:
		Nav.go("design_table", {"job": job})


func _pet() -> void:
	Game.bump("pets")
	if _dog.is_up():
		_hearts()
	else:
		Audio.ui("rustle", -12.0)
	_dog.pet()


func _hearts() -> void:
	Audio.ui("dog", -8.0)
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
	Audio.ui("nope", -8.0)


func _save_and_quit() -> void:
	Saves.save()
	Nav.go("title")


func _queue_event(e: Dictionary) -> void:
	if not Game.state.has("pending_events"):
		Game.state["pending_events"] = []
	Game.state["pending_events"].push_front(e)


## Shows the next letter waiting: a new chapter, or what a client said about their floor.
func _show_next_event() -> void:
	var pending: Array = Game.state.get("pending_events", [])
	if pending.is_empty() or _popup:
		return
	var e: Dictionary = pending.pop_front()
	_popup = Ui.panel(_root, "PagePanel")
	var sides := Ui.hbox(_popup, 10)
	var col := Ui.vbox(sides, 5)
	var news: bool = e.get("kind", "") == "chapter" and int(e.get("n", 1)) > 1
	if e.get("kind", "") == "chapter":
		Ui.label(col, "Chapter %d" % int(e.get("n", 1)), "MutedLabel").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var t := Ui.label(col, str(e.get("title", "")), "Heading")
		t.add_theme_font_size_override("font_size", 16)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		Ui.label(col, str(e.get("title", Data.client(e.get("client", "")).get("name", "News"))), "Heading")
	Ui.label(col, str(e.get("text", "")), "", 200 if news else 240)
	if e.get("kind", "") == "chapter":
		_chapter_news(sides, col, int(e.get("n", 1)))
	var ok := Ui.button(col, "Carry on", func() -> void:
		_popup.queue_free()
		_popup = null
		_show_next_event(), "tick", true)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Audio.ui("page_turn", -6.0)
	_layout.call_deferred()


## Beside a chapter's letter, what it adds to the workshop, and under it how far off the next one is.
func _chapter_news(sides: HBoxContainer, col: VBoxContainer, n: int) -> void:
	if n > 1:
		var list := Ui.vbox(sides, 2)
		Ui.label(list, "New in the workshop:", "Heading")
		for line in Story.chapter_unlocks(n):
			var r := Ui.hbox(list, 3)
			Ui.icon(r, "tick_small").size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			Ui.label(r, line, "", 220)
	var next := Story.next_chapter_line(Game.state)
	if n == 1:
		next = "Finish floors to earn reputation, and better floors earn more. " + next + "."
	elif next != "":
		next += "."
	if next != "":
		Ui.label(col, next + " The Chapter button at the top shows what each chapter brings.", "MutedLabel", 200 if n > 1 else 240)


func _close_panel() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null


func _open_merchant() -> void:
	_close_panel()
	_panel = Ui.panel(_root, "PagePanel")
	var col := Ui.vbox(_panel, 3)
	Ui.label(col, "The stone merchant", "Heading")
	Ui.label(col, "Stone comes in sacks of 100 tiles. What you run short of while laying is bought for you anyway.", "", 250)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	col.add_child(grid)
	for id in Game.state["unlocked_stones"]:
		Ui.texture(grid, MotifIcons.swatch(id, 10))
		Ui.label(grid, str(Stones.LIST[Stones.index(id)]["name"]))
		var have := Ui.label(grid, "%d in stock" % Game.stock(id), "MutedLabel")
		var sid: String = id
		var price := int(ceil(Game.stone_price(sid) * Data.num("sack", 100)))
		Ui.button(grid, "Buy 100: %d d" % price, func() -> void:
			if Game.spend(price, "Stone: " + str(Stones.LIST[Stones.index(sid)]["name"])):
				Game.add_stock(sid, int(Data.num("sack", 100)))
				Audio.ui("coins")
				have.text = "%d in stock" % Game.stock(sid)
			else:
				Audio.ui("nope"))
	var cargo := Story.ship_stone(Game.state)
	if cargo != "" and not cargo in Game.state["unlocked_stones"]:
		var ship := Ui.panel(col, "CardPanel")
		var row := Ui.hbox(ship, 6)
		Ui.texture(row, MotifIcons.swatch(cargo, 12))
		var name := str(Stones.LIST[Stones.index(cargo)]["name"])
		var text := Ui.vbox(row, 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Ui.label(text, "%s, off the ship from %s" % [name, Game.state["ship"].get("port", "abroad")])
		Ui.label(text, "Today only. Buy a sack and it's yours to use from now on.", "MutedLabel", 170)
		var price := int(ceil(Data.stone_price(cargo) * Data.num("ship.price_scale", 1.5) * Data.num("sack", 100)))
		Ui.button(row, "Buy 100: %d d" % price, func() -> void:
			if Game.spend(price, "Stone off the ship: " + name):
				Game.bump("ship_stones")
				Game.state["unlocked_stones"].append(cargo)
				Game.add_stock(cargo, int(Data.num("sack", 100)))
				Audio.ui("coins")
				Saves.save()
				_open_merchant()
			else:
				Audio.ui("nope"), "sack", true)
	Ui.button(col, "Done", _close_panel, "tick").size_flags_horizontal = Control.SIZE_SHRINK_END
	_layout.call_deferred()


## The workbench: a picture panel to lay today, the panels made so far for collectors to buy, and the upgrades.
func _open_bench() -> void:
	_close_panel()
	_panel = Ui.panel(_root, "PagePanel")
	var col := Ui.vbox(_panel, 4)
	var head := Ui.hbox(col, 4)
	Ui.label(head, "The workbench", "Heading").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.button(head, "Done", _close_panel, "tick")
	Ui.label(col, "Lay a small picture panel here, one a day. A collector will buy it, or you can set it into a client's floor, where it comes laid already and the client pays extra.", "MutedLabel", 270)
	var lay := Ui.button(col, "Lay a picture panel", _start_panel, "brush", true)
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
			var name := Ui.label(row, "%s, %d stars" % [str(Data.motif(panel["motif"]).get("name", "A picture")), int(panel.get("stars", 0))])
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var value := Story.panel_value(Game.state, int(panel.get("stars", 0)))
			var sold: Dictionary = panel
			Ui.button(row, "Sell: %d d" % value, func() -> void: _sell_panel(sold, value), "coin")
	Ui.button(col, "Improve the workshop", _open_upgrades, "hammer")
	_layout.call_deferred()


func _start_panel() -> void:
	var job := {"kind": "panel", "room": "panel", "client": "", "client_name": "Your picture panel", "portrait": "", "brief": {},
		"budget": 0, "arc_step": -1, "taste": [], "id": "panel_%d" % int(Game.state["day"])}
	Game.state["active_job"] = job
	Nav.go("design_table", {"job": job})


func _sell_panel(panel: Dictionary, value: int) -> void:
	Game.state["panels"] = (Game.state["panels"] as Array).filter(func(p: Dictionary) -> bool: return p["id"] != panel["id"])
	Game.earn(value, "Picture panel")
	Game.bump("panels_sold")
	Audio.ui("coins")
	Saves.save()
	_open_bench()


func _open_upgrades() -> void:
	_close_panel()
	_panel = Ui.panel(_root, "PagePanel")
	var col := Ui.vbox(_panel, 3)
	var head := Ui.hbox(col, 4)
	Ui.label(head, "Improve the workshop", "Heading").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.button(head, "Done", _close_panel, "tick")
	# Two to a row, so every upgrade fits on the screen at once.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 3)
	col.add_child(grid)
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
		Ui.label(text, str(u["name"]) + ("  (%d of %d)" % [owned, limit] if limit > 1 else ""), "", 172)
		Ui.label(text, str(u.get("text", "")), "MutedLabel", 172)
		var uid: String = id
		var cost := int(u.get("cost", 0))
		var b := Ui.button(row, "Owned" if owned >= limit else "%d d" % cost, func() -> void: _buy(uid, cost))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = owned >= limit or cost > Game.coins()
	_layout.call_deferred()


func _buy(id: String, cost: int) -> void:
	if not Game.spend(cost, Data.upgrades[id]["name"]):
		Audio.ui("nope")
		return
	if id == "apprentice":
		Game.state["apprentices"] = int(Game.state["apprentices"]) + 1
	else:
		Game.state["upgrades"].append(id)
	Audio.ui("coins")
	Saves.save()
	Nav.go("workshop")
