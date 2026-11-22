class_name Touch
## Decisions about a phone's touch screen, kept apart from the interface so the tests can check them.

## How long a finger rests on something before the game shows what it is rather than acting on it.
const HOLD_SECONDS := 0.4
## How long one finger on the floor waits before it lays, in case a second finger follows for a pinch.
const BRUSH_WAIT := 0.1


## Whether a finger that has rested this long and wandered this far, in screen pixels, is holding rather than tapping.
static func is_hold(seconds: float, moved: float, slop: float) -> bool:
	return seconds >= HOLD_SECONDS and moved <= slop


## Whether a lifted finger acts on what it touched, which a finger that slid away or was held to read it does not.
static func is_tap(moved: float, slop: float, held: bool) -> bool:
	return moved <= slop and not held


## A tip without the key that does the same, such as "(R)" or "(Ctrl+Z)", since a phone has no keys.
static func drop_key_hint(text: String) -> String:
	var t := text.strip_edges()
	for pair in [["(", ")"], ["（", "）"]]:
		var at := t.rfind(pair[0])
		if t.ends_with(pair[1]) and at > 0:
			var inside := t.substr(at + 1, t.length() - at - 2).strip_edges()
			if inside.length() <= 10 and not inside.contains(" "):
				return t.substr(0, at).strip_edges()
	return text


## Where the back gesture goes from a screen that has no step back of its own: "background" puts the game away,
## "job_board" or "title" go there, and "carry_on" does what the screen's one button does.
static func back_from(screen: String) -> String:
	match screen:
		"title":
			return "background"
		"client_visit":
			return "job_board"
		"reveal", "day_end":
			return "carry_on"
	return "title"


## Whether one finger on the floor starts laying: once it sweeps past the slop, or has rested a moment.
static func brush_starts(seconds: float, moved: float, slop: float) -> bool:
	return moved > slop or seconds >= BRUSH_WAIT


## How much farther apart two fingers are than they were.
static func pinch_factor(from_a: Vector2, from_b: Vector2, to_a: Vector2, to_b: Vector2) -> float:
	return to_a.distance_to(to_b) / maxf(from_a.distance_to(from_b), 1.0)


## A camera moved by two fingers, as [position, zoom]: it zooms by the pinch, and the point between the fingers stays
## under them as they move, so the same gesture pans and zooms.
static func pinch_camera(pos: Vector2, zoom: float, view: Vector2, from_a: Vector2, from_b: Vector2, to_a: Vector2, to_b: Vector2, least: float, most: float) -> Array:
	var z := clampf(zoom * pinch_factor(from_a, from_b, to_a, to_b), least, most)
	var held := pos + ((from_a + from_b) * 0.5 - view * 0.5) / zoom
	return [held - ((to_a + to_b) * 0.5 - view * 0.5) / z, z]


## How far from a motif's corner a press grabs it, in interface pixels: half a fingertip, but inside a small motif no
## more than a quarter of its short side, so its middle can still be dragged.
static func handle_reach(inside: bool, finger: float, short_side: float) -> float:
	if finger <= 0.0:
		return PlanView.HANDLE
	if not inside:
		return maxf(PlanView.HANDLE, finger * 0.5)
	return clampf(short_side * 0.25, PlanView.HANDLE, finger * 0.5)


## Where a window goes, from `y`, so its text field (`field_top` to `field_bottom` down from the window's top) shows just
## above a keyboard whose top is at `keyboard_top`, but never higher than the top of the screen.
static func clear_keyboard(y: float, field_top: float, field_bottom: float, keyboard_top: float) -> float:
	return maxf(minf(y, keyboard_top - field_bottom - 4.0), 2.0 - field_top)
