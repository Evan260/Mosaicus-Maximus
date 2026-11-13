extends Node
## Switches between screens with a short fade. Every screen draws into three layers: the world, at the window's full
## resolution; the pictures, painted art made for a 480 by 270 view, scaled up by a whole number that fills the window;
## and the interface, pixel art one scale step finer than what fits the window, so it has more room than 480 by 270.

signal screen_changed(screen: String)
signal resized

const BASE := Vector2(480, 270)
## The interface scale starts from what fits this width, so it is one step finer than the pictures on a 16:9 window.
const UI_FIT_WIDTH := 400.0
## Windows this tall or shorter, such as 720p and the Steam Deck's 1280 by 800, draw the interface at what fits rather
## than a step finer, since a step finer there is too small to read.
const SMALL_HEIGHT := 800.0
## The most of the pictures' 480 by 270 view a scale may cut off each side to fill the window.
const MOST_CROP := 0.12
const SCREENS := {
	"title": "res://scripts/screens/title.gd",
	"workshop": "res://scripts/screens/workshop.gd",
	"job_board": "res://scripts/screens/job_board.gd",
	"client_visit": "res://scripts/screens/client_visit.gd",
	"design_table": "res://scripts/screens/design_table.gd",
	"floor": "res://scripts/floor/floor_screen.gd",
	"reveal": "res://scripts/screens/reveal.gd",
	"day_end": "res://scripts/screens/day_end.gd",
	"town_map": "res://scripts/screens/town_map.gd",
	"library": "res://scripts/screens/library_screen.gd",
}

var world: Node2D
var pictures_layer: CanvasLayer
## Where screens put their painted pictures, in picture pixels: (0, 0) to BASE is the view kept in the middle.
var pictures: Control
var ui_layer: CanvasLayer
var ui: Control
var current: Node
var current_name := ""
var _args := {}
var _fade: ColorRect
var _busy := false
var _fitted := Vector2.ZERO
## A fixed interface scale, for recordings that frame the interface as it was laid out for them; 0 picks it as usual.
var ui_scale_override := 0
## Worker tasks whose screen closed before they finished, each waited for once done, since a task never waited for is never freed.
var _left_tasks: Array[int] = []
## Set once the game starts quitting, so a screen change still fading stops instead of opening a new screen.
var _closed := false


func _ready() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	pictures_layer = CanvasLayer.new()
	pictures_layer.layer = 4
	add_child(pictures_layer)
	pictures = Control.new()
	pictures.name = "Pictures"
	pictures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pictures.theme = UiTheme.build()
	pictures_layer.add_child(pictures)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	ui = Control.new()
	ui.name = "UI"
	ui.theme = UiTheme.build()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui)
	var top := CanvasLayer.new()
	top.layer = 50
	add_child(top)
	_fade = ColorRect.new()
	_fade.color = Color(0.08, 0.06, 0.05, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_fade)
	get_viewport().size_changed.connect(_fit)
	_fit()


## Screen pixels per interface pixel.
func scale_factor() -> int:
	if ui_scale_override > 0:
		return ui_scale_override
	return ui_scale_for(get_viewport().get_visible_rect().size, Settings.ui_scale_step)


## Screen pixels per picture pixel.
func picture_scale() -> int:
	return picture_scale_for(get_viewport().get_visible_rect().size)


## One step under what fits the window, or what fits on a small window, moved by the player's interface size, but never
## so large that 480 by 270 won't fit.
static func ui_scale_for(window: Vector2, step: int = 0) -> int:
	var fit := maxi(1, int(minf(window.x / UI_FIT_WIDTH, window.y / BASE.y)))
	var most := maxi(1, int(minf(window.x / BASE.x, window.y / BASE.y)))
	var finer := 0 if window.y <= SMALL_HEIGHT else 1
	return clampi(fit - finer + step, 1, most)


## The smallest scale that covers the window when it crops only a little, else the largest that fits.
static func picture_scale_for(window: Vector2) -> int:
	var fits := maxi(1, int(minf(window.x / BASE.x, window.y / BASE.y)))
	var covers := maxi(1, ceili(maxf(window.x / BASE.x, window.y / BASE.y)))
	var crop := (BASE * covers - window) * 0.5 / (BASE * covers)
	return covers if maxf(crop.x, crop.y) <= MOST_CROP else fits


## Where the pictures' 480 by 270 view starts in the window, in screen pixels: centred.
func picture_origin() -> Vector2:
	return ((get_viewport().get_visible_rect().size - BASE * picture_scale()) * 0.5).floor()


## The part of the pictures the window shows, in picture pixels.
func picture_view() -> Rect2:
	var k := float(picture_scale())
	return Rect2(-picture_origin() / k, get_viewport().get_visible_rect().size / k)


