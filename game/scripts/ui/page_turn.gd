class_name PageTurn
extends Control
## A leaf of an open book turning over its spine, laid over the book once the new spread is already drawn underneath.
## The page lifts from its outer edge, swings over the gutter with the new page printed on its back, and settles flat
## on the other side, its free edge leading as it rises and trailing as it falls. Until the leaf covers it, the page it
## lands on still shows what was there. The whole leaf is one triangle mesh drawn in a single call, so the turn stays
## smooth however finely it is divided.

signal landed

const TIME := 0.55
const COLUMNS := 40
## How far the free edge leads the fold as the leaf rises and trails it as it falls, in radians.
const CURL := 0.5
## How much nearer the viewer a lifted leaf comes, as a share of its height for each page width it rises.
const NEAR := 0.06
## The offscreen pictures keep ten bits a colour, and the leaf drops the last two so its colours are exact eight-bit ones.
const SHADER := """shader_type canvas_item;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() { COLOR = floor(round(texture(TEXTURE, UV) * 1023.0) / 4.0) / 255.0 * tint; }
"""

## 1 turns the right page over to the left, -1 the left page over to the right.
var direction := 1
var left_page := Rect2()
var right_page := Rect2()
## The turning page's face, the page the leaf lands on as it was, and the new page printed on the leaf's back.
var front: Texture2D
var behind: Texture2D
var back: Texture2D
## Draws the book's gutter again over the leaf's root, so the fold stays inside the binding.
var gutter := Callable()
var progress := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 20
	var shader := Shader.new()
	shader.code = SHADER
	material = ShaderMaterial.new()
	material.shader = shader
	var tween := create_tween()
	tween.tween_method(func(p: float):
		progress = p
		queue_redraw(), 0.0, 1.0, TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		landed.emit()
		queue_free())


## Pictures laid-out pages, each with its paper behind it, `scale` window pixels to the book's pixel so the turning
## leaf is as sharp as the book. Each shot is {page, paper, at, size, theme}. Each page is moved into its picture, so a
## page that stays in the book is given as a copy. Each picture is drawn offscreen once, in the frame it is taken, and is
## freed with the leaf.
func capture(shots: Array, scale: int) -> Array:
	var out := []
	for shot in shots:
		var size: Vector2 = shot["size"]
		var port := SubViewport.new()
		port.size = Vector2i(size * scale)
		port.transparent_bg = false
		port.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		port.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(port)
		var root := Control.new()
		root.size = size
		root.scale = Vector2.ONE * scale
		root.theme = shot["theme"]
		root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		port.add_child(root)
		var paper := TextureRect.new()
		paper.texture = shot["paper"]
		paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paper.size = size
		root.add_child(paper)
		var page: Control = shot["page"]
		if page.get_parent():
			page.get_parent().remove_child(page)
		page.position = shot["at"]
		root.add_child(page)
		out.append(port.get_texture())
	return out


## The leaf's outline at a moment of the turn: for each of its columns from the fold out, the x it is drawn at, how
## near the viewer it has risen, and the angle it lies at, 0 flat on its own side and PI flat on the other.
func leaf(p: float) -> Array:
	var w := right_page.size.x
	var lift := sin(PI * p)
	var fold := lerpf(right_page.position.x, left_page.end.x, p) if direction > 0 else lerpf(left_page.end.x, right_page.position.x, p)
	var x := fold
	var z := 0.0
	var out := []
	for i in COLUMNS + 1:
		var u := float(i) / COLUMNS
		var angle := clampf(PI * p + CURL * u * u * sin(TAU * p), 0.0, PI)
		out.append(Vector3(x, z, angle))
		x += direction * cos(angle) * w / COLUMNS
		z += sin(angle) * lift * w / COLUMNS
	return out


