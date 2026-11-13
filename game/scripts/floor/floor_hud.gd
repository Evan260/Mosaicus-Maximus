class_name FloorHud
extends Control
## The floor screen's interface: what to do now and how far along it is, the tray of stones or tools for the job in
## hand, and the brush. Nothing in the tray is picked until the player picks it.

var screen: Node
var _title: Label
var _bar: ProgressBar
var _top: PanelContainer
var _tray: GridContainer
var _side: HBoxContainer
var _tray_panel: PanelContainer
var _tools: VBoxContainer
var _buttons := {}
var _done: Button
var _find: Button
var _hint: Label
var _last_hint := ""
var _last_title := ""
var _tray_phase := -1
## The 1 to 9 in the corner of the first nine stone chips, which name their number keys.
var _digits: Array[Label] = []


func setup(s: Node) -> void:
	screen = s
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top = PanelContainer.new()
	_top.theme_type_variation = "PagePanel"
	add_child(_top)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_top.add_child(col)
	_title = Label.new()
	_title.theme_type_variation = "Heading"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(150, 5)
	_bar.add_theme_stylebox_override("background", _flat(Color8(196, 172, 128)))
	_bar.add_theme_stylebox_override("fill", _flat(Color8(178, 92, 58)))
	col.add_child(_bar)
	_tray_panel = PanelContainer.new()
	_tray_panel.theme_type_variation = "TabletPanel"
	add_child(_tray_panel)
	var row := Ui.hbox(_tray_panel, 6)
	_tray = GridContainer.new()
	_tray.add_theme_constant_override("h_separation", 4)
	_tray.add_theme_constant_override("v_separation", 4)
	row.add_child(_tray)
	_side = Ui.hbox(row, 4)
	_tools = VBoxContainer.new()
	_tools.add_theme_constant_override("separation", 3)
	add_child(_tools)
	var tool_glyphs := {"pad_rb": _icon_button("plus", "Bigger brush ( ] )", func() -> void: screen.grow_brush(1.0)),
		"pad_lb": _icon_button("minus", "Smaller brush ( [ )", func() -> void: screen.grow_brush(-1.0)),
		"pad_view": _icon_button("eye", "Show or hide the chalk sketch (C)", func() -> void: screen.floor_view.chalk_visible = not screen.floor_view.chalk_visible)}
	for glyph in tool_glyphs:
		_tools.add_child(tool_glyphs[glyph])
		PadGlyph.badge(tool_glyphs[glyph], glyph, Vector2(0.0, 0.5), Vector2(-14, 0))
	_hint = Label.new()
	_hint.theme_type_variation = "LightLabel"
	_hint.add_theme_color_override("font_outline_color", Color8(40, 26, 20))
	_hint.add_theme_constant_override("outline_size", 2)
	add_child(_hint)
	# The d-pad's right picks the next stone, as Tab does, so its picture follows the hint about picking stones.
	PadGlyph.badge(_hint, "pad_dpad_right", Vector2(1.0, 0.5), Vector2(12, 0), func() -> bool: return screen.floor_view != null and screen.floor_view.phase == FloorView.Phase.LAY)
	Nav.resized.connect(_place)
	_place.call_deferred()


