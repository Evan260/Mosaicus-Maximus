class_name SettingsPanel
extends PanelContainer
## Volume, hints, full screen and language, opened from the title and the workshop, where it can also change the dog.

## Each language's name in that language, for the language list.
const NATIVE_NAMES := {"en": "English", "fr": "Français", "de": "Deutsch", "es": "Español", "it": "Italiano", "pt_BR": "Português (BR)",
	"pl": "Polski", "tr": "Türkçe", "ru": "Русский", "uk": "Українська", "ja": "日本語", "ko": "한국어", "zh_CN": "简体中文", "zh_TW": "繁體中文"}


static func open(parent: Control, in_game: bool = false) -> SettingsPanel:
	var p := SettingsPanel.new()
	p.theme_type_variation = "PagePanel"
	parent.add_child(p)
	p._build(in_game)
	return p


func _build(in_game: bool) -> void:
	var sides := Ui.hbox(self, 10)
	var col := Ui.vbox(sides, 4)
	Ui.label(col, "Settings", "Heading")
	_slider(col, "Everything", Settings.master, func(v: float) -> void: Settings.master = v)
	_slider(col, "Music", Settings.music, func(v: float) -> void: Settings.music = v)
	_slider(col, "Sounds", Settings.effects, func(v: float) -> void: Settings.effects = v)
	var hints := CheckButton.new()
	hints.text = "Show hints on the floor"
	hints.button_pressed = Settings.hints
	hints.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hints.toggled.connect(func(on: bool) -> void:
		Audio.ui("click", -8.0)
		Settings.hints = on
		Settings.save())
	col.add_child(hints)
	Ui.button(col, "Full screen (F11)", Settings.toggle_fullscreen)
	if in_game:
		Ui.button(col, "Your dog", func() -> void:
			queue_free()
			DogPanel.open(get_parent()), "paw")
		Ui.button(col, "Achievements", func() -> void:
			queue_free()
			AchievementsPanel.open(get_parent()), "laurel")
	Ui.button(col, "Done", func() -> void: queue_free(), "tick", true)
	_languages(sides)
	Nav.resized.connect(_place)
	_place.call_deferred()


func _place() -> void:
	reset_size()
	position = ((Nav.ui_size() - size) * 0.5).floor()


## Every translated language, named in its own words and letters, so a player can find theirs whatever is showing.
func _languages(parent: Node) -> void:
	var locales := TranslationServer.get_loaded_locales()
	if locales.size() < 2:
		return
	var col := Ui.vbox(parent, 4)
	Ui.label(col, "Language", "Heading")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	col.add_child(grid)
	var order := NATIVE_NAMES.keys().filter(func(loc: String) -> bool: return loc in locales)
	var now := UiTheme.language()
	for loc in order:
		var b := Ui.button(grid, NATIVE_NAMES[loc], func() -> void:
			if loc != now:
				Settings.set_language(loc))
		b.toggle_mode = true
		b.button_pressed = loc == now
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size.x = 76
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UiTheme.body_font(loc))
		b.add_theme_font_size_override("font_size", UiTheme.text_size(loc))


func _slider(parent: Node, label: String, value: float, apply: Callable) -> void:
	var row := Ui.hbox(parent, 6)
	Ui.label(row, label).custom_minimum_size.x = 60
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(120, 16)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	s.value_changed.connect(func(v: float) -> void:
		apply.call(v)
		Settings.apply()
		Settings.save())
	row.add_child(s)
