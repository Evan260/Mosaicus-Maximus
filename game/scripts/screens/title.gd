extends Node
## The title screen: an old floor lays itself behind the menu while you choose a workshop or start a new one.

var _floor: FloorView
var _cam: Camera2D
var _menu: PanelContainer
var _task := -1
var _layout: MosaicLayout
var _t := 0.0
var _name_edit: LineEdit
var _chooser: DogChooser
var _begun := false
## Which page the menu shows: "menu", "new" or "delete".
var _page := "menu"
var _version: Label


func enter(_args: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var design := RandomDesign.make(["dining_room", "villa_dining", "atrium", "changing_room"][rng.randi() % 4], 3 + rng.randi() % 2, rng)
	var layout := MosaicLayout.new()
	_layout = layout
	_task = WorkerThreadPool.add_task(func() -> void:
		layout.build(Composer.compose(design, 6), 6, Composer.fine_mask(design, 6))
		FloorView.prepare(layout))
	_version = Ui.label(Nav.ui, "v" + str(ProjectSettings.get_setting("application/config/version", "")), "LightLabel")
	_version.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_version.modulate.a = 0.7
	_version.add_theme_color_override("font_outline_color", UiTheme.INK)
	_version.add_theme_constant_override("outline_size", 2)
	Nav.resized.connect(_place)
	_show_menu()
	match Dev.get_arg("panel"):
		"new":
			_show_new()
		"settings":
			open_settings()
		"delete":
			var kept := Saves.slots()
			if not kept[0].is_empty():
				_confirm_delete(1, kept[0])


func open_settings() -> void:
	SettingsPanel.open(Nav.ui)


func _process(delta: float) -> void:
	_t += delta
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_floor = FloorView.new()
		Nav.world.add_child(_floor)
		_floor.setup(_layout)
		_floor.chalk_visible = false
		_cam = Camera2D.new()
		Nav.world.add_child(_cam)
		_cam.make_current()
		_fit()
		_floor.lay_rest(6.0)
	if _cam:
		var drift := Vector2.ZERO if Settings.reduced_motion else Vector2(sin(_t * 0.07), cos(_t * 0.05)) * 60.0
		_cam.position = _floor.size_world() * 0.5 + drift


func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := _floor.size_world()
	_cam.zoom = Vector2.ONE * maxf(vp.x / s.x, vp.y / s.y) * 1.05


func _place() -> void:
	if is_instance_valid(_version):
		_version.reset_size()
		_version.position = (Nav.ui_size() - _version.size - Vector2(4, 2)).floor()
	if not is_instance_valid(_menu):
		return
	_menu.reset_size()
	var s := Nav.ui_size()
	_menu.position = Vector2(floorf((s.x - _menu.size.x) * 0.5), floorf((s.y - _menu.size.y) * 0.5))


func _swap_menu() -> VBoxContainer:
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = Ui.panel(Nav.ui, "PagePanel")
	_menu.custom_minimum_size.x = 236
	# Buttons widen a little once their text is centred, after the menu was first placed.
	_menu.resized.connect(_place)
	_place.call_deferred()
	return Ui.vbox(_menu, 5)


func _show_menu() -> void:
	_page = "menu"
	var col := _swap_menu()
	var title := Ui.label(col, "Mosaicus Maximus", "Heading")
	# The game's name is Latin in every language, so it keeps Silkscreen's capitals.
	title.add_theme_font_override("font", UiTheme.title_font("en"))
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if Game.is_demo():
		var demo := Ui.label(col, "Demo", "Heading")
		demo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		demo.add_theme_color_override("font_color", UiTheme.RED)
	Ui.label(col, "A town of floors, waiting to be laid", "MutedLabel").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.label(col, "The Bay of Naples, AD 72", "MutedLabel").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var info := Saves.slots()
	for n in range(1, Saves.SLOTS + 1):
		var s: Dictionary = info[n - 1]
		if not s.is_empty():
			_slot_row(col, n, s)
	var fresh := Ui.button(col, "New workshop", _show_new, "plus", Saves.free_slot() > 0 and info.all(func(s: Dictionary) -> bool: return s.is_empty()))
	fresh.custom_minimum_size.y = 22
	if Saves.free_slot() == 0:
		fresh.disabled = true
		Ui.tip_on(fresh, "You already keep three workshops. Delete one to start another.")
	var row := Ui.hbox(col, 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	Ui.button(row, "Free design", func() -> void: Nav.go("design_table", {"free": true}), "brush")
	Ui.button(row, "Library", func() -> void: Nav.go("library", {"back": "title"}), "book")
	Ui.button(row, "Settings", open_settings, "gear")
	Ui.button(row, "Quit", quit_game)
	if Game.is_demo():
		var wish := DemoEnd.wishlist_button(col)
		if wish:
			wish.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## One saved workshop: its name and how far along it is, and a bin that asks first.
func _slot_row(parent: Node, slot: int, s: Dictionary) -> void:
	var row := Ui.hbox(parent, 3)
	var b := Button.new()
	b.theme_type_variation = "MainButton"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = (tr("%s\nDay %d, chapter %d, 1 floor laid") % [s["name"], s["day"], s["chapter"]]) if int(s["floors"]) == 1 else tr("%s\nDay %d, chapter %d, %d floors laid") % [s["name"], s["day"], s["chapter"], s["floors"]]
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 30
	b.add_theme_constant_override("line_spacing", 1)
	b.icon = UiTheme.icon("house")
	b.pressed.connect(func() -> void:
		Audio.play("click")
		_continue(slot))
	row.add_child(b)
	if Game.in_full_game(int(s["chapter"])):
		b.disabled = true
		Ui.tip_on(b, "In the full game")
	var del := Ui.icon_button(row, "trash", "Delete this workshop", func() -> void: _confirm_delete(slot, s))
	del.custom_minimum_size = Vector2(22, 30)


## Deleting a workshop can't be undone, so the word "delete" has to be typed before it goes.
func _confirm_delete(slot: int, s: Dictionary) -> void:
	Audio.play("click")
	_page = "delete"
	var col := _swap_menu()
	var title := Ui.label(col, "Delete this workshop?", "Heading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var floors := int(s["floors"])
	var word := tr("delete")
	var gone_text := tr("%s's workshop, on day %d with 1 floor laid, will be gone for good. Type \"%s\" to delete it.") % [s["name"], s["day"], word] if floors == 1 else tr("%s's workshop, on day %d with %d floors laid, will be gone for good. Type \"%s\" to delete it.") % [s["name"], s["day"], floors, word]
	Ui.label(col, gone_text, "", 226).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var field := LineEdit.new()
	field.placeholder_text = word
	field.max_length = 20
	col.add_child(field)
	var row := Ui.hbox(col, 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# The English word works in every language, for a player whose keyboard can't type the translated one.
	var typed := func() -> bool: return field.text.strip_edges().to_lower() in ["delete", word.to_lower()]
	var delete := func() -> void:
		if not typed.call():
			return
		Saves.delete(slot)
		Audio.play("rustle")
		_show_menu()
	var gone := Ui.button(row, "Delete", delete, "trash")
	gone.disabled = true
	Ui.button(row, "Cancel", _show_menu, "arrow_l", true)
	Ui.closes_with(_menu, _show_menu)
	field.text_changed.connect(func(_t: String) -> void: gone.disabled = not typed.call())
	field.text_submitted.connect(func(_t: String) -> void: delete.call())
	field.grab_focus.call_deferred()


## Starting a workshop: your name and your dog.
func _show_new() -> void:
	_page = "new"
	var col := _swap_menu()
	var title := Ui.label(col, "A new workshop", "Heading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.label(col, "Your uncle has left you his mosaic workshop, his tools, and his dog's basket.", "", 226).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name_row := Ui.hbox(col, 6)
	Ui.label(name_row, "Your name").custom_minimum_size.x = 52
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Lucia"
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(120, 20)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(_t: String) -> void: _begin())
	name_row.add_child(_name_edit)
	Ui.label(col, "Your dog")
	_chooser = DogChooser.make({"breed": "hound", "coat": "golden", "name": ""})
	col.add_child(_chooser)
	var buttons := Ui.hbox(col, 4)
	Ui.button(buttons, "Back", _show_menu, "arrow_l")
	var go := Ui.button(buttons, "Open the workshop", _begin, "house", true)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A click beside the page would throw away the name typed so far, so only Back and Escape leave it.
	Ui.closes_with(_menu, _show_menu, false)
	_name_edit.grab_focus.call_deferred()


## Quitting here does what closing the window does, so the window's size and the settings are kept.
func quit_game() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)


## Escape steps back from a new workshop or a deletion to the menu, and never quits from the title.
func go_back() -> bool:
	if _page == "menu":
		return false
	_show_menu()
	return true


func _begin() -> void:
	if _begun:
		return
	var slot := Saves.free_slot()
	if slot == 0:
		Audio.play("nope")
		return
	var who := _name_edit.text.strip_edges()
	if who == "":
		who = _name_edit.placeholder_text
	_begun = true
	Game.new_game(who, _chooser.chosen())
	Saves.slot = slot
	Saves.save(slot)
	Nav.go("workshop")


func _continue(slot: int) -> void:
	if Saves.load_slot(slot):
		Nav.go("workshop")
	else:
		Audio.play("nope")


func _exit_tree() -> void:
	Nav.leave_task(_task)
	_task = -1
