class_name TouchScroll
extends Node
## Lets a finger scroll a list on a touch screen: dragging up or down anywhere over the list moves it, even when the
## drag starts on a button, and a drag never counts as pressing the button it began on.

## How far a finger must move, in screen pixels, before a touch becomes a scroll rather than a tap.
const DEADZONE := 8.0

var scroll: ScrollContainer
var _touching := false
var _dragging := false
var _from := Vector2.ZERO
var _start := 0
## Shared by every list, since a list inside a scrolling window feels the same drag and only one of them takes its release.
static var _swallow_release := false


## Gives a list finger scrolling, once; the list may have gone by the time this is called.
static func attach(s: Variant) -> void:
	if not is_instance_valid(s) or not s is ScrollContainer or (s as Node).get_children(true).any(func(c: Node) -> bool: return c is TouchScroll):
		return
	var t := TouchScroll.new()
	t.scroll = s
	(s as Node).add_child(t, false, Node.INTERNAL_MODE_BACK)


func _input(event: InputEvent) -> void:
	if scroll == null or not scroll.is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _screen_rect().has_point(event.position):
			_touching = true
			_dragging = false
			_swallow_release = false
			_from = event.position
			_start = scroll.scroll_vertical
		elif not event.pressed and _touching:
			_touching = false
			if _dragging:
				_swallow_release = true
	elif event is InputEventScreenDrag and _touching:
		var moved: float = event.position.y - _from.y
		if not _dragging and absf(moved) > DEADZONE and _can_scroll():
			_dragging = true
			# The press already reached the button under the finger; a release far away lets it go without a click.
			var away := InputEventMouseButton.new()
			away.button_index = MOUSE_BUTTON_LEFT
			away.pressed = false
			away.position = Vector2(-10000, -10000)
			Input.parse_input_event(away)
			_let_go(_from)
		if _dragging:
			scroll.scroll_vertical = _start - roundi(moved / _scale())
	elif event is InputEventMouseButton and not event.pressed and _swallow_release and event.position.x > -1000:
		# The release the system makes up for the lifted finger would otherwise press the button now under it.
		_swallow_release = false
		get_viewport().set_input_as_handled()


## Whether the list is longer than its window, so a drag over a list that fits still drags what is in it.
func _can_scroll() -> bool:
	var bar := scroll.get_v_scroll_bar()
	return bar != null and bar.max_value - bar.page > 0.5


## The button a drag began on forgets its press, as disabling it for a moment makes it do.
func _let_go(at: Vector2) -> void:
	for b in scroll.find_children("*", "BaseButton", true, false):
		var xform: Transform2D = b.get_global_transform_with_canvas()
		if not b.disabled and Rect2(xform.origin, b.size * xform.get_scale()).has_point(at):
			b.disabled = true
			b.disabled = false


func _scale() -> float:
	return maxf(0.01, scroll.get_global_transform_with_canvas().get_scale().y)


func _screen_rect() -> Rect2:
	var xform := scroll.get_global_transform_with_canvas()
	return Rect2(xform.origin, scroll.size * xform.get_scale())
