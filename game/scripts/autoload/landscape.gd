extends Node
## Keeps a phone or tablet in landscape: a portrait-only window from another app, such as Google Play's purchase sheet
## or a phone's game assistant, turns the screen to portrait, and some phones leave it there after it closes.

## How long the game, in front in a tall window, gives the phone to turn the screen back by itself.
const WAIT := 0.5
## How often it asks again while the window stays tall, as under another app's window or in split screen.
const AGAIN := 2.0
const LANDSCAPES := [DisplayServer.SCREEN_LANDSCAPE, DisplayServer.SCREEN_REVERSE_LANDSCAPE, DisplayServer.SCREEN_SENSOR_LANDSCAPE]

## The project's own landscape orientation, or -1 where nothing is kept, as on a computer.
var _wanted := -1
var _front := true
var _wait: Timer


func _ready() -> void:
	var wanted := int(ProjectSettings.get_setting("display/window/handheld/orientation", DisplayServer.SCREEN_LANDSCAPE))
	if OS.get_name() != "Android" or not LANDSCAPES.has(wanted):
		return
	_wanted = wanted
	# A paused game still has to turn back, so the wait runs whatever the tree is doing.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wait = Timer.new()
	_wait.one_shot = true
	_wait.timeout.connect(_check)
	add_child(_wait)
	get_window().size_changed.connect(_look)
	_look()


func _notification(what: int) -> void:
	if _wanted < 0:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_front = true
			_look()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_front = false
			_wait.stop()


func _look() -> void:
	_wait.start(WAIT)


func _check() -> void:
	var size := get_window().size
	if not _front or size.y <= size.x:
		return
	# Android ignores a request for the orientation the game already holds, so another landscape is asked for first.
	DisplayServer.screen_set_orientation(other_landscape(_wanted))
	DisplayServer.screen_set_orientation(_wanted)
	_wait.start(AGAIN)


## The landscape asked for on the way back: plain landscape for sensor landscape, else sensor landscape.
static func other_landscape(orientation: int) -> int:
	if orientation == DisplayServer.SCREEN_SENSOR_LANDSCAPE:
		return DisplayServer.SCREEN_LANDSCAPE
	return DisplayServer.SCREEN_SENSOR_LANDSCAPE
