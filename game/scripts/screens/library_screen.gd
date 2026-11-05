extends Node
## The library: every floor the player kept, as a shelf of little pictures. Choosing one shows it large, and it can be
## watched being laid again, tile by tile in the order it went down, or copied to the Pictures folder to share.

const REPLAY_SECONDS := 9.0

var _back_to := "title"
var _entries: Array = []
var _chosen := {}
var _root: Control
var _desk: PanelContainer
var _list: PanelContainer
var _grid: GridContainer
var _viewer: PanelContainer
var _view: Control
var _picture: TextureRect
var _screen: TextureRect
var _title: Label
var _info: Label
var _note: Label
var _watch: Button
var _copy: Button
var _remove: Button
var _buttons: HBoxContainer
var _vp: SubViewport
var _floor: FloorView
var _cam: Camera2D
var _layout: MosaicLayout
var _layout_for := ""
var _task := -1
var _gif_task := -1
var _gif := PackedByteArray()
var _after_build := ""
var _slots := {}


func enter(args: Dictionary) -> void:
	_back_to = str(args.get("back", "title"))
	_entries = Library.entries()
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Nav.ui.add_child(_root)
	_desk = Ui.panel(_root, "BoardPanel")
	_list = Ui.panel(_root, "PagePanel")
	var col := Ui.vbox(_list, 4)
	Ui.label(col, "Your library", "Heading").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var count := Ui.label(col, "", "MutedLabel")
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.text = "No floors kept yet" if _entries.is_empty() else "%d floor%s kept" % [_entries.size(), "" if _entries.size() == 1 else "s"]
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(_grid)
	Ui.button(col, "Back", _leave, "arrow_l")
	_viewer = Ui.panel(_root, "TabletPanel")
	var vcol := Ui.vbox(_viewer, 4)
	_view = Control.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.clip_contents = true
	vcol.add_child(_view)
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.add_child(_picture)
	_screen = TextureRect.new()
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.visible = false
	_view.add_child(_screen)
	_title = Ui.label(vcol, "", "LightHeading")
	_info = Ui.label(vcol, "", "LightLabel")
	_buttons = Ui.hbox(vcol, 3)
	_watch = Ui.button(_buttons, "Watch it being laid", _watch_it, "play", true)
	_copy = Ui.button(_buttons, "Copy to Pictures", _copy_it, "eye")
	Ui.tip_on(_copy, "Saves the picture and a time-lapse to a Mosaicus Maximus folder in your Pictures, for sharing")
	_remove = Ui.button(_buttons, "", _remove_it, "trash")
	Ui.tip_on(_remove, "Take it out of the library (click twice)")
	_note = Ui.label(vcol, "", "LightLabel")
	for e in _entries:
		_add_slot(e)
	if _entries.is_empty():
		_title.text = "Nothing here yet"
		_info.text = "When a client's floor is finished, press \"Keep in my library\"\nand it will wait for you here."
		_buttons.visible = false
	else:
		_choose(_entries[0])
	Nav.resized.connect(_layout_ui)
	_layout_ui()


