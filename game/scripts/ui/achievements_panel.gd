class_name AchievementsPanel
extends PanelContainer
## The workshop's achievements, opened from the settings in a workshop: the earned ones first, then the rest greyed.


static func open(parent: Control) -> AchievementsPanel:
	var p := AchievementsPanel.new()
	p.theme_type_variation = "PagePanel"
	parent.add_child(p)
	p._build()
	return p


func _build() -> void:
	var have: Array = Game.state.get("achievements", [])
	var col := Ui.vbox(self, 4)
	Ui.label(col, "Achievements", "Heading").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var count := Ui.label(col, "%d of %d earned" % [have.size(), Achievements.all().size()], "MutedLabel")
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(250, minf(180.0, Nav.ui_size().y - 80.0))
	col.add_child(scroll)
	var list := Ui.vbox(scroll, 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ordered := Achievements.all().filter(func(a: Dictionary) -> bool: return a["id"] in have)
	ordered += Achievements.all().filter(func(a: Dictionary) -> bool: return not a["id"] in have)
	for a in ordered:
		var earned: bool = a["id"] in have
		var row := Ui.hbox(list, 5)
		var icon := Ui.icon(row, "laurel" if earned else "lock")
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var text := Ui.vbox(row, 0)
		Ui.label(text, str(a["name"]), "Heading" if earned else "MutedLabel")
		Ui.label(text, str(a["text"]), "" if earned else "MutedLabel", 220)
	var done := Ui.button(col, "Done", func() -> void: queue_free(), "tick", true)
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	Nav.resized.connect(_place)
	_place.call_deferred()


func _place() -> void:
	reset_size()
	position = ((Nav.ui_size() - size) * 0.5).floor()
