extends Node
## Controller support: the left stick moves the pointer and A clicks and drags, so every screen works as with a mouse.
## The shoulder buttons change the brush size, B steps back, X turns and Y mirrors a motif.

const SPEED := 900.0
const DEAD := 0.18

var _held := false
var _cursor := Vector2.ZERO
var _active := false


func _process(delta: float) -> void:
	if Input.get_connected_joypads().is_empty():
		return
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() < DEAD:
		return
	if not _active:
		_active = true
		_cursor = get_viewport().get_mouse_position()
	var size := get_viewport().get_visible_rect().size
	var before := _cursor
	_cursor = (_cursor + stick * stick.length() * SPEED * delta).clamp(Vector2.ZERO, size - Vector2.ONE)
	get_viewport().warp_mouse(_cursor)
	var motion := InputEventMouseMotion.new()
	motion.position = _cursor
	motion.global_position = _cursor
	motion.relative = _cursor - before
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _held else 0
	Input.parse_input_event(motion)


func _input(event: InputEvent) -> void:
	if not event is InputEventJoypadButton:
		return
	var b := event as InputEventJoypadButton
	match b.button_index:
		JOY_BUTTON_A:
			_click(MOUSE_BUTTON_LEFT, b.pressed)
			_held = b.pressed
		JOY_BUTTON_B:
			if b.pressed:
				_key(KEY_ESCAPE)
		JOY_BUTTON_X:
			if b.pressed:
				_key(KEY_R)
		JOY_BUTTON_Y:
			if b.pressed:
				_key(KEY_F)
		JOY_BUTTON_LEFT_SHOULDER:
			if b.pressed:
				_key(KEY_BRACKETLEFT)
		JOY_BUTTON_RIGHT_SHOULDER:
			if b.pressed:
				_key(KEY_BRACKETRIGHT)


func _click(button: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = get_viewport().get_mouse_position()
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