func _process(_delta: float) -> void:
	var fv: FloorView = screen.floor_view
	if fv.phase != _tray_phase:
		_tray_phase = fv.phase
		_build_tray()
	var tool: String = screen.tool
	_bar.value = 100.0 * fv.progress()
	match fv.phase:
		FloorView.Phase.LAY:
			_title.text = "Lay the tiles"
			_hint.text = "Pick a stone from the tray below to start laying." if screen.stone < 0 else "Sweep over the places that glow. Pick another stone when you like (1 to 9)."
		FloorView.Phase.DIG:
			_title.text = "Clear away the dirt"
			_hint.text = "Pick the trowel from the tray below." if tool == "" else "Scrape the dirt away to find the old floor underneath."
		FloorView.Phase.REPAIR:
			var left := fv.gaps_left()
			_title.text = tr("Fill the gaps") if left == 0 else tr("Fill the gaps: %d left") % left
			if fv.repairs_done():
				_hint.text = "Every gap is filled. Check your stones, then press Done."
			elif tool == "lift":
				_hint.text = "Click a tile you set to lift it out again."
			elif fv.repair_stone < 0:
				_hint.text = "Pick the stone that matches a gap, or the chisel to lift a tile out."
			elif left < FloorView.RING_GAPS_BELOW:
				_hint.text = "The last gaps are ringed in gold. Click one to set a tile."
			else:
				_hint.text = "Click a gap to set one tile. The wheel zooms in for the details."
		FloorView.Phase.GROUT:
			_title.text = "Grout and polish"
			if tool == "sponge":
				_hint.text = "Wipe the grout into every gap."
			elif tool == "cloth":
				_hint.text = "Polish the grouted stone until it shines."
			else:
				_hint.text = "Pick the sponge to wipe in the grout, then the cloth to polish it."
		FloorView.Phase.DONE:
			_title.text = "Finished"
			_hint.text = ""
	_hint.visible = Settings.hints and _hint.text != ""
	if _hint.text != _last_hint or _title.text != _last_title:
		_last_hint = _hint.text
		_last_title = _title.text
		_place.call_deferred()
	_tray_panel.visible = fv.phase != FloorView.Phase.DONE
	if _done:
		_done.disabled = not fv.repairs_done()
	if _find and _find.visible != (fv.gaps_left() > 0):
		_find.visible = fv.gaps_left() > 0
		_tray_panel.size = Vector2.ZERO
		_place.call_deferred()
	for d in _digits:
		d.visible = not Pad.using
	for key in _buttons:
		var b: Button = _buttons[key]
		if key is int:
			if fv.phase == FloorView.Phase.LAY:
				var left: int = fv.stone_unplaced(key)
				b.text = str(left)
				b.modulate.a = 1.0 if left > 0 else 0.4
				b.button_pressed = key == screen.stone
			else:
				b.button_pressed = key == fv.repair_stone and tool == "stone"
		else:
			b.button_pressed = key == tool


## The tray for the job in hand: stones to lay, the trowel, stones and the chisel for mending, or sponge and cloth.
func _build_tray() -> void:
	# Detached at once, so the tray measures only the new buttons when it sizes itself.
	for c in _tray.get_children() + _side.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	_buttons.clear()
	_digits.clear()
	_done = null
	_find = null
	var fv: FloorView = screen.floor_view
	match fv.phase:
		FloorView.Phase.LAY:
			var order := fv.stones_used()
			for k in order.size():
				var st: int = order[k]
				var b := _tray_button(MotifIcons.swatch(Stones.id_of(st), 12), "%s (%d)" % [Stones.title(Stones.id_of(st)), k + 1] if k < 9 else Stones.title(Stones.id_of(st)), func() -> void: screen.select_stone(st))
				b.custom_minimum_size = Vector2(38, 22)
				if k < 9:
					_add_digit(b, k + 1)
				_buttons[st] = b
		FloorView.Phase.DIG:
			_buttons["trowel"] = _tray_button(UiTheme.icon("trowel"), "Trowel: scrape away the dirt", func() -> void: screen.select_tool("trowel"), "Trowel")
		FloorView.Phase.REPAIR:
			var ids: Array = (Game.state["unlocked_stones"] as Array).duplicate()
			for st in fv.stones_used():
				if not Stones.id_of(st) in ids:
					ids.append(Stones.id_of(st))
			for id in ids:
				var st := Stones.index(id)
				_buttons[st] = _tray_button(MotifIcons.swatch(id, 12), Stones.title(id), func() -> void: screen.select_repair_stone(st))
			_buttons["lift"] = _tray_button(UiTheme.icon("chisel"), "Chisel: lift out a tile you set", func() -> void: screen.select_tool("lift"))
			# These have no count beside them, so the picture sits in the middle of its square.
			for key in _buttons:
				_buttons[key].icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_find = Ui.button(_side, "Find a gap", screen.find_gap, "eye")
			Ui.tip_on(_find, "Shows you a gap that still needs a stone")
			_find.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_done = Ui.button(_side, "Done", func() -> void: screen.floor_view.finish_repairs(), "tick", true)
			_done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		FloorView.Phase.GROUT:
			_buttons["sponge"] = _tray_button(UiTheme.icon("sponge"), "Sponge: wipe the grout into the gaps", func() -> void: screen.select_tool("sponge"), "Sponge")
			_buttons["cloth"] = _tray_button(UiTheme.icon("cloth"), "Cloth: polish the grouted stone", func() -> void: screen.select_tool("cloth"), "Cloth")
	_tray.columns = maxi(1, mini(_buttons.size(), 10))
	_tray_panel.size = Vector2.ZERO
	_place.call_deferred()


