class_name PadGlyph
extends TextureRect
## A controller button's picture beside a key hint, shown only while the player is using a controller.

const DIR := "res://assets/ui/pad/"

## Whether the hint the picture belongs to applies just now; empty for always.
var when := Callable()


static func picture(glyph: String) -> Texture2D:
	return load(DIR + glyph + ".png")


## Pins a button's picture to a control, centred `offset` interface pixels from `anchor` (0 to 1 across and down it).
static func badge(target: Control, glyph: String, anchor: Vector2, offset: Vector2, shown: Callable = Callable()) -> PadGlyph:
	var g := PadGlyph.new()
	g.when = shown
	g.texture = picture(glyph)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.anchor_left = anchor.x
	g.anchor_right = anchor.x
	g.anchor_top = anchor.y
	g.anchor_bottom = anchor.y
	var dims := g.texture.get_size()
	g.offset_left = floorf(offset.x - dims.x * 0.5)
	g.offset_top = floorf(offset.y - dims.y * 0.5)
	g.offset_right = g.offset_left + dims.x
	g.offset_bottom = g.offset_top + dims.y
	target.add_child(g)
	g._process(0.0)
	return g


func _process(_delta: float) -> void:
	visible = Pad.using and (when.is_null() or when.call())
