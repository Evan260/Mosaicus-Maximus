extends Node
## The town from above. Every floor you've laid is marked where it lies; click one to see it again.

const MAP := "res://assets/art/town/map.png"
const DISTRICTS := {
	"lane": {"name": "Potters' Lane", "at": Vector2(56, 130), "chapter": 1},
	"forum": {"name": "The forum", "at": Vector2(217, 118), "chapter": 1},
	"harbour": {"name": "The harbour", "at": Vector2(190, 214), "chapter": 1},
	"baths": {"name": "The baths", "at": Vector2(386, 136), "chapter": 2},
	"hill": {"name": "The villas on the hill", "at": Vector2(372, 44), "chapter": 2},
	"temple": {"name": "The temple of Venus", "at": Vector2(92, 30), "chapter": 4},
}
const ROOM_DISTRICT := {
	"vestibule": "lane", "bedroom": "lane", "study": "lane", "shop": "forum", "tavern": "harbour", "bakery": "forum",
	"changing_room": "baths", "nymphaeum": "baths", "dining_room": "hill", "villa_dining": "hill", "atrium": "hill",
	"corridor": "forum", "temple": "temple", "forum": "forum",
}

var _root: Control
var _map: Control
var _tip: PanelContainer
var _tip_label: Label
var _view: PanelContainer
var _visit: Control
var _task := -1
var _pending := {}


func enter(_args: Dictionary) -> void:
	_root = Control.new()
	Nav.ui.add_child(_root)
	_map = Control.new()
	_map.size = Nav.BASE
	_map.draw.connect(_draw_map)
	_root.add_child(_map)
	if ResourceLoader.exists(MAP):
		var back := TextureRect.new()
		back.texture = load(MAP)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map.add_child(back)
	var chapter := int(Game.state["chapter"])
	for id in DISTRICTS:
		var d: Dictionary = DISTRICTS[id]
		var open := int(d["chapter"]) <= chapter
		var tag := Ui.panel(_map, "TipPanel")
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := Ui.label(tag, str(d["name"]) if open else "%s (chapter %d)" % [d["name"], d["chapter"]], "LightLabel")
		if not open:
			name_label.add_theme_color_override("font_color", Color8(170, 150, 130))
		tag.reset_size()
		tag.position = (Vector2(d["at"]) - Vector2(tag.size.x * 0.5, 24)).floor()
	var floors: Array = Game.state["floors"]
	if Dev.has("visit"):
		var room := Dev.get_arg("room", "study")
		floors.append({"room": room, "design": Samples.moved(Samples.make("villa"), room).to_dict(), "client": "septimus",
			"client_name": "Old Septimus", "day": 3, "score": 0.9, "paid": 87, "stars": 5})
		_show_floor.call_deferred(floors[-1], "Old Septimus's study, day 3")
	for i in floors.size():
		_marker(floors[i], i)
	_rival()
	_tip = Ui.panel(_root, "TipPanel")
	_tip_label = Ui.label(_tip, "", "LightLabel")
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := Ui.button(_root, "Back to the workshop", func() -> void: Nav.go("workshop"), "arrow_l")
	var place := func() -> void:
		var s := Nav.ui_size()
		_root.size = s
		_map.position = ((s - Nav.BASE) * 0.5).floor()
		back.reset_size()
		back.position = Vector2(s.x - back.size.x - 6, s.y - back.size.y - 6)
	Nav.resized.connect(place)
	place.call()