func _tray_button(icon: Texture2D, tip: String, action: Callable, text: String = "") -> Button:
	var b := Button.new()
	b.icon = icon
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(22, 22)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", UiTheme.panel("chip_off", 3, 3))
	b.add_theme_stylebox_override("hover", UiTheme.panel("chip_off", 3, 3))
	b.add_theme_stylebox_override("pressed", UiTheme.panel("chip_on", 3, 3))
	b.add_theme_stylebox_override("hover_pressed", UiTheme.panel("chip_on", 3, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	Ui.tip_on(b, tip)
	b.pressed.connect(action)
	_tray.add_child(b)
	if text != "":
		Ui.centre_text(b)
	return b


## Writes a chip's number key small in its top left corner, with the chip's picture moved over to make room.
func _add_digit(b: Button, n: int) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		(b.get_theme_stylebox(state) as StyleBoxTexture).content_margin_left = 8
	var d := Label.new()
	d.text = str(n)
	d.add_theme_font_override("font", UiTheme.digit_font())
	d.add_theme_font_size_override("font_size", 8)
	d.add_theme_color_override("font_color", UiTheme.MUTED)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.position = Vector2(2, 1)
	b.add_child(d)
	_digits.append(d)


## A little bounce of the tray, when the brush is used before anything in it is picked.
func nudge_tray() -> void:
	if _tray_panel.has_meta("nudging"):
		return
	_tray_panel.set_meta("nudging", true)
	var home := _tray_panel.position
	var tw := create_tween()
	tw.tween_property(_tray_panel, "position:y", home.y - 4, 0.08)
	tw.tween_property(_tray_panel, "position:y", home.y, 0.12)
	tw.tween_callback(func() -> void: _tray_panel.remove_meta("nudging"))
	Audio.play("nope", -14.0)


func _place() -> void:
	var s := Nav.ui_size()
	size = s
	_top.reset_size()
	_top.position = Vector2(floorf((s.x - _top.size.x) * 0.5), 4)
	_tray_panel.reset_size()
	_tray_panel.position = Vector2(floorf((s.x - _tray_panel.size.x) * 0.5), s.y - _tray_panel.size.y - 4)
	_tools.reset_size()
	_tools.position = Vector2(s.x - _tools.size.x - 6, floorf((s.y - _tools.size.y) * 0.5))
	_hint.reset_size()
	_hint.position = Vector2(floorf((s.x - _hint.size.x) * 0.5), _top.position.y + _top.size.y + 3)


func _icon_button(icon_name: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.icon = UiTheme.icon(icon_name)
	Ui.tip_on(b, tip)
	b.custom_minimum_size = Vector2(22, 22)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(func() -> void:
		Audio.play("click")
		action.call())
	return b


func _flat(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	return s