## A point in picture pixels turned into interface pixels.
func picture_to_ui(p: Vector2) -> Vector2:
	return (picture_origin() + p * picture_scale()) / scale_factor()


## A rectangle in picture pixels turned into interface pixels.
func picture_rect_to_ui(r: Rect2) -> Rect2:
	return Rect2(picture_to_ui(r.position), r.size * picture_scale() / scale_factor())


## The interface's size in its own pixels. Wider windows get more room at the sides, never stretched pixels.
func ui_size() -> Vector2:
	return (get_viewport().get_visible_rect().size / scale_factor()).floor()


## A point in the window turned into interface pixels.
func to_ui(screen: Vector2) -> Vector2:
	return screen / scale_factor()


func go(screen: String, args: Dictionary = {}) -> void:
	if _busy or _closed or not SCREENS.has(screen):
		return
	_busy = true
	if current:
		var out := create_tween()
		out.tween_property(_fade, "color:a", 1.0, 0.14)
		await out.finished
		if _closed:
			return
		current.queue_free()
		current = null
	for c in world.get_children():
		c.queue_free()
	for c in ui.get_children():
		c.queue_free()
	for c in pictures.get_children():
		c.queue_free()
	_forget_screen_listeners()
	await get_tree().process_frame
	if _closed:
		return
	var s: Node = load(SCREENS[screen]).new()
	s.name = screen
	add_child(s)
	current = s
	current_name = screen
	_args = args
	if s.has_method("enter"):
		s.enter(args)
	screen_changed.emit(screen)
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.2)
	await back.finished
	_busy = false


## Builds the current screen again, as after a change of language, with its settings open where they were.
func reopen() -> void:
	await go(current_name, _args)
	if current and current.has_method("open_settings"):
		current.open_settings()


## Drops the last screen's listeners, keeping the autoloads', since a leftover one pointing at a freed panel crashes.
func _forget_screen_listeners() -> void:
	for sig in [resized, Game.changed]:
		for c in sig.get_connections():
			var owner: Object = (c["callable"] as Callable).get_object()
			if not (owner is Node and (owner as Node).get_parent() == get_tree().root):
				sig.disconnect(c["callable"])


## Refits whenever the window's size differs from the last fit, in case the window changed without saying so.
func _process(_delta: float) -> void:
	if get_viewport().get_visible_rect().size != _fitted:
		_fit()
	for task in _left_tasks.duplicate():
		if WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
			_left_tasks.erase(task)


## Takes over a worker task a closing screen started, so it is finished off without making the next screen wait.
func leave_task(task: int) -> void:
	if task >= 0:
		_left_tasks.append(task)


## Closes the screen and waits for every worker task, as the game quits, since a task still running at exit crashes it.
func close() -> void:
	_closed = true
	if current:
		current.queue_free()
		current = null
	for layer in [world, ui, pictures]:
		for c in layer.get_children():
			c.queue_free()
	_forget_screen_listeners()
	await get_tree().process_frame
	for task in _left_tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_left_tasks.clear()


## Lays every layer out again, as after the interface scale is changed.
func refit() -> void:
	_fit()


func _fit() -> void:
	_fitted = get_viewport().get_visible_rect().size
	var k := scale_factor()
	ui_layer.transform = Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)
	ui.size = ui_size()
	var p := picture_scale()
	pictures_layer.transform = Transform2D(0.0, Vector2(p, p), 0.0, picture_origin())
	pictures.size = BASE
	_fade.size = get_viewport().get_visible_rect().size
	resized.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		Settings.toggle_fullscreen()


## Escape, which the pad's B sends too, closes the topmost window, or else steps back out of the screen, even while typing.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) or _busy:
		return
	if close_top() or (current and current.has_method("go_back") and current.go_back()):
		get_viewport().set_input_as_handled()


## Whether a window marked by `Ui.closes_with` is open, leaving out the guide's notes, which lie beside what they point at.
func window_open() -> bool:
	if ui == null:
		return false
	for c in ui.find_children("*", "Control", true, false):
		if c.has_meta("close") and not c is Guide and c.is_visible_in_tree() and not c.is_queued_for_deletion():
			return true
	return false


## Closes the newest window open of those marked by `Ui.closes_with`; false when none is open.
func close_top() -> bool:
	var top: Control = null
	for c in ui.find_children("*", "Control", true, false):
		if c.has_meta("close") and c.is_visible_in_tree() and not c.is_queued_for_deletion():
			if top == null or int(c.get_meta("opened", 0)) >= int(top.get_meta("opened", 0)):
				top = c
	if top == null:
		return false
	Audio.play("click")
	(top.get_meta("close") as Callable).call()
	return true
