class_name Guide
extends PanelContainer
## The guide for a new workshop: a short note on each screen the first time it opens, saying what to do there, with a
## bouncing arrow at the thing to click. Each note shows once, and "Skip the guide" turns the rest off.

const WIDTH := 190.0

var _corner := ""
var _arrow: TextureRect
var _target_rect := Rect2()
var _target_control: Control
var _follows := false
var _t := 0.0


## Whether the guide is still running: until the first floor is done and the day ended, unless it was skipped.
static func active() -> bool:
	return not bool(Game.state.get("guide_off", false)) and (Game.state.get("floors", []) as Array).size() <= 1 and (str(Game.state.get("name", "")) != "" or Dev.has("guide"))


## Shows a note once, at a corner of the screen, "top" or "right", with an arrow at the target if given: a Control,
## which the arrow follows wherever it moves, or a Rect2 in interface pixels.
static func note(id: String, text: String, corner: String, target: Variant = null) -> Guide:
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


func _build(text: String, corner: String, target: Variant) -> void:
	_corner = corner
	_follows = target is Control
	if _follows:
		_target_control = target
	elif target is Rect2:
		_target_rect = target
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
	Ui.closes_with(self)
	if _follows or _target_rect.has_area():
		_arrow = TextureRect.new()
		_arrow.texture = UiTheme.icon("arrow_r")
		_arrow.pivot_offset = Vector2(8, 8)
		_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Nav.ui.add_child(_arrow)
		tree_exiting.connect(_arrow.queue_free)
		_point()
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


func _process(delta: float) -> void:
	if _arrow:
		_t += delta
		_point()


## Points the arrow at the target where it is now, bobbing up and down.
func _point() -> void:
	var target := _target_rect
	if _follows:
		if not is_instance_valid(_target_control) or not _target_control.is_visible_in_tree():
			_arrow.visible = false
			return
		var to_ui := Nav.ui.get_global_transform_with_canvas().affine_inverse() * _target_control.get_global_transform_with_canvas()
		target = to_ui * Rect2(Vector2.ZERO, _target_control.size)
	_arrow.visible = true
	# Something in the top bar is pointed at from below; anything lower down from just inside its top edge.
	var up := target.position.y < 40.0
	_arrow.rotation = -PI * 0.5 if up else PI * 0.5
	var at := Vector2(target.get_center().x - 8.0, target.end.y + 2.0 if up else target.position.y + 6.0).floor()
	_arrow.position = at + Vector2(0.0, 2.0 * cos(_t * PI / 0.4) - 2.0)
