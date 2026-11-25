class_name RoomView
extends Control
## A client's room with the finished floor laid in it. The room is one painting with a gap where its floor is; the
## floor is drawn behind that gap in perspective, from a live picture of the real floor, so it is sharp at any window
## size and its band of light still runs across it.

const ART := "res://assets/art/rooms/"
## How far the floor keeps from the card beside it and from the top and bottom of the screen, in interface pixels.
const GAP := 2.0

var floor_view: FloorView
var _viewport: SubViewport
var _camera: Camera2D
var _world := Vector2.ONE
## The floor's bounding box in the painting's pixels.
var _floor_box := Rect2()
## Screen pixels per painting pixel, which is never more than the other pictures' scale.
var _scale := 1
## The card the room sits beside, in interface pixels; empty while there is none.
var _card := Rect2()
## A note at the top of the screen that the floor keeps below, in interface pixels; empty while there is none.
var _note := Rect2()

static var _rooms := {}


## Whether this kind of room has a painting yet.
static func has_room(room: String) -> bool:
	return not _info(room).is_empty() and ResourceLoader.exists(ART + room + ".png")


static func _info(room: String) -> Dictionary:
	if _rooms.is_empty() and FileAccess.file_exists(ART + "rooms.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ART + "rooms.json"))
		_rooms = parsed if parsed is Dictionary else {}
	return _rooms.get(room, {})


func setup(room: String, layout: MosaicLayout, stones: Dictionary) -> void:
	var info := _info(room)
	size = Vector2(info["size"][0], info["size"][1])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var corners: Array = (info["floor"] as Array).map(func(c: Array) -> Vector2: return Vector2(c[0], c[1]))
	var box := Rect2(corners[0], Vector2.ZERO)
	for c in corners:
		box = box.expand(c)
	box.position = box.position.floor()
	box.end = box.end.ceil()
	_world = Vector2(layout.w, layout.h) * FloorView.WORLD
	_floor_box = box
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	_viewport = vp
	floor_view = FloorView.new()
	floor_view.walls_visible = false
	vp.add_child(floor_view)
	floor_view.setup(layout)
	floor_view.chalk_visible = false
	floor_view.show_finished()
	floor_view.apply_stones(stones)
	_camera = Camera2D.new()
	_camera.position = _world * 0.5
	vp.add_child(_camera)
	_camera.make_current()
	var floor_rect := ColorRect.new()
	floor_rect.position = box.position
	floor_rect.size = box.size
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/room_floor.gdshader")
	mat.set_shader_parameter("floor_tex", vp.get_texture())
	var rows := Perspective.to_floor(corners.map(func(c: Vector2) -> Vector2: return c - box.position))
	for k in 3:
		mat.set_shader_parameter("row%d" % k, rows[k])
	floor_rect.material = mat
	add_child(floor_rect)
	var painting := TextureRect.new()
	painting.texture = load(ART + room + ".png")
	painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(painting)
	Nav.resized.connect(place)
	place()


## Sets the room so its whole floor shows right of the client's card and below a note at the top, both in interface pixels.
func keep_clear_of(card: Rect2, note := Rect2()) -> void:
	_card = card
	_note = note
	place()


## The largest whole scale, up to the pictures', at which the whole floor fits right of `card` and below `note`, both in interface pixels.
func scale_beside(card: Rect2, note := Rect2()) -> int:
	var free := _free(card, note)
	var k := Nav.picture_scale()
	while k > 1 and (_floor_box.size.x * k > free.size.x or _floor_box.size.y * k > free.size.y):
		k -= 1
	return k


## The screen right of `card` and below `note`, in screen pixels, keeping a gap from both and from the top and bottom.
func _free(card: Rect2, note: Rect2) -> Rect2:
	var ui := float(Nav.scale_factor())
	var free := Rect2(Nav.safe_top_left * ui, Nav.ui_size() * ui).grow_individual(0.0, -GAP * ui, 0.0, -GAP * ui)
	if card.size != Vector2.ZERO:
		var left := (Nav.safe_top_left.x + card.end.x + GAP) * ui
		free = Rect2(left, free.position.y, free.end.x - left, free.size.y)
	if note.has_area():
		free = free.grow_side(SIDE_TOP, minf(0.0, free.position.y - (Nav.safe_top_left.y + note.end.y + GAP) * ui))
	return free


## Draws the room at the largest whole scale, up to the pictures', that fits its whole floor beside the card and under the note.
func place() -> void:
	var free := _free(_card, _note)
	_scale = scale_beside(_card, _note)
	var window := get_viewport().get_visible_rect().size
	var room := size * _scale
	var at := Vector2(minf((window.x - room.x) * 0.5, window.x - room.x) + 24.0 * _scale, (window.y - room.y) * 0.5)
	var box := Rect2(at + _floor_box.position * _scale, _floor_box.size * _scale)
	var low := free.position - box.position
	var high := free.end - box.end
	at += Vector2(maxf(low.x, minf(0.0, high.x)), maxf(low.y, minf(0.0, high.y)))
	var picture := float(Nav.picture_scale())
	scale = Vector2.ONE * _scale / picture
	position = (at.floor() - Nav.picture_origin()) / picture
	_fit_floor()


## Draws the floor at about the size it shows on screen, so it stays sharp when the window's scale changes.
func _fit_floor() -> void:
	var wide := clampi(int(_floor_box.size.x * _scale * 1.25), 512, 2048)
	_viewport.size = Vector2i(wide, int(ceil(wide * _world.y / _world.x)))
	_camera.zoom = Vector2.ONE * wide / _world.x
