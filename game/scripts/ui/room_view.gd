class_name RoomView
extends Control
## A client's room with the finished floor laid in it. The room is one painting with a gap where its floor is; the
## floor is drawn behind that gap in perspective, from a live picture of the real floor, so it is sharp at any window
## size and its band of light still runs across it.

const ART := "res://assets/art/rooms/"

var floor_view: FloorView

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
	var world := Vector2(layout.w, layout.h) * FloorView.WORLD
	var wide := clampi(int(box.size.x * Nav.scale_factor() * 1.25), 512, 2048)
	var vp := SubViewport.new()
	vp.size = Vector2i(wide, int(ceil(wide * world.y / world.x)))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	floor_view = FloorView.new()
	floor_view.walls_visible = false
	vp.add_child(floor_view)
	floor_view.setup(layout)
	floor_view.chalk_visible = false
	floor_view.show_finished()
	floor_view.apply_stones(stones)
	var cam := Camera2D.new()
	cam.position = world * 0.5
	cam.zoom = Vector2.ONE * wide / world.x
	vp.add_child(cam)
	cam.make_current()
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
