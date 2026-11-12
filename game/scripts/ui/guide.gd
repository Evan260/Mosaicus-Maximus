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
var _over: Control
var _words: Label
var _chrome: Array[Control] = []


## Whether the guide is still running: until the first floor is done and the day ended, unless it was skipped.
static func active() -> bool:
	return Settings.guide and not bool(Game.state.get("guide_off", false)) and (Game.state.get("floors", []) as Array).size() <= 1 and (str(Game.state.get("name", "")) != "" or Dev.has("guide"))


## Shows a note once, at a corner of the screen, "top" or "right", with an arrow at the target if given: a Control,
## which the arrow follows wherever it moves, or a Rect2 in interface pixels. "over" lays the note on the target Control
## instead, as narrow as fits its height, reaching left past it only when it must.
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
	if corner == "over":
		_over = target
		target = null
	_follows = target is Control
	if _follows:
		_target_control = target
	elif target is Rect2:
		_target_rect = target
	var col := Ui.vbox(self, 4)
	var head := Ui.hbox(col, 3)
	Ui.icon(head, "laurel")
	Ui.label(head, "Your uncle's notes", "LightHeading")
	var big := Settings.message_scale()
	_words = Ui.label(col, text, "LightLabel", minf(WIDTH * big, Nav.ui_size().x - 24.0))
	_words.add_theme_font_size_override("font_size", UiTheme.text_size() * big)
	var row: BoxContainer = Ui.vbox(col, 3) if _over else Ui.hbox(col, 4)
	_chrome = [head, row]
	var skip := Ui.button(row, "Skip the guide", func() -> void:
		Game.state["guide_off"] = true
		queue_free())
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.button(row, "Got it", func() -> void: queue_free(), "tick", true)
	Ui.closes_with(self, Callable(), false)
	if _follows or _target_rect.has_area():
		_arrow = TextureRect.new()
		_arrow.texture = UiTheme.icon("arrow_r")
		_arrow.pivot_offset = Vector2(8, 8)
		_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Nav.ui.add_child(_arrow)
		tree_exiting.connect(_arrow.queue_free)
		_point()
	Audio.play("page_turn", -10.0)
	Nav.resized.connect(_on_resized)
	_place.call_deferred()


## Places the note once the screen's containers have laid themselves out after a resize.
func _on_resized() -> void:
	_place.call_deferred()


func _place() -> void:
	if _over:
		_place_over()
		return
	reset_size()
	var s := Nav.ui_size()
	var x := 6.0 if _corner.ends_with("left") else s.x - size.x - 6.0
	if _corner == "top":
		x = floorf((s.x - size.x) * 0.5)
	var y := 30.0 if _corner.begins_with("top") else s.y - size.y - 6.0
	if _corner == "right":
		y = floorf((s.y - size.y) * 0.5)
	position = Vector2(x, y).floor()


## Covers the target from its top right, as narrow as fits its height; a note too long for it reaches down, then left.
func _place_over() -> void:
	if not is_instance_valid(_over):
		return
	var to_ui := Nav.ui.get_global_transform_with_canvas().affine_inverse() * _over.get_global_transform_with_canvas()
	var room := to_ui * Rect2(Vector2.ZERO, _over.size)
	var frame := get_theme_stylebox("panel").get_minimum_size()
	var narrow := room.size.x - frame.x
	var wide := maxf(narrow, minf(WIDTH * Settings.message_scale(), room.end.x - 6.0) - frame.x)
	var tall := Nav.ui_size().y - 6.0 - room.position.y
	var w := _width_for(narrow, wide, room.size.y)
	if _height(w) > room.size.y:
		w = _width_for(narrow, maxf(wide, room.end.x - 6.0 - frame.x), tall)
	_words.custom_minimum_size.x = w
	_settle.call_deferred(room)


## Shrinks the note round its words and sets it in place, once its boxes have caught up with the new width.
func _settle(room: Rect2) -> void:
	reset_size()
	var y := clampf(minf(room.position.y, Nav.ui_size().y - 6.0 - size.y), 0.0, room.position.y)
	position = Vector2(room.end.x - size.x, y).floor()


## The narrowest width from `narrow` to `wide`, in steps, at which the note is no taller than `height`.
func _width_for(narrow: float, wide: float, height: float) -> float:
	var w := narrow
	while w < wide and _height(w) > height:
		w += 10.0
	return minf(w, wide)


## How tall the note is with its words wrapped at width `w`.
func _height(w: float) -> float:
	_words.custom_minimum_size.x = w
	_words.size.x = w
	var h := get_theme_stylebox("panel").get_minimum_size().y + 8.0 + _words.get_minimum_size().y
	for c in _chrome:
		h += c.get_combined_minimum_size().y
	return h


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
	_arrow.position = at + (Vector2.ZERO if Settings.reduced_motion else Vector2(0.0, 2.0 * cos(_t * PI / 0.4) - 2.0))
