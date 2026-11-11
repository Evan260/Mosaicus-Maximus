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
