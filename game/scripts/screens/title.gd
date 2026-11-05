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


func enter(_args: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var design := RandomDesign.make(["dining_room", "villa_dining", "atrium", "changing_room"][rng.randi() % 4], 3 + rng.randi() % 2, rng)
	var layout := MosaicLayout.new()
	_layout = layout
	_task = WorkerThreadPool.add_task(func() -> void: layout.build(Composer.compose(design, 6), 6, Composer.fine_mask(design, 6)))
	Nav.resized.connect(_place)
	_show_menu()
	match Dev.get_arg("panel"):
		"new":
			_show_new()
		"settings":
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
		_cam.position = _floor.size_world() * 0.5 + Vector2(sin(_t * 0.07), cos(_t * 0.05)) * 60.0


func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := _floor.size_world()
	_cam.zoom = Vector2.ONE * maxf(vp.x / s.x, vp.y / s.y) * 1.05


func _place() -> void:
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
	_place.call_deferred()
	return Ui.vbox(_menu, 5)


func _show_menu() -> void:
	var col := _swap_menu()
	var title := Ui.label(col, "Mosaicus Maximus", "Heading")
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.label(col, "A town of floors, waiting to be laid", "MutedLabel").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var info := Saves.slots()
	for n in range(1, Saves.SLOTS + 1):
		var s: Dictionary = info[n - 1]
		if not s.is_empty():
			_slot_row(col, n, s)
	var fresh := Ui.button(col, "New workshop", _show_new, "plus", Saves.free_slot() > 0 and info.all(func(s: Dictionary) -> bool: return s.is_empty()))
	fresh.custom_minimum_size.y = 22
	if Saves.free_slot() == 0:
		fresh.disabled = true
		Ui.tip_on(fresh, "You already keep three workshops. Forget one to start another.")
	var row := Ui.hbox(col, 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	Ui.button(row, "Free design", func() -> void: Nav.go("design_table", {"free": true}), "brush")
	Ui.button(row, "Library", func() -> void: Nav.go("library", {"back": "title"}), "book")
	Ui.button(row, "Settings", func() -> void: SettingsPanel.open(Nav.ui), "gear")
	Ui.button(row, "Quit", func() -> void: get_tree().quit())


## One saved workshop: its name and how far along it is, and a bin that asks twice.
func _slot_row(parent: Node, slot: int, s: Dictionary) -> void:
	var row := Ui.hbox(parent, 3)
	var b := Button.new()
	b.theme_type_variation = "MainButton"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "%s\nDay %d, chapter %d, %d floor%s laid" % [s["name"], s["day"], s["chapter"], s["floors"], "" if int(s["floors"]) == 1 else "s"]
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 30
	b.add_theme_constant_override("line_spacing", 1)
	b.icon = UiTheme.icon("house")
	b.pressed.connect(func() -> void:
		Audio.ui("click")
		_continue(slot))
	row.add_child(b)
	var del := Ui.icon_button(row, "trash", "Forget this workshop (click twice)", func() -> void: pass)
	del.custom_minimum_size = Vector2(22, 30)
	del.pressed.connect(func() -> void:
		if del.has_meta("armed"):
			Saves.delete(slot)
			Audio.ui("rustle")
			_show_menu()
		else:
			del.set_meta("armed", true)
			Ui.tip_on(del, "Click again to forget %s's workshop for good" % s["name"])
			del.modulate = Color(1.0, 0.6, 0.5))


## Starting a workshop: your name and your dog.
func _show_new() -> void:
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
	_name_edit.grab_focus.call_deferred()


func _begin() -> void:
	var slot := Saves.free_slot()
	if slot == 0:
		Audio.ui("nope")
		return
	var who := _name_edit.text.strip_edges()
	if who == "":
		who = _name_edit.placeholder_text
	Game.new_game(who, _chooser.chosen())
	Saves.slot = slot
	Saves.save(slot)
	Nav.go("workshop")


func _continue(slot: int) -> void:
	if Saves.load_slot(slot):
		Nav.go("workshop")
	else:
		Audio.ui("nope")
