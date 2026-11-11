class_name EdgeFade
extends Control
## Laid over a picture smaller than the window, it fades each edge with room past it into the background colour, a
## pixel at a time, so the picture never ends in a straight cut.

## The most pixels an edge fades over.
const FADE := 24

var picture := Rect2()
var colour: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color.BLACK)


static func make() -> EdgeFade:
	var e := EdgeFade.new()
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e


## Fades `rect` inside a view of `view` pixels.
func fit(rect: Rect2, view: Vector2) -> void:
	picture = rect
	size = view
	queue_redraw()


## Pixels each edge (left, top, right, bottom) fades over: as far as the view reaches past it, at most FADE.
func widths() -> Array:
	var room := [picture.position.x, picture.position.y, size.x - picture.end.x, size.y - picture.end.y]
	return room.map(func(r: float) -> int: return clampi(int(r), 0, FADE))


func _draw() -> void:
	var w := widths()
	var p := picture
	for side in 4:
		var f: int = w[side]
		for i in f:
			var c := Color(colour, 1.0 - smoothstep(0.0, 1.0, (i + 1.0) / (f + 1.0)))
			match side:
				0: draw_rect(Rect2(p.position.x + i, p.position.y, 1, p.size.y), c)
				1: draw_rect(Rect2(p.position.x, p.position.y + i, p.size.x, 1), c)
				2: draw_rect(Rect2(p.end.x - 1 - i, p.position.y, 1, p.size.y), c)
				3: draw_rect(Rect2(p.position.x, p.end.y - 1 - i, p.size.x, 1), c)
