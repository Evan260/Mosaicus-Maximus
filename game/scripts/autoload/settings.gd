extends Node
## The player's settings, kept apart from the save slots so they apply to every workshop.

const PATH := "user://settings.cfg"

var master := 0.9
var music := 0.6
var effects := 0.9
var fullscreen := false
var maximized := false
var hints := true
## How much larger or smaller than usual the interface is drawn: Smaller -1, Normal 0, Larger 1 or Largest 2 scale steps.
var ui_scale_step := 0
## A language code such as "fr" or "zh_CN"; empty until chosen, when the computer's own language is used if the game has it.
var language := ""
## The window's mode before going full screen, so F11 brings back a maximised window as it was.
var _before := DisplayServer.WINDOW_MODE_WINDOWED


func _ready() -> void:
	_bring_old_saves()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		master = cfg.get_value("sound", "master", master)
		music = cfg.get_value("sound", "music", music)
		effects = cfg.get_value("sound", "effects", effects)
		fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
		maximized = cfg.get_value("display", "maximized", maximized)
		hints = cfg.get_value("play", "hints", hints)
		ui_scale_step = clampi(int(cfg.get_value("display", "ui_scale_step", ui_scale_step)), -1, 2)
		language = str(cfg.get_value("play", "language", language))
	_load_translations()
	TranslationServer.set_locale(language if language in TranslationServer.get_loaded_locales() else _system_language())
	# --locale=xx shows the game in another language without keeping it.
	var trial := Dev.get_arg("locale")
	if trial != "":
		TranslationServer.set_locale(trial)
	apply.call_deferred()
	_restore_window.call_deferred()


## Loads every translated column of the strings sheet; one without even the word "Language" is still waiting for Azure.
func _load_translations() -> void:
	for file in ResourceLoader.list_directory("res://translations/"):
		if file.get_extension() == "translation":
			var t: Translation = load("res://translations/" + file)
			if t.locale == "en" or t.get_message("Language") != "":
				TranslationServer.add_translation(t)


## The computer's own language if the game has it, matching "fr_CA" to "fr" and "zh_Hans_CN" to "zh_CN"; otherwise English.
func _system_language() -> String:
	var have := TranslationServer.get_loaded_locales()
	var os := OS.get_locale()
	if os in have:
		return os
	if os.begins_with("zh"):
		var traditional := os.contains("Hant") or os.ends_with("TW") or os.ends_with("HK") or os.ends_with("MO")
		var zh := "zh_TW" if traditional else "zh_CN"
		return zh if zh in have else "en"
	var lang := OS.get_locale_language()
	for loc in have:
		if loc.get_slice("_", 0) == lang:
			return loc
	return "en"


## Shows the game in another language and keeps the choice: the fonts change with it, and the screen is built again.
func set_language(code: String) -> void:
	language = code
	save()
	TranslationServer.set_locale(code)
	UiTheme.use_language()
	Nav.reopen()


## The first time the game starts under this name, copies the saves, settings and kept floors from its old folder.
func _bring_old_saves() -> void:
	var here := OS.get_user_data_dir()
	var old := here.get_base_dir().path_join("Roman Mosaic Workshop")
	if old == here or not DirAccess.dir_exists_absolute(old) or FileAccess.file_exists(PATH):
		return
	DirAccess.make_dir_recursive_absolute(here)
	var d := DirAccess.open(old)
	if d == null:
		return
	for f in d.get_files():
		if (f.begins_with("workshop_") or f == "settings.cfg") and not FileAccess.file_exists(here.path_join(f)):
			DirAccess.copy_absolute(old.path_join(f), here.path_join(f))
	var kept := DirAccess.open(old.path_join("library"))
	if kept:
		DirAccess.make_dir_recursive_absolute(here.path_join("library"))
		for f in kept.get_files():
			if not FileAccess.file_exists(here.path_join("library").path_join(f)):
				DirAccess.copy_absolute(old.path_join("library").path_join(f), here.path_join("library").path_join(f))


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
	cfg.set_value("display", "ui_scale_step", ui_scale_step)
	cfg.set_value("play", "hints", hints)
	cfg.set_value("play", "language", language)
	cfg.save(PATH)


## The interface size after `step`: Normal, Larger, Largest, Smaller, then Normal again.
static func next_ui_step(step: int) -> int:
	return (step + 2) % 4 - 1


## Steps the interface size on to the next of Smaller, Normal, Larger and Largest, and lays the screen out again at it.
func cycle_ui_size() -> void:
	ui_scale_step = next_ui_step(ui_scale_step)
	save()
	Nav.refit()


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	fullscreen = mode != DisplayServer.WINDOW_MODE_FULLSCREEN
	if fullscreen:
		_before = mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(_before)
	save()
