class_name Guide
extends PanelContainer
## The guide for a new workshop: a short note on each screen the first time it opens, saying what to do there, with a
## bouncing arrow at the thing to click. Each note shows once, and "Skip the guide" turns the rest off.

const WIDTH := 190.0

var _corner := ""
var _arrow: TextureRect
var _target := Rect2()


## Whether the guide is still running: until the first floor is done and the day ended, unless it was skipped.
static func active() -> bool:
	return not bool(Game.state.get("guide_off", false)) and (Game.state.get("floors", []) as Array).size() <= 1 and (str(Game.state.get("name", "")) != "" or Dev.has("guide"))


## Shows a note once, at a corner of the screen, "top" or "right", with an arrow at the target (interface pixels) if given.
static func note(id: String, text: String, corner: String, target := Rect2()) -> Guide:
	var seen: Array = Game.state.get("guide_seen", [])
	if not active() or id in seen:
		return null
	seen.append(id)
	Game.state["guide_seen"] = seen
	var g := Guide.new()
	g.theme_type_variation = "TabletPanel"
	Nav.ui.add_child(g)
	g._build(text, corner, target)
	return g


func _build(text: String, corner: String, target: Rect2) -> void:
	_corner = corner
	_target = target
	var col := Ui.vbox(self, 4)
	var head := Ui.hbox(col, 3)
	Ui.icon(head, "laurel")
	Ui.label(head, "Your uncle's notes", "LightHeading")
	Ui.label(col, text, "LightLabel", WIDTH)
	var row := Ui.hbox(col, 4)
	var skip := Ui.button(row, "Skip the guide", func() -> void:
		Game.state["guide_off"] = true
		queue_free())
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.button(row, "Got it", func() -> void: queue_free(), "tick", true)
	if target.has_area():
		_arrow = TextureRect.new()
		_arrow.texture = UiTheme.icon("arrow_r")
		_arrow.pivot_offset = Vector2(8, 8)
		_arrow.rotation = PI * 0.5
		_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Nav.ui.add_child(_arrow)
		tree_exiting.connect(_arrow.queue_free)
		var tw := _arrow.create_tween().set_loops()
		tw.tween_property(_arrow, "position:y", -4.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)
		tw.tween_property(_arrow, "position:y", 4.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)
	Audio.ui("page_turn", -10.0)
	Nav.resized.connect(_place)
	_place.call_deferred()


func _place() -> void:
	reset_size()
	var s := Nav.ui_size()
	var x := 6.0 if _corner.ends_with("left") else s.x - size.x - 6.0
	if _corner == "top":
		x = floorf((s.x - size.x) * 0.5)
	var y := 30.0 if _corner.begins_with("top") else s.y - size.y - 6.0
	if _corner == "right":
		y = floorf((s.y - size.y) * 0.5)
	position = Vector2(x, y).floor()
	if _arrow:
		# Something in the top bar is pointed at from below; anything lower down from just inside its top edge.
		var up := _target.position.y < 40.0
		_arrow.rotation = -PI * 0.5 if up else PI * 0.5
		_arrow.position = Vector2(_target.get_center().x - 8.0, _target.end.y + 2.0 if up else _target.position.y + 6.0).floor()
