extends Control
## The loading screen's bar, drawn on the loading picture's own pixels in the logo's golds, so it reads as part of the
## picture wherever the window crops it.

## The bar's rows from top to bottom, the logo's letters' golds from their shine down to their shade.
const GOLDS: Array[Color] = [Color("ffe8a0"), Color("fad46e"), Color("f0b648"), Color("e09634"), Color("cc7a2a")]
const OUTLINE := Color("3a221a")
const TRACK := Color(0.227, 0.133, 0.102, 0.6)
const SHADOW := Color(0.0, 0.0, 0.0, 0.3)
## The bar's size in the picture's own pixels.
const WIDTH := 512.0
const HEIGHT := 28.0

var picture_size := Vector2(2560, 1080)
## How far the bar's bottom sits above the picture's bottom, in the picture's own pixels.
var lift := 48.0
## The picture's pixels to one pixel of its art, so the bar's outline and steps are one pixel of the art.
var art_pixel := 4.0
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## How many pixels of the art the gold covers inside a bar `inside` pixels long, so it grows a whole pixel at a time.
static func filled(share: float, inside: int) -> int:
	return clampi(floori(share * inside), 0, inside)


## The picture's scale in the window and where its top left corner lands: the cover placement of the picture under the
## bar, so the bar's pixels land on the picture's.
func _placement() -> Array:
	var zoom := maxf(size.x / picture_size.x, size.y / picture_size.y)
	return [zoom, (size - picture_size * zoom) / 2.0]


## The bar's width in the picture's own pixels: its own, or less in a window too narrow to show that much of the picture.
func _width() -> float:
	var shown: float = size.x / _placement()[0]
	return minf(WIDTH, floorf(shown * 0.8 / art_pixel) * art_pixel)


## Where the bar's top left corner sits on the picture, in the picture's own pixels.
func _corner() -> Vector2:
	var zoom: float = _placement()[0]
	var origin: Vector2 = _placement()[1]
	var corner := Vector2((picture_size.x - _width()) / 2.0, picture_size.y - lift - HEIGHT)
	# A window wider than the picture crops its bottom, so the bar rises to stay in sight.
	corner.y = minf(corner.y, (size.y - origin.y) / zoom - lift - HEIGHT)
	return corner


## The bar's outline in window pixels.
func box() -> Rect2:
	var zoom: float = _placement()[0]
	var origin: Vector2 = _placement()[1]
	return Rect2(origin + _corner() * zoom, Vector2(_width(), HEIGHT) * zoom)


func _draw() -> void:
	var zoom: float = _placement()[0]
	var origin: Vector2 = _placement()[1]
	var corner := _corner()
	var cols := roundi(_width() / art_pixel)
	var rows := roundi(HEIGHT / art_pixel)
	var cell := func(x: float, y: float, w: float, h: float, color: Color) -> void:
		var a := (origin + (corner + Vector2(x, y) * art_pixel) * zoom).round()
		var b := (origin + (corner + Vector2(x + w, y + h) * art_pixel) * zoom).round()
		draw_rect(Rect2(a, b - a), color)
	cell.call(1, rows, cols - 2, 1, SHADOW)
	cell.call(1, 1, cols - 2, rows - 2, TRACK)
	cell.call(1, 0, cols - 2, 1, OUTLINE)
	cell.call(1, rows - 1, cols - 2, 1, OUTLINE)
	cell.call(0, 1, 1, rows - 2, OUTLINE)
	cell.call(cols - 1, 1, 1, rows - 2, OUTLINE)
	var gold := filled(progress, cols - 2)
	if gold == 0:
		return
	for r in rows - 2:
		cell.call(1, 1 + r, gold, 1, GOLDS[floori(float(r) * GOLDS.size() / (rows - 2))])