func _draw() -> void:
	var p := progress
	var lift := sin(PI * p)
	var landing := left_page if direction > 0 else right_page
	var turning := right_page if direction > 0 else left_page
	if behind:
		draw_texture_rect(behind, landing, false)
	var cols := leaf(p)
	var fold: float = cols[0].x
	# The new page under a lifted leaf darkens towards the fold, where the leaf hangs over it.
	var reach := turning.size.x * 0.45 * lift
	if reach > 1.0:
		_shade(fold, fold + direction * reach, turning, 0.28 * lift)
	var tip: float = cols[COLUMNS].x
	# Ahead of its edge the falling leaf casts a soft shadow on the page it is about to cover.
	if landing.has_point(Vector2(tip, landing.get_center().y)) and lift > 0.05:
		_shade(tip, tip - direction * 18.0 * lift, landing, 0.2 * lift)
	var faces := [_mesh(), _mesh()]
	var w := turning.size.x
	var h := turning.size.y
	var mid := turning.position.y + h / 2.0
	for i in COLUMNS:
		var a: Vector3 = cols[i]
		var b: Vector3 = cols[i + 1]
		var face: int = 0 if cos((a.z + b.z) / 2.0) >= 0.0 else 1
		var mesh: Dictionary = faces[face]
		var u0 := float(i) / COLUMNS
		var u1 := float(i + 1) / COLUMNS
		# The front's inner edge is at the spine; the back is the landing page seen from behind, its inner edge too.
		var inner_left := (direction > 0) == (face == 0)
		var s0 := u0 if inner_left else 1.0 - u0
		var s1 := u1 if inner_left else 1.0 - u1
		var light0 := 0.62 + 0.38 * absf(cos(a.z))
		var light1 := 0.62 + 0.38 * absf(cos(b.z))
		var near0 := 1.0 + NEAR * a.y / w
		var near1 := 1.0 + NEAR * b.y / w
		var n: int = mesh["points"].size()
		mesh["points"].append_array(PackedVector2Array([
			Vector2(a.x, mid - h / 2.0 * near0), Vector2(b.x, mid - h / 2.0 * near1),
			Vector2(b.x, mid + h / 2.0 * near1), Vector2(a.x, mid + h / 2.0 * near0)]))
		mesh["uvs"].append_array(PackedVector2Array([Vector2(s0, 0), Vector2(s1, 0), Vector2(s1, 1), Vector2(s0, 1)]))
		var c0 := Color(light0, light0, light0)
		var c1 := Color(light1, light1, light1)
		mesh["colours"].append_array(PackedColorArray([c0, c1, c1, c0]))
		mesh["indices"].append_array(PackedInt32Array([n, n + 1, n + 2, n, n + 2, n + 3]))
	var textures := [front, back if back else behind]
	for face in 2:
		var mesh: Dictionary = faces[face]
		var texture: Texture2D = textures[face]
		if mesh["indices"].is_empty() or texture == null:
			continue
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), mesh["indices"], mesh["points"], mesh["colours"],
			mesh["uvs"], PackedInt32Array(), PackedFloat32Array(), texture.get_rid())
	if gutter.is_valid():
		gutter.call(self)


static func _mesh() -> Dictionary:
	return {"points": PackedVector2Array(), "uvs": PackedVector2Array(), "colours": PackedColorArray(), "indices": PackedInt32Array()}


## A band of shadow across a page from x `from`, where it is `dark`, fading out by x `to`.
func _shade(from: float, to: float, page: Rect2, dark: float) -> void:
	var a := clampf(from, page.position.x, page.end.x)
	var b := clampf(to, page.position.x, page.end.x)
	if absf(b - a) < 1.0:
		return
	var ink := Color(0.16, 0.1, 0.06, dark)
	var clear := Color(ink, 0.0)
	draw_polygon(PackedVector2Array([Vector2(a, page.position.y), Vector2(b, page.position.y), Vector2(b, page.end.y),
		Vector2(a, page.end.y)]), PackedColorArray([ink, clear, clear, ink]))
