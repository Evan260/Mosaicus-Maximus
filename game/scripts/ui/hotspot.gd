class_name Hotspot
extends Control
## Something in the workshop that can be clicked: it answers only over its own shape, and lights up the pictures
## that belong to it while the mouse is over it.

signal clicked
signal hovered(on: bool)

const GLOW := preload("res://shaders/glow_outline.gdshader")

var tip := ""
var _mask: Image
var _targets: Array[CanvasItem] = []
var _glow := 0.0
var _tween: Tween
var _pressed := false


## A hotspot over a rectangle, or over the visible pixels of a picture placed at the rectangle's corner.
static func make(rect: Rect2, tip_text: String, shape: Texture2D = null) -> Hotspot:
	var h := Hotspot.new()
	h.position = rect.position
	h.size = rect.size
	h.tip = tip_text
	h.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if shape:
		h._mask = shape.get_image()
		h._mask.decompress()
	return h


## Adds a picture that brightens while this is hovered, with an outline round a traced shape or its own edge.
func light(item: CanvasItem, shape: Texture2D = null, outline: bool = true) -> void:
	var m := ShaderMaterial.new()
	m.shader = GLOW
	m.set_shader_parameter("outline", 1.0 if outline else 0.0)
	if shape:
		m.set_shader_parameter("use_shape", true)
		m.set_shader_parameter("shape", shape)
	item.material = m
	_targets.append(item)


func _ready() -> void:
	mouse_entered.connect(func() -> void: _fade(1.0))
	mouse_exited.connect(func() -> void: _fade(0.0))


func _has_point(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	if _mask == null:
		return true
	var p := Vector2i(point)
	# Thin gaps inside a piece still count, so the pointer never flickers between its parts.
	for o in [Vector2i.ZERO, Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]:
		var q: Vector2i = p + o
		if q.x >= 0 and q.y >= 0 and q.x < _mask.get_width() and q.y < _mask.get_height() and _mask.get_pixelv(q).a > 0.5:
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		# The release comes here even off the shape, since this took the press, so letting go elsewhere cancels.
		if not event.pressed and _pressed and _has_point(event.position):
			clicked.emit()
		_pressed = event.pressed


func _fade(to: float) -> void:
	hovered.emit(to > 0.5)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_glow, _glow, to, 0.12)


func _set_glow(v: float) -> void:
	_glow = v
	for t in _targets:
		if is_instance_valid(t):
			(t.material as ShaderMaterial).set_shader_parameter("glow", v)
