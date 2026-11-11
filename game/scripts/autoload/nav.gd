extends Node
## Switches between screens with a short fade. Every screen draws into two layers: the world, at the window's full
## resolution, and the interface, pixel art drawn at 480 by 270 and scaled up by the largest whole number that fits.

signal screen_changed(screen: String)
signal resized

const BASE := Vector2(480, 270)
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
var ui_layer: CanvasLayer
var ui: Control
var current: Node
var current_name := ""
var _args := {}
var _fade: ColorRect
var _busy := false
var _fitted := Vector2.ZERO


func _ready() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
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


func scale_factor() -> int:
	var s := get_viewport().get_visible_rect().size
	return maxi(1, int(minf(s.x / BASE.x, s.y / BASE.y)))


## The interface's size in its own pixels. Wider windows get more room at the sides, never stretched pixels.
func ui_size() -> Vector2:
	return (get_viewport().get_visible_rect().size / scale_factor()).floor()


## A point in the window turned into interface pixels.
func to_ui(screen: Vector2) -> Vector2:
	return screen / scale_factor()


func go(screen: String, args: Dictionary = {}) -> void:
	if _busy or not SCREENS.has(screen):
		return
	_busy = true
	if current:
		var out := create_tween()
		out.tween_property(_fade, "color:a", 1.0, 0.14)
		await out.finished
		current.queue_free()
		current = null
	for c in world.get_children():
		c.queue_free()
	for c in ui.get_children():
		c.queue_free()
	_forget_screen_listeners()
	await get_tree().process_frame
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


func _fit() -> void:
	_fitted = get_viewport().get_visible_rect().size
	var k := scale_factor()
	ui_layer.transform = Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)
	ui.size = ui_size()
	_fade.size = get_viewport().get_visible_rect().size
	resized.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		Settings.toggle_fullscreen()