func _add_slot(e: Dictionary) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(70, 54)
	b.toggle_mode = true
	b.add_theme_stylebox_override("normal", UiTheme.panel("slot", 3, 3))
	b.add_theme_stylebox_override("hover", UiTheme.panel("chip_off", 3, 3))
	b.add_theme_stylebox_override("pressed", UiTheme.panel("chip_on", 3, 3))
	b.add_theme_stylebox_override("hover_pressed", UiTheme.panel("chip_on", 3, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var t := TextureRect.new()
	t.texture = Library.picture(e, true)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	b.add_child(t)
	Ui.tip_on(b, _title_of(e))
	b.pressed.connect(func() -> void:
		Audio.ui("page_turn", -10.0)
		_choose(e))
	_grid.add_child(b)
	_slots[e["id"]] = b


func _layout_ui() -> void:
	var s := Nav.ui_size()
	_root.size = s
	Ui.put(_desk, Vector2.ZERO, s)
	var list_w := 162.0
	Ui.put(_list, Vector2(5, 5), Vector2(list_w, s.y - 10))
	Ui.put(_viewer, Vector2(list_w + 9, 5), Vector2(s.x - list_w - 14, s.y - 10))
	_fit_view.call_deferred()


func _fit_view() -> void:
	_picture.size = _view.size
	_screen.size = _view.size
	if _vp:
		_vp.size = Vector2i(_view.size * Nav.scale_factor())
		_frame_camera()


func _title_of(e: Dictionary) -> String:
	var room := str(Data.room(str(e.get("room", ""))).get("name", "Floor"))
	var who := str(e.get("client_name", ""))
	return room if who == "" else "%s, for %s" % [room, who]


func _choose(e: Dictionary) -> void:
	_stop_replay()
	_chosen = e
	for id in _slots:
		_slots[id].button_pressed = id == e["id"]
	_picture.texture = Library.picture(e)
	_picture.visible = true
	_title.text = _title_of(e)
	var bits := []
	if str(e.get("workshop", "")) != "":
		bits.append("%s's workshop" % e["workshop"])
	if int(e.get("day", 0)) > 0:
		bits.append("day %d" % int(e["day"]))
	bits.append("%d tiles" % int(e.get("tiles", 0)))
	if int(e.get("stars", 0)) > 0:
		bits.append("%d star%s" % [int(e["stars"]), "" if int(e["stars"]) == 1 else "s"])
	var line := ", ".join(bits)
	_info.text = line[0].to_upper() + line.substr(1)
	_note.text = ""
	_remove.remove_meta("armed")
	_remove.modulate = Color.WHITE
	_watch.text = "Watch it being laid"


func _process(_delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		var next := _after_build
		_after_build = ""
		if next == "watch":
			_start_replay()
		elif next == "copy":
			_make_gif()
	if _gif_task >= 0 and WorkerThreadPool.is_task_completed(_gif_task):
		WorkerThreadPool.wait_for_task_completion(_gif_task)
		_gif_task = -1
		var ok := Library.export_picture(_chosen) and Library.export_gif(_chosen, _gif)
		_note.text = "Copied to Pictures, in a Mosaicus Maximus folder." if ok else "That couldn't be copied."
		_copy.disabled = false
		Audio.ui("page_turn", -8.0)


## Builds the floor's tiles from its design on a worker thread, then carries on with what was asked for.
func _with_layout(next: String) -> void:
	if _layout and _layout_for == str(_chosen["id"]):
		_after_build = ""
		if next == "watch":
			_start_replay()
		else:
			_make_gif()
		return
	if _task >= 0:
		return
	_after_build = next
	_note.text = "Setting out the tiles..."
	var design := FloorDesign.from_dict(_chosen["design"])
	var layout := MosaicLayout.new()
	_layout = layout
	_layout_for = str(_chosen["id"])
	_task = WorkerThreadPool.add_task(func() -> void: layout.build(Composer.compose(design, 6), 6, Composer.fine_mask(design, 6)))


func _watch_it() -> void:
	if _vp:
		_stop_replay()
		_watch.text = "Watch it being laid"
		return
	_with_layout("watch")


func _start_replay() -> void:
	_note.text = ""
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	add_child(_vp)
	_floor = FloorView.new()
	_vp.add_child(_floor)
	_floor.setup(_layout)
	_floor.apply_stones(_chosen.get("stones", {}))
	_floor.chalk_visible = false
	_floor.tiles_landed.connect(Audio.on_landed)
	_floor.floor_finished.connect(func() -> void:
		Audio.glissando()
		_floor.wash(1.6))
	_cam = Camera2D.new()
	_vp.add_child(_cam)
	_cam.make_current()
	_fit_view()
	_screen.texture = _vp.get_texture()
	_screen.visible = true
	_picture.visible = false
	_floor.replay(Library.order_of(_chosen), REPLAY_SECONDS)
	_watch.text = "Stop"


func _frame_camera() -> void:
	if not _cam or not _floor:
		return
	var room := _floor.size_world()
	var wall := FloorView.WALL * _floor.tile_world() * 0.55
	var area := room + Vector2.ONE * wall * 2.0
	var vp := Vector2(_vp.size)
	_cam.position = room * 0.5
	_cam.zoom = Vector2.ONE * minf(vp.x / area.x, vp.y / area.y)


func _stop_replay() -> void:
	if _vp:
		_vp.queue_free()
	_vp = null
	_floor = null
	_cam = null
	_screen.visible = false
	_picture.visible = true


func _copy_it() -> void:
	if _gif_task >= 0:
		return
	_copy.disabled = true
	_with_layout("copy")


func _make_gif() -> void:
	_note.text = "Making the time-lapse..."
	var layout := _layout
	var order := Library.order_of(_chosen)
	_gif_task = WorkerThreadPool.add_task(func() -> void: _gif = Timelapse.make(layout, order))


func _remove_it() -> void:
	if not _remove.has_meta("armed"):
		_remove.set_meta("armed", true)
		_remove.modulate = Color(1.0, 0.6, 0.5)
		Ui.tip_on(_remove, "Click again to take this floor out of the library")
		return
	Library.remove(_chosen)
	Audio.ui("rustle")
	Nav.go("library", {"back": _back_to})


func _leave() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	if _gif_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_gif_task)
	Nav.go(_back_to)
