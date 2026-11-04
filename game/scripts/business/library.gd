class_name Library
## The floors the player chose to keep: a picture of each, and the order its tiles went down, so the library can play
## the laying back. Kept in the game's own folder and shared by every workshop, free designs included.

const THUMB := 112
const PICTURE := 960

static var dir := "user://library/"
## Off for scripted runs, like saving, so a test never fills the real library.
static var enabled := true


static func add(design: FloorDesign, order: PackedInt32Array, picture: Image, info: Dictionary) -> String:
	if not enabled:
		return ""
	DirAccess.make_dir_recursive_absolute(dir)
	var id := "floor_%d" % int(Time.get_unix_time_from_system() * 1000.0)
	picture.save_png(dir.path_join(id + ".png"))
	var thumb := picture.duplicate() as Image
	var k := float(THUMB) / maxf(thumb.get_width(), thumb.get_height())
	thumb.resize(maxi(1, int(thumb.get_width() * k)), maxi(1, int(thumb.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	thumb.save_png(dir.path_join(id + "_thumb.png"))
	var entry := info.duplicate()
	entry["id"] = id
	entry["design"] = design.to_dict()
	entry["order"] = Marshalls.raw_to_base64(order.to_byte_array()) if not order.is_empty() else ""
	entry["kept"] = Time.get_date_string_from_system()
	var f := FileAccess.open(dir.path_join(id + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(entry))
	f.close()
	return id


## Every kept floor, newest first.
static func entries() -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for file in d.get_files():
		if not file.ends_with(".json"):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(file)))
		if parsed is Dictionary and parsed.has("design"):
			out.append(parsed)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) > str(b["id"]))
	return out


static func order_of(entry: Dictionary) -> PackedInt32Array:
	var text := str(entry.get("order", ""))
	return Marshalls.base64_to_raw(text).to_int32_array() if text != "" else PackedInt32Array()


static func picture(entry: Dictionary, thumb: bool = false) -> Texture2D:
	var path := dir.path_join(str(entry["id"]) + ("_thumb.png" if thumb else ".png"))
	var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
	return ImageTexture.create_from_image(img) if img else null


static func remove(entry: Dictionary) -> void:
	for suffix in [".json", ".png", "_thumb.png"]:
		var path := dir.path_join(str(entry["id"]) + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Where exported copies go, so a floor can be shared: a folder in the player's Pictures.
static func export_dir() -> String:
	var base := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if base == "":
		base = OS.get_user_data_dir()
	return base.path_join("Roman Mosaic Workshop")


static func export_picture(entry: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(export_dir())
	var src := dir.path_join(str(entry["id"]) + ".png")
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(src), export_dir().path_join(str(entry["id"]) + ".png")) == OK


static func export_gif(entry: Dictionary, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(export_dir())
	var f := FileAccess.open(export_dir().path_join(str(entry["id"]) + ".gif"), FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	return true


## A clean picture of a finished floor in its walls, drawn off screen at a fixed size. Waits for one frame to draw.
static func photograph(layout: MosaicLayout, host: Node, stones: Dictionary = {}) -> Image:
	var floor_view := FloorView.new()
	var room := Vector2(layout.w, layout.h) * FloorView.WORLD
	var wall := FloorView.WALL * layout.px * FloorView.WORLD * 0.55
	var area := room + Vector2.ONE * wall * 2.0
	var k := float(PICTURE) / maxf(area.x, area.y)
	var vp := SubViewport.new()
	vp.size = Vector2i((area * k).ceil())
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	vp.add_child(floor_view)
	floor_view.setup(layout)
	floor_view.chalk_visible = false
	floor_view.show_finished()
	floor_view.apply_stones(stones)
	var cam := Camera2D.new()
	cam.position = room * 0.5
	cam.zoom = Vector2.ONE * k
	vp.add_child(cam)
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img
