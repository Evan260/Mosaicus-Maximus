class_name Ui
## Shorthand for building the interface in code with the game's theme.


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
		Audio.ui("click")
		action.call())
	if parent:
		parent.add_child(b)
	return b


static func icon_button(parent: Node, icon_name: String, tip: String, action: Callable) -> Button:
	var b := button(parent, "", action, icon_name)
	tip_on(b, tip)
	b.custom_minimum_size = Vector2(20, 20)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


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


static func coins_text(n: int) -> String:
	return "%d d" % n


## Places a control at a position in interface pixels, sized to its contents unless a size is given.
static func put(c: Control, pos: Vector2, size: Vector2 = Vector2.ZERO) -> void:
	c.position = pos.floor()
	if size != Vector2.ZERO:
		c.size = size.floor()
	else:
		c.reset_size()
