extends CanvasLayer
## The game's first frames repeat the loading screen where Godot drew it, then fade once the title's floor is out, so
## the start never shows the empty window while that floor is set out.

const PICTURE := preload("res://assets/loading_screen.png")
const FADE := 0.5
## The longest the picture waits for the title's floor before it fades anyway.
const LONGEST := 3.0

var _cover: ColorRect
var _waited := 0.0
var _fading := false


func _ready() -> void:
	layer = 100
	_cover = ColorRect.new()
	_cover.color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.BLACK)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cover)
	var picture := TextureRect.new()
	picture.texture = PICTURE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.add_child(picture)
	# Godot's cover stretch scales the splash until it fills the window and centres it, so the picture lands on its pixels.
	var place := func():
		var zoom := maxf(_cover.size.x / PICTURE.get_width(), _cover.size.y / PICTURE.get_height())
		picture.size = PICTURE.get_size() * zoom
		picture.position = (_cover.size - picture.size) / 2.0
	_cover.resized.connect(place)
	place.call()


func _process(delta: float) -> void:
	_waited += delta
	if _fading:
		return
	if _waited >= LONGEST or Nav.world.get_children().any(func(c): return c is FloorView):
		_fading = true
		var fade := create_tween()
		fade.tween_property(_cover, "modulate:a", 0.0, FADE)
		fade.tween_callback(queue_free)
