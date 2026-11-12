class_name Ui
## Shorthand for building the interface in code with the game's theme.

## The page of a window, the darker paper of a tab that is not open, and the line round tabs.
const TAB_OPEN := Color8(240, 226, 192)
const TAB_SHUT := Color8(214, 190, 146)
const TAB_EDGE := Color8(160, 122, 84)


static func label(parent: Node, text: String, variation: String = "", wrap_width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = wrap_width
	if parent:
		parent.add_child(l)
	return l


static func button(parent: Node, text: String, action: Callable, icon_name: String = "", main: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = UiTheme.icon(icon_name)
	if main:
		b.theme_type_variation = "MainButton"
	b.pressed.connect(func() -> void:
		Audio.play("click")
		action.call())
	if parent:
		parent.add_child(b)
	if icon_name != "" and text != "":
		# Deferred, since callers set a list's left alignment after making the button.
		centre_text.call_deferred(b)
	return b


## Centres a centred button's text on the whole button: Godot centres it beside the icon, so the right keeps the icon's room too.
static func centre_text(b: Button) -> void:
	if not is_instance_valid(b) or b.icon == null or b.text == "" or b.has_meta("centred"):
		return
	if b.alignment != HORIZONTAL_ALIGNMENT_CENTER or b.icon_alignment != HORIZONTAL_ALIGNMENT_LEFT:
		return
	var theme := UiTheme.build()
	var gap := b.get_theme_constant("h_separation") if b.has_theme_constant_override("h_separation") else theme.get_constant("h_separation", "Button")
	var room := b.icon.get_width() + gap
	var types := [b.theme_type_variation, "Button"] if b.theme_type_variation != "" else ["Button"]
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box: StyleBox = null
		if b.has_theme_stylebox_override(state):
			box = b.get_theme_stylebox(state)
		else:
			for t in types:
				if theme.has_stylebox(state, t):
					box = theme.get_stylebox(state, t)
					break
		if box == null:
			continue
		var wider := box.duplicate() as StyleBox
		wider.content_margin_right = box.get_margin(SIDE_RIGHT) + room
		b.add_theme_stylebox_override(state, wider)
	b.set_meta("centred", true)


## Changes a button's look, and centres its text again on the new look's paper.
static func restyle(b: Button, variation: String) -> void:
	if b.theme_type_variation == variation:
		return
	b.theme_type_variation = variation
	if b.has_meta("centred"):
		_uncentre(b)
		centre_text(b)


## Changes a button's text, keeping it centred, and keeping a button left with only its icon even on both sides.
static func relabel(b: Button, text: String) -> void:
	if b.text == text:
		return
	b.text = text
	if b.has_meta("centred"):
		_uncentre(b)
	centre_text(b)


static func _uncentre(b: Button) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.remove_theme_stylebox_override(state)
	b.remove_meta("centred")


static func icon_button(parent: Node, icon_name: String, tip: String, action: Callable) -> Button:
	var b := button(parent, "", action, icon_name)
	tip_on(b, tip)
	b.custom_minimum_size = Vector2(20, 20)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


## A line of a window naming a setting on the left, wrapped if long, with a short button for it on the right.
static func setting(parent: Node, text: String, value: String, action: Callable, width: float = 270.0) -> Button:
	var row := hbox(parent, 6)
	var l := label(row, text, "", width - 76.0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b := button(row, value, action)
	b.custom_minimum_size.x = 70
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## A setting that is on or off, shown as a button reading On or Off.
static func on_off(parent: Node, text: String, on: bool, action: Callable, width: float = 270.0) -> Button:
	return setting(parent, text, TranslationServer.translate("On") if on else TranslationServer.translate("Off"), action, width)


## A row of paper tabs over a page, with a rule along its foot that the open tab stands on.
static func tab_row(parent: Node) -> HBoxContainer:
	var r := hbox(parent, 1)
	r.draw.connect(func() -> void: r.draw_rect(Rect2(0, r.size.y - 1, r.size.x, 1), TAB_EDGE))
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(3, 0)
	r.add_child(indent)
	return r


## A paper tab in a `tab_row`: the open one is taller and the colour of the page, the others shorter and darker.
static func tab_button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var open: bool = state.ends_with("pressed")
		var box := StyleBoxFlat.new()
		box.anti_aliasing = false
		box.bg_color = TAB_OPEN if open else (TAB_SHUT.lightened(0.12) if state == "hover" else TAB_SHUT)
		box.border_color = TAB_EDGE
		box.border_width_left = 1
		box.border_width_right = 1
		box.border_width_top = 1
		box.border_width_bottom = 0 if open else 1
		box.corner_radius_top_left = 2
		box.corner_radius_top_right = 2
		box.content_margin_left = 6
		box.content_margin_right = 6
		box.content_margin_top = 4 if open else 2
		box.content_margin_bottom = 3 if open else 2
		b.add_theme_stylebox_override(state, box)
	for c in ["font_color", "font_hover_color"]:
		b.add_theme_color_override(c, UiTheme.MUTED)
	for c in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, UiTheme.INK)
	b.pressed.connect(func() -> void:
		Audio.play("page_turn", -10.0)
		action.call())
	parent.add_child(b)
	return b


## A small X for a window's top right corner. Escape, the pad's B and a click beside the window do the same, through `closes_with`.
static func close_button(parent: Node, window: Control, action: Callable = Callable()) -> Button:
	var close := closes_with(window, action)
	var b := icon_button(parent, "cross_small", "Close", close)
	b.custom_minimum_size = Vector2(16, 16)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return b


## Marks a control as a window that Escape, the pad's B and, unless `outside` is false, a click beside it close with `action`, or by freeing it; returns that action.
static func closes_with(window: Control, action: Callable = Callable(), outside: bool = true) -> Callable:
	var close := action if action.is_valid() else window.queue_free
	window.set_meta("close", close)
	if outside:
		_backdrop(window, close)
	return close


## Puts a clear backdrop just under a window, covering the interface, that closes it when clicked beside it.
static func _backdrop(window: Control, close: Callable) -> void:
	if not is_instance_valid(window) or window.is_queued_for_deletion():
		return
	var parent := window.get_parent()
	if parent == null:
		_backdrop.call_deferred(window, close)
		return
	var back := Backdrop.new()
	back.name = "Backdrop"
	# Far larger than any interface, so it covers the screen whatever its parent's size and position.
	back.position = Vector2(-4096, -4096)
	back.size = Vector2(8192, 8192)
	closes_on_click(back, close)
	parent.add_child(back)
	parent.move_child(back, window.get_index())
	back.visible = window.visible
	window.visibility_changed.connect(func() -> void: back.visible = window.visible)
	window.tree_exiting.connect(back.queue_free)


## Closes a window on a click on this control itself, keeping the click so it never also acts on what lies under it.
static func closes_on_click(c: Control, close: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT):
			c.accept_event()
			Audio.play("click")
			close.call())


## A window's top line: its heading, and the X that closes it in the corner.
static func window_head(parent: Node, window: Control, title: String, action: Callable = Callable(), wrap_width: float = 0.0) -> HBoxContainer:
	var head := hbox(parent, 4)
	label(head, title, "Heading", wrap_width).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button(head, window, action)
	return head


## Gives a control a tooltip, shown at the interface's scale by the Tips layer.
static func tip_on(c: Control, text: String) -> Control:
	c.set_meta("tip", text)
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c


static func panel(parent: Node, variation: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	if parent:
		parent.add_child(p)
	return p


static func vbox(parent: Node, gap: int = 3) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", gap)
	if parent:
		parent.add_child(b)
	return b


static func hbox(parent: Node, gap: int = 3) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", gap)
	if parent:
		parent.add_child(b)
	return b


static func icon(parent: Node, icon_name: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiTheme.icon(icon_name)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	if parent:
		parent.add_child(t)
	return t


static func texture(parent: Node, tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	if parent:
		parent.add_child(t)
	return t


## An amount of money in words, in the Roman silver coin: one denarius, two denarii.
static func coins_text(n: int) -> String:
	return text(coins(n))


## An amount of money kept as words to be read later, in whatever language is chosen by then.
static func coins(n: int) -> Dictionary:
	return say("%d denarius" if n == 1 else "%d denarii", [n])


## Words kept in the save to show later in whatever language is chosen then: an English format and the parts that fill it.
static func say(format: String, args: Variant = []) -> Dictionary:
	return {"say": format, "args": args}


## Words in the player's language: a string translated whole, a say() translated and filled in, or a list of sentences.
static func text(v: Variant) -> String:
	if v is Dictionary and (v as Dictionary).has("say"):
		var format := String(TranslationServer.translate(str(v["say"])))
		var args: Variant = v.get("args", [])
		if args is Dictionary:
			var named := {}
			for k in args:
				named[k] = _part(args[k])
			return format.format(named)
		return format % (args as Array).map(func(a: Variant) -> Variant: return _part(a))
	if v is Array:
		var out := PackedStringArray()
		for part in v:
			var t := text(part)
			if t != "":
				out.append(t)
		return sentence_gap().join(out)
	return String(TranslationServer.translate(str(v))) if str(v) != "" else ""


static func _part(a: Variant) -> Variant:
	return text(a) if (a is String or a is StringName or a is Dictionary or a is Array) else a


## What goes between two sentences: a space, or nothing in Chinese and Japanese, which leave none.
static func sentence_gap() -> String:
	var loc := TranslationServer.get_locale()
	return "" if loc.begins_with("zh") or loc.begins_with("ja") else " "


## The width at which a text takes no more than `lines` lines, from `width` up to `widest`, for long languages.
static func wrap_width(text: String, width: float, lines: int, widest: float) -> float:
	var font := UiTheme.body_font()
	var size := UiTheme.text_size()
	var w := width
	while w < widest and font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, size).y > lines * font.get_height(size):
		w += 10.0
	return minf(w, widest)


## Narrows a panel's wrapped labels step by step, never below a word's width, until the panel fits `room` across.
static func narrow_to_fit(panel: Control, labels: Array, room: float) -> void:
	for _step in 16:
		if panel.get_combined_minimum_size().x <= room:
			return
		for l in labels:
			var c := l as Control
			c.custom_minimum_size.x = maxf(56.0, c.custom_minimum_size.x - 8.0)


## Things in a row as words, already in the player's language: "a", "a and b", "a, b and c".
static func list(items: Array) -> String:
	var names := items.map(func(i: Variant) -> String: return str(i))
	if names.size() <= 1:
		return "" if names.is_empty() else names[0]
	return String(TranslationServer.translate(", ")).join(names.slice(0, names.size() - 1)) + TranslationServer.translate(" and ") + names[-1]



## Places a control at a position in interface pixels, sized to its contents unless a size is given.
static func put(c: Control, pos: Vector2, size: Vector2 = Vector2.ZERO) -> void:
	c.position = pos.floor()
	if size != Vector2.ZERO:
		c.size = size.floor()
	else:
		c.reset_size()
