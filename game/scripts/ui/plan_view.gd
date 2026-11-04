class_name PlanView
extends Control
## The floor plan on the design table: the design drawn as it will be laid, the selected motif with handles at its
## corners for resizing, and the part being coloured glowing softly.

signal pressed_at(tile: Vector2, button: int)
signal dragged_to(tile: Vector2)
signal released
signal wheeled(steps: int, tile: Vector2)
signal dropped(motif: String, tile: Vector2)
signal hovered_at(tile: Vector2)
signal handle_grabbed(corner: int)
signal handle_dragged(tile: Vector2)

const HANDLE := 5.0
const GOLD := Color8(236, 196, 96)

var texture: Texture2D
var tiles := Vector2(40, 28)
var selection := Rect2()
## Pictures the size of the plan: the part being coloured, and the part under the mouse, each drawn as an outline.
var chosen_part: Texture2D:
	set(t):
		chosen_part = t
		_chosen_layer.texture = t
var hover_part: Texture2D:
	set(t):
		hover_part = t
		_hover_layer.texture = t
## How many plan pixels wide the outlines are, so they stay visible however finely the plan is drawn.
var outline_width := 1.0
var _chosen_layer: TextureRect
var _hover_layer: TextureRect
## A copy job's sketch, laid over the plan while the player compares.
var peek: Texture2D
var _down := false
var _resizing := false
var _corner := -1
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_drag_forwarding(Callable(), _can_drop, _drop)


func _init() -> void:
	_hover_layer = _outline_layer(Color(1, 1, 1, 0.9))
	_chosen_layer = _outline_layer(Color8(255, 214, 80))


func _outline_layer(c: Color) -> TextureRect:
	var t := TextureRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/part_outline.gdshader")
	m.set_shader_parameter("colour", c)
	t.material = m
	add_child(t)
	return t


func _process(delta: float) -> void:
	_t += delta
	var r := plan_rect()
	for layer in [_hover_layer, _chosen_layer]:
		layer.position = r.position
		layer.size = r.size
		(layer.material as ShaderMaterial).set_shader_parameter("width", outline_width)
	(_chosen_layer.material as ShaderMaterial).set_shader_parameter("strength", 0.7 + 0.3 * sin(_t * 5.0))


func set_image(tex: Texture2D, room_tiles: Vector2) -> void:
	texture = tex
	tiles = room_tiles
	queue_redraw()


## Where the plan is drawn inside this control, as large as fits without stretching it.
func plan_rect() -> Rect2:
	var k := minf(size.x / tiles.x, size.y / tiles.y)
	var s := (tiles * k).floor()
	return Rect2(((size - s) * 0.5).floor(), s)


func tile_at(local: Vector2) -> Vector2:
	var r := plan_rect()
	return (local - r.position) / r.size * tiles


## The selection's rectangle in this control's own pixels.
func selection_local() -> Rect2:
	return _to_local_rect(selection)


func _draw() -> void:
	var r := plan_rect()
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.3))
	if texture:
		draw_texture_rect(texture, r, false)
	_draw_guides(r)
	if peek:
		draw_texture_rect(peek, r, false, Color(1, 1, 1, 0.85))
	if selection.size != Vector2.ZERO:
		var s := _to_local_rect(selection)
		draw_rect(s.grow(1), GOLD, false, 1.0)
		for c in _corners(s):
			draw_rect(Rect2(c - Vector2(2, 2), Vector2(5, 5)), Color8(58, 38, 30))
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), GOLD)


## Dotted lines through the middle of the room, side to side and top to bottom, for lining motifs up.
func _draw_guides(r: Rect2) -> void:
	var ink := Color8(120, 78, 50, 110)
	var mid := (r.position + r.size * 0.5).floor()
	for x in range(int(r.position.x), int(r.end.x), 4):
		draw_rect(Rect2(x, mid.y, 2, 1), ink)
	for y in range(int(r.position.y), int(r.end.y), 4):
		draw_rect(Rect2(mid.x, y, 1, 2), ink)
	draw_rect(Rect2(mid - Vector2(2, 2), Vector2(5, 5)), Color(ink, 0.2), false, 1.0)


func _corners(s: Rect2) -> Array:
	return [s.position, Vector2(s.end.x, s.position.y), s.end, Vector2(s.position.x, s.end.y)]


## Which corner handle is under a point, 0 to 3 clockwise from the top left, or -1.
func handle_at(local: Vector2) -> int:
	if selection.size == Vector2.ZERO:
		return -1
	var cs := _corners(_to_local_rect(selection))
	for i in 4:
		if (cs[i] as Vector2).distance_to(local) <= HANDLE:
			return i
	return -1


func _to_local_rect(t: Rect2) -> Rect2:
	var r := plan_rect()
	var k := r.size / tiles
	return Rect2(r.position + t.position * k, t.size * k)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			wheeled.emit(1, tile_at(mb.position))
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			wheeled.emit(-1, tile_at(mb.position))
			accept_event()
		elif mb.pressed:
			var corner := handle_at(mb.position) if mb.button_index == MOUSE_BUTTON_LEFT else -1
			_down = mb.button_index == MOUSE_BUTTON_LEFT
			_resizing = corner >= 0
			_corner = corner
			if _resizing:
				handle_grabbed.emit(corner)
			else:
				pressed_at.emit(tile_at(mb.position), mb.button_index)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_down = false
			_resizing = false
			released.emit()
	elif event is InputEventMouseMotion:
		var pos := (event as InputEventMouseMotion).position
		if _down:
			if _resizing:
				handle_dragged.emit(tile_at(pos))
			else:
				dragged_to.emit(tile_at(pos))
		else:
			hovered_at.emit(tile_at(pos))
		_set_cursor(pos)


func _set_cursor(pos: Vector2) -> void:
	var corner := _corner if _resizing else (handle_at(pos) if not _down else -1)
	if corner >= 0:
		mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE if corner % 2 == 0 else Control.CURSOR_BDIAGSIZE
	elif _to_local_rect(selection).has_point(pos):
		mouse_default_cursor_shape = Control.CURSOR_MOVE
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not _down:
		hovered_at.emit(Vector2(-1, -1))


func _can_drop(_at: Vector2, data) -> bool:
	return data is Dictionary and data.has("motif")


func _drop(at: Vector2, data) -> void:
	dropped.emit(data["motif"], tile_at(at))
