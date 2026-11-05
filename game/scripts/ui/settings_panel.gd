class_name SettingsPanel
extends PanelContainer
## Volume, hints and full screen, opened from the title screen and the workshop. In a workshop it can also change
## the dog.


static func open(parent: Control, in_game: bool = false) -> SettingsPanel:
	var p := SettingsPanel.new()
	p.theme_type_variation = "PagePanel"
	parent.add_child(p)
	p._build(in_game)
	return p


func _build(in_game: bool) -> void:
	var col := Ui.vbox(self, 4)
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
	var place := func() -> void:
		reset_size()
		position = ((Nav.ui_size() - size) * 0.5).floor()
	place.call_deferred()


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
