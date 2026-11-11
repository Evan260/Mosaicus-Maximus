class_name RoomView
extends Control
## A client's room with the finished floor laid in it. The room is one painting with a gap where its floor is; the
## floor is drawn behind that gap in perspective, from a live picture of the real floor, so it is sharp at any window
## size and its band of light still runs across it.

const ART := "res://assets/art/rooms/"

var floor_view: FloorView
var _viewport: SubViewport
var _camera: Camera2D
var _world := Vector2.ONE
var _floor_width := 0.0

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
	_floor_width = box.size.x
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
	_fit_floor()
	Nav.resized.connect(_fit_floor)
	Nav.resized.connect(place)
	place()
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


## Sets the room right of centre on the picture layer, leaving the left side for the client's card.
func place() -> void:
	var view := Nav.picture_view()
	var x := minf((view.size.x - size.x) * 0.5 + 24.0, view.size.x - size.x + 24.0)
	position = (view.position + Vector2(x, (view.size.y - size.y) * 0.5)).floor()


## Draws the floor at about the size it shows on screen, so it stays sharp when the window's scale changes.
func _fit_floor() -> void:
	var wide := clampi(int(_floor_width * Nav.picture_scale() * 1.25), 512, 2048)
	_viewport.size = Vector2i(wide, int(ceil(wide * _world.y / _world.x)))
	_camera.zoom = Vector2.ONE * wide / _world.x
