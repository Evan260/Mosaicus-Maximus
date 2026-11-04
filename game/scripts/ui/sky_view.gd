class_name SkyView
extends Control
## The sky behind the workshop's door and window, drawn in interface pixels: blue by day, warm at dawn and dusk,
## and dark with twinkling stars and a moon at night, with a few clouds drifting across.

var hour := 12.0
var _t := 0.0
var _stars: Array = []
var _clouds: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 140:
		_stars.append([Vector2(rng.randi_range(0, 479), rng.randi_range(20, 110)), rng.randf() * TAU, rng.randf_range(0.5, 1.0)])
	for i in 6:
		_clouds.append([rng.randf_range(0.0, 600.0), rng.randf_range(44.0, 96.0), rng.randi_range(10, 22), rng.randf_range(2.0, 5.0)])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var colours := Daylight.sky(hour)
	var top: Color = colours[0]
	var low: Color = colours[1]
	for y in range(0, 120, 2):
		draw_rect(Rect2(0, y, size.x, 2), top.lerp(low, clampf((y - 20.0) / 90.0, 0.0, 1.0)))
	var night := Daylight.night(hour)
	if night > 0.05:
		for s in _stars:
			var a := night * float(s[2]) * (0.55 + 0.45 * sin(_t * 1.7 + float(s[1])))
			draw_rect(Rect2(s[0], Vector2.ONE), Color(1.0, 0.97, 0.88, a))
		draw_circle(Vector2(392, 34), 5.0, Color(0.97, 0.95, 0.86, night))
		draw_circle(Vector2(394, 33), 4.0, Color(top, night))
	var cloud := Color(1, 1, 1, 0.75).lerp(Color(0.5, 0.52, 0.7, 0.5), night).lerp(Color(1.0, 0.78, 0.66, 0.8), _dusk())
	for c in _clouds:
		var x := fposmod(float(c[0]) + _t * float(c[3]), 600.0) - 60.0
		var w := float(c[2])
		draw_rect(Rect2(x, c[1], w, 3), cloud)
		draw_rect(Rect2(x + 3, float(c[1]) - 2, w - 7, 2), cloud)


## How golden the light is, highest at dawn and dusk.
func _dusk() -> float:
	return maxf(0.0, 1.0 - absf(hour - 18.5) / 1.5) + maxf(0.0, 1.0 - absf(hour - 6.0) / 1.2)