func _draw_map() -> void:
	if ResourceLoader.exists(MAP):
		return
	_map.draw_rect(Rect2(Vector2.ZERO, Nav.BASE), Color8(196, 176, 120))
	var sea := PackedVector2Array([Vector2(0, 228), Vector2(90, 236), Vector2(160, 250), Vector2(240, 244), Vector2(330, 252), Vector2(480, 240), Vector2(480, 270), Vector2(0, 270)])
	_map.draw_colored_polygon(sea, Color8(70, 120, 160))
	_map.draw_polyline(sea.slice(0, 6), Color8(236, 224, 190), 2.0)
	_map.draw_colored_polygon(PackedVector2Array([Vector2(300, 30), Vector2(480, 10), Vector2(480, 140), Vector2(360, 120)]), Color8(150, 164, 96))
	for road in [[Vector2(20, 140), Vector2(460, 150)], [Vector2(236, 20), Vector2(236, 240)], [Vector2(236, 140), Vector2(380, 70)]]:
		_map.draw_line(road[0], road[1], Color8(226, 206, 160), 5.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 70:
		var p := Vector2(rng.randf_range(30, 450), rng.randf_range(40, 215))
		if absf(p.x - 236) < 8 or absf(p.y - (140 + (p.x - 20) * 0.023)) < 7:
			continue
		var near_label := false
		for id in DISTRICTS:
			var at: Vector2 = DISTRICTS[id]["at"]
			if absf(p.x + 7 - at.x) < 50 and p.y > at.y - 30 and p.y < at.y - 4:
				near_label = true
		if near_label or (p.x > 360 and p.y > 80 and p.y < 125):
			continue
		var w := rng.randf_range(10, 20)
		var h := rng.randf_range(8, 14)
		_map.draw_rect(Rect2(p, Vector2(w, h)), Color8(206, 196, 176))
		_map.draw_rect(Rect2(p, Vector2(w, h * 0.45)), Color8(176, 92, 60))
		_map.draw_rect(Rect2(p, Vector2(w, h)), Color8(110, 80, 60), false, 1.0)
	_map.draw_circle(Vector2(236, 140), 18, Color8(226, 214, 186))
	_map.draw_arc(Vector2(236, 140), 18, 0, TAU, 32, Color8(150, 120, 90), 1.0)


func _marker(f: Dictionary, i: int) -> void:
	var district: String = ROOM_DISTRICT.get(f.get("room", ""), "lane")
	var centre: Vector2 = DISTRICTS[district]["at"]
	var rng := RandomNumberGenerator.new()
	rng.seed = i * 7919 + 13
	var at := centre + Vector2(rng.randf_range(-34, 34), rng.randf_range(-12, 18))
	var b := Button.new()
	b.icon = UiTheme.icon("tile")
	b.flat = true
	b.position = (at - Vector2(8, 8)).floor()
	b.size = Vector2(16, 16)
	var who: String = f.get("client_name", "")
	var room := str(Data.room(f.get("room", "")).get("name", "")).to_lower()
	var tip := "%s's %s, day %d" % [who, room, int(f.get("day", 1))] if who != "" else "A %s, day %d" % [room, int(f.get("day", 1))]
	b.mouse_entered.connect(func() -> void:
		_tip_label.text = tip
		_tip.visible = true
		_tip.reset_size()
		_tip.position = (_map.position + at - Vector2(_tip.size.x * 0.5, 22)).floor())
	b.mouse_exited.connect(func() -> void: _tip.visible = false)
	b.pressed.connect(func() -> void: _show_floor(f, tip))
	_map.add_child(b)


func _rival() -> void:
	var at := Vector2(430, 196)
	var tag := Ui.panel(_map, "TipPanel")
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rep := int(Game.state["rival"].get("reputation", 0))
	Ui.label(tag, "The rival workshop
reputation %d" % rep, "LightLabel")
	tag.reset_size()
	tag.position = (at - Vector2(tag.size.x * 0.5, 18)).floor()


func _show_floor(f: Dictionary, title: String) -> void:
	if _view:
		_view.queue_free()
		_view = null
	if RoomView.has_room(str(f.get("room", ""))) and _task < 0:
		_start_visit(f, title)
		return
	_view = Ui.panel(_root, "PagePanel")
	var col := Ui.vbox(_view, 4)
	Ui.label(col, title, "Heading")
	var d := FloorDesign.from_dict(f.get("design", {}))
	var px := clampi(int(220.0 / maxf(d.w, d.h * 1.5)), 2, 5)
	var img := Composer.picture(d, px)
	Ui.texture(col, ImageTexture.create_from_image(img))
	Ui.label(col, "Paid %d d. %s" % [int(f.get("paid", 0)), _owner_line(f)], "MutedLabel")
	Ui.button(col, "Close", func() -> void:
		_view.queue_free()
		_view = null, "tick")
	_view.reset_size()
	_view.position = ((Nav.ui_size() - _view.size) * 0.5).floor()
	Audio.ui("page_turn", -8.0)


## What the floor's owner thought of it: he or she by their portrait, or the owners when it isn't known.
func _owner_line(f: Dictionary) -> String:
	var portrait := str(f.get("portrait", ""))
	if portrait == "":
		portrait = str(Data.client(str(f.get("client", ""))).get("portrait", ""))
	var who := "The owners" if portrait == "" else str(JobFactory.pronouns({"portrait": portrait})["he"]).capitalize()
	var verb := "love" if portrait == "" else "loves"
	if float(f.get("score", 0)) < 0.8:
		verb = "like" if portrait == "" else "likes"
		return "%s %s it well enough." % [who, verb]
	return "%s %s it." % [who, verb]


## Lays the floor out away from the main thread, then shows it in its room.
func _start_visit(f: Dictionary, title: String) -> void:
	_visit = Control.new()
	_visit.size = Nav.ui_size()
	_root.add_child(_visit)
	var shade := ColorRect.new()
	shade.color = Color(0.13, 0.1, 0.09)
	shade.size = _visit.size
	_visit.add_child(shade)
	var wait := Ui.label(_visit, "Walking over to see it...", "LightLabel")
	wait.position = ((_visit.size - Vector2(120, 10)) * 0.5).floor()
	var d := FloorDesign.from_dict(f.get("design", {}))
	var layout := MosaicLayout.new()
	_pending = {"floor": f, "title": title, "layout": layout, "wait": wait}
	_task = WorkerThreadPool.add_task(func() -> void: layout.build(Composer.compose(d, 6), 6, Composer.fine_mask(d, 6)))
	Audio.ui("page_turn", -8.0)


func _process(_delta: float) -> void:
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	if _visit == null:
		return
	(_pending["wait"] as Label).queue_free()
	var f: Dictionary = _pending["floor"]
	var room := RoomView.new()
	_visit.add_child(room)
	room.setup(str(f.get("room", "")), _pending["layout"], f.get("stones", {}))
	room.floor_view.shine(0.4, 1.6)
	var s := Nav.ui_size()
	room.position = Vector2(minf((s.x - room.size.x) * 0.5 + 24.0, s.x - room.size.x + 24.0), (s.y - room.size.y) * 0.5).floor()
	var card := Ui.panel(_visit, "PagePanel")
	var col := Ui.vbox(card, 4)
	Ui.label(col, str(_pending["title"]), "Heading", 150)
	var stars := Ui.hbox(col, 1)
	for k in 5:
		Ui.icon(stars, "star").modulate = Color(1, 1, 1, 1.0 if k < int(f.get("stars", Looks.stars(float(f.get("score", 0))))) else 0.2)
	Ui.label(col, "Paid %d d. %s" % [int(f.get("paid", 0)), _owner_line(f)], "", 150)
	Ui.button(col, "Back to the map", func() -> void:
		_visit.queue_free()
		_visit = null, "arrow_l", true)
	card.reset_size()
	card.position = Vector2(6, floorf((s.y - card.size.y) * 0.5))
