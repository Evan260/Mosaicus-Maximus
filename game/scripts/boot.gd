extends Node
## The first scene. A player's launch shows the loading picture with a bar that fills as the title's files load in the
## background, then hands the window to the game, whose own cover fades the picture and the full bar into the title.

const MAIN := "res://scenes/main.tscn"
const PICTURE := preload("res://assets/loading_screen.png")
const COVER := "res://scripts/ui/boot_cover.gd"
const LoadBar := preload("res://scripts/ui/load_bar.gd")
const StartupFiles := preload("res://scripts/startup_files.gd")
## How long the files may take before the bar shows, so a quick start never flashes it.
const BAR_AFTER := 0.4
## The share of the bar the files fill; the rest fills once the game is set up from them.
const LOADED_SHARE := 0.9

var _paths: Array[String] = []
## The loaded files, held until the game holds them itself.
var _kept: Array = []
var _bar: Control
var _picture: Control
var _waited := 0.0
var _shown_loaded := false
var _cover: Node


func _ready() -> void:
	if not player_launch():
		_hand_over.call_deferred()
		return
	var layer := CanvasLayer.new()
	layer.layer = 101
	add_child(layer)
	_picture = ColorRect.new()
	_picture.color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.BLACK)
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_picture)
	var art := TextureRect.new()
	art.texture = PICTURE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.add_child(art)
	# Godot's cover stretch scales the splash until it fills the window and centres it, so the picture lands on its pixels.
	var place := func():
		var zoom := maxf(_picture.size.x / PICTURE.get_width(), _picture.size.y / PICTURE.get_height())
		art.size = PICTURE.get_size() * zoom
		art.position = (_picture.size - art.size) / 2.0
	_picture.resized.connect(place)
	place.call()
	_bar = LoadBar.new()
	_bar.picture_size = PICTURE.get_size()
	_bar.art_pixel = 2.0
	# The picture's border of waves runs along its bottom, so the bar sits above it.
	_bar.lift = 104.0
	_bar.visible = false
	layer.add_child(_bar)
	# tools/list_startup_files.py lists the files loaded after this line.
	print_verbose("Boot: loading the title's files")
	for path in StartupFiles.FILES + [MAIN]:
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
			_paths.append(path)


## Whether this is a player's launch, which the game opens with its loading picture; checks with flags start at once.
static func player_launch() -> bool:
	return Dev.args.is_empty() or Dev.has("boot")


func _process(delta: float) -> void:
	if _picture == null:
		return
	if not _paths.is_empty():
		_load_step(delta)
	elif not is_instance_valid(_cover):
		print_verbose("Boot: done")
		queue_free()
	else:
		_bar.modulate.a = _cover.get_child(0).modulate.a


func _load_step(delta: float) -> void:
	_waited += delta
	var done := 0.0
	var loading := false
	for path in _paths:
		var share := []
		if ResourceLoader.load_threaded_get_status(path, share) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			done += share[0]
			loading = true
		else:
			done += 1.0
	_bar.progress = maxf(_bar.progress, LOADED_SHARE * done / _paths.size())
	if _waited >= BAR_AFTER:
		_bar.visible = true
	if loading:
		return
	# A shown bar gets one frame with every file loaded, since setting the game up holds the window still.
	if _bar.visible and not _shown_loaded:
		_shown_loaded = true
		return
	_hand_over()


func _hand_over() -> void:
	var scene: PackedScene = null
	for path in _paths:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			var loaded := ResourceLoader.load_threaded_get(path)
			if path == MAIN:
				scene = loaded
			else:
				_kept.append(loaded)
	_paths.clear()
	if scene == null:
		scene = load(MAIN)
	var main := scene.instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	if _picture == null:
		queue_free()
		return
	_bar.progress = 1.0
	_picture.visible = false
	for child in main.get_children():
		if child.get_script() != null and child.get_script().resource_path == COVER:
			_cover = child
