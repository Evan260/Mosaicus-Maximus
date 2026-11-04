class_name LampGlow
extends TextureRect
## A lit lamp's warm light, added over the room: it flickers a little, breathes in size, and is strongest at night.

var night := 0.0
var power := 1.0
var _t := 0.0


static func make(centre: Vector2, radius: float, strength: float = 1.0) -> LampGlow:
	var g := LampGlow.new()
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1.0, 0.76, 0.42, 0.85), Color(1.0, 0.64, 0.32, 0.32), Color(1.0, 0.56, 0.26, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	g.texture = tex
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_SCALE
	g.size = Vector2.ONE * radius * 2.0
	g.position = centre - g.size * 0.5
	g.pivot_offset = g.size * 0.5
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.power = strength
	g._t = randf() * 10.0
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = add
	return g


func _process(delta: float) -> void:
	_t += delta
	var flicker := 0.86 + 0.09 * sin(_t * 9.0) + 0.05 * sin(_t * 23.0) + randf() * 0.03
	modulate.a = clampf((0.12 + 0.88 * night) * flicker * power, 0.0, 1.0)
	scale = Vector2.ONE * (0.97 + 0.03 * sin(_t * 5.3))
