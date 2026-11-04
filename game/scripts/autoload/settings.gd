extends Node
## The player's settings, kept apart from the save slots so they apply to every workshop.

const PATH := "user://settings.cfg"

var master := 0.9
var music := 0.6
var effects := 0.9
var fullscreen := false
var maximized := false
var hints := true
## The window's mode before going full screen, so F11 brings back a maximised window as it was.
var _before := DisplayServer.WINDOW_MODE_WINDOWED


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		master = cfg.get_value("sound", "master", master)
		music = cfg.get_value("sound", "music", music)
		effects = cfg.get_value("sound", "effects", effects)
		fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
		maximized = cfg.get_value("display", "maximized", maximized)
		hints = cfg.get_value("play", "hints", hints)
	apply.call_deferred()
	_restore_window.call_deferred()


## Sets the volumes. The window is left alone, so changing a setting never resizes it.
func apply() -> void:
	Audio.set_volumes(master, music, effects)


func _restore_window() -> void:
	if "--window" in str(OS.get_cmdline_user_args()):
		return
	if maximized:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	if fullscreen:
		_before = DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var mode := DisplayServer.window_get_mode()
		maximized = mode == DisplayServer.WINDOW_MODE_MAXIMIZED or (mode == DisplayServer.WINDOW_MODE_FULLSCREEN and _before == DisplayServer.WINDOW_MODE_MAXIMIZED)
		save()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("sound", "master", master)
	cfg.set_value("sound", "music", music)
	cfg.set_value("sound", "effects", effects)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "maximized", maximized)
	cfg.set_value("play", "hints", hints)
	cfg.save(PATH)


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	fullscreen = mode != DisplayServer.WINDOW_MODE_FULLSCREEN
	if fullscreen:
		_before = mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(_before)
	save()
