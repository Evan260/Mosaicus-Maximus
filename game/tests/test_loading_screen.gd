extends "res://tests/test_case.gd"

const Boot := preload("res://scripts/boot.gd")
const LoadBar := preload("res://scripts/ui/load_bar.gd")
const StartupFiles := preload("res://scripts/startup_files.gd")


func test_the_game_opens_on_the_loading_screen() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/boot.tscn", "the game starts on the loading screen")
	check(ResourceLoader.exists(Boot.MAIN), "which hands over to the game's own scene")


func test_the_loading_screen_loads_files_that_exist() -> void:
	check(not StartupFiles.FILES.is_empty(), "the loading screen has the title's files to load")
	for path in StartupFiles.FILES:
		check(ResourceLoader.exists(path), "%s, which the loading screen loads, exists" % path)
		check(path.get_extension() not in ["gd", "tscn"], "%s is a file, not a script or scene loading with the game" % path)


func test_the_bar_grows_a_whole_pixel_of_the_art_at_a_time() -> void:
	check(LoadBar.filled(0.0, 126) == 0, "an empty bar has no gold")
	check(LoadBar.filled(0.5, 126) == 63, "half the files fill half the bar")
	check(LoadBar.filled(0.999, 126) == 125, "the last pixel fills only when every file is in")
	check(LoadBar.filled(1.0, 126) == 126, "a full bar is all gold")
	check(LoadBar.filled(1.5, 126) == 126 and LoadBar.filled(-0.5, 126) == 0, "and never spills past either end")


func test_the_bar_stays_in_sight_on_every_screen_shape() -> void:
	for window in [Vector2(1212, 540), Vector2(1024, 768), Vector2(1440, 810), Vector2(3840, 1080), Vector2(540, 1212)]:
		var bar := LoadBar.new()
		bar.picture_size = Boot.PICTURE.get_size()
		bar.size = window
		var box: Rect2 = bar.box()
		check(Rect2(Vector2.ZERO, window).encloses(box), "the bar is inside a %dx%d window" % [window.x, window.y])
		check(box.position.y > window.y * 0.75, "and along its bottom")
		check(is_equal_approx(box.get_center().x, window.x / 2.0), "and centred")
		bar.free()
